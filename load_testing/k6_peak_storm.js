import http from 'k6/http';
import { check, sleep } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

// Run against live stack:
// k6 run -e BASE_URL=https://api.mizan.local -e JWT_TOKEN=... -e ORG_ID=... load_testing/k6_peak_storm.js
export const options = {
  scenarios: {
    peak_ledger_and_fx_storm: {
      executor: 'ramping-vus',
      startVUs: 20,
      stages: [
        { duration: '1m', target: 200 },   // Ramp up to busy market hour
        { duration: '3m', target: 1000 },  // Peak-hour storm (1,000 concurrent users)
        { duration: '1m', target: 0 },     // Cool down
      ],
      exec: 'peakCommerceFlow',
    },
    idempotency_retry_burst: {
      executor: 'per-vu-iterations',
      vus: 100,
      iterations: 5,
      startTime: '30s',
      exec: 'idempotencyBurst',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.001'],       // < 0.1% unexpected failures
    http_req_duration: ['p(95)<250', 'p(99)<600'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'https://api.mizan.local';
const HEADERS = {
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${__ENV.JWT_TOKEN || 'REPLACE_ME'}`,
  'X-Org-Id': __ENV.ORG_ID || '00000000-0000-0000-0000-000000000001',
};

export function peakCommerceFlow() {
  // 1. Verify Trial Balance Variance == 0.0000 under peak read/write load
  const tbRes = http.get(`${BASE_URL}/api/v1/ledger/trial-balance/variance`, { headers: HEADERS });
  check(tbRes, {
    'TB status 200': (r) => r.status === 200,
    'TB balanced': (r) => r.json('balanced') === true,
  });

  // 2. Fetch effective operational feature preferences
  const prefRes = http.get(`${BASE_URL}/api/v1/preferences/features`, { headers: HEADERS });
  check(prefRes, { 'Prefs status 200': (r) => r.status === 200 });

  // 3. Verify server-side gate blocks disabled Phase-2 Instant Translation with 403
  const trnRes = http.post(
    `${BASE_URL}/api/v1/translation/field`,
    JSON.stringify({ text: 'عبوة مياه', sourceLang: 'ar', targetLang: 'en' }),
    { headers: HEADERS }
  );
  check(trnRes, { 'Phase-2 Translation blocked 403': (r) => r.status === 403 });

  sleep(0.2);
}

export function idempotencyBurst() {
  // 100 VUs hammering the exact same Idempotency-Key simultaneously
  const hdrs = Object.assign({}, HEADERS, { 'Idempotency-Key': 'K6-PEAK-IDEM-KEY-001' });
  const res = http.post(`${BASE_URL}/api/v1/gates/ubl-preview?invoiceId=INV-K6&currency=USD&net=100&tax=15`, null, { headers: hdrs });
  check(res, { 'Idempotency burst handled cleanly': (r) => r.status === 200 || r.status === 201 });
}
