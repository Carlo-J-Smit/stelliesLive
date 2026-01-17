import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();
const db = getFirestore();
const storageBucket = getStorage().bucket();
const messaging = getMessaging();


const GROUP_RADIUS_METERS = 100;
const LOCATION_CONFIDENCE_SATURATION = 50;

const busynessToScore = (b: string) =>
  b === "Quiet" ? 0 : b === "Moderate" ? 1 : 2;
  


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

function bayesianBusyness(scores: number[]): number {
  let q = 0, m = 0, b = 0;

  for (const s of scores) {
    if (s === 0) q++;
    else if (s === 1) m++;
    else b++;
  }

  // Prior: [Quiet, Moderate, Busy]
  const pq = 0.1;  // minimal smoothing, barely affects real votes
  const pm = 0.05; // very low, just to avoid division by zero
  const pb = 0.1;  // minimal smoothing

  return (
    0 * (q + pq) +
    1 * (m + pm) +
    2 * (b + pb)
  ) / ((q + pq) + (m + pm) + (b + pb));
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
    const cutoff = Timestamp.fromMillis(now - 30 * 60 * 1000); // last 30 mins

    // 1️⃣ Fetch recent location logs
    const logSnap = await db
      .collection("location_logs")
      .where("timestamp", ">=", cutoff)
      .get();

    const logs = logSnap.docs
      .map(d => d.data())
      .filter(l => typeof l.lat === "number" && typeof l.lng === "number");

    if (!logs.length) return;

    // 2️⃣ Fetch recent feedback
    const feedbackSnap = await db
      .collection("event_feedback")
      .where("timestamp", ">=", cutoff)
      .get();

    const feedbackByEvent = new Map<string, number[]>();
    feedbackSnap.docs.forEach(doc => {
      const f = doc.data();
      if (!f.eventId || !f.busyness) return;
      const score = busynessToScore(f.busyness);
      if (!feedbackByEvent.has(f.eventId)) feedbackByEvent.set(f.eventId, []);
      feedbackByEvent.get(f.eventId)!.push(score);
    });

    // 3️⃣ Fetch all events
    const eventSnap = await db.collection("events").get();
    const batch = db.batch();
    let updatedCount = 0;

    for (const snap of eventSnap.docs) {
      const eventData = snap.data();
      const lat = eventData?.location?.lat;
      const lng = eventData?.location?.lng;
      if (typeof lat !== "number" || typeof lng !== "number") continue;

      // 4️⃣ Count location logs near this event
      const nearbyLogs = logs.filter(l => distance(lat, lng, l.lat, l.lng) <= GROUP_RADIUS_METERS);
      const locationScore =
        nearbyLogs.length < 3 ? 0 :
        nearbyLogs.length < 6 ? 1 : 1.75;

      // 5️⃣ Feedback score (bayesian smoothing)
      const feedbackScores = feedbackByEvent.get(snap.id) || [];
      const feedbackScore =
        feedbackScores.length ? bayesianBusyness(feedbackScores) : 0;

      // 6️⃣ Weighted final busyness (trust feedback > faraway logs)
      const locationConfidence = Math.min(nearbyLogs.length / LOCATION_CONFIDENCE_SATURATION, 1);
      const locationWeight = 0.3 * locationConfidence; // reduced weight
      const feedbackWeight = 1 - locationWeight;

      const normalizedLocationScore = locationScore / 2;
      const normalizedFeedbackScore = feedbackScore / 2;
      const weighted = locationWeight * normalizedLocationScore + feedbackWeight * normalizedFeedbackScore;

      // 7️⃣ Determine busyness level
      const finalLevel =
        weighted >= 0.6 ? "Busy" :
        weighted >= 0.3 ? "Moderate" :
        "Quiet";

      batch.update(snap.ref, {
        busynessLevel: finalLevel,
        busynessUpdatedAt: Timestamp.now(),
      });

      updatedCount++;
    }

    if (updatedCount) await batch.commit();
  }
);


export const cleanUpOldEvents = onDocumentUpdated(
  {
    document: "events/{eventId}",
    region: "africa-south1",
    memory: "256MiB",
    cpu: 1,
  },
  async () => {
    const now = Date.now();
    const cutoff = Timestamp.fromMillis(now - 12 * 60 * 60 * 1000); // 24h ago

    // Fetch all single-use events older than 24h
    const oldEventsSnap = await db
      .collection("events")
      .where("recurring", "==", false)
      .where("dateTime", "<", cutoff)
      .get();

    if (oldEventsSnap.empty) return;

    for (const doc of oldEventsSnap.docs) {
      const eventId = doc.id;

      const foldersToDelete = [
        `event_pics/${eventId}/`,
        `event_icon/${eventId}/`,
      ];

      try {
        // Delete storage files
        for (const prefix of foldersToDelete) {
          const [files] = await storageBucket.getFiles({ prefix });
          for (const file of files) {
            try { await file.delete(); } catch (err) { }
          }
        }

        // Delete Firestore document
        await doc.ref.delete();
      } catch (err) {
        console.error(`Failed to delete old event ${eventId}`, err);
      }
    }
  }
);



export const sendNotification = onDocumentCreated(
  {
    document: "notifications/{notificationId}",
    region: "africa-south1",
    memory: "256MiB",
    cpu: 1,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const ref = snap.ref;

    // --- Safety checks ---
    if (!data?.title || !data?.message || !data?.business || !data?.type) {
      await ref.update({
        status: "Failed",
        error: "Missing required fields: title, message, business, or type",
        processedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    // Compose the topic based on business + type
    const topic = `business_${data.business}_${(data.type as string).toLowerCase()}`;

    const message = {
      notification: {
        title: data.title,
        body: data.message,
      },
      data: {
        type: data.type,
        eventId: data.eventId ?? "",
        business: data.business,
      },
      topic,
    };

    try {
      await messaging.send(message);

      await ref.update({
        status: "Sent",
        processedAt: FieldValue.serverTimestamp(),
      });

      
    } catch (err: any) {
      console.error(`Failed to send notification to ${topic}`, err);

      await ref.update({
        status: "Failed",
        error: err.message ?? String(err),
        processedAt: FieldValue.serverTimestamp(),
      });
    }
  }
);
