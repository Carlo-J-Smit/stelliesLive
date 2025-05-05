import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 5, // 5 concurrent users
  duration: '30s', // test runs for 30 seconds
};

const baseURL = 'https://stellieslive.web.app'; // Replace with your actual domain

export default function () {
  // Home page
  let res = http.get(`${baseURL}/`);
  check(res, { 'home loaded': (r) => r.status === 200 });

  // Events page
  res = http.get(`${baseURL}/events`);
  check(res, { 'events loaded': (r) => r.status === 200 });

  // Optional: Admin login page or events filtering
  // Don't call protected endpoints directly — this test is light and avoids real writes

  sleep(1); // wait before next user iteration
}
