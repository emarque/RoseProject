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
- **Smart Wandering with Home Position**: Natural movement with configurable home base
- **Avatar Detection**: Automatic greeting when visitors arrive
- **Animation System**: Contextual gestures and expressions
- **Conversation Memory**: Maintains context across multiple messages
- **Access Control**: Configurable roles (Owner, Visitor, Blocked)
- **Chat Actions**: Natural language commands trigger in-world actions (give items, navigate, etc.)
- **Activity Context**: AI is aware of Rose's current activity and available services

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

## 🔒 Two-Tier API Key Authentication

Rose uses a two-tier authentication system to support multiple paying subscribers:

### 1. **Subscriber API Keys** (Customer-Facing)
For regular subscribers who use Rose in their Second Life locations.

### 2. **Master API Key** (System Admin)
For system administrators to manage subscriber accounts.

---

## 🎫 For Subscribers: Getting Started

### Obtaining Your API Key

Contact your service provider to receive your unique subscriber API key.

### Configuring Your Rose Receptionist

1. In Second Life, right-click your Rose object and select **Edit**
2. Go to the **Contents** tab
3. Find or create a notecard named **RoseConfig**
4. Add your subscriber key:
   ```
   SUBSCRIBER_KEY=your-subscriber-key-here
   ```
5. Save the notecard
6. Reset the scripts (right-click object → More → Reset Scripts)

**Your Rose is now ready to use!**

### Subscription Levels

| Level | Name | Monthly Credits | Best For |
|-------|------|-----------------|----------|
| 1 | Basic | 1,000 | Small shops, personal offices |
| 2 | Pro | 5,000 | Busy stores, event venues |
| 3 | Enterprise | 50,000 | High-traffic locations, multiple sites |

### Credit System

- Each API request (greeting, chat message) consumes 1 credit
- When credits are exhausted, Rose will stop responding until the next billing cycle
- Check your credit usage: Touch your Rose object and say "credits"
- Upgrade your subscription at any time by contacting your provider

### RoseConfig Notecard Reference

```
# API Configuration
SUBSCRIBER_KEY=your-subscriber-key-here

# Optional: Custom API endpoint
# API_ENDPOINT=https://rosercp.pantherplays.com/api

# Owner UUIDs (can have multiple)
OWNER_UUID=00000000-0000-0000-0000-000000000000

# Home Position (NEW)
HOME_WAYPOINT=0
HOME_DURATION_MINUTES=15

# Available Menu Items (NEW - comma-separated)
AVAILABLE_ACTIONS=Coffee, Tea, Water, Hot Chocolate, Espresso

# Advanced Settings
# GREETING_RANGE=10
```

**New Features:**
- `HOME_WAYPOINT`: Waypoint number where Rose spends most of her time (set to -1 to disable)
- `HOME_DURATION_MINUTES`: How long Rose stays at home before starting her activity loop
- `AVAILABLE_ACTIONS`: Services/items Rose can provide via natural language chat

See [docs/HOME_POSITION_AND_CHAT_ACTIONS.md](docs/HOME_POSITION_AND_CHAT_ACTIONS.md) for detailed documentation.

---

## 🔐 For System Administrators

### Master API Key Configuration

The master API key is stored **only** in the backend server configuration and grants access to all system administration endpoints.

**Backend Setup (`appsettings.json`):**
```json
{
  "ApiAuthentication": {
    "MasterApiKey": "your-master-key-here"
  },
  "SubscriptionLevels": {
    "1": {
      "Name": "Basic",
      "CreditLimit": 1000
    },
    "2": {
      "Name": "Pro",
      "CreditLimit": 5000
    },
    "3": {
      "Name": "Enterprise",
      "CreditLimit": 50000
    }
  }
}
```

### Generating Secure API Keys

**For Master Key (Linux/Mac):**
```bash
openssl rand -base64 32
```

**PowerShell (Windows):**
```powershell
[Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

### System Admin API Endpoints

All endpoints require the master API key via `X-API-Key` header.

#### Create New Subscriber
```http
POST /api/system/subscribers/generate-key
Content-Type: application/json
X-API-Key: your-master-key

{
  "subscriberId": "customer-123",
  "subscriberName": "Jane's Boutique",
  "subscriptionLevel": 2,
  "notes": "Pro plan - annual billing",
  "orderNumber": "ORD-2024-001",
  "creditLimit": 5000,
  "expiresAt": "2025-12-31T23:59:59Z"
}
```

**Response:**
```json
{
  "id": "guid",
  "apiKey": "generated-subscriber-key",
  "subscriberId": "customer-123",
  "subscriberName": "Jane's Boutique",
  "subscriptionLevel": 2,
  "createdAt": "2024-01-15T10:30:00Z",
  "expiresAt": "2025-12-31T23:59:59Z",
  "creditLimit": 5000
}
```

#### Activate/Deactivate Subscriber
```http
PUT /api/system/subscribers/{id}/status
Content-Type: application/json
X-API-Key: your-master-key

{
  "isActive": false
}
```

#### List All Subscribers
```http
GET /api/system/subscribers?activeOnly=true&level=2
X-API-Key: your-master-key
```

#### Get Subscriber Details
```http
GET /api/system/subscribers/{id}
X-API-Key: your-master-key
```

#### Update Credit Limits
```http
PUT /api/system/subscribers/{id}/credits
Content-Type: application/json
X-API-Key: your-master-key

{
  "creditLimit": 10000,
  "resetUsage": true
}
```

#### System Statistics
```http
GET /api/system/status
X-API-Key: your-master-key
```

**Response:**
```json
{
  "totalSubscribers": 25,
  "activeSubscribers": 23,
  "totalRequests": 45230,
  "totalCreditsUsed": 38942,
  "serverTime": "2024-01-15T10:30:00Z",
  "subscribersByLevel": {
    "1": 10,
    "2": 12,
    "3": 3
  }
}
```

#### Recent System Logs
```http
GET /api/system/logs?count=50&subscriberName=Jane
X-API-Key: your-master-key
```

### Using the LSL Admin Menu

If you configure your Rose with the master API key in the RoseConfig notecard, you can access system admin functions directly in Second Life:

1. Set `SUBSCRIBER_KEY` to your master key in RoseConfig
2. Touch your Rose object
3. Select from the admin menu:
   - **New API Key**: Generate a new subscriber key
   - **List Subs**: View all subscribers
   - **Status**: Check system statistics
   - **Logs**: View recent activity logs
   - **Credits**: Manage subscriber credits

### Security Best Practices

1. **Never commit** the master API key to version control
2. **Use environment variables** or secure secret management in production
3. **Rotate keys periodically** (at least annually)
4. **Monitor access logs** for unauthorized attempts
5. **Keep subscriber keys separate** from master key documentation
6. **Use HTTPS only** for all API communications

---

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

1. **Configure Settings**
   Edit `RoseReceptionist.API/appsettings.json` and add your Anthropic API key and owner UUIDs.

2. **Run Locally**
   ```bash
   cd RoseReceptionist.API
   dotnet restore
   dotnet build
   dotnet run
   ```
   **Note:** The database (`rose.db`) is created automatically on first run with default settings. No manual database setup required!

3. **Deploy to Production**
   Use Docker or systemd service (see detailed documentation below).

### Second Life Setup

1. Create an object in Second Life
2. Add all 5 LSL scripts from `RoseReceptionist.LSL/` folder
3. Edit **RoseReceptionist_Main** script and configure API credentials (see Security Setup above)
4. Create a `RoseConfig` notecard with owner UUIDs and other settings
5. Optionally add animations: wave, offer, think, flirt

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
# API credentials are configured in the script (secure)
OWNER_UUID_1=your-uuid-here
OWNER_UUID_2=your-uuid-here
WANDER_ENABLED=TRUE
WANDER_RADIUS=10
GREETING_RANGE=10
RECEPTIONIST_NAME=Rose
```

## Prim-Based Navigation System

Rose now features an intelligent waypoint navigation system that allows her to patrol specific areas and perform activities at designated locations.

### Overview

Instead of random wandering, Rose follows a path of numbered waypoint prims (Wander0, Wander1, Wander2, etc.) and performs actions defined in each prim's description. This creates realistic work routines like watering plants, checking equipment, or tidying the office.

### Setting Up Waypoints

1. **Create Waypoint Prims**
   - Create prims in Second Life and name them sequentially: `Wander0`, `Wander1`, `Wander2`, etc.
   - Rose will visit them in numerical order, looping back to the start after completing all waypoints.

2. **Configure Waypoint Actions**
   Each waypoint prim's **Description** field should contain JSON defining what Rose does at that location:

   ```json
   {"type":"linger","name":"watering plants","orientation":180,"time":45,"animation":"watering","attachments":[{"item":"WateringCan","point":"RightHand"}]}
   ```

3. **Action Types**
   
   **Transient** - Pass through without stopping
   ```json
   {"type":"transient","name":"walking through hallway"}
   ```
   
   **Linger** - Stop, face direction, play animation, wait
   ```json
   {"type":"linger","name":"checking computer","orientation":90,"time":30,"animation":"typing"}
   ```
   
   **Sit** - Sit at the location with optional animation
   ```json
   {"type":"sit","name":"taking a break","time":60,"animation":"sit_relaxed"}
   ```

4. **JSON Field Reference**
   - `type` (required): "transient", "linger", or "sit"
   - `name` (required): Activity description (e.g., "watering plants")
   - `orientation` (optional): Direction to face in degrees (0-360)
   - `time` (optional): Duration in seconds
   - `animation` (optional): Animation name from inventory
   - `attachments` (optional): Array of items to attach (e.g., tools, props)

### Example Setup

Here's a complete example of a 4-waypoint patrol route:

**Wander0** - Reception Desk
```json
{"type":"linger","name":"greeting visitors","orientation":0,"time":20}
```

**Wander1** - Break Room
```json
{"type":"linger","name":"making coffee","orientation":270,"time":30,"animation":"pouring"}
```

**Wander2** - Office Plants
```json
{"type":"linger","name":"watering plants","orientation":180,"time":45,"animation":"watering","attachments":[{"item":"WateringCan","point":"RightHand"}]}
```

**Wander3** - Hallway
```json
{"type":"transient","name":"walking to next area"}
```

### Activity Tracking & Reports

Rose automatically tracks all activities and generates daily reports:

- **Activity Logs**: Every action is logged with timestamp, location, and duration
- **Daily Reports**: At the end of shift (configurable time), Rose generates a summary using Claude AI
- **"What are you doing?"**: Rose can respond in chat with her current activity

### Configuration Options

Update `RoseConfig.txt` with these new settings:

```
# Wandering Configuration
WANDER_ENABLED=TRUE
WANDER_SENSOR_RANGE=50        # How far to scan for waypoints
WANDER_SCAN_INTERVAL=5        # How often to scan for new waypoints

# Shift and Reporting
SHIFT_START_TIME=09:00        # When Rose's workday begins
SHIFT_END_TIME=17:00          # When Rose's workday ends
DAILY_REPORT_TIME=17:05       # When to generate end-of-day report
```

### API Endpoints for Activity Tracking

The backend now includes these new endpoints:

- `POST /api/reports/activities` - Log a new activity
- `PUT /api/reports/activities/{id}/complete` - Complete an activity
- `GET /api/reports/activities/current` - Get Rose's current activity
- `GET /api/reports/activities/date/{date}` - Get all activities for a specific date
- `POST /api/reports/daily` - Generate daily report with Claude AI summary

### Tips for Best Results

1. **Spacing**: Place waypoints 5-10 meters apart for natural walking
2. **Line of Sight**: Ensure waypoints are within sensor range (50m default)
3. **Permissions**: Verify pathfinding is enabled on your land
4. **Animations**: Add custom animations to Rose's inventory for variety
5. **Activity Names**: Use descriptive names for better daily reports

## Troubleshooting

### Backend Issues
- **500 errors**: Check logs in `logs/` directory
- **Database errors**: Verify write permissions
- **Claude timeout**: Check API key and rate limits

### Second Life Issues

#### ❌ "ERROR: Please configure API_KEY in the script!"

**Cause:** The script still has the default placeholder API key.

**Solution:**
1. Edit the `RoseReceptionist_Main` script
2. Update `API_KEY` in the SECURITY CONFIGURATION section
3. Save the script

#### ⚠️ HTTP Request Fails with 401 Unauthorized

**Cause:** API key in script doesn't match the key in your backend configuration.

**Solution:**
1. Check your backend `appsettings.json` → `ApiAuthentication:ApiKey`
2. Compare with the `API_KEY` value in your LSL script
3. Make sure they match exactly
4. Restart both the backend service and reset LSL scripts

#### ⚠️ Content-Type Header Issue

**Important:** Second Life does NOT allow setting the `Content-Type` header directly - it's automatically set to `text/plain; charset=utf-8`.

**Solution:**
- The LSL scripts in this repository use the `HTTP_MIMETYPE` parameter to set the content type to `application/json`
- No action needed if using the provided scripts
- If writing custom scripts, use: `HTTP_MIMETYPE, "application/json"` in your HTTP parameters list

#### Other Issues
- **No response**: Verify API_ENDPOINT is configured correctly in the script
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
