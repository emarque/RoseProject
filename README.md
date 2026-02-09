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

## 🔒 Security Setup

### Configuring API Credentials

API credentials are stored **in the script itself** for security, not in the notecard.

**Why?** LSL scripts can only be viewed by their creator, while notecards can be read by anyone with object permissions.

### Setup Steps

1. In Second Life, right-click your Rose object and select **Edit**
2. Go to the **Contents** tab
3. Double-click **RoseReceptionist_Main** to open the script
4. Find the **SECURITY CONFIGURATION** section at the top
5. Replace the placeholder values:
   ```lsl
   string API_ENDPOINT = "https://rosercp.pantherplays.com/api";
   string API_KEY = "your-actual-api-key-here";
   ```
6. Click **Save**
7. The script will automatically reset and validate your configuration

### Generating a Secure API Key

Use one of these methods to generate a strong API key:

**Linux/Mac:**
```bash
openssl rand -base64 32
```

**PowerShell (Windows):**
```powershell
[Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

**Example output:** `7Hn9Kp2Lm4Qr6Ts8Vw1Xz3Bc5Df7Gh9Jk`

Add this same key to your backend `appsettings.json`:
```json
{
  "ApiAuthentication": {
    "ApiKey": "7Hn9Kp2Lm4Qr6Ts8Vw1Xz3Bc5Df7Gh9Jk"
  }
}
```

## 📝 User Configuration (RoseConfig Notecard)

The `RoseConfig` notecard contains **non-sensitive** settings that users can customize:

- Owner avatar UUIDs
- Wandering behavior
- Greeting preferences  
- Appearance settings

These settings can be safely shared and modified without exposing your API credentials.

## 🔐 Security Benefits

| Storage Location | Visibility | Use For |
|-----------------|------------|---------|
| **LSL Script** | Creator only ✅ | API keys, endpoints, secrets |
| **Notecard** | Anyone with permissions ⚠️ | User preferences, non-sensitive config |

**Users cannot extract your API credentials from the object.**

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
