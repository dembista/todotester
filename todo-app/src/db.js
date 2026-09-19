const { Pool } = require('pg');

// Base de données PostgreSQL managée (Neon) via DATABASE_URL.
// Si DATABASE_URL est absent, l'application fonctionne en mémoire (dev/local).
const connectionString = process.env.DATABASE_URL;

const pool = connectionString
  ? new Pool({
      connectionString,
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 5000,
      statement_timeout: 10000,
    })
  : null;

async function init() {
  if (!pool) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS todos (
      id         SERIAL PRIMARY KEY,
      title      TEXT NOT NULL,
      done       BOOLEAN NOT NULL DEFAULT false,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

async function ping() {
  if (!pool) return 'disabled';
  try {
    await pool.query('SELECT 1');
    return 'connected';
  } catch (err) {
    return 'error';
  }
}

module.exports = { pool, init, ping };