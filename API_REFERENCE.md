# Rose Receptionist API Reference

## Base URL
```
Production: https://your-domain.com/api
Development: http://localhost:5000/api
```

## Authentication
All endpoints currently accept anonymous requests. In production, consider adding API key authentication.

## Important: Second Life Content-Type Workaround

**For Second Life clients:** Second Life forces the Content-Type header to `text/plain; charset=utf-8` and does not allow it to be customized. To work around this limitation:

1. **Do NOT set** the `Content-Type` header (Second Life will block it)
2. **Instead, use** the `X-Content-Type` custom header with value `application/json`
3. The server's middleware will automatically detect `X-Content-Type` and parse the body as JSON

**Example LSL Code:**
```lsl
llHTTPRequest(url,
    [HTTP_METHOD, "POST",
     HTTP_CUSTOM_HEADER, "X-Content-Type", "application/json",
     HTTP_CUSTOM_HEADER, "X-API-Key", API_KEY],
    json_body);
```

**Note:** Regular HTTP clients (Postman, curl, etc.) should still use the standard `Content-Type: application/json` header.

## Endpoints

### Chat Endpoints

#### POST /api/chat/arrival
Notify Rose when a new avatar arrives.

**Request Body:**
```json
{
  "avatarKey": "uuid",
  "avatarName": "John Doe",
  "location": "Virtual Office (128, 128, 25)"
}
```

**Response:** `200 OK`
```json
{
  "greeting": "*smiles warmly* Hello John! Welcome to our office.",
  "role": "visitor",
  "shouldNotifyOwners": true,
  "sessionId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response Fields:**
- `greeting` (string): AI-generated greeting message
- `role` (string): Avatar's role - "owner", "visitor", or "blocked"
- `shouldNotifyOwners` (boolean): Whether to notify office owners
- `sessionId` (guid): Session ID for conversation continuity

**Error Responses:**
- `400 Bad Request`: Invalid request data
- `500 Internal Server Error`: Server error

---

#### POST /api/chat/message
Send a chat message to Rose.

**Request Body:**
```json
{
  "avatarKey": "uuid",
  "avatarName": "John Doe",
  "message": "Can I speak with the manager?",
  "location": "Virtual Office",
  "sessionId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response:** `200 OK`
```json
{
  "response": "*nods* Of course! Let me check if they're available.",
  "shouldNotifyOwners": false,
  "suggestedAnimation": "think"
}
```

**Response Fields:**
- `response` (string): AI-generated response
- `shouldNotifyOwners` (boolean): Whether to notify owners
- `suggestedAnimation` (string): Suggested animation - "greet", "offer", "think", "flirt", or empty

**Error Responses:**
- `400 Bad Request`: Missing required fields
- `500 Internal Server Error`: Server error

---

### Message Queue Endpoints

#### POST /api/message/queue
Queue a message for offline delivery.

**Request Body:**
```json
{
  "fromAvatarKey": "sender-uuid",
  "fromAvatarName": "John Doe",
  "toAvatarKey": "recipient-uuid",
  "messageContent": "Please call me when you get back"
}
```

**Response:** `200 OK`
```json
{
  "messageId": "550e8400-e29b-41d4-a716-446655440000",
  "queued": true
}
```

**Error Responses:**
- `400 Bad Request`: Missing required fields
- `500 Internal Server Error`: Failed to queue message

---

#### GET /api/message/pending/{avatarKey}
Retrieve pending messages for an avatar.

**URL Parameters:**
- `avatarKey` (string, required): Avatar's UUID

**Response:** `200 OK`
```json
{
  "messages": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "fromAvatarName": "John Doe",
      "messageContent": "Please call me when you get back",
      "createdAt": "2026-02-08T16:30:00Z"
    }
  ]
}
```

**Error Responses:**
- `400 Bad Request`: Invalid avatar key
- `500 Internal Server Error`: Failed to retrieve messages

---

#### POST /api/message/delivered/{messageId}
Mark a message as delivered.

**URL Parameters:**
- `messageId` (guid, required): Message ID

**Response:** `200 OK` (no body)

**Error Responses:**
- `500 Internal Server Error`: Failed to update message

---

### Configuration Endpoints

#### GET /api/config/access-list
Get all access list entries.

**Response:** `200 OK`
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "avatarKey": "uuid",
    "avatarName": "John Doe",
    "role": 1,
    "personalityNotes": "Loves coffee",
    "favoriteDrink": "cappuccino",
    "createdAt": "2026-02-08T16:00:00Z",
    "lastSeen": "2026-02-08T16:30:00Z"
  }
]
```

**Role Values:**
- `0` = Owner
- `1` = Visitor
- `2` = Blocked

---

#### GET /api/config/access-list/{avatarKey}
Get specific avatar's access list entry.

**URL Parameters:**
- `avatarKey` (string, required): Avatar's UUID

**Response:** `200 OK`
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "avatarKey": "uuid",
  "avatarName": "John Doe",
  "role": 0,
  "personalityNotes": "Loves coffee and tech discussions",
  "favoriteDrink": "cappuccino",
  "createdAt": "2026-02-08T16:00:00Z",
  "lastSeen": "2026-02-08T16:30:00Z"
}
```

**Error Responses:**
- `404 Not Found`: Avatar not in access list
- `400 Bad Request`: Invalid avatar key
- `500 Internal Server Error`: Server error

---

#### POST /api/config/access-list
Create or update an access list entry.

**Request Body:**
```json
{
  "avatarKey": "uuid",
  "avatarName": "John Doe",
  "role": 0,
  "personalityNotes": "Loves coffee and tech discussions",
  "favoriteDrink": "cappuccino"
}
```

**Response:** `200 OK` (update) or `201 Created` (new)
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "avatarKey": "uuid",
  "avatarName": "John Doe",
  "role": 0,
  "personalityNotes": "Loves coffee and tech discussions",
  "favoriteDrink": "cappuccino",
  "createdAt": "2026-02-08T16:00:00Z",
  "lastSeen": "2026-02-08T16:30:00Z"
}
```

**Error Responses:**
- `400 Bad Request`: Missing required fields
- `500 Internal Server Error`: Failed to save entry

---

#### DELETE /api/config/access-list/{avatarKey}
Remove an avatar from the access list.

**URL Parameters:**
- `avatarKey` (string, required): Avatar's UUID

**Response:** `204 No Content`

**Error Responses:**
- `404 Not Found`: Avatar not in access list
- `400 Bad Request`: Invalid avatar key
- `500 Internal Server Error`: Failed to delete entry

---

## Common Response Codes

| Code | Description |
|------|-------------|
| 200  | Success |
| 201  | Created |
| 204  | No Content (success, no body) |
| 400  | Bad Request (invalid input) |
| 404  | Not Found |
| 500  | Internal Server Error |

## Rate Limiting

Currently no rate limiting is enforced. In production, consider:
- 100 requests per minute per IP
- 1000 requests per hour per avatar
- Burst allowance for legitimate usage

## Webhooks (Future Feature)

Consider implementing webhooks for:
- Avatar arrival notifications
- New message notifications
- Owner alerts

## Best Practices

1. **Session Management**
   - Store `sessionId` from arrival response
   - Use same `sessionId` for all messages in conversation
   - Sessions timeout after 30 minutes of inactivity

2. **Error Handling**
   - Always check response status codes
   - Implement retry logic with exponential backoff
   - Fall back to default behavior on errors

3. **Performance**
   - Cache access list entries
   - Batch message retrievals
   - Use connection pooling

4. **Security**
   - Use HTTPS in production
   - Validate all input data
   - Sanitize user messages
   - Implement rate limiting

## Example: Full Conversation Flow

```bash
# 1. Avatar arrives
curl -X POST http://localhost:5000/api/chat/arrival \
  -H "Content-Type: application/json" \
  -d '{
    "avatarKey": "user-123",
    "avatarName": "John Doe",
    "location": "Main Office"
  }'

# Response includes sessionId: "abc-123"

# 2. Send first message
curl -X POST http://localhost:5000/api/chat/message \
  -H "Content-Type: application/json" \
  -d '{
    "avatarKey": "user-123",
    "avatarName": "John Doe",
    "message": "Hello Rose, I need help",
    "location": "Main Office",
    "sessionId": "abc-123"
  }'

# 3. Send follow-up message (same sessionId)
curl -X POST http://localhost:5000/api/chat/message \
  -H "Content-Type: application/json" \
  -d '{
    "avatarKey": "user-123",
    "avatarName": "John Doe",
    "message": "Can you help me find the manager?",
    "location": "Main Office",
    "sessionId": "abc-123"
  }'

# 4. Queue a message for the manager
curl -X POST http://localhost:5000/api/message/queue \
  -H "Content-Type: application/json" \
  -d '{
    "fromAvatarKey": "user-123",
    "fromAvatarName": "John Doe",
    "toAvatarKey": "manager-uuid",
    "messageContent": "Please contact John Doe"
  }'
```

## Support

For API questions or issues:
- GitHub Issues: https://github.com/yourusername/RoseProject/issues
- Documentation: See README.md and DEPLOYMENT.md
