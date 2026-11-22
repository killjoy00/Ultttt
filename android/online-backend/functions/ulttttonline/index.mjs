import pg from 'pg';
import { createHash } from 'node:crypto';

// A fresh 256-bit random guest credential is generated and retained by Android.
// Never accept client-provided player IDs; the server derives one from the credential.
export function guestIdentity(header) {
  const match = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(header ?? '');
  if (!match) return null;
  const bytes = Buffer.from(match[1], 'base64url');
  if (bytes.length !== 32 || bytes.toString('base64url') !== match[1]) return null;
  return createHash('sha256').update(bytes).digest('hex');
}

// Never return guest hashes or database roles to the Android client.
export function visibleMatch(match, actor) {
  const isX = match.player_x === actor;
  const isO = match.player_o === actor;
  if (!isX && !isO) return null;
  return {
    id: match.id,
    invite_code: match.invite_code,
    player_x: isX ? 'self' : 'opponent',
    player_o: match.player_o == null ? null : (isO ? 'self' : 'opponent'),
    moves: match.moves,
    status: match.status,
    winner: match.winner,
    updated_at: match.updated_at,
  };
}

const json = (value, status = 200) =>
  Response.json(value, { status, headers: { 'Cache-Control': 'no-store' } });

async function readBody(request) {
  const length = Number(request.headers.get('content-length') ?? 0);
  if (Number.isFinite(length) && length > 4096) throw new InputError('Request is too large.');
  const body = await request.text();
  if (body.length > 4096) throw new InputError('Request is too large.');
  try {
    const parsed = JSON.parse(body);
    if (parsed == null || Array.isArray(parsed) || typeof parsed !== 'object')
      throw new InputError('Invalid request body.');
    return parsed;
  } catch (error) {
    if (error instanceof InputError) throw error;
    throw new InputError('Invalid JSON.');
  }
}

class InputError extends Error {}

function validId(value) {
  return typeof value === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

const knownConflicts = new Set([
  'Invalid guest session', 'You already have ten invitations awaiting an opponent',
  'Invitation expired, unavailable, or already joined', 'Match not found',
  'The match is not ready for moves', 'Match changed; refresh before moving',
  'It is not your turn', 'Illegal move', 'Match is full', 'Invalid invitation code',
  'Move out of bounds',
]);

export function createHandler(database) {
  return {
    async fetch(request) {
      // No public database access and no database work for missing credentials.
      const actor = guestIdentity(request.headers.get('authorization'));
      if (!actor) return json({ error: 'A valid guest session is required.' }, 401);
      const url = new URL(request.url);
      const path = url.pathname;
      try {
        if (request.method === 'GET' && path === '/health') {
          await database.query('SELECT 1');
          return json({ ok: true });
        }
        if (request.method === 'GET' && path === '/matches') {
          const { rows } = await database.query(
            `SELECT * FROM public.ultttt_matches
             WHERE player_x = $1 OR player_o = $1
             ORDER BY updated_at DESC LIMIT 50`, [actor]);
          return json(rows.map(row => visibleMatch(row, actor)).filter(Boolean));
        }
        if (request.method === 'GET' && path.startsWith('/matches/')) {
          const matchId = path.slice('/matches/'.length);
          if (!validId(matchId)) return json({ error: 'Invalid match ID.' }, 400);
          const { rows } = await database.query(
            `SELECT * FROM public.ultttt_matches
             WHERE id = $1::uuid AND (player_x = $2 OR player_o = $2)`,
            [matchId, actor]);
          if (!rows.length) return json({ error: 'Match not found.' }, 404);
          return json(visibleMatch(rows[0], actor));
        }
        if (request.method !== 'POST') return json({ error: 'Route not found.' }, 404);
        if (!['/matches/create', '/matches/find', '/matches/join', '/matches/move'].includes(path))
          return json({ error: 'Route not found.' }, 404);
        const body = await readBody(request);
        let result;
        switch (path) {
          case '/matches/create':
            result = await database.query('SELECT * FROM public.ultttt_create_match($1)', [actor]);
            break;
          case '/matches/find':
            result = await database.query('SELECT * FROM public.ultttt_find_match($1)', [actor]);
            break;
          case '/matches/join':
            if (typeof body.invite_code !== 'string' ||
                !/^[0-9A-F]{12}$/.test(body.invite_code))
              throw new InputError('Invalid invitation code.');
            result = await database.query(
              'SELECT * FROM public.ultttt_join_match($1, $2)',
              [actor, body.invite_code]);
            break;
          case '/matches/move':
            if (!validId(body.match_id) ||
                !Number.isInteger(body.board) || body.board < 0 || body.board > 8 ||
                !Number.isInteger(body.cell) || body.cell < 0 || body.cell > 8 ||
                !Number.isInteger(body.expected_moves) ||
                body.expected_moves < 0 || body.expected_moves > 81)
              throw new InputError('Invalid move.');
            result = await database.query(
              'SELECT * FROM public.ultttt_play_move($1, $2::uuid, $3, $4, $5)',
              [actor, body.match_id, body.board, body.cell, body.expected_moves]);
            break;
        }
        if (!result?.rows?.length) return json({ error: 'No match returned.' }, 503);
        const match = visibleMatch(result.rows[0], actor);
        return match ? json(match) : json({ error: 'Not a participant.' }, 403);
      } catch (error) {
        if (error instanceof InputError) return json({ error: error.message }, 400);
        if (error?.code === 'P0001' && knownConflicts.has(error.message))
          return json({ error: error.message }, error.message === 'Match not found' ? 404 : 409);
        // Do not leak DB hostnames, SQL, token hashes or stack traces to players.
        console.error('Online match operation failed', { code: error?.code ?? 'unknown' });
        return json({ error: 'The online service is temporarily unavailable.' }, 503);
      }
    },
  };
}

let pool;
export default {
  fetch(request) {
    if (!process.env.DATABASE_URL)
      return json({ error: 'Online server is not configured.' }, 503);
    pool ??= new pg.Pool({
      connectionString: process.env.DATABASE_URL,
      max: 3,
      idleTimeoutMillis: 15000,
      connectionTimeoutMillis: 10000,
    });
    return createHandler(pool).fetch(request);
  },
};
