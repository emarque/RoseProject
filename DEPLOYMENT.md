# Rose Receptionist - Deployment Guide

## 🔒 IMPORTANT: API Key Authentication Required

This deployment guide has been updated for the new two-tier API key authentication system. You MUST configure API keys for the system to work.

## Prerequisites
- Docker and Docker Compose installed (or .NET 8.0 SDK)
- Domain name pointing to your server
- **Anthropic API key** (for Claude AI)
- **Master API key** (generated during setup for system administration)

## Docker Deployment (Recommended)

### 1. Setup Environment

```bash
# Clone the repository
git clone https://github.com/yourusername/RoseProject.git
cd RoseProject

# Create environment file
cp .env.example .env
```

### 2. Generate Master API Key

**Linux/Mac:**
```bash
openssl rand -base64 32
```

**Windows PowerShell:**
```powershell
[Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

**Save this key securely!** You'll need it to:
- Generate subscriber keys
- Manage subscriber accounts
- Access system admin features

### 3. Configure Environment Variables

Edit `.env` file:
```bash
# Required: System Admin Access
MASTER_API_KEY=your-generated-master-key-here

# Required: Claude AI
ANTHROPIC_API_KEY=your-anthropic-key-here

# Optional: Override defaults
# DATABASE_PATH=./data/rose.db
# API_PORT=5000
```

### 4. Update Docker Compose

Ensure `docker-compose.yml` includes the new environment variables:
```yaml
version: '3.8'
services:
  rose-api:
    build: .
    ports:
      - "5000:5000"
    environment:
      - ApiAuthentication__MasterApiKey=${MASTER_API_KEY}
      - Anthropic__ApiKey=${ANTHROPIC_API_KEY}
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
```

### 5. Database Setup

**Note:** The database is created automatically on first run!

When the application starts for the first time:
- The SQLite database (`rose.db`) will be created automatically
- All migrations including `SubscriberApiKeys` table will be applied
- Default settings will be seeded
- No manual intervention required

The application logs will show:
```
[INF] Checking database...
[INF] Applying migration '20260209231549_AddSubscriberApiKeys'
[INF] Database ready
[INF] Seeding default data...
[INF] Default data seeded successfully
```

### 6. Deploy
```bash
# Build and start the service
docker-compose up -d

# Check logs
docker-compose logs -f

# Access at http://your-server:5000
```

### 7. Verify Installation

Test system admin access with your master key:
```bash
curl http://localhost:5000/api/system/status \
  -H "X-API-Key: your-master-key-here"
```

**Expected Response:**
```json
{
  "totalSubscribers": 0,
  "activeSubscribers": 0,
  "totalRequests": 0,
  "totalCreditsUsed": 0,
  "serverTime": "2024-12-20T18:30:00Z",
  "subscribersByLevel": {}
}
```

### 8. Create First Subscriber

Generate a subscriber API key for your first user:
```bash
curl http://localhost:5000/api/system/subscribers/generate-key \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-master-key-here" \
  -d '{
    "subscriberId": "subscriber-001",
    "subscriberName": "First User",
    "subscriptionLevel": 2,
    "creditLimit": 5000
  }'
```

Save the returned `apiKey` - you'll provide this to your subscribers.

## Manual Deployment (Without Docker)
```

### 5. Configure Nginx (SSL)
```nginx
server {
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# Install SSL certificate
sudo certbot --nginx -d your-domain.com
```

### 6. Configure Second Life Scripts
1. Update `RoseConfig` notecard with your API endpoint
2. Add scripts to your object
3. Test!

## Manual Deployment

### 1. Install .NET 8.0
```bash
# Ubuntu/Debian
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --channel 8.0
```

### 2. Build and Deploy
```bash
# Build the application
cd RoseReceptionist.API
dotnet publish -c Release -o /opt/rose-receptionist

# Install systemd service
sudo cp rose-receptionist.service /etc/systemd/system/
sudo systemctl enable rose-receptionist
sudo systemctl start rose-receptionist

# The database will be created automatically on first run
# Check the logs to verify:
sudo journalctl -u rose-receptionist -f
```

### 3. Configure appsettings.json
```bash
sudo nano /opt/rose-receptionist/appsettings.json
# Add your Anthropic API key and owner UUIDs
```

### 4. Restart Service
```bash
sudo systemctl restart rose-receptionist
sudo systemctl status rose-receptionist
```

## Troubleshooting

### Check Application Status
```bash
# Docker
docker-compose ps
docker-compose logs rose-api

# Systemd
sudo systemctl status rose-receptionist
sudo journalctl -u rose-receptionist -f
```

### Test API Endpoints
```bash
# Test health
curl http://localhost:5000/swagger/index.html

# Test arrival endpoint
curl -X POST http://localhost:5000/api/chat/arrival \
  -H "Content-Type: application/json" \
  -d '{"avatarKey":"test","avatarName":"Test","location":"Office"}'
```

### Common Issues

**Issue**: Database initialization errors
```bash
# Check logs for database creation issues
sudo journalctl -u rose-receptionist -f

# Verify database file permissions
ls -l /opt/rose-receptionist/rose.db

# If database is corrupted, you can safely delete it (backup first!)
sudo mv /opt/rose-receptionist/rose.db /opt/rose-receptionist/rose.db.backup
sudo systemctl restart rose-receptionist
# A fresh database will be created automatically
```

**Issue**: Database permission errors
```bash
# Fix permissions
sudo chown -R www-data:www-data /opt/rose-receptionist/data
```

**Issue**: Port already in use
```bash
# Find and kill process
sudo lsof -i :5000
sudo kill -9 <PID>
```

**Issue**: SSL certificate errors
```bash
# Renew certificate
sudo certbot renew
```

## Maintenance

### Update Application
```bash
# Docker
docker-compose pull
docker-compose up -d

# Manual
cd RoseProject
git pull
cd RoseReceptionist.API
dotnet publish -c Release -o /opt/rose-receptionist
sudo systemctl restart rose-receptionist
```

### Backup Database
```bash
# Docker
docker cp rose-receptionist-api:/app/data/rose.db ./backup/

# Manual
sudo cp /opt/rose-receptionist/data/rose.db ./backup/
```

### Monitor Logs
```bash
# Docker
docker-compose logs -f --tail=100

# Manual
sudo journalctl -u rose-receptionist -f
tail -f /opt/rose-receptionist/logs/rose-*.txt
```

## Performance Tuning

### For High Traffic
1. Increase connection pool size in appsettings.json
2. Use Redis for caching instead of in-memory
3. Deploy behind a load balancer
4. Enable response compression

### For Low Resources
1. Use claude-3-haiku instead of sonnet
2. Reduce ConversationContextLimit to 5
3. Lower SessionTimeoutMinutes
4. Clean up old data more frequently

## Security Checklist

- [ ] Changed default API keys
- [ ] Enabled HTTPS
- [ ] Configured firewall (allow 80, 443)
- [ ] Set up automatic updates
- [ ] Configured rate limiting
- [ ] Restricted database permissions
- [ ] Enabled log rotation
- [ ] Set up monitoring/alerts

## Support

For issues or questions:
- GitHub Issues: https://github.com/yourusername/RoseProject/issues
- Documentation: See README.md
