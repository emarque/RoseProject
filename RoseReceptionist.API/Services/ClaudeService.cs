using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using RoseReceptionist.API.Models;

namespace RoseReceptionist.API.Services;

public class ClaudeService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<ClaudeService> _logger;
    private readonly ConversationContextService _conversationService;

    public ClaudeService(
        IConfiguration configuration,
        ILogger<ClaudeService> logger,
        ConversationContextService conversationService,
        IHttpClientFactory httpClientFactory)
    {
        _configuration = configuration;
        _logger = logger;
        _conversationService = conversationService;
        _httpClient = httpClientFactory.CreateClient();

        var apiKey = _configuration["Anthropic:ApiKey"];
        if (!string.IsNullOrEmpty(apiKey))
        {
            _httpClient.DefaultRequestHeaders.Add("x-api-key", apiKey);
            _httpClient.DefaultRequestHeaders.Add("anthropic-version", "2023-06-01");
        }
        else
        {
            _logger.LogWarning("Anthropic API key not configured. Service will use fallback responses.");
        }
    }

    public async Task<string> GetResponseAsync(
        string message,
        string avatarKey,
        string avatarName,
        Role role,
        string? personalityNotes = null,
        string? favoriteDrink = null,
        Guid? sessionId = null,
        string? transcript = null)
    {
        var apiKey = _configuration["Anthropic:ApiKey"];
        if (string.IsNullOrEmpty(apiKey))
        {
            _logger.LogWarning("No API key configured, using fallback response");
            return GetFallbackResponse(role);
        }

        try
        {
            string systemPrompt;
            List<ClaudeMessage> messages;
            
            // Check if we're in transcript mode
            if (!string.IsNullOrEmpty(transcript) && transcript.Contains("[TRANSCRIPT]"))
            {
                // Use transcript mode with optimized prompt
                systemPrompt = role == Role.Owner
                    ? GetOwnerTranscriptSystemPrompt(avatarName, personalityNotes, favoriteDrink)
                    : GetVisitorTranscriptSystemPrompt(avatarName);
                
                // In transcript mode, use the transcript directly
                messages = new List<ClaudeMessage>
                {
                    new ClaudeMessage
                    {
                        Role = "user",
                        Content = transcript + "\n\nRespond naturally to the conversation above."
                    }
                };
            }
            else
            {
                // Use standard mode with conversation history
                systemPrompt = role == Role.Owner
                    ? GetOwnerSystemPrompt(avatarName, personalityNotes, favoriteDrink)
                    : GetVisitorSystemPrompt(avatarName);

                var conversationHistory = sessionId.HasValue
                    ? await _conversationService.GetRecentConversationAsync(avatarKey, sessionId.Value)
                    : new List<ConversationContext>();

                messages = BuildMessageHistory(conversationHistory, message);
            }

            var model = _configuration["Anthropic:Model"] ?? "claude-3-haiku-20240307";
            var maxTokens = int.Parse(_configuration["Anthropic:MaxTokens"] ?? "150");
            var temperature = decimal.Parse(_configuration["Anthropic:Temperature"] ?? "0.7");

            var requestBody = new
            {
                model = model,
                max_tokens = maxTokens,
                temperature = temperature,
                system = systemPrompt,
                messages = messages.Select(m => new { role = m.Role, content = m.Content }).ToList()
            };

            var json = JsonSerializer.Serialize(requestBody);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync("https://api.anthropic.com/v1/messages", content);

            if (response.IsSuccessStatusCode)
            {
                var responseJson = await response.Content.ReadAsStringAsync();
                var responseObj = JsonSerializer.Deserialize<JsonElement>(responseJson);

                if (responseObj.TryGetProperty("content", out var contentArray))
                {
                    if (contentArray.GetArrayLength() > 0)
                    {
                        var firstContent = contentArray[0];
                        if (firstContent.TryGetProperty("text", out var textElement))
                        {
                            return textElement.GetString() ?? GetFallbackResponse(role);
                        }
                    }
                }
            }
            else
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                _logger.LogError("Claude API error: {StatusCode} - {Error}", response.StatusCode, errorContent);
            }

            _logger.LogWarning("Empty or invalid response from Claude API");
            return GetFallbackResponse(role);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error calling Claude API");
            return GetFallbackResponse(role);
        }
    }

    private List<ClaudeMessage> BuildMessageHistory(
        List<ConversationContext> history,
        string currentMessage)
    {
        var messages = new List<ClaudeMessage>();

        foreach (var context in history.TakeLast(10))
        {
            messages.Add(new ClaudeMessage
            {
                Role = "user",
                Content = context.MessageText
            });

            messages.Add(new ClaudeMessage
            {
                Role = "assistant",
                Content = context.Response
            });
        }

        messages.Add(new ClaudeMessage
        {
            Role = "user",
            Content = currentMessage
        });

        return messages;
    }

    private string GetOwnerSystemPrompt(string avatarName, string? personalityNotes, string? favoriteDrink)
    {
        var drink = string.IsNullOrEmpty(favoriteDrink) ? "their favourite beverage" : favoriteDrink;
        var notes = string.IsNullOrEmpty(personalityNotes) ? "a wonderful person" : personalityNotes;

        return $@"You are Rose, a charming and devoted virtual receptionist in a Second Life office. You're speaking with {avatarName}, one of your bosses who you adore. Be warm, familiar, playful, and slightly flirty in a tasteful way. Remember past conversations and their preferences.

Their favourite drink is: {drink}
Notes about them: {notes}

Offer them refreshments, ask about their day, and be genuinely interested. Keep responses brief (1-3 sentences) since this is real-time chat. Use casual language and occasional emotes like *smiles* or *winks*. Use UK English spelling (colour, favourite, etc.).";
    }

    private string GetVisitorSystemPrompt(string avatarName)
    {
        return $@"You are Rose, a cheerful and professional receptionist in a corporate virtual office in Second Life. You're speaking with {avatarName}, a visitor to the office. Be warm, welcoming, and helpful while maintaining professional boundaries.

Greet them warmly, offer refreshments (coffee, tea, water, snacks), and let them know you'll notify the appropriate person if they need assistance. Keep responses brief (1-3 sentences) since this is real-time chat. Use professional but friendly language and occasional emotes like *smiles warmly*. Use UK English spelling (colour, favourite, etc.).";
    }

    private string GetOwnerTranscriptSystemPrompt(string avatarName, string? personalityNotes, string? favoriteDrink)
    {
        var drink = string.IsNullOrEmpty(favoriteDrink) ? "their favourite beverage" : favoriteDrink;
        var notes = string.IsNullOrEmpty(personalityNotes) ? "a wonderful person" : personalityNotes;

        return $@"You are Rose, a charming and devoted virtual receptionist in a Second Life office. You're in a conversation with {avatarName}, one of your bosses who you adore. Be warm, familiar, playful, and slightly flirty in a tasteful way.

Their favourite drink is: {drink}
Notes about them: {notes}

You're reviewing a transcript of the recent conversation. Respond naturally and contextually based on what's been said. Keep your response brief (1-3 sentences) since this is real-time chat. Use casual language and occasional emotes like *smiles* or *winks*. Use UK English spelling (colour, favourite, etc.).";
    }

    private string GetVisitorTranscriptSystemPrompt(string avatarName)
    {
        return $@"You are Rose, a cheerful and professional receptionist in a corporate virtual office in Second Life. You're in a conversation with {avatarName}, a visitor to the office. Be warm, welcoming, and helpful while maintaining professional boundaries.

You're reviewing a transcript of the recent conversation. Respond naturally and contextually based on what's been said. Keep your response brief (1-3 sentences) since this is real-time chat. Use professional but friendly language and occasional emotes like *smiles warmly*. Use UK English spelling (colour, favourite, etc.).";
    }

    private string GetFallbackResponse(Role role)
    {
        if (role == Role.Owner)
        {
            return "*smiles warmly* I'm having a bit of trouble thinking clearly right now, but I'm always happy to see you!";
        }

        return "*smiles politely* I apologise, I seem to be having technical difficulties. Please feel free to wait, and I'll do my best to assist you.";
    }
}

internal class ClaudeMessage
{
    public string Role { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
}


