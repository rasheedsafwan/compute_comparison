import http from 'k6/http';
import { sleep, check } from 'k6';

// Predictable, constant moderate traffic 
export const options = {
  stages: [
    { duration: '30s', target: 15 },  // ramp up
    { duration: '4m', target: 15 },   // hold steady
    { duration: '30s', target: 0 },   // ramp down
  ],
};

const BASE_URL = __ENV.TARGET_URL;

export default function () {
  const res = http.get(`${BASE_URL}/coffee`);
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}