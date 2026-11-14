// k6 load script for the built API (and, with the same routes, the PHP parity API). Run through tools/load/run.sh,
// inside the stack's Docker network. Synthetic stacks only: it signs synthetic .invalid members in at the stack's
// Firebase Auth emulator in setup(), so no token is ever written to a file or printed.
//
//   BASE_URL      the gateway (or the PHP api) inside the network, for example http://gateway:8080
//   EMULATOR_URL  the stack's Auth emulator, for example http://firebase-emulator:9099
//   PROJECT       the emulator project id (demo-...)
//   PASSWORD      the local-only emulator placeholder password (not a secret; see tools/dev-auth/mint-token.sh)
//   CALLERS       path of the callers file tools/load/callers.sh wrote (emails, roles, a class id each)
//   MODE          route | mixed | heavy
//   ROUTE         the route key (MODE=route or heavy), see ROUTES
//   VUS, DURATION (seconds), WARMUP (seconds); MODE=heavy: ITERATIONS per VU instead of DURATION
//   OUT           path of the JSON summary to write
//
// Every figure the summary reports is for the measured phase only (tag phase:m): the warm-up and the sign-ins of
// setup() are left out, and req/s divides by the measured seconds (the 9 Nov review, finding m1).

import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || '';
const EMULATOR_URL = __ENV.EMULATOR_URL || '';
const PROJECT = __ENV.PROJECT || 'demo-tsr-app';
const PASSWORD = __ENV.PASSWORD || '';
const MODE = __ENV.MODE || 'route';
const ROUTE = __ENV.ROUTE || 'me';
const VUS = parseInt(__ENV.VUS || '1', 10);
const DURATION = parseInt(__ENV.DURATION || '60', 10);
const WARMUP = parseInt(__ENV.WARMUP || '15', 10);
const ITERATIONS = parseInt(__ENV.ITERATIONS || '20', 10);
const OUT = __ENV.OUT || '/out/summary.json';
const DATA = JSON.parse(open(__ENV.CALLERS));
const SIGN_IN_BATCH = 20;
const REQUEST_TIMEOUT = '60s';

// role: which callers may run the route; path: built per caller; min: the smallest body (bytes) a real answer has,
// so an empty or error-shaped 200 is counted as a failure (the 9 Nov review, finding J4).
const ROUTES = {
  me: { roles: ['member', 'teacher', 'coordinator', 'gender_admin', 'super_admin'], path: () => '/me', min: 50 },
  permissions: { roles: ['member', 'teacher', 'coordinator', 'gender_admin', 'super_admin'], path: () => '/me/permissions', min: 50 },
  classes_coordinator: { roles: ['coordinator'], path: () => '/classes?include=managed', min: 50 },
  classes_super: { roles: ['super_admin'], path: () => '/classes?include=managed', min: 50 },
  class_detail: { roles: ['member'], path: (c) => '/classes/' + c.class_id, min: 50 },
  this_week: { roles: ['gender_admin', 'super_admin'], path: () => '/reports/this-week', min: 20 },
  notifications: { roles: ['member'], path: () => '/user/notifications?limit=20', min: 2 },
  unread_count: { roles: ['member'], path: () => '/user/notifications/unread-count', min: 2 },
  search: { roles: ['gender_admin', 'super_admin'], path: () => '/search?q=' + encodeURIComponent(DATA.search_word), min: 20 },
  registrations: { roles: ['gender_admin', 'super_admin'], path: () => '/reports/registrations', min: 20 },
  articles: { roles: null, path: () => '/api/v1/articles', min: 20 },
  article: { roles: null, path: () => '/api/v1/articles/' + DATA.article_slug, min: 20 },
  // A control, not an API route: the emulator's account lookup, which the API (in emulator mode) and PHP call once per
  // signed-in request. It shows what the emulator itself can serve, which caps every signed-in route in this test.
  emulator_lookup: { roles: ['member'], method: 'LOOKUP', min: 20 },
  // Heavy routes (MODE=heavy).
  xlsx: { roles: ['super_admin'], path: () => DATA.heavy.xlsx, min: 1000 },
  pdf: { roles: ['super_admin'], path: () => DATA.heavy.pdf, min: 1000 },
  mis: { roles: ['super_admin'], path: () => DATA.heavy.mis, min: 20 },
  // The repeatable write: a teacher saves the same city on the own profile (PATCH /me). Each VU keeps one caller.
  write: { roles: ['teacher'], method: 'PATCH', path: () => '/me', body: () => JSON.stringify({ city: 'Load Test City' }), min: 50 },
};
// The calls the app makes when a member opens it, in order (tsr-account mobile; tools/perf/k6/smoke.js STARTUP).
const MIXED = ['me', 'permissions', 'classes_member', 'notifications', 'unread_count'];
ROUTES.classes_member = { roles: ['member'], path: () => '/classes?include=managed', min: 2 };

const STATUS_BUCKETS = ['0', '400', '401', '403', '404', '422', '429', '500', '502', '503', '504', 'other'];
const statusCounters = {};
STATUS_BUCKETS.forEach((s) => { statusCounters[s] = new Counter('bad_status_' + s); });
const shortBody = new Counter('bad_short_body');

function names() {
  if (MODE === 'mixed') { return MIXED; }
  return [ROUTE];
}

function thresholds() {
  // An always-true threshold per tag makes k6 keep the sub-metric in the summary.
  const t = {};
  names().forEach((n) => {
    t['http_req_duration{phase:m,route:' + n + '}'] = ['max>=0'];
    t['http_reqs{phase:m,route:' + n + '}'] = ['count>=0'];
    t['http_req_failed{phase:m,route:' + n + '}'] = ['rate>=0'];
  });
  t['http_req_duration{phase:m}'] = ['max>=0'];
  t['http_reqs{phase:m}'] = ['count>=0'];
  t['http_req_failed{phase:m}'] = ['rate>=0'];
  t['iterations{phase:m}'] = ['count>=0'];
  return t;
}

function scenarios() {
  if (MODE === 'heavy') {
    return { measure: { executor: 'per-vu-iterations', vus: VUS, iterations: ITERATIONS, maxDuration: '20m', tags: { phase: 'm' } } };
  }
  return {
    warmup: { executor: 'constant-vus', vus: VUS, duration: WARMUP + 's', gracefulStop: '5s', tags: { phase: 'w' } },
    measure: { executor: 'constant-vus', vus: VUS, duration: DURATION + 's', startTime: (WARMUP + 5) + 's', gracefulStop: '30s', tags: { phase: 'm' } },
  };
}

export const options = {
  scenarios: scenarios(),
  thresholds: thresholds(),
  summaryTrendStats: ['min', 'avg', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  setupTimeout: '180s',
  discardResponseBodies: false,
};

function rolesNeeded() {
  const set = {};
  names().forEach((n) => (ROUTES[n].roles || []).forEach((r) => { set[r] = true; }));
  return set;
}

// Creates each caller's emulator account when it is missing (an existing one answers 400, which is fine) and signs
// it in. Only the callers the chosen routes use are signed in. The tokens live in memory for this run only.
export function setup() {
  if (!/^https?:\/\/[a-z0-9-]+(:\d+)?$/.test(BASE_URL) || /\./.test(BASE_URL)) {
    throw new Error('refusing to run: BASE_URL must be a container name inside a Docker network, never a public host');
  }
  const needed = rolesNeeded();
  const callers = DATA.callers.filter((c) => needed[c.role]);
  const identity = EMULATOR_URL + '/identitytoolkit.googleapis.com/v1';
  const json = { headers: { 'Content-Type': 'application/json' }, tags: { phase: 'setup' } };
  const owner = { headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' }, tags: { phase: 'setup' } };
  const signedIn = [];
  for (let i = 0; i < callers.length; i += SIGN_IN_BATCH) {
    const slice = callers.slice(i, i + SIGN_IN_BATCH);
    const bodies = slice.map((c) => JSON.stringify({ email: c.email, password: PASSWORD, emailVerified: true, returnSecureToken: true }));
    http.batch(bodies.map((b) => ['POST', identity + '/projects/' + PROJECT + '/accounts', b, owner]));
    const answers = http.batch(bodies.map((b) => ['POST', identity + '/accounts:signInWithPassword?key=local', b, json]));
    answers.forEach((a, k) => {
      const token = a.status === 200 ? a.json('idToken') : null;
      if (!token) { throw new Error('sign-in failed for a ' + slice[k].role + ' caller with status ' + a.status); }
      signedIn.push(Object.assign({}, slice[k], { bearer: 'Bearer ' + token }));
    });
  }
  const byRole = {};
  signedIn.forEach((c) => { (byRole[c.role] = byRole[c.role] || []).push(c); });
  names().forEach((n) => {
    const roles = ROUTES[n].roles;
    if (roles !== null && !roles.some((r) => (byRole[r] || []).length > 0)) {
      throw new Error('no caller for route ' + n);
    }
  });
  return { byRole: byRole };
}

function pick(data, route, vu, iteration) {
  if (route.roles === null) { return null; }
  let pool = [];
  route.roles.forEach((r) => { pool = pool.concat(data.byRole[r] || []); });
  // Each VU starts at its own caller and walks the pool, so VUs spread over distinct members.
  // A write keeps one caller per VU, so a run changes at most VUS members.
  const step = route.method === 'PATCH' ? 0 : iteration;
  return pool[(vu * 7919 + step) % pool.length];
}

function hit(name, caller) {
  const route = ROUTES[name];
  const params = { headers: {}, tags: { route: name }, timeout: REQUEST_TIMEOUT };
  if (caller) { params.headers.Authorization = caller.bearer; }
  let res;
  if (route.method === 'LOOKUP') {
    params.headers = { 'Content-Type': 'application/json' };
    res = http.post(EMULATOR_URL + '/identitytoolkit.googleapis.com/v1/accounts:lookup?key=local', JSON.stringify({ idToken: caller.bearer.slice(7) }), params);
  } else if (route.method === 'PATCH') {
    params.headers['Content-Type'] = 'application/json';
    res = http.patch(BASE_URL + route.path(caller), route.body(caller), params);
  } else {
    res = http.get(BASE_URL + route.path(caller), params);
  }
  const ok = res.status === 200;
  if (!ok) {
    const key = STATUS_BUCKETS.indexOf(String(res.status)) >= 0 ? String(res.status) : 'other';
    statusCounters[key].add(1, { route: name });
  }
  const long = ok && res.body !== null && res.body.length >= route.min;
  if (ok && !long) { shortBody.add(1, { route: name }); }
  check(res, { 'status 200': () => ok, 'body present': () => long }, { route: name });
}

export default function (data) {
  if (MODE === 'mixed') {
    // One member per iteration makes all five calls, as one phone does.
    const caller = pick(data, ROUTES.me, __VU, __ITER);
    const member = caller.role === 'member' ? caller : pick(data, ROUTES.classes_member, __VU, __ITER);
    MIXED.forEach((n) => hit(n, member));
    return;
  }
  hit(ROUTE, pick(data, ROUTES[ROUTE], __VU, __ITER));
}

function trend(metric) {
  if (!metric) { return null; }
  const v = metric.values;
  return { min: v.min, avg: v.avg, p50: v.med, p90: v['p(90)'], p95: v['p(95)'], p99: v['p(99)'], max: v.max };
}

function routeSummary(metrics, selector, seconds) {
  const reqs = metrics['http_reqs{' + selector + '}'];
  const failed = metrics['http_req_failed{' + selector + '}'];
  const count = reqs ? reqs.values.count : 0;
  return {
    requests: count,
    req_per_s: seconds > 0 ? count / seconds : null,
    http_failed_rate: failed ? failed.values.rate : null,
    latency_ms: trend(metrics['http_req_duration{' + selector + '}']),
  };
}

export function handleSummary(data) {
  const m = data.metrics;
  // Heavy runs have no fixed duration: req/s is not reported for them (the latencies are the result).
  const seconds = MODE === 'heavy' ? 0 : DURATION;
  const out = {
    mode: MODE, route: MODE === 'mixed' ? 'mixed' : ROUTE, vus: VUS, measured_seconds: seconds, warmup_seconds: MODE === 'heavy' ? 0 : WARMUP,
    all: routeSummary(m, 'phase:m', seconds),
    iterations: m['iterations{phase:m}'] ? m['iterations{phase:m}'].values.count : null,
    routes: {},
    bad_status: {},
    bad_short_body: m.bad_short_body ? m.bad_short_body.values.count : 0,
    checks_failed: m.checks ? m.checks.values.fails : 0,
  };
  names().forEach((n) => { out.routes[n] = routeSummary(m, 'phase:m,route:' + n, seconds); });
  // These counters include the warm-up phase: any error at all is worth seeing.
  STATUS_BUCKETS.forEach((s) => {
    const c = m['bad_status_' + s];
    if (c && c.values.count > 0) { out.bad_status[s] = c.values.count; }
  });
  const result = {};
  result[OUT] = JSON.stringify(out, null, 2);
  result.stdout = MODE + ' ' + out.route + ' vus=' + VUS + ' requests=' + out.all.requests
    + ' p95=' + (out.all.latency_ms ? out.all.latency_ms.p95.toFixed(1) : 'n/a') + 'ms bad=' + JSON.stringify(out.bad_status) + '\n';
  return result;
}
