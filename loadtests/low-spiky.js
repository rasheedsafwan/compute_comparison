import http from 'k6/http';
import { sleep, check } from 'k6';

// Bursty, mostly-idle traffic — three short spikes separated by quiet gaps.
export const options = {
  stages: [
    { duration: '20s', target: 30 },  // burst 1
    { duration: '90s', target: 0 },   // idle
    { duration: '20s', target: 30 },  // burst 2
    { duration: '90s', target: 0 },   // idle
    { duration: '20s', target: 30 },  // burst 3
    { duration: '10s', target: 0 },   // cool down
  ],
};

const BASE_URL = __ENV.TARGET_URL;

export default function () {
  const res = http.get(`${BASE_URL}/coffee`);
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}