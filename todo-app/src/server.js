const express = require('express');
const db = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;
const ENV = process.env.NODE_ENV || 'development';

app.use(express.json());
app.use(express.static('public'));

// Fallback en mémoire lorsque aucune base n'est configurée (tests, dev local)
let todos = [];

app.get('/api/health', async (req, res) => {
  res.json({ status: 'ok', env: ENV, database: await db.ping(), timestamp: new Date().toISOString() });
});

// ---------- CRUD (PostgreSQL si DATABASE_URL, sinon mémoire) ----------

app.get('/api/todos', async (req, res) => {
  try {
    if (db.pool) {
      const { rows } = await db.pool.query('SELECT * FROM todos ORDER BY id');
      return res.json(rows.map(toApi));
    }
    res.json(todos);
  } catch (err) {
    res.status(500).json({ error: 'database error' });
  }
});

app.post('/api/todos', async (req, res) => {
  const { title } = req.body;
  if (!title) return res.status(400).json({ error: 'title is required' });
  try {
    if (db.pool) {
      const { rows } = await db.pool.query(
        'INSERT INTO todos (title) VALUES ($1) RETURNING *',
        [title]
      );
      return res.status(201).json(toApi(rows[0]));
    }
    const todo = { id: todos.length + 1, title, done: false, createdAt: new Date().toISOString() };
    todos.push(todo);
    res.status(201).json(todo);
  } catch (err) {
    res.status(500).json({ error: 'database error' });
  }
});

app.put('/api/todos/:id', async (req, res) => {
  try {
    if (db.pool) {
      const { title, done } = req.body;
      const { rows } = await db.pool.query(
        'UPDATE todos SET title = COALESCE($1, title), done = COALESCE($2, done) WHERE id = $3 RETURNING *',
        [title, done === undefined ? null : Boolean(done), Number(req.params.id)]
      );
      if (rows.length === 0) return res.status(404).json({ error: 'todo not found' });
      return res.json(toApi(rows[0]));
    }
    const todo = todos.find((t) => t.id === Number(req.params.id));
    if (!todo) return res.status(404).json({ error: 'todo not found' });
    if (req.body.title !== undefined) todo.title = req.body.title;
    if (req.body.done !== undefined) todo.done = Boolean(req.body.done);
    res.json(todo);
  } catch (err) {
    res.status(500).json({ error: 'database error' });
  }
});

app.delete('/api/todos/:id', async (req, res) => {
  try {
    if (db.pool) {
      const { rows } = await db.pool.query(
        'DELETE FROM todos WHERE id = $1 RETURNING id',
        [Number(req.params.id)]
      );
      if (rows.length === 0) return res.status(404).json({ error: 'todo not found' });
      return res.status(204).end();
    }
    const index = todos.findIndex((t) => t.id === Number(req.params.id));
    if (index === -1) return res.status(404).json({ error: 'todo not found' });
    todos.splice(index, 1);
    res.status(204).end();
  } catch (err) {
    res.status(500).json({ error: 'database error' });
  }
});

function toApi(row) {
  return { id: row.id, title: row.title, done: row.done, createdAt: row.created_at };
}

db.init()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Todo app listening on port ${PORT} (${ENV})`);
    });
  })
  .catch((err) => {
    console.error("Échec d'initialisation de la base de données :", err.message);
    process.exit(1);
  });

module.exports = app;