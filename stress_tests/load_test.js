 import http from 'k6/http';
  import { check, sleep } from 'k6';
  import { Trend, Rate } from 'k6/metrics';

  const writeLatency = new Trend('firestore_write_latency');
  const errorRate = new Rate('error_rate');

  const PROJECT_ID = 'turjuman-63e17';
  const API_KEY = "AIzaSyA_YyUhvsBZO5swoX-geNl2T-tNNM3x4X8"; // from Firebase Console
  const MEETING_ID = 'load-test-meeting-001';

  export const options = {
    scenarios: {
      concurrent_users: {
        executor: 'ramping-vus',
        startVUs: 0,
        stages: [
          { duration: '30s', target: 50 },  // ramp up to 50 users
          { duration: '2m',  target: 50 },  // hold at 50
          { duration: '15s', target: 0  },  // ramp down
        ],
      },
    },
    thresholds: {
      firestore_write_latency: ['p(95)<3000'],  // 95% of writes under 3s
      error_rate: ['rate<0.01'],                // less than 1% errors
      http_req_duration: ['p(99)<5000'],        // 99th percentile under 5s
    },
  };

  // Runs once per VU (virtual user) — signs in and gets an auth token
  export function setup() {
    const res = http.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
      JSON.stringify({
        email: 'testuser@turjuman.test',
        password: 'TestPassword123',
        returnSecureToken: true,
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );

    check(res, { 'auth ok': (r) => r.status === 200 });
    return { token: res.json('idToken') };
  }

  export default function (data) {
    const token = data.token;
    const userId = `user_${__VU}`;   // __VU is k6's virtual user ID
    const userName = `TestUser ${__VU}`;

    const headers = {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    };

    const firestoreUrl =
      `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}` +
      `/databases/(default)/documents/captionsFileTranscription/${MEETING_ID}`;

    // ── Simulate caption write (like CaptionController.updateCaption) ──
    const entry = {
      userId: { stringValue: userId },
      userName: { stringValue: userName },
      text: { stringValue: `Test caption from ${userName} at ${Date.now()}` },
      timestamp: { timestampValue: new Date().toISOString() },
    };

    const writeStart = Date.now();
    const writeRes = http.patch(
      firestoreUrl,
      JSON.stringify({
        fields: {
          meetingId: { stringValue: MEETING_ID },
          updatedAt: { timestampValue: new Date().toISOString() },
          activeSpeakerId: { stringValue: userId },
        },
      }),
      { headers }
    );

    writeLatency.add(Date.now() - writeStart);
    errorRate.add(writeRes.status !== 200);

    check(writeRes, {
      'write status 200': (r) => r.status === 200,
      'write under 3s':   (r) => r.timings.duration < 3000,
    });

    // ── Simulate caption read (like Firestore snapshot listener) ──
    const readRes = http.get(firestoreUrl, { headers });
    check(readRes, { 'read status 200': (r) => r.status === 200 });

    sleep(1); // simulate 1 caption per second per user
  }
