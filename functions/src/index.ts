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
  console.log("🚀 Busyness job started");

  const now = Date.now();
  const cutoff = Timestamp.fromMillis(now - 30 * 60 * 1000);

  /* ────────────────────────────────────────────────
   * 1️⃣ Fetch recent location logs
   * ──────────────────────────────────────────────── */
  const logSnap = await db
    .collection("location_logs")
    .where("timestamp", ">=", cutoff)
    .get();

  console.log(`📍 Location logs fetched: ${logSnap.size}`);

  const logs = logSnap.docs
    .map(d => d.data())
    .filter(l =>
      typeof l.lat === "number" &&
      typeof l.lng === "number"
    );

  console.log(`📍 Valid logs after filtering: ${logs.length}`);

  if (!logs.length) {
    console.warn("⚠️ No valid location logs, exiting");
    return;
  }

  /* ────────────────────────────────────────────────
   * 2️⃣ Cluster logs
   * ──────────────────────────────────────────────── */
  const clusters: { lat: number; lng: number; count: number }[] = [];

  logs.forEach(log => {
    let assigned = false;

    for (const cluster of clusters) {
      if (
        distance(log.lat, log.lng, cluster.lat, cluster.lng) <
        GROUP_RADIUS_METERS
      ) {
        cluster.lat =
          (cluster.lat * cluster.count + log.lat) / (cluster.count + 1);
        cluster.lng =
          (cluster.lng * cluster.count + log.lng) / (cluster.count + 1);
        cluster.count++;
        assigned = true;
        break;
      }
    }

    if (!assigned) {
      clusters.push({ lat: log.lat, lng: log.lng, count: 1 });
    }
  });

  console.log(`🧠 Clusters created: ${clusters.length}`);
  clusters.forEach((c, i) =>
    console.log(`  └─ Cluster ${i}: count=${c.count}`)
  );

  /* ────────────────────────────────────────────────
   * 3️⃣ Fetch recent feedback
   * ──────────────────────────────────────────────── */
  const feedbackSnap = await db
    .collection("event_feedback")
    .where("timestamp", ">=", cutoff)
    .get();

  console.log(`🗣️ Feedback entries fetched: ${feedbackSnap.size}`);

  const feedbackByEvent = new Map<string, number[]>();

  feedbackSnap.docs.forEach(doc => {
    const f = doc.data();

    if (!f.eventId || !f.busyness) {
      console.warn("⚠️ Invalid feedback doc:", doc.id);
      return;
    }

    const score = busynessToScore(f.busyness);

    if (!feedbackByEvent.has(f.eventId)) {
      feedbackByEvent.set(f.eventId, []);
    }
    feedbackByEvent.get(f.eventId)!.push(score);
  });

  console.log(`🗂️ Events with feedback: ${feedbackByEvent.size}`);

  /* ────────────────────────────────────────────────
   * 4️⃣ Fetch ALL events near clusters
   * ──────────────────────────────────────────────── */
  const eventSnap = await db.collection("events").get();
  console.log(`🎪 Events fetched: ${eventSnap.size}`);

  const batch = db.batch();
  let updatedCount = 0;

  /* ────────────────────────────────────────────────
   * 5️⃣ Compute busyness per event
   * ──────────────────────────────────────────────── */
  for (const snap of eventSnap.docs) {
    const eventData = snap.data();
    
    const lat = eventData?.location?.lat;
    const lng = eventData?.location?.lng;

     if (typeof lat !== "number" || typeof lng !== "number") {
    console.warn(
      `⚠️ Event ${snap.id} missing coordinates`,
      {
        location: eventData?.location ?? null,
      }
    );
    continue;
  }
   console.log(
    `📍 Event ${snap.id} coordinates OK: lat=${lat}, lng=${lng}`
  );

    let nearest: any = null;
    let minDist = Infinity;

    for (const cluster of clusters) {
      const d = distance(lat, lng, cluster.lat, cluster.lng);
      if (d < minDist) {
        minDist = d;
        nearest = cluster;
      }
    }

    if (!nearest) continue;

    const locationScore =
      nearest.count < 3 ? 0 :
      nearest.count < 6 ? 1 : 1.75;

    const feedbackScores = feedbackByEvent.get(snap.id) || [];

    // Bayesian-smoothed feedback score
    const feedbackScore =
      feedbackScores.length
        ? bayesianBusyness(feedbackScores)
        : locationScore;

    // Dynamic location weighting
    const locationConfidence = Math.min(
      nearest.count / LOCATION_CONFIDENCE_SATURATION,
      1
    );
    const locationWeight = 0.5 * locationConfidence;
    const feedbackWeight = 1 - locationWeight;

    // Normalize scores to [0,1]
    const normalizedLocationScore = locationScore / 2;
    const normalizedFeedbackScore = feedbackScore / 2;

    // Weighted final score
    const weighted = locationWeight * normalizedLocationScore + feedbackWeight * normalizedFeedbackScore;

    // Determine final busyness level
    const finalLevel =
      weighted >= 0.6 ? "Busy" :
      weighted >= 0.3 ? "Moderate" :
      "Quiet";

    // Count feedback buckets for detailed debug
    let q = 0, m = 0, b = 0;
    for (const s of feedbackScores) {
      if (s === 0) q++;
      else if (s === 1) m++;
      else b++;
    }

    // Priors (must match bayesianBusyness)
    const pq = 0.1, pm = 0.05, pb = 0.1;

    // Bayes numerator / denominator (for logging clarity)
    const bayesianNumerator = 0 * (q + pq) + 1 * (m + pm) + 2 * (b + pb);
    const bayesianDenominator = (q + pq) + (m + pm) + (b + pb);

    /* 🔍 FULL DEBUG — BUSYNESS CALCULATION */
    console.log(
      "📊 Busyness calc",
      {
        eventId: snap.id,
        clusterCount: nearest.count,
        locationScore,
        normalizedLocationScore: Number(normalizedLocationScore.toFixed(2)),

        feedbackCount: feedbackScores.length,
        feedbackScores,
        feedbackBreakdown: { Quiet: q, Moderate: m, Busy: b },
        normalizedFeedbackScore: Number(normalizedFeedbackScore.toFixed(2)),

        priors: { Quiet: pq, Moderate: pm, Busy: pb },
        bayesian: {
          numerator: bayesianNumerator,
          denominator: bayesianDenominator,
          score: Number(feedbackScore.toFixed(2)),
        },

        locationConfidence: Number(locationConfidence.toFixed(2)),
        locationWeight: Number(locationWeight.toFixed(2)),
        feedbackWeight: Number(feedbackWeight.toFixed(2)),

        weighted: Number(weighted.toFixed(2)),
        finalLevel,
      }
    );


    console.log(
      `📊 Event ${snap.id}: loc=${locationScore}, fb=${feedbackScores.length}, final=${finalLevel}`
    );

    batch.update(snap.ref, {
      busynessLevel: finalLevel,
      busynessUpdatedAt: Timestamp.now(),
    });

    updatedCount++;
  }

  if (!updatedCount) {
    console.warn("⚠️ No events updated");
  } else {
    await batch.commit();
    console.log(`✅ Busyness updated for ${updatedCount} events`);
  }
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
      const foldersToDelete = [
        `event_pics/${eventId}/`,
        `event_icon/${eventId}/`
      ];
      let deletedFiles = 0;

      try {
        for (const folderPrefix of foldersToDelete) {
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
