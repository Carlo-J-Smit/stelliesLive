import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
admin.initializeApp();

const db = admin.firestore();
const GROUP_RADIUS_METERS = 50;

function distance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const toRad = (deg: number) => deg * Math.PI / 180;

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function inferLevel(count: number): string {
  if (count < 30) return "Quiet";
  if (count < 150) return "Moderate";
  return "Busy";
}

export const updatePopularityClusters = onDocumentCreated("location_logs/{logId}", async (event) => {
  logger.log("📍 New location log created. Recomputing clusters...");

  const thirtyMinutesAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 30 * 60 * 1000);

  const snapshot = await db.collection("location_logs")
    .where("timestamp", ">=", thirtyMinutesAgo)
    .get();

  const logs = snapshot.docs.map(doc => doc.data())
    .filter(log => log.lat && log.lng);

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

  const batch = db.batch();
  const clusterRef = db.collection("popularity_clusters");

  // Clear old clusters
  const existing = await clusterRef.get();
  existing.docs.forEach(doc => batch.delete(doc.ref));

  groups.forEach((group, index) => {
    const avgLat = group.reduce((sum, p) => sum + p.lat, 0) / group.length;
    const avgLng = group.reduce((sum, p) => sum + p.lng, 0) / group.length;

    const id = `cluster_${index}`;
    batch.set(clusterRef.doc(id), {
      lat: avgLat,
      lng: avgLng,
      count: group.length,
      level: inferLevel(group.length),
      updated: admin.firestore.Timestamp.now(),
    });
  });

  await batch.commit();
  logger.log("✅ Clusters updated successfully.");
});

import { onSchedule } from "firebase-functions/v2/scheduler";

export const decayClusterWeights = onSchedule("every 5 minutes", async () => {
  const snapshot = await db.collection("popularity_clusters").get();

  const batch = db.batch();

  snapshot.docs.forEach(doc => {
    const data = doc.data();
    const current = data.count || 0;

    // Decrease by 1 every 5 min, but clamp to minimum 0
    const decayed = Math.max(0, current - 1);

    batch.update(doc.ref, {
      count: decayed,
      level: inferLevel(decayed),
      updated: admin.firestore.Timestamp.now()
    });
  });

  await batch.commit();
  logger.log("✅ Decayed cluster weights.");
});


export const mergeClusterWithFeedback = onSchedule("every 2 minutes", async () => {
  const now = Date.now();
  const cutoff = admin.firestore.Timestamp.fromMillis(now - 30 * 60 * 1000);

  const clusters = await db.collection("popularity_clusters").get();
  const feedbacks = await db.collection("event_feedback")
    .where("timestamp", ">=", cutoff)
    .get();

  const feedbackMap = new Map<string, number[]>(); // clusterId → feedback scores

  feedbacks.docs.forEach(doc => {
    const data = doc.data();
    const level = data.busyness;
    const score = level === "Quiet" ? 0 : level === "Moderate" ? 1 : 2;

    const clusterId = data.clusterId;
    if (!feedbackMap.has(clusterId)) feedbackMap.set(clusterId, []);
    feedbackMap.get(clusterId)!.push(score);
  });

  const batch = db.batch();
  const output = db.collection("merged_clusters");

  for (const cluster of clusters.docs) {
    const data = cluster.data();
    const clusterId = cluster.id;
    const locationScore = data.count < 30 ? 0 : data.count < 150 ? 1 : 2;

    const feedbacks = feedbackMap.get(clusterId) ?? [];
    const feedbackScore = feedbacks.length
      ? feedbacks.reduce((a, b) => a + b, 0) / feedbacks.length
      : locationScore;

    const weighted = 0.3 * locationScore + 0.7 * feedbackScore;

    let finalLevel = "Quiet";
    if (weighted >= 1.5) finalLevel = "Busy";
    else if (weighted >= 0.5) finalLevel = "Moderate";

    batch.set(output.doc(clusterId), {
      lat: data.lat,
      lng: data.lng,
      level: finalLevel,
      updated: admin.firestore.Timestamp.now(),
    });
  }

  await batch.commit();
  logger.log("✅ Merged clusters updated with feedback weighting.");
});



