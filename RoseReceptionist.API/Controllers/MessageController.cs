using Microsoft.AspNetCore.Mvc;
using RoseReceptionist.API.Authorization;
using RoseReceptionist.API.Models;
using RoseReceptionist.API.Services;

namespace RoseReceptionist.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[RequireSubscriberKey]
public class MessageController : ControllerBase
{
    private readonly MessageQueueService _messageService;
    private readonly ILogger<MessageController> _logger;

    public MessageController(
        MessageQueueService messageService,
        ILogger<MessageController> logger)
    {
        _messageService = messageService;
        _logger = logger;
    }

    [HttpPost("queue")]
    public async Task<ActionResult<MessageQueueResponse>> QueueMessage([FromBody] MessageQueueRequest request)
    {
        if (string.IsNullOrEmpty(request.FromAvatarKey) ||
            string.IsNullOrEmpty(request.ToAvatarKey) ||
            string.IsNullOrEmpty(request.MessageContent))
        {
            return BadRequest("From avatar key, to avatar key, and message content are required");
        }

        try
        {
            var messageId = await _messageService.QueueMessageAsync(
                request.FromAvatarKey,
                request.FromAvatarName,
                request.ToAvatarKey,
                request.MessageContent);

            return Ok(new MessageQueueResponse
            {
                MessageId = messageId,
                Queued = true
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error queuing message");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpGet("pending/{avatarKey}")]
    public async Task<ActionResult<PendingMessagesResponse>> GetPendingMessages(string avatarKey)
    {
        if (string.IsNullOrEmpty(avatarKey))
        {
            return BadRequest("Avatar key is required");
        }

        try
        {
            var messages = await _messageService.GetPendingMessagesAsync(avatarKey);

            var messageDtos = messages.Select(m => new MessageDto
            {
                Id = m.Id,
                FromAvatarName = m.FromAvatarName,
                MessageContent = m.MessageContent,
                CreatedAt = m.CreatedAt
            }).ToList();

            return Ok(new PendingMessagesResponse
            {
                Messages = messageDtos
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving pending messages for {AvatarKey}", avatarKey);
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpPost("delivered/{messageId}")]
    public async Task<ActionResult> MarkAsDelivered(Guid messageId)
    {
        try
        {
            await _messageService.MarkAsDeliveredAsync(messageId);
            return Ok();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error marking message {MessageId} as delivered", messageId);
            return StatusCode(500, "Internal server error");
        }
    }
}
