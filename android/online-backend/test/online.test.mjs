import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, createHash } from 'node:crypto';
import { createHandler, guestIdentity, visibleMatch } from '../functions/ulttttonline/index.mjs';

const token = randomBytes(32).toString('base64url');
const hash = createHash('sha256').update(Buffer.from(token, 'base64url')).digest('hex');
const match = {
  id: '123e4567-e89b-12d3-a456-426614174000',
  invite_code: 'A1B2C3D4E5F6', player_x: hash, player_o: 'f'.repeat(64),
  moves: [], status: 'active', winner: null, updated_at: '2026-11-22T12:00:00Z',
};
const url = 'https://online.example.neon.tech';
const authed = (path, options = {}) => new Request(url + path, {
  ...options, headers: { authorization: 'Bearer ' + token, ...options.headers },
});
const fakeDb = (rows = [match]) => {
  const calls = [];
  return {
    calls,
    async query(sql, params) { calls.push({ sql, params }); return { rows }; },
  };
};

test('guest token is random-key authenticated, not an arbitrary user ID', () => {
  assert.equal(guestIdentity('Bearer ' + token), hash);
  assert.equal(guestIdentity('Bearer ' + 'a'.repeat(20)), null);
  assert.equal(guestIdentity('Bearer ' + 'not-valid'), null);
  assert.equal(guestIdentity(null), null);
});
test('match projection contains aliases, never guest token hashes', () => {
  const projected = visibleMatch(match, hash);
  assert.equal(projected.player_x, 'self');
  assert.equal(projected.player_o, 'opponent');
  assert.equal(JSON.stringify(projected).includes(hash), false);
  assert.equal(visibleMatch(match, 'z'.repeat(64)), null);
});
test('unauthenticated requests do not query the database', async () => {
  const db = fakeDb();
  const response = await createHandler(db).fetch(new Request(url + '/matches'));
  assert.equal(response.status, 401);
  assert.equal(db.calls.length, 0);
});
test('list query is always scoped to the authenticated guest', async () => {
  const db = fakeDb();
  const response = await createHandler(db).fetch(authed('/matches'));
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).map(r => r.id), [match.id]);
  assert.match(db.calls[0].sql, /player_x = \$1 OR player_o = \$1/);
  assert.equal(db.calls[0].params[0], hash);
});
test('no result for another player and no guest hash leakage', async () => {
  const db = fakeDb([match]);
  const response = await createHandler(db).fetch(authed('/matches/' + match.id));
  assert.equal(response.status, 200);
  assert.equal((await response.json()).player_x, 'self');
  assert.equal(db.calls[0].params[1], hash);
});
test('moves require valid expected version and legal bounds before database call', async () => {
  const db = fakeDb();
  const r = await createHandler(db).fetch(authed('/matches/move', {
    method: 'POST', body: JSON.stringify({ match_id: match.id, board: 9, cell: 0, expected_moves: 0 }),
  }));
  assert.equal(r.status, 400);
  assert.equal(db.calls.length, 0);
});
test('a valid move reaches a parameterized server rule, never a raw table write', async () => {
  const db = fakeDb();
  const r = await createHandler(db).fetch(authed('/matches/move', {
    method: 'POST', body: JSON.stringify({ match_id: match.id, board: 3, cell: 2, expected_moves: 0 }),
  }));
  assert.equal(r.status, 200);
  assert.match(db.calls[0].sql, /ultttt_play_move/);
  assert.deepEqual(db.calls[0].params, [hash, match.id, 3, 2, 0]);
});
test('joining requires an exact invitation code and the actor is server-derived', async () => {
  const db = fakeDb();
  const bad = await createHandler(db).fetch(authed('/matches/join', {method:'POST', body: JSON.stringify({ invite_code:'AAAA' })}));
  assert.equal(bad.status, 400);
  const good = await createHandler(db).fetch(authed('/matches/join', {method:'POST', body: JSON.stringify({ invite_code:match.invite_code })}));
  assert.equal(good.status, 200);
  assert.deepEqual(db.calls[0].params, [hash, match.invite_code]);
});
test('a database rejection is a conflict, and unexpected SQL errors are redacted', async () => {
  const conflict = {query: async () => {const e=new Error('Match changed; refresh before moving');e.code='P0001';throw e;}};
  const a = await createHandler(conflict).fetch(authed('/matches/create',{method:'POST',body:'{}'}));
  assert.equal(a.status,409);
  const failed = {query:async()=>{const e=new Error('password=do-not-leak');e.code='XX000';throw e;}};
  const b = await createHandler(failed).fetch(authed('/matches'));
  assert.equal(b.status,503);
  assert.equal(JSON.stringify(await b.json()).includes('do-not-leak'),false);
});
