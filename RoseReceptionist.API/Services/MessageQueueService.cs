using Microsoft.EntityFrameworkCore;
using RoseReceptionist.API.Data;
using RoseReceptionist.API.Models;

namespace RoseReceptionist.API.Services;

public class MessageQueueService
{
    private readonly RoseDbContext _context;
    private readonly ILogger<MessageQueueService> _logger;

    public MessageQueueService(RoseDbContext context, ILogger<MessageQueueService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<Guid> QueueMessageAsync(
        string fromAvatarKey,
        string fromAvatarName,
        string toAvatarKey,
        string messageContent)
    {
        try
        {
            var message = new Message
            {
                FromAvatarKey = fromAvatarKey,
                FromAvatarName = fromAvatarName,
                ToAvatarKey = toAvatarKey,
                MessageContent = messageContent,
                IsDelivered = false,
                CreatedAt = DateTime.UtcNow
            };

            _context.Messages.Add(message);
            await _context.SaveChangesAsync();

            _logger.LogInformation(
                "Message queued from {FromName} to {ToKey}",
                fromAvatarName,
                toAvatarKey);

            return message.Id;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error queuing message");
            throw;
        }
    }

    public async Task<List<Message>> GetPendingMessagesAsync(string avatarKey)
    {
        try
        {
            return await _context.Messages
                .Where(m => m.ToAvatarKey == avatarKey && !m.IsDelivered)
                .OrderBy(m => m.CreatedAt)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving pending messages for {AvatarKey}", avatarKey);
            return new List<Message>();
        }
    }

    public async Task MarkAsDeliveredAsync(Guid messageId)
    {
        try
        {
            var message = await _context.Messages.FindAsync(messageId);
            if (message != null)
            {
                message.IsDelivered = true;
                message.DeliveredAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();

                _logger.LogInformation("Message {MessageId} marked as delivered", messageId);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error marking message {MessageId} as delivered", messageId);
        }
    }

    public async Task CleanupOldMessagesAsync()
    {
        try
        {
            var cutoffDate = DateTime.UtcNow.AddDays(-30);

            var oldMessages = await _context.Messages
                .Where(m => m.IsDelivered && m.DeliveredAt < cutoffDate)
                .ToListAsync();

            if (oldMessages.Any())
            {
                _context.Messages.RemoveRange(oldMessages);
                await _context.SaveChangesAsync();

                _logger.LogInformation("Cleaned up {Count} old delivered messages", oldMessages.Count);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error cleaning up old messages");
        }
    }
}
