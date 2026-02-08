# Rose Receptionist - Quick Deployment Guide

## Docker Deployment (Recommended)

### 1. Prerequisites
- Docker and Docker Compose installed
- Domain name pointing to your server
- Anthropic API key

### 2. Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/RoseProject.git
cd RoseProject

# Create environment file
cp .env.example .env

# Edit .env and add your credentials
nano .env
```

### 3. Database Setup

**Note:** The database is created automatically on first run!

When the application starts for the first time:
- The SQLite database (`rose.db`) will be created automatically
- All migrations will be applied
- Default settings will be seeded
- No manual intervention required

The application logs will show:
```
[INF] Checking database...
[INF] Applying migration '...'
[INF] Database ready
[INF] Seeding default data...
[INF] Default data seeded successfully
```

### 4. Deploy
```bash
# Build and start the service
docker-compose up -d

# Check logs
docker-compose logs -f

# Access at http://your-server:5000
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
