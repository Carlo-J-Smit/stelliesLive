// ping-simulation.ts

import * as admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';
import * as path from 'path';

// 🔐 Load credentials FIRST before touching anything Firestore
const serviceAccount = require(path.resolve(__dirname, 'stellieslive-firebase-adminsdk-fbsvc-073c038be1.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
console.log("✅ Firebase Admin initialized with custom service account.");

// 🔥 Get Firestore AFTER init
const db = new admin.firestore.Firestore({
  projectId: serviceAccount.project_id,
  credentials: {
    client_email: serviceAccount.client_email,
    private_key: serviceAccount.private_key,
  },
});


// 🎯 Stellenbosch University center point
const centerLat = -33.9341;
const centerLng = 18.8610;
const radiusMeters = 1000;

function generateRandomPointInRadius() {
  const r = radiusMeters / 111320; // ~1 degree = 111.32 km
  const u = Math.random();
  const v = Math.random();
  const w = r * Math.sqrt(u);
  const t = 2 * Math.PI * v;
  const x = w * Math.cos(t);
  const y = w * Math.sin(t);

  return {
    lat: centerLat + y,
    lng: centerLng + x,
  };
}

async function simulatePing(index: number) {
  const { lat, lng } = generateRandomPointInRadius();
  const timestamp = admin.firestore.Timestamp.now();
  const userId = `test_user_${uuidv4().slice(0, 6)}`;

  await db.collection('location_logs').add({
    userId,
    lat,
    lng,
    timestamp,
  });

  console.log(`📍 Ping ${index + 1}: ${userId} at (${lat.toFixed(5)}, ${lng.toFixed(5)})`);
}

async function runSimulation() {
  const durationMinutes = 20;      // ⏱️ 10 minutes
  const intervalSeconds = 1;      // 🔁 every 10s
  const totalPings = (durationMinutes * 60) / intervalSeconds;

  console.log(`🚀 Starting simulation: ${totalPings} pings every ${intervalSeconds}s`);

  for (let i = 0; i < totalPings; i++) {
    await simulatePing(i);

    if (i < totalPings - 1) {
      await new Promise(resolve => setTimeout(resolve, intervalSeconds));
    }
  }

  console.log('✅ Finished simulation over 10 minutes.');
  process.exit(0);
}

runSimulation().catch(err => {
  console.error('❌ Simulation error:', err);
  process.exit(1);
});

// Optional utility export
export function randomFloat(min: number, max: number): number {
  return Math.random() * (max - min) + min;
}

