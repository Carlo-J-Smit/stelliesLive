import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

initializeApp();
const db = getFirestore();
const storageBucket = getStorage().bucket();


const GROUP_RADIUS_METERS = 100;

function distance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const toRad = (deg: number) => deg * Math.PI / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function inferLevel(count: number): string {
  if (count < 3) return "Quiet";
  if (count < 6) return "Moderate";
  return "Busy";
}

export const handleLocationLog = onDocumentCreated(
  {
    document: "location_logs/{logId}",
    region: "africa-south1",
    memory: "256MiB", // Fast enough, no cold start spike
    cpu: 1,
  },
  async (event) => {

    const now = Date.now();
    const cutoff = Timestamp.fromMillis(now - 30 * 60 * 1000);

    // 🔹 Step 1: Fetch last 30 mins of logs
    const logSnap = await db.collection("location_logs")
      .where("timestamp", ">=", cutoff)
      .get();

    const logs = logSnap.docs
      .map(doc => doc.data())
      .filter(log => log.lat && log.lng);

    if (logs.length === 0) {
      return;
    }

    // 🔹 Step 2: Cluster logs
    const groups: { lat: number; lng: number }[][] = [];

    logs.forEach(log => {
      const point = { lat: log.lat, lng: log.lng };
      let added = false;

      for (const group of groups) {
        if (group.some(member =>
          distance(point.lat, point.lng, member.lat, member.lng) < GROUP_RADIUS_METERS
        )) {
          group.push(point);
          added = true;
          break;
        }
      }

      if (!added) groups.push([point]);
    });

    // 🔹 Step 3: Wipe old clusters
    const clusterRef = db.collection("popularity_clusters");
    const mergedRef = db.collection("merged_clusters");

    const [popSnap, mergedSnap] = await Promise.all([
      clusterRef.get(),
      mergedRef.get()
    ]);

    const batch = db.batch();
    popSnap.docs.forEach(doc => batch.delete(doc.ref));
    mergedSnap.docs.forEach(doc => batch.delete(doc.ref));

    // 🔹 Step 4: Write new popularity_clusters
    const clusterDataMap = new Map<string, any>();
    groups.forEach((group, index) => {
      const avgLat = group.reduce((sum, p) => sum + p.lat, 0) / group.length;
      const avgLng = group.reduce((sum, p) => sum + p.lng, 0) / group.length;
      const count = group.length;
      const level = inferLevel(count);
      const id = `cluster_${index}`;

      const data = {
        lat: avgLat,
        lng: avgLng,
        count,
        level,
        updated: Timestamp.now(),
      };

      batch.set(clusterRef.doc(id), data);
      clusterDataMap.set(id, data); // For merging
    });

    // 🔹 Step 5: Merge clusters with recent feedback
    const feedbackSnap = await db.collection("event_feedback")
      .where("timestamp", ">=", cutoff)
      .get();

    const feedbackMap = new Map<string, number[]>();
    feedbackSnap.docs.forEach(doc => {
      const data = doc.data();
      const score = data.busyness === "Quiet" ? 0 : data.busyness === "Moderate" ? 1 : 2;
      const clusterId = data.clusterId;
      if (!feedbackMap.has(clusterId)) feedbackMap.set(clusterId, []);
      feedbackMap.get(clusterId)!.push(score);
    });

    for (const [clusterId, cluster] of clusterDataMap.entries()) {
      const locationScore = cluster.count < 3 ? 0 : cluster.count < 6 ? 1 : 2;
      const feedbackScores = feedbackMap.get(clusterId) || [];

      if (cluster.count < 2 && feedbackScores.length === 0) continue;

      const feedbackScore = feedbackScores.length
        ? feedbackScores.reduce((a, b) => a + b, 0) / feedbackScores.length
        : locationScore;

      const weighted = 0.3 * locationScore + 0.7 * feedbackScore;
      const finalLevel = weighted >= 1.5 ? "Busy" : weighted >= 0.5 ? "Moderate" : "Quiet";

      batch.set(mergedRef.doc(clusterId), {
        lat: cluster.lat,
        lng: cluster.lng,
        level: finalLevel,
        updated: Timestamp.now(),
      });
    }

    await batch.commit();
  }
);


export const cleanUpOldEvents = onDocumentUpdated(
  {
    document: "events/{eventId}",
    region: "africa-south1",
    memory: "256MiB",
    cpu: 1,
  },
  async (event) => {

    const change = event.data;
    if (!change) return; // TS-safe: event.data can be undefined

    const after = change.after; // OK now
    const eventId = after.id;
    const docData = after.data();

    if (!docData) {
      console.log(`Event ${eventId} has no data, skipping.`);
      return;
    }

    const eventTime = docData.dateTime?.toMillis?.();

    // Only delete if single-use and event was >24h ago
    if (!docData.recurring && eventTime && eventTime < Date.now() - 24 * 60 * 60 * 1000) {
      const folderPrefix = `event_pics/${eventId}/`;
      let deletedFiles = 0;

      try {
        const [files] = await storageBucket.getFiles({ prefix: folderPrefix });

        for (const file of files) {
          try {
            await file.delete();
            deletedFiles++;
            console.log(`Deleted file: ${file.name}`);
          } catch (err) {
            console.error(`Cannot delete file ${file.name}:`, err);
          }
        }

        await after.ref.delete();
        console.log(`Deleted event ${eventId} and ${deletedFiles} image(s).`);
      } catch (err) {
        console.error(`Error cleaning up event ${eventId}:`, err);
      }
    } else {
      console.log(`Event ${eventId} not expired or recurring, skipping cleanup.`);
    }
  }
);

