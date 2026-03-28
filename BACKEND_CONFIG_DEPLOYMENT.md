# Backend Config Service - Deployment Guide

## Summary

Created a Node.js Express backend that serves app configuration from a JSON file instead of hardcoded values.

## Changes Made

### New Files Created

1. **backend/src/config-loader.js** - Config file reader with:
   - Reads from `/etc/wawapp/config.json`
   - Falls back to safe defaults if file missing/invalid
   - 1-minute caching to reduce I/O
   - Clear error logging

2. **backend/src/server.js** - Express API server:
   - Serves `GET /api/public/config`
   - Adds `serverTime` as ISO string
   - Health check endpoint: `GET /health`

3. **backend/package.json** - NPM dependencies

4. **backend/README.md** - Complete documentation

5. **backend/config.example.json** - Sample config file

6. **backend/.gitignore** - Git ignore file

## Safe Defaults

If `/etc/wawapp/config.json` doesn't exist or is invalid:

```json
{
  "minClientVersion": "1.0.0",
  "maintenance": false,
  "forceUpdate": false,
  "supportWhatsApp": null,
  "message": null
}
```

Plus `serverTime` is always added to response.

## API Response Format

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

## Deployment to 77.42.76.36

### Quick Deploy Script

```bash
#!/bin/bash
# Deploy to 77.42.76.36

SERVER="root@77.42.76.36"
REMOTE_PATH="/opt/wawapp-backend"

echo "📦 Copying backend files to server..."
scp -r backend ${SERVER}:${REMOTE_PATH}

echo "🔌 Connecting to server..."
ssh ${SERVER} << 'ENDSSH'
  cd /opt/wawapp-backend
  
  echo "📥 Installing dependencies..."
  npm install --production
  
  echo "📝 Creating config directory..."
  mkdir -p /etc/wawapp
  
  if [ ! -f /etc/wawapp/config.json ]; then
    echo "📄 Creating default config file..."
    cat > /etc/wawapp/config.json << 'EOF'
{
  "minClientVersion": "1.0.5",
  "maintenance": false,
  "forceUpdate": false,
  "supportWhatsApp": "+222XXXXXXXX",
  "message": null
}
EOF
  else
    echo "✅ Config file already exists at /etc/wawapp/config.json"
  fi
  
  echo "🔒 Setting permissions..."
  chmod 644 /etc/wawapp/config.json
  
  echo "🚀 Starting server with PM2..."
  npm install -g pm2
  pm2 delete wawapp-config-api 2>/dev/null || true
  pm2 start src/server.js --name wawapp-config-api
  pm2 save
  
  echo "✅ Deployment complete!"
  echo "📊 Server status:"
  pm2 status
  
  echo ""
  echo "🧪 Testing endpoint..."
  sleep 2
  curl http://localhost/api/public/config
ENDSSH

echo ""
echo "🎉 Done! Test the endpoint:"
echo "curl http://77.42.76.36/api/public/config"
```

### Manual Deployment Steps

1. **Copy files to server:**
   ```bash
   scp -r backend root@77.42.76.36:/opt/wawapp-backend
   ```

2. **SSH into server:**
   ```bash
   ssh root@77.42.76.36
   ```

3. **Install dependencies:**
   ```bash
   cd /opt/wawapp-backend
   npm install --production
   ```

4. **Create config file:**
   ```bash
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
   chmod 644 /etc/wawapp/config.json
   ```

5. **Start server (Option A - PM2):**
   ```bash
   npm install -g pm2
   pm2 start src/server.js --name wawapp-config-api
   pm2 save
   pm2 startup  # Follow the instructions
   ```

6. **Start server (Option B - systemd):**
   ```bash
   cat > /etc/systemd/system/wawapp-config.service << 'EOF'
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
   EOF
   
   systemctl daemon-reload
   systemctl enable wawapp-config
   systemctl start wawapp-config
   systemctl status wawapp-config
   ```

7. **Test:**
   ```bash
   curl http://77.42.76.36/api/public/config
   ```

## Operational Config Changes

### Enable Maintenance Mode

Edit `/etc/wawapp/config.json`:
```bash
ssh root@77.42.76.36
nano /etc/wawapp/config.json
```

Set:
```json
{
  "minClientVersion": "1.0.5",
  "maintenance": true,
  "message": "نعتذر، الخدمة متوقفة مؤقتاً للصيانة",
  "forceUpdate": false,
  "supportWhatsApp": "+222XXXXXXXX"
}
```

**No restart needed** - config auto-reloads within 1 minute.

### Force Update

```json
{
  "minClientVersion": "1.0.5",
  "maintenance": false,
  "forceUpdate": true,
  "message": "يرجى تحديث التطبيق",
  "supportWhatsApp": "+222XXXXXXXX"
}
```

### Bump Minimum Version

```json
{
  "minClientVersion": "1.1.0",
  "maintenance": false,
  "forceUpdate": false,
  "supportWhatsApp": "+222XXXXXXXX",
  "message": null
}
```

## Monitoring

### Check Server Status (PM2)
```bash
pm2 status
pm2 logs wawapp-config-api
```

### Check Server Status (systemd)
```bash
systemctl status wawapp-config
journalctl -u wawapp-config -f
```

### Test Endpoint
```bash
curl http://77.42.76.36/api/public/config
```

## Logs

Server logs all requests and operations:

```
[2026-01-03T09:30:00.000Z] GET /api/public/config
[ConfigLoader] Config loaded successfully from file
```

**File missing:**
```
[ConfigLoader] Config file not found at /etc/wawapp/config.json, using safe defaults
```

**Invalid JSON:**
```
[ConfigLoader] Error loading config: Unexpected token } in JSON at position 45
```

## Rollback

If issues occur, restore old behavior by redeploying previous server version or point backend to a hardcoded config.

## Testing Checklist

- [ ] Deploy backend to server
- [ ] Create `/etc/wawapp/config.json`
- [ ] Start server (PM2 or systemd)
- [ ] Test: `curl http://77.42.76.36/api/public/config`
- [ ] Verify `serverTime` is present
- [ ] Test missing file scenario (rename config file temporarily)
- [ ] Test invalid JSON (add syntax error)
- [ ] Verify safe defaults are returned
- [ ] Test maintenance mode (set `maintenance: true`)
- [ ] Test force update (set `forceUpdate: true`)
- [ ] Test version bump (set `minClientVersion: "2.0.0"`)

## Notes

- **Minimal change**: New backend, no changes to existing Firebase Functions
- **Safe defaults**: Always returns valid config even on errors
- **No restart**: Config changes take effect within 1 minute (cache TTL)
- **Clear logs**: All operations logged for debugging
- **Production ready**: Includes systemd service file and PM2 config

## Support

See `backend/README.md` for complete documentation.
