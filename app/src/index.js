const { createApp } = require('./app');

const PORT = process.env.PORT || 8080;
const app = createApp();

const server = app.listen(PORT, () => {
  console.log(`orders-backend listening on :${PORT}`);
});

// Graceful shutdown: stop accepting new connections and let in-flight
// requests finish before the pod's Envoy sidecar also terminates.
function shutdown() {
  console.log('received shutdown signal, draining connections...');
  server.close(() => process.exit(0));
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
