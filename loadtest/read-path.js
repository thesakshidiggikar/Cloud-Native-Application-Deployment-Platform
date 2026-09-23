import http from 'k6/http';
import { check } from 'k6';

// Set BASE_URL to the local or sandbox endpoint. This is a bounded, read-heavy workload.
export const options = {
  vus: 10,
  duration: '2m',
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(50)<100', 'p(95)<300', 'p(99)<750'],
  },
};

const base = __ENV.BASE_URL || 'http://127.0.0.1:8000';

export function setup() {
  const response = http.post(`${base}/api/v1/tasks`, JSON.stringify({ title: `load-test-${Date.now()}` }), {
    headers: { 'Content-Type': 'application/json' },
  });
  check(response, { 'seed task created': (r) => r.status === 201 });
  return { id: response.json('id') };
}

export default function (data) {
  const response = http.get(`${base}/api/v1/tasks/${data.id}`);
  check(response, { 'task lookup succeeds': (r) => r.status === 200 });
}
