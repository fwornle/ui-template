import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = process.env.PORT || 3030;
const DIST_DIR = path.join(__dirname, 'dist');

// MIME types for common file extensions
const MIME_TYPES = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.eot': 'application/vnd.ms-fontobject',
};

// Helper to get local time string
function localTime() {
  return new Date().toLocaleTimeString();
}

// Create HTTP server
const server = http.createServer((req, res) => {
  console.log(`[${localTime()}] ${req.method} ${req.url}`);

  // Handle API routes
  if (req.url?.startsWith('/api/')) {
    handleApiRoute(req, res);
    return;
  }

  // Serve static files from dist directory
  let filePath = path.join(DIST_DIR, req.url === '/' ? 'index.html' : req.url);

  // For SPA routing, serve index.html for non-file routes
  const ext = path.extname(filePath);
  if (!ext) {
    filePath = path.join(DIST_DIR, 'index.html');
  }

  // Check if file exists
  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      // Serve index.html for SPA routing
      filePath = path.join(DIST_DIR, 'index.html');
    }

    const mimeType = MIME_TYPES[path.extname(filePath)] || 'application/octet-stream';

    fs.readFile(filePath, (readErr, data) => {
      if (readErr) {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found');
        return;
      }

      res.writeHead(200, { 'Content-Type': mimeType });
      res.end(data);
    });
  });
});

// Handle API routes
function handleApiRoute(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);

  // Health check endpoint
  if (url.pathname === '/api/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    }));
    return;
  }

  // Version endpoint
  if (url.pathname === '/api/version') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      version: '1.0.0',
      environment: process.env.NODE_ENV || 'development',
    }));
    return;
  }

  // 404 for unknown API routes
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not Found' }));
}

// Handle uncaught errors
process.on('uncaughtException', (error) => {
  console.error(`[${localTime()}] Uncaught Exception:`, error);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error(`[${localTime()}] Unhandled Rejection at:`, promise, 'reason:', reason);
});

// Start server
server.listen(PORT, () => {
  console.log(`[${localTime()}] Server running at http://localhost:${PORT}`);
  console.log(`[${localTime()}] Serving static files from: ${DIST_DIR}`);
});
