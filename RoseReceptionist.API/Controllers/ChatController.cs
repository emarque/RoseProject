using Microsoft.AspNetCore.Mvc;
using RoseReceptionist.API.Models;
using RoseReceptionist.API.Services;

namespace RoseReceptionist.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ChatController : ControllerBase
{
    private readonly ClaudeService _claudeService;
    private readonly PersonalityService _personalityService;
    private readonly ConversationContextService _conversationService;
    private readonly ILogger<ChatController> _logger;

    public ChatController(
        ClaudeService claudeService,
        PersonalityService personalityService,
        ConversationContextService conversationService,
        ILogger<ChatController> logger)
    {
        _claudeService = claudeService;
        _personalityService = personalityService;
        _conversationService = conversationService;
        _logger = logger;
    }

    [HttpPost("message")]
    public async Task<ActionResult<ChatResponse>> PostMessage([FromBody] ChatRequest request)
    {
        if (string.IsNullOrEmpty(request.AvatarKey) || string.IsNullOrEmpty(request.Message))
        {
            return BadRequest("Avatar key and message are required");
        }

        try
        {
            var accessEntry = await _personalityService.GetOrCreateAccessListEntryAsync(
                request.AvatarKey,
                request.AvatarName);

            if (accessEntry.Role == Role.Blocked)
            {
                _logger.LogWarning("Blocked avatar {AvatarKey} attempted to chat", request.AvatarKey);
                return Ok(new ChatResponse
                {
                    Response = "*looks away politely* I'm afraid I'm quite busy at the moment.",
                    ShouldNotifyOwners = false,
                    SuggestedAnimation = ""
                });
            }

            var response = await _claudeService.GetResponseAsync(
                request.Message,
                request.AvatarKey,
                request.AvatarName,
                accessEntry.Role,
                accessEntry.PersonalityNotes,
                accessEntry.FavoriteDrink,
                request.SessionId);

            await _conversationService.SaveConversationAsync(
                request.AvatarKey,
                request.AvatarName,
                accessEntry.Role.ToString(),
                request.Message,
                response,
                request.SessionId);

            var suggestedAnimation = DetermineSuggestedAnimation(response, accessEntry.Role);

            return Ok(new ChatResponse
            {
                Response = response,
                ShouldNotifyOwners = false,
                SuggestedAnimation = suggestedAnimation
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing chat message from {AvatarKey}", request.AvatarKey);
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpPost("arrival")]
    public async Task<ActionResult<ArrivalResponse>> PostArrival([FromBody] ArrivalRequest request)
    {
        if (string.IsNullOrEmpty(request.AvatarKey))
        {
            return BadRequest("Avatar key is required");
        }

        try
        {
            var accessEntry = await _personalityService.GetOrCreateAccessListEntryAsync(
                request.AvatarKey,
                request.AvatarName);

            if (accessEntry.Role == Role.Blocked)
            {
                _logger.LogWarning("Blocked avatar {AvatarKey} attempted arrival", request.AvatarKey);
                return Ok(new ArrivalResponse
                {
                    Greeting = "",
                    Role = "blocked",
                    ShouldNotifyOwners = false,
                    SessionId = Guid.NewGuid()
                });
            }

            var sessionId = Guid.NewGuid();
            var greeting = await _claudeService.GetResponseAsync(
                $"Hello! I just arrived at {request.Location}.",
                request.AvatarKey,
                request.AvatarName,
                accessEntry.Role,
                accessEntry.PersonalityNotes,
                accessEntry.FavoriteDrink,
                sessionId);

            await _conversationService.SaveConversationAsync(
                request.AvatarKey,
                request.AvatarName,
                accessEntry.Role.ToString(),
                "Arrival greeting",
                greeting,
                sessionId);

            var shouldNotifyOwners = accessEntry.Role == Role.Visitor;

            return Ok(new ArrivalResponse
            {
                Greeting = greeting,
                Role = accessEntry.Role.ToString().ToLower(),
                ShouldNotifyOwners = shouldNotifyOwners,
                SessionId = sessionId
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing arrival from {AvatarKey}", request.AvatarKey);
            return StatusCode(500, "Internal server error");
        }
    }

    private string DetermineSuggestedAnimation(string response, Role role)
    {
        var responseLower = response.ToLower();

        if (responseLower.Contains("*wave") || responseLower.Contains("hello") || responseLower.Contains("welcome"))
        {
            return "greet";
        }

        if (responseLower.Contains("*offer") || responseLower.Contains("coffee") || responseLower.Contains("tea") || responseLower.Contains("drink"))
        {
            return "offer";
        }

        if (responseLower.Contains("*wink") || (role == Role.Owner && (responseLower.Contains("*smile") || responseLower.Contains("darling"))))
        {
            return "flirt";
        }

        if (responseLower.Contains("*think") || responseLower.Contains("hmm") || responseLower.Contains("let me"))
        {
            return "think";
        }

        return "";
    }
}
