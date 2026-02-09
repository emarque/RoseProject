using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RoseReceptionist.API.Authorization;
using RoseReceptionist.API.Data;
using RoseReceptionist.API.Models;
using RoseReceptionist.API.Services;

namespace RoseReceptionist.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[RequireSubscriberKey]
public class ConfigController : ControllerBase
{
    private readonly PersonalityService _personalityService;
    private readonly RoseDbContext _context;
    private readonly ILogger<ConfigController> _logger;

    public ConfigController(
        PersonalityService personalityService,
        RoseDbContext context,
        ILogger<ConfigController> logger)
    {
        _personalityService = personalityService;
        _context = context;
        _logger = logger;
    }

    [HttpPost("access-list")]
    public async Task<ActionResult<AccessListEntry>> CreateOrUpdateAccessListEntry([FromBody] AccessListEntry entry)
    {
        if (string.IsNullOrEmpty(entry.AvatarKey))
        {
            return BadRequest("Avatar key is required");
        }

        try
        {
            var existing = await _personalityService.GetAccessListEntryAsync(entry.AvatarKey);

            if (existing != null)
            {
                existing.AvatarName = entry.AvatarName;
                existing.Role = entry.Role;
                existing.PersonalityNotes = entry.PersonalityNotes;
                existing.FavoriteDrink = entry.FavoriteDrink;
                existing.LastSeen = DateTime.UtcNow;

                await _personalityService.UpdateAccessListEntryAsync(existing);
                return Ok(existing);
            }

            entry.Id = Guid.NewGuid();
            entry.CreatedAt = DateTime.UtcNow;
            entry.LastSeen = DateTime.UtcNow;

            _context.AccessList.Add(entry);
            await _context.SaveChangesAsync();

            _personalityService.ClearCache(entry.AvatarKey);

            return CreatedAtAction(nameof(GetAccessListEntry), new { avatarKey = entry.AvatarKey }, entry);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating/updating access list entry");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpGet("access-list/{avatarKey}")]
    public async Task<ActionResult<AccessListEntry>> GetAccessListEntry(string avatarKey)
    {
        if (string.IsNullOrEmpty(avatarKey))
        {
            return BadRequest("Avatar key is required");
        }

        try
        {
            var entry = await _personalityService.GetAccessListEntryAsync(avatarKey);

            if (entry == null)
            {
                return NotFound();
            }

            return Ok(entry);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving access list entry");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpGet("access-list")]
    public async Task<ActionResult<List<AccessListEntry>>> GetAllAccessListEntries()
    {
        try
        {
            var entries = await _context.AccessList
                .OrderBy(e => e.AvatarName)
                .ToListAsync();

            return Ok(entries);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving all access list entries");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpDelete("access-list/{avatarKey}")]
    public async Task<ActionResult> DeleteAccessListEntry(string avatarKey)
    {
        if (string.IsNullOrEmpty(avatarKey))
        {
            return BadRequest("Avatar key is required");
        }

        try
        {
            var entry = await _context.AccessList
                .FirstOrDefaultAsync(a => a.AvatarKey == avatarKey);

            if (entry == null)
            {
                return NotFound();
            }

            _context.AccessList.Remove(entry);
            await _context.SaveChangesAsync();

            _personalityService.ClearCache(avatarKey);

            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting access list entry");
            return StatusCode(500, "Internal server error");
        }
    }
}
