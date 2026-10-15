// k6 load test for the IT Service Desk API (or the AI Gateway MCP endpoint's backing API).
// Run:  k6 run -e BASE_URL=https://<func>.azurewebsites.net -e FUNCTION_KEY=<key> perf/k6-api.js
// Ramp:  -e VUS=20 -e DURATION=2m
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

const BASE = __ENV.BASE_URL;
const KEY = __ENV.FUNCTION_KEY;

export const options = {
  scenarios: {
    mixed: { executor: 'constant-vus', vus: Number(__ENV.VUS || 10), duration: __ENV.DURATION || '1m' },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1000'],
  },
};

const byOperation = {};
function trend(name) {
  if (!byOperation[name]) byOperation[name] = new Trend(`duration_${name}`, true);
  return byOperation[name];
}

const calls = [
  ['getTicket', () => `/api/tickets/INC-${String(1 + Math.floor(Math.random() * 100000)).padStart(6, '0')}`],
  ['searchTickets', () => '/api/tickets?status=Open&priority=High&pageSize=10'],
  ['getTicketComments', () => `/api/tickets/INC-${String(1 + Math.floor(Math.random() * 100000)).padStart(6, '0')}/comments`],
  ['getCustomerTickets', () => `/api/customers/${1 + Math.floor(Math.random() * 5000)}/tickets?top=10`],
  ['getAgentWorkload', () => '/api/agents/workload?team=Service%20Desk'],
  ['getTicketSummary', () => '/api/reports/summary'],
  ['getSlaBreaches', () => '/api/reports/sla-breaches?top=10'],
];

export default function () {
  const [name, path] = calls[Math.floor(Math.random() * calls.length)];
  const res = http.get(`${BASE}${path()}`, { headers: { 'x-functions-key': KEY }, tags: { operation: name } });
  trend(name).add(res.timings.duration);
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(0.2);
}
