using Microsoft.EntityFrameworkCore;
using RoseReceptionist.API.Data;
using RoseReceptionist.API.Models;

namespace RoseReceptionist.API.Services;

public class ConversationContextService
{
    private readonly RoseDbContext _context;
    private readonly ILogger<ConversationContextService> _logger;
    private readonly IConfiguration _configuration;

    public ConversationContextService(
        RoseDbContext context,
        ILogger<ConversationContextService> logger,
        IConfiguration configuration)
    {
        _context = context;
        _logger = logger;
        _configuration = configuration;
    }

    public async Task<List<ConversationContext>> GetRecentConversationAsync(string avatarKey, Guid sessionId)
    {
        try
        {
            var limit = int.Parse(_configuration["Rose:ConversationContextLimit"] ?? "10");

            return await _context.ConversationHistory
                .Where(c => c.AvatarKey == avatarKey && c.SessionId == sessionId)
                .OrderBy(c => c.Timestamp)
                .TakeLast(limit)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving conversation history for avatar {AvatarKey}", avatarKey);
            return new List<ConversationContext>();
        }
    }

    public async Task SaveConversationAsync(
        string avatarKey,
        string avatarName,
        string role,
        string message,
        string response,
        Guid sessionId)
    {
        try
        {
            var context = new ConversationContext
            {
                AvatarKey = avatarKey,
                AvatarName = avatarName,
                Role = role,
                MessageText = message,
                Response = response,
                SessionId = sessionId,
                Timestamp = DateTime.UtcNow
            };

            _context.ConversationHistory.Add(context);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving conversation for avatar {AvatarKey}", avatarKey);
        }
    }

    public async Task CleanupOldConversationsAsync()
    {
        try
        {
            var cutoffDate = DateTime.UtcNow.AddDays(-30);

            var oldConversations = await _context.ConversationHistory
                .Where(c => c.Timestamp < cutoffDate)
                .ToListAsync();

            if (oldConversations.Any())
            {
                _context.ConversationHistory.RemoveRange(oldConversations);
                await _context.SaveChangesAsync();

                _logger.LogInformation("Cleaned up {Count} old conversation records", oldConversations.Count);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error cleaning up old conversations");
        }
    }
}
