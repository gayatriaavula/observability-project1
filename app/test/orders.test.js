const test = require('node:test');
const assert = require('node:assert');
const { createApp } = require('../src/app');

async function request(app, method, path, body) {
  const server = app.listen(0);
  const { port } = server.address();
  try {
    const res = await fetch(`http://127.0.0.1:${port}${path}`, {
      method,
      headers: body ? { 'Content-Type': 'application/json' } : undefined,
      body: body ? JSON.stringify(body) : undefined,
    });
    const json = await res.json().catch(() => undefined);
    return { status: res.status, body: json };
  } finally {
    server.close();
  }
}

test('GET /healthz returns ok', async () => {
  const app = createApp();
  const res = await request(app, 'GET', '/healthz');
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.status, 'ok');
});

test('POST /orders then GET /orders/:id round-trips', async () => {
  const app = createApp();
  const created = await request(app, 'POST', '/orders', { item: 'widget', quantity: 2 });
  assert.strictEqual(created.status, 201);
  assert.strictEqual(created.body.item, 'widget');

  const fetched = await request(app, 'GET', `/orders/${created.body.id}`);
  assert.strictEqual(fetched.status, 200);
  assert.strictEqual(fetched.body.quantity, 2);
});

test('POST /orders without item is rejected', async () => {
  const app = createApp();
  const res = await request(app, 'POST', '/orders', { quantity: 1 });
  assert.strictEqual(res.status, 400);
});

test('GET /orders/:id for unknown id returns 404', async () => {
  const app = createApp();
  const res = await request(app, 'GET', '/orders/does-not-exist');
  assert.strictEqual(res.status, 404);
});
