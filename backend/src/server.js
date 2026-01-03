const express = require('express');
const ConfigLoader = require('./config-loader');

const app = express();
const PORT = process.env.PORT || 80;

// Initialize config loader
const configLoader = new ConfigLoader();

// Middleware for logging
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

/**
 * Public Config Endpoint
 * GET /api/public/config
 * Returns app configuration with serverTime
 */
app.get('/api/public/config', (req, res) => {
  try {
    const config = configLoader.getConfigWithServerTime();
    res.json(config);
  } catch (error) {
    console.error('[API Error] Failed to get config:', error);
    
    // Return safe defaults even on error
    res.json({
      minClientVersion: '1.0.0',
      maintenance: false,
      forceUpdate: false,
      supportWhatsApp: null,
      message: null,
      serverTime: new Date().toISOString()
    });
  }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[Server] WawApp Config API listening on port ${PORT}`);
  console.log(`[Server] Config path: ${configLoader.configPath}`);
  console.log(`[Server] Endpoint: http://0.0.0.0:${PORT}/api/public/config`);
});

module.exports = app;
