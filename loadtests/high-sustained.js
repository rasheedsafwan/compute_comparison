import http from 'k6/http';
import { sleep, check } from 'k6';

// High, sustained load held for a long duration 
export const options = {
  stages: [
    { duration: '1m', target: 60 },   // ramp up
    { duration: '8m', target: 60 },   // hold steady
    { duration: '1m', target: 0 },    // ramp down
  ],
};

const BASE_URL = __ENV.TARGET_URL;

export default function () {
  const res = http.get(`${BASE_URL}/coffee`);
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}