# Rose Receptionist System

Rose is an intelligent virtual receptionist for Second Life that combines LSL scripts with a .NET Core backend and Claude AI to create natural, context-aware conversations.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Second Life (LSL)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Sensor     │  │     Chat     │  │  Animations  │     │
│  │   Script     │──│    Script    │──│    Script    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                 │                  │             │
│         └─────────────────┼──────────────────┘             │
│                           │                                │
│                    ┌──────┴───────┐                        │
│                    │     Main     │                        │
│                    │    Script    │                        │
│                    └──────┬───────┘                        │
│                           │                                │
└───────────────────────────┼────────────────────────────────┘
                            │ HTTPS
                            │
┌───────────────────────────┼────────────────────────────────┐
│                   Backend Server (.NET)                    │
│                           │                                │
│                    ┌──────┴───────┐                        │
│                    │     API      │                        │
│                    │  Controllers │                        │
│                    └──────┬───────┘                        │
│                           │                                │
│    ┌──────────────────────┼──────────────────────┐         │
│    │                      │                      │         │
│ ┌──┴────┐           ┌─────┴─────┐          ┌────┴────┐    │
│ │Claude │           │ Personality│          │ Message │    │
│ │Service│           │  Service   │          │  Queue  │    │
│ └───┬───┘           └─────┬─────┘          └────┬────┘    │
│     │                     │                      │         │
│     └─────────────────────┼──────────────────────┘         │
│                           │                                │
│                    ┌──────┴───────┐                        │
│                    │   Database   │                        │
│                    │   (SQLite)   │                        │
│                    └──────────────┘                        │
└────────────────────────────────────────────────────────────┘
                            │
                            │ API Call
                            │
┌───────────────────────────┼────────────────────────────────┐
│                   Anthropic Claude API                     │
│                    (AI Conversation)                       │
└────────────────────────────────────────────────────────────┘
```

## Features

- **Natural Conversations**: Uses Claude AI for intelligent, context-aware responses
- **Dual Personality System**: Different behavior for office owners vs. visitors
- **Message Queue**: Store messages when recipients are offline
- **Smart Wandering**: Natural movement within defined boundaries
- **Avatar Detection**: Automatic greeting when visitors arrive
- **Animation System**: Contextual gestures and expressions
- **Conversation Memory**: Maintains context across multiple messages
- **Access Control**: Configurable roles (Owner, Visitor, Blocked)

## Prerequisites

### Backend Server
- .NET 8.0 SDK
- SQLite
- VPS or cloud hosting with public HTTPS endpoint
- Anthropic API key (https://console.anthropic.com/)

### Second Life
- Land with script permissions
- Avatar or NPC to host the scripts
- Build/modify permissions on the object

## Quick Start

### Backend Setup

1. **Configure Settings**
   Edit `RoseReceptionist.API/appsettings.json` and add your Anthropic API key and owner UUIDs.

2. **Run Locally**
   ```bash
   cd RoseReceptionist.API
   dotnet restore
   dotnet build
   dotnet run
   ```

3. **Deploy to Production**
   Use Docker or systemd service (see detailed documentation below).

### Second Life Setup

1. Create an object in Second Life
2. Add all 5 LSL scripts from `RoseReceptionist.LSL/` folder
3. Create a `RoseConfig` notecard with your API endpoint and settings
4. Optionally add animations: wave, offer, think, flirt

## Detailed Documentation

### Installation

#### Backend Setup (VPS Deployment)

**Option A: Docker Deployment**
```bash
docker build -t rose-receptionist .
docker run -d -p 5000:5000 -v /opt/rose-data:/app/data rose-receptionist
```

**Option B: systemd Service**
```bash
dotnet publish -c Release -o /opt/rose-receptionist
sudo cp rose-receptionist.service /etc/systemd/system/
sudo systemctl enable rose-receptionist
sudo systemctl start rose-receptionist
```

#### Configure Reverse Proxy (Nginx)
```nginx
server {
    listen 80;
    server_name your-domain.com;
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
    }
}
```

Add SSL: `sudo certbot --nginx -d your-domain.com`

### API Endpoints

#### POST /api/chat/arrival
Notify Rose of visitor arrival
```json
{
  "avatarKey": "uuid",
  "avatarName": "John Doe",
  "location": "Virtual Office"
}
```

#### POST /api/chat/message
Send message to Rose
```json
{
  "avatarKey": "uuid",
  "avatarName": "John Doe",
  "message": "Hello Rose!",
  "location": "Office",
  "sessionId": "guid"
}
```

#### POST /api/message/queue
Queue message for offline delivery

#### GET /api/message/pending/{avatarKey}
Retrieve pending messages

#### GET /api/config/access-list
Manage access control list

## Configuration

### appsettings.json
```json
{
  "Anthropic": {
    "ApiKey": "your-key-here",
    "Model": "claude-3-haiku-20240307",
    "MaxTokens": "150"
  },
  "Rose": {
    "DefaultOwnerKeys": ["your-sl-uuid"],
    "ConversationContextLimit": "10"
  }
}
```

### RoseConfig Notecard (Second Life)
```
API_ENDPOINT=https://your-domain.com/api
OWNER_UUID_1=your-uuid-here
WANDER_ENABLED=TRUE
WANDER_RADIUS=10
RECEPTIONIST_NAME=Rose
```

## Troubleshooting

### Backend Issues
- **500 errors**: Check logs in `logs/` directory
- **Database errors**: Verify write permissions
- **Claude timeout**: Check API key and rate limits

### Second Life Issues
- **No response**: Verify API_ENDPOINT in RoseConfig
- **No movement**: Enable pathfinding and check permissions
- **No animations**: Add animations to inventory

## Cost Estimates

- **Claude API**: ~$0.45/month (1000 messages/day)
- **VPS Hosting**: $10-20/month
- **Total**: ~$10-20/month

## Security

1. Change default API key
2. Use HTTPS only
3. Enable rate limiting
4. Restrict database permissions
5. Rotate logs regularly

## Support

For issues or questions:
- GitHub Issues
- Second Life contact: [Your SL Name]

## License

MIT License

---

Built with ❤️ for the Second Life community
