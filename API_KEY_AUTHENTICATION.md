# Rose Receptionist API Key Authentication Guide

## Overview

Rose uses a two-tier API key authentication system to support multiple paying subscribers while maintaining administrative control.

## Authentication Tiers

### 1. Subscriber API Keys (Customer-Facing)
- Stored in the database with metadata
- Each subscriber receives a unique key
- Can be activated/deactivated by administrators
- Configured in the Second Life RoseConfig notecard
- Subject to credit limits based on subscription level
- Grants access to regular Rose API endpoints

### 2. Master API Key (System Administrator)
- Stored only in backend `appsettings.json`
- Never exposed in user-facing documentation
- Grants access to system administration endpoints
- Used to manage subscriber accounts and system status
- Not subject to credit limits

## Security Model

```
┌──────────────────────────────────────────────────────┐
│              Second Life Client                       │
│  RoseConfig notecard: SUBSCRIBER_KEY=xxx             │
└────────────────────┬─────────────────────────────────┘
                     │ X-API-Key Header
                     ▼
┌──────────────────────────────────────────────────────┐
│           API Key Authentication Middleware          │
│                                                       │
│  1. Check if key exists                              │
│  2. Master key? → System Admin Access                │
│  3. Subscriber key?                                   │
│     - Lookup in database                             │
│     - Check if active                                │
│     - Check if expired                               │
│     - Check credit limit                             │
│     - Track usage                                    │
└────────────────────┬─────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────┐
│            API Controllers                           │
│                                                       │
│  [RequireSystemKey] → System Admin Only              │
│  [RequireSubscriberKey] → Subscriber Access          │
└──────────────────────────────────────────────────────┘
```

## Subscription Levels

| Level | Name | Default Credits | Typical Usage |
|-------|------|-----------------|---------------|
| 1 | Basic | 1,000/month | Small shops, personal offices |
| 2 | Pro | 5,000/month | Busy stores, event venues |
| 3 | Enterprise | 50,000/month | High-traffic locations, multiple sites |

## Credit System

### How Credits Work
- Each API request consumes **1 credit**
- Credits are tracked per subscriber
- When limit is reached, API returns `429 Too Many Requests`
- Credits can be reset monthly or per billing cycle
- Administrators can update credit limits anytime

### Request Tracking
For each subscriber, the system tracks:
- `RequestCount`: Total number of API requests made
- `CreditsUsed`: Total credits consumed
- `CreditLimit`: Maximum credits allowed
- `LastUsedAt`: Timestamp of most recent API call

## API Endpoints

### Public Endpoints (Require Subscriber Key)

#### Chat & Conversation
```http
POST /api/chat/message
POST /api/chat/arrival
```
**Headers:**
- `X-API-Key: <subscriber-key>`
- `Content-Type: application/json`

**Credit Cost:** 1 per request

---

#### Configuration Management
```http
POST /api/config/access-list
GET /api/config/access-list/{avatarKey}
GET /api/config/access-list
DELETE /api/config/access-list/{avatarKey}
```
**Headers:**
- `X-API-Key: <subscriber-key>`

**Credit Cost:** 1 per request

---

#### Message Queue
```http
POST /api/message/queue
GET /api/message/pending/{avatarKey}
POST /api/message/delivered/{messageId}
```
**Headers:**
- `X-API-Key: <subscriber-key>`

**Credit Cost:** 1 per request

---

#### Reports & Activity
```http
POST /api/reports/daily
POST /api/reports/activities
PUT /api/reports/activities/{activityId}/complete
GET /api/reports/activities/current
GET /api/reports/activities/date/{date}
```
**Headers:**
- `X-API-Key: <subscriber-key>`

**Credit Cost:** 1 per request

---

### System Admin Endpoints (Require Master Key)

All system endpoints require the master API key and return `401 Unauthorized` if accessed with a subscriber key.

#### Generate New Subscriber Key
```http
POST /api/system/subscribers/generate-key
```

**Headers:**
- `X-API-Key: <master-key>`
- `Content-Type: application/json`

**Request Body:**
```json
{
  "subscriberId": "customer-abc-123",
  "subscriberName": "Jane's Virtual Shop",
  "subscriptionLevel": 2,
  "notes": "Annual Pro subscription",
  "orderNumber": "ORD-2024-12345",
  "creditLimit": 5000,
  "expiresAt": "2025-12-31T23:59:59Z"
}
```

**Response:**
```json
{
  "id": "3283a1ca-32a6-460e-84b4-275728853e03",
  "apiKey": "dKxCLc7JCqXX7bV5woYIvjDFPk4RC1qP0wUS6lGFHLQ",
  "subscriberId": "customer-abc-123",
  "subscriberName": "Jane's Virtual Shop",
  "subscriptionLevel": 2,
  "createdAt": "2024-12-15T10:30:00Z",
  "expiresAt": "2025-12-31T23:59:59Z",
  "creditLimit": 5000
}
```

**Important:** The `apiKey` is only returned once. Store it securely and provide it to the customer.

---

#### Update Subscriber Status
```http
PUT /api/system/subscribers/{id}/status
```

**Headers:**
- `X-API-Key: <master-key>`
- `Content-Type: application/json`

**Request Body:**
```json
{
  "isActive": false
}
```

**Response:**
```json
{
  "message": "Status updated successfully",
  "isActive": false
}
```

**Use Cases:**
- Suspend account for non-payment: `isActive: false`
- Reactivate account after payment: `isActive: true`

---

#### List All Subscribers
```http
GET /api/system/subscribers
GET /api/system/subscribers?activeOnly=true
GET /api/system/subscribers?level=2
GET /api/system/subscribers?activeOnly=true&level=3
```

**Headers:**
- `X-API-Key: <master-key>`

**Response:**
```json
[
  {
    "id": "3283a1ca-32a6-460e-84b4-275728853e03",
    "apiKey": "dKxCLc7JCqXX7bV5woYIvjDFPk4RC1qP0wUS6lGFHLQ",
    "subscriberId": "customer-abc-123",
    "subscriberName": "Jane's Virtual Shop",
    "subscriptionLevel": 2,
    "notes": "Annual Pro subscription",
    "orderNumber": "ORD-2024-12345",
    "isActive": true,
    "createdAt": "2024-12-15T10:30:00Z",
    "expiresAt": "2025-12-31T23:59:59Z",
    "lastUsedAt": "2024-12-20T15:45:30Z",
    "requestCount": 3847,
    "creditsUsed": 3847,
    "creditLimit": 5000
  }
]
```

---

#### Get Subscriber Details
```http
GET /api/system/subscribers/{id}
```

**Headers:**
- `X-API-Key: <master-key>`

**Response:** Same format as list endpoint, but returns single object.

---

#### Update Credit Limits
```http
PUT /api/system/subscribers/{id}/credits
```

**Headers:**
- `X-API-Key: <master-key>`
- `Content-Type: application/json`

**Request Body:**
```json
{
  "creditLimit": 10000,
  "resetUsage": true
}
```

**Response:**
```json
{
  "message": "Credits updated successfully",
  "creditLimit": 10000,
  "creditsUsed": 0
}
```

**Parameters:**
- `creditLimit`: New credit limit
- `resetUsage`: If `true`, resets `creditsUsed` to 0 (use for monthly billing cycles)

---

#### System Status
```http
GET /api/system/status
```

**Headers:**
- `X-API-Key: <master-key>`

**Response:**
```json
{
  "totalSubscribers": 47,
  "activeSubscribers": 45,
  "totalRequests": 1234567,
  "totalCreditsUsed": 1198432,
  "serverTime": "2024-12-20T18:30:00Z",
  "subscribersByLevel": {
    "1": 20,
    "2": 22,
    "3": 5
  }
}
```

---

#### Recent System Logs
```http
GET /api/system/logs
GET /api/system/logs?count=100
GET /api/system/logs?subscriberName=Jane
```

**Headers:**
- `X-API-Key: <master-key>`

**Response:**
```json
[
  {
    "timestamp": "2024-12-20T18:25:13Z",
    "level": "Information",
    "message": "Activity: sit - Reception Desk",
    "subscriberName": null
  }
]
```

---

## Error Responses

### 401 Unauthorized - No API Key
```json
{
  "error": "API key required"
}
```

### 401 Unauthorized - Invalid API Key
```json
{
  "error": "Invalid API key"
}
```

### 401 Unauthorized - System Access Required
```json
{
  "error": "System admin access required"
}
```

### 403 Forbidden - Inactive Key
```json
{
  "error": "API key is inactive"
}
```

### 403 Forbidden - Expired Key
```json
{
  "error": "API key has expired"
}
```

### 429 Too Many Requests - Credit Limit
```json
{
  "error": "Credit limit exceeded"
}
```

---

## LSL Integration

### RoseConfig Notecard Setup

```
# Rose Receptionist Configuration
SUBSCRIBER_KEY=your-subscriber-key-here
API_ENDPOINT=https://rosercp.pantherplays.com/api
OWNER_UUID=your-uuid-here
```

### Admin Menu Access

If you configure the master key as `SUBSCRIBER_KEY`, the LSL script will detect admin access and provide a secret menu when touched:

**Menu Options:**
- **New API Key**: Generate a new subscriber (prompts for name)
- **List Subs**: Display all subscribers
- **Status**: Show system statistics
- **Logs**: View recent activity logs
- **Credits**: Credit management (placeholder)

**Usage:**
1. Touch your Rose object
2. If master key is detected, admin menu appears
3. Select option from dialog
4. For "New API Key", enter subscriber name in text box
5. Results displayed in owner chat

---

## Best Practices

### For System Administrators

1. **Never commit master key to version control**
   - Use environment variables: `ApiAuthentication__MasterApiKey`
   - Or secure secrets management (Azure Key Vault, AWS Secrets Manager)

2. **Rotate keys regularly**
   - Master key: At least annually
   - Subscriber keys: Only if compromised

3. **Monitor usage patterns**
   - Check `/api/system/status` regularly
   - Watch for unusual credit consumption
   - Alert on rapid credit depletion

4. **Keep master key separate**
   - Don't document it in public repositories
   - Store securely with other infrastructure secrets
   - Limit access to senior administrators

### For Subscribers

1. **Protect your subscriber key**
   - Don't share it publicly
   - Store only in RoseConfig notecard
   - Contact admin immediately if compromised

2. **Monitor credit usage**
   - Track requests to avoid surprise limits
   - Upgrade subscription level if needed
   - Plan for high-traffic events

3. **Test before go-live**
   - Verify key works in test environment
   - Understand credit consumption rate
   - Have support contact ready

---

## Configuration Reference

### appsettings.json

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

### Environment Variables (Alternative)

```bash
ApiAuthentication__MasterApiKey=your-master-key-here
SubscriptionLevels__1__CreditLimit=1000
SubscriptionLevels__2__CreditLimit=5000
SubscriptionLevels__3__CreditLimit=50000
```

---

## Database Schema

### SubscriberApiKeys Table

| Column | Type | Description |
|--------|------|-------------|
| Id | Guid | Primary key |
| ApiKey | string | Unique API key (indexed) |
| SubscriberId | string | Customer identifier |
| SubscriberName | string | Display name |
| SubscriptionLevel | int | 1=Basic, 2=Pro, 3=Enterprise |
| Notes | string | Admin notes |
| OrderNumber | string | Reference to billing system |
| IsActive | bool | Can use API? (indexed) |
| CreatedAt | DateTime | Account creation timestamp |
| ExpiresAt | DateTime? | Optional expiration date |
| LastUsedAt | DateTime? | Most recent API call |
| RequestCount | int | Total requests made |
| CreditsUsed | int | Total credits consumed |
| CreditLimit | int | Maximum credits allowed |

**Indexes:**
- `IX_SubscriberApiKeys_ApiKey` (unique)
- `IX_SubscriberApiKeys_SubscriberId`
- `IX_SubscriberApiKeys_IsActive`

---

## Support & Troubleshooting

### Common Issues

**"API key required"**
- Ensure `X-API-Key` header is present
- Check header name spelling (case-sensitive)
- Verify key is in RoseConfig notecard

**"Invalid API key"**
- Key not found in database
- May have been deactivated or deleted
- Contact administrator for new key

**"Credit limit exceeded"**
- Subscription usage quota reached
- Contact provider to upgrade or reset credits
- Check usage via admin panel

**"System admin access required"**
- Trying to access `/api/system/*` with subscriber key
- System endpoints require master key
- Use correct key for endpoint type

### Getting Help

- System administrators: Check server logs in `/logs/` directory
- Subscribers: Contact your service provider
- Developers: Review API_REFERENCE.md and this guide
