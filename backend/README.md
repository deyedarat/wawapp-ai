# WawApp Config Backend

Simple Express API that serves app configuration from a JSON file.

## Features

- ✅ Reads config from `/etc/wawapp/config.json`
- ✅ Falls back to safe defaults if file missing or invalid
- ✅ Adds `serverTime` to every response
- ✅ In-memory caching (1 minute TTL)
- ✅ Clear error logging

## API Endpoint

### GET /api/public/config

Returns app configuration with server time.

**Response:**
```json
{
  "minClientVersion": "1.0.5",
  "maintenance": false,
  "forceUpdate": false,
  "supportWhatsApp": "+222XXXXXXXX",
  "message": null,
  "serverTime": "2026-01-03T09:30:00.000Z"
}
```

## Installation

```bash
cd backend
npm install
```

## Usage

### Development
```bash
npm run dev
```

### Production
```bash
npm start
```

### With PM2
```bash
pm2 start src/server.js --name wawapp-config-api
```

### With systemd
Create `/etc/systemd/system/wawapp-config.service`:
```ini
[Unit]
Description=WawApp Config API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/wawapp-backend
ExecStart=/usr/bin/node src/server.js
Restart=always
Environment=NODE_ENV=production
Environment=PORT=80

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable wawapp-config
sudo systemctl start wawapp-config
sudo systemctl status wawapp-config
```

## Configuration File

Create `/etc/wawapp/config.json`:

```json
{
  "minClientVersion": "1.0.5",
  "maintenance": false,
  "forceUpdate": false,
  "supportWhatsApp": "+222XXXXXXXX",
  "message": null
}
```

### Config Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `minClientVersion` | string | No | Minimum app version required (semantic versioning) |
| `maintenance` | boolean | No | Enable maintenance mode (blocks app access) |
| `forceUpdate` | boolean | No | Force users to update immediately |
| `supportWhatsApp` | string\|null | No | WhatsApp support number for contact |
| `message` | string\|null | No | Custom message to display (e.g., maintenance reason) |

### Safe Defaults

If `/etc/wawapp/config.json` is missing or invalid:

```json
{
  "minClientVersion": "1.0.0",
  "maintenance": false,
  "forceUpdate": false,
  "supportWhatsApp": null,
  "message": null
}
```

## Deployment on 77.42.76.36

### Option 1: Direct Deployment

```bash
# 1. Copy backend folder to server
scp -r backend root@77.42.76.36:/opt/wawapp-backend

# 2. SSH into server
ssh root@77.42.76.36

# 3. Install dependencies
cd /opt/wawapp-backend
npm install --production

# 4. Create config file
mkdir -p /etc/wawapp
cat > /etc/wawapp/config.json << 'EOF'
{
  "minClientVersion": "1.0.5",
  "maintenance": false,
  "forceUpdate": false,
  "supportWhatsApp": "+222XXXXXXXX",
  "message": null
}
EOF

# 5. Start with PM2
npm install -g pm2
pm2 start src/server.js --name wawapp-config-api
pm2 save
pm2 startup
```

### Option 2: Using systemd (Recommended for Production)

```bash
# 1-4: Same as Option 1

# 5. Create systemd service
sudo nano /etc/systemd/system/wawapp-config.service
# (Copy the systemd unit file from above)

# 6. Enable and start
sudo systemctl daemon-reload
sudo systemctl enable wawapp-config
sudo systemctl start wawapp-config
sudo systemctl status wawapp-config

# 7. Check logs
sudo journalctl -u wawapp-config -f
```

## Testing

```bash
# Test local
curl http://localhost/api/public/config

# Test remote
curl http://77.42.76.36/api/public/config
```

## Maintenance Operations

### Enable Maintenance Mode

Edit `/etc/wawapp/config.json`:
```json
{
  "minClientVersion": "1.0.5",
  "maintenance": true,
  "message": "نعتذر، الخدمة متوقفة مؤقتاً للصيانة",
  "forceUpdate": false,
  "supportWhatsApp": "+222XXXXXXXX"
}
```

No server restart needed (config reloads automatically with 1-minute cache).

### Force Update

```json
{
  "minClientVersion": "1.0.5",
  "maintenance": false,
  "forceUpdate": true,
  "message": "يرجى تحديث التطبيق إلى أحدث إصدار",
  "supportWhatsApp": "+222XXXXXXXX"
}
```

### Minimum Version Bump

```json
{
  "minClientVersion": "1.1.0",
  "maintenance": false,
  "forceUpdate": false,
  "supportWhatsApp": "+222XXXXXXXX",
  "message": null
}
```

Users with version < 1.1.0 will see update screen.

## Logs

The server logs all requests and config load operations:

```
[2026-01-03T09:30:00.000Z] GET /api/public/config
[ConfigLoader] Config loaded successfully from file
```

If config file is missing:
```
[ConfigLoader] Config file not found at /etc/wawapp/config.json, using safe defaults
```

If JSON is invalid:
```
[ConfigLoader] Error loading config: Unexpected token } in JSON at position 45
```

## Architecture

- **config-loader.js**: Config file reader with caching and safe defaults
- **server.js**: Express API server
- **Cache**: 1-minute TTL to reduce file I/O
- **Error Handling**: Always returns safe defaults on error

## Security Notes

- Config file should be owned by root: `sudo chown root:root /etc/wawapp/config.json`
- Permissions: `sudo chmod 644 /etc/wawapp/config.json`
- Server runs on port 80 (requires root or CAP_NET_BIND_SERVICE)

## Support

For issues or questions, see the main WawApp documentation.
