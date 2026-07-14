const express = require('express');
const client = require('prom-client');
const crypto = require('crypto');

function createApp() {
  const app = express();
  app.use(express.json());

  const registry = new client.Registry();
  client.collectDefaultMetrics({ register: registry });

  const httpRequestDuration = new client.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route', 'status_code'],
    registers: [registry],
  });

  const ordersCreatedTotal = new client.Counter({
    name: 'orders_created_total',
    help: 'Total number of orders created',
    registers: [registry],
  });

  app.use((req, res, next) => {
    const end = httpRequestDuration.startTimer();
    res.on('finish', () => {
      end({ method: req.method, route: req.route ? req.route.path : req.path, status_code: res.statusCode });
    });
    next();
  });

  // In-memory order store (demo only -- a real deployment would use a database)
  const orders = new Map();

  let isReady = false;
  const warmupTimer = setTimeout(() => { isReady = true; }, 2000);
  warmupTimer.unref();

  app.get('/healthz', (req, res) => {
    res.status(200).json({ status: 'ok' });
  });

  app.get('/readyz', (req, res) => {
    if (!isReady) return res.status(503).json({ status: 'starting' });
    res.status(200).json({ status: 'ready' });
  });

  app.get('/metrics', async (req, res) => {
    res.set('Content-Type', registry.contentType);
    res.end(await registry.metrics());
  });

  app.get('/orders', (req, res) => {
    res.json(Array.from(orders.values()));
  });

  app.get('/orders/:id', (req, res) => {
    const order = orders.get(req.params.id);
    if (!order) return res.status(404).json({ error: 'order not found' });
    res.json(order);
  });

  app.post('/orders', (req, res) => {
    const { item, quantity } = req.body || {};
    if (!item || !quantity) {
      return res.status(400).json({ error: 'item and quantity are required' });
    }
    const order = {
      id: crypto.randomUUID(),
      item,
      quantity,
      createdAt: new Date().toISOString(),
    };
    orders.set(order.id, order);
    ordersCreatedTotal.inc();
    res.status(201).json(order);
  });

  app.setReadyForTest = () => { isReady = true; };

  return app;
}

module.exports = { createApp };
