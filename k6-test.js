import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 3, // max 3 users
  iterations: 30, // keep total usage very low
};

const base = 'https://stellieslive.web.app';

const queries = ['Karel & Pikkie', 'Bingo', 'music', 'quiz', 'komfees']; // simulate event filters

export default function () {
  // 1. Home page
  let res = http.get(`${base}/`);
  check(res, { 'home ok': (r) => r.status === 200 });

  // 2. Events page
  res = http.get(`${base}/events`);
  check(res, { 'events ok': (r) => r.status === 200 });

  // 4. Admin page view (no write)
  res = http.get(`${base}/admin`);
  check(res, { 'admin ok': (r) => r.status === 200 || r.status === 403 }); // expect redirect if not logged in

  // 5. Simulated Firestore read (REST API)
  const firestoreURL = `https://firestore.googleapis.com/v1/projects/YOUR_PROJECT_ID/databases/(default)/documents/events?pageSize=1`;
  res = http.get(firestoreURL);
  check(res, { 'Firestore GET ok': (r) => r.status === 200 || r.status === 403 });

  sleep(1); // wait before next iteration
}
