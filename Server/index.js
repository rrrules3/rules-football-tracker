require('dotenv').config();
const express = require('express');
const axios   = require('axios');
const NodeCache = require('node-cache');

const app  = express();
const PORT = process.env.PORT || 3000;

// ─── Config ──────────────────────────────────────────────────────────────────

const API_KEY    = process.env.API_FOOTBALL_KEY;   // your API-Football key
const APP_SECRET = process.env.APP_SECRET;          // shared secret sent by the app
const API_BASE   = 'https://v3.football.api-sports.io';

if (!API_KEY) {
    console.error('ERROR: API_FOOTBALL_KEY is not set in .env');
    process.exit(1);
}

// ─── Cache ───────────────────────────────────────────────────────────────────

const cache = new NodeCache({ checkperiod: 60 });

// TTL in seconds per endpoint type
const TTL = {
    live:      60,      // live fixtures — refresh every minute
    fixtures:  90,      // today's fixtures — 90s (short so FT scores appear quickly)
    rounds:    3600,    // fixture round lists — 1 hour
    standings: 1800,    // standings — 30 min
    stats:     1800,    // top scorers / assists / ratings — 30 min
    search:    86400,   // team / league search — 24 hours (rarely changes)
    match:     60,      // per-fixture stats, events, lineups, ratings — 1 min when live
};

function ttlFor(path) {
    if (path.includes('live=all'))                         return TTL.live;
    if (path.includes('/fixtures/rounds'))                 return TTL.rounds;
    if (path.includes('/fixtures/statistics'))             return TTL.match;
    if (path.includes('/fixtures/events'))                 return TTL.match;
    if (path.includes('/fixtures/lineups'))                return TTL.match;
    if (path.includes('/fixtures/players'))                return TTL.match;
    if (path.includes('/fixtures'))                        return TTL.fixtures;
    if (path.includes('/standings'))                       return TTL.standings;
    if (path.includes('/players/top'))                     return TTL.stats;
    if (path.includes('/teams') || path.includes('/leagues')) return TTL.search;
    return 300;
}

// ─── Auth middleware ──────────────────────────────────────────────────────────

function authenticate(req, res, next) {
    // Skip auth check if no secret is configured (useful during local dev)
    if (!APP_SECRET) return next();

    const secret = req.headers['x-app-secret'];
    if (secret !== APP_SECRET) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
}

// ─── Generic proxy ───────────────────────────────────────────────────────────
//
//  The app sends the exact same path + query params it would send to
//  API-Football. The server just forwards them, adding the secret API key.
//  This means we never need to update the server when adding new endpoints.

async function proxy(req, res) {
    // Build the upstream URL: combine path + original query string
    const upstreamURL = `${API_BASE}${req.path}${req.url.includes('?') ? '?' + req.url.split('?')[1] : ''}`;
    const cacheKey    = upstreamURL;

    // Serve from cache if available
    const cached = cache.get(cacheKey);
    if (cached) {
        res.setHeader('X-Cache', 'HIT');
        return res.json(cached);
    }

    try {
        const upstream = await axios.get(upstreamURL, {
            headers: {
                'x-rapidapi-key':  API_KEY,
                'x-apisports-key': API_KEY,
                'x-rapidapi-host': 'v3.football.api-sports.io',
            },
            timeout: 10000,
        });

        const ttl = ttlFor(upstreamURL);
        cache.set(cacheKey, upstream.data, ttl);

        res.setHeader('X-Cache', 'MISS');
        res.json(upstream.data);

    } catch (err) {
        const status = err.response?.status ?? 500;
        console.error(`[proxy] ${status} ${upstreamURL} — ${err.message}`);
        res.status(status).json({ error: 'Upstream request failed', detail: err.message });
    }
}

// ─── Routes ──────────────────────────────────────────────────────────────────

// Health check — no auth required (used by Railway / uptime monitors)
app.get('/health', (req, res) => {
    res.json({
        status:    'ok',
        timestamp: new Date().toISOString(),
        cache:     { keys: cache.keys().length, stats: cache.getStats() },
    });
});

// All API routes go through auth then the generic proxy
app.get('/fixtures*',          authenticate, proxy);
app.get('/standings*',         authenticate, proxy);
app.get('/players*',           authenticate, proxy);
app.get('/teams*',             authenticate, proxy);
app.get('/leagues*',           authenticate, proxy);

// ─── Start ───────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
    console.log(`⚽ Football proxy server running on http://localhost:${PORT}`);
    console.log(`   API key: ${API_KEY ? '✓ set' : '✗ MISSING'}`);
    console.log(`   App secret: ${APP_SECRET ? '✓ set' : '⚠ not set (auth disabled)'}`);
});
