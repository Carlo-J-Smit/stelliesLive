import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();
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
  if (count < 30) return "Quiet";
  if (count < 150) return "Moderate";
  return "Busy";
}

export const handleNewLocationLog = onDocumentCreated(
  {
    document: "location_logs/{logId}",
    region: "africa-south1",
  },
  async (event) => {
    logger.log("📍 New location log created. Recomputing clusters...");

    // --- Step 1: Fetch recent location logs (past 30 mins)
    const thirtyMinutesAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 30 * 60 * 1000);
    const snapshot = await db.collection("location_logs")
      .where("timestamp", ">=", thirtyMinutesAgo)
      .get();

    const logs = snapshot.docs.map(doc => doc.data())
      .filter(log => log.lat && log.lng);

    // --- Step 2: Form spatial groups
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

    // --- Step 3: Write clusters to Firestore
    const clusterRef = db.collection("popularity_clusters");
    const batch = db.batch();

    const existing = await clusterRef.get();
    existing.docs.forEach(doc => batch.delete(doc.ref));

    groups.forEach((group, index) => {
      const avgLat = group.reduce((sum, p) => sum + p.lat, 0) / group.length;
      const avgLng = group.reduce((sum, p) => sum + p.lng, 0) / group.length;

      batch.set(clusterRef.doc(`cluster_${index}`), {
        lat: avgLat,
        lng: avgLng,
        count: group.length,
        level: inferLevel(group.length),
        updated: admin.firestore.Timestamp.now(),
      });
    });

    // --- Step 4: Merge with feedback
    const feedbackSnap = await db.collection("event_feedback")
      .where("timestamp", ">=", thirtyMinutesAgo)
      .get();

    const feedbackMap = new Map<string, number[]>();
    feedbackSnap.docs.forEach(doc => {
      const data = doc.data();
      const level = data.busyness;
      const score = level === "Quiet" ? 0 : level === "Moderate" ? 1 : 2;
      const clusterId = data.clusterId;
      if (!feedbackMap.has(clusterId)) feedbackMap.set(clusterId, []);
      feedbackMap.get(clusterId)!.push(score);
    });

    const mergedRef = db.collection("merged_clusters");
    const mergedSnap = await mergedRef.get();
    mergedSnap.forEach(doc => batch.delete(doc.ref));

    for (const doc of (await clusterRef.get()).docs) {
      const data = doc.data();
      const clusterId = doc.id;
      const locationCount = data.count || 0;
      const locationScore = locationCount < 30 ? 0 : locationCount < 150 ? 1 : 2;
      const feedbacks = feedbackMap.get(clusterId) ?? [];

      if (locationCount < 5 && feedbacks.length === 0) {
        logger.log(`⚠️ Skipping cluster ${clusterId} — too few logs and no feedback.`);
        continue;
      }

      const feedbackScore = feedbacks.length
        ? feedbacks.reduce((a, b) => a + b, 0) / feedbacks.length
        : locationScore;

      const weighted = 0.3 * locationScore + 0.7 * feedbackScore;
      const finalLevel = weighted >= 1.5 ? "Busy" : weighted >= 0.5 ? "Moderate" : "Quiet";

      batch.set(mergedRef.doc(clusterId), {
        lat: data.lat,
        lng: data.lng,
        level: finalLevel,
        updated: admin.firestore.Timestamp.now(),
      });
    }

    // --- Step 5: Delete stale logs and feedbacks
    const oldCutoffDate = new Date(Date.now() - 30 * 60 * 1000);

    const oldLogs = await db.collection("location_logs")
      .where("timestamp", "<", oldCutoffDate)
      .get();

    const oldFeedback = await db.collection("event_feedback")
      .where("timestamp", "<", oldCutoffDate)
      .get();

    oldLogs.forEach(doc => batch.delete(doc.ref));
    oldFeedback.forEach(doc => batch.delete(doc.ref));

    // --- Final commit
    await batch.commit();
    logger.log("✅ Clusters updated, merged, and stale data cleaned up.");
  }
);

