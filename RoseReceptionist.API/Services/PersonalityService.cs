using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using RoseReceptionist.API.Data;
using RoseReceptionist.API.Models;

namespace RoseReceptionist.API.Services;

public class PersonalityService
{
    private readonly RoseDbContext _context;
    private readonly ILogger<PersonalityService> _logger;
    private readonly IMemoryCache _cache;
    private readonly IConfiguration _configuration;
    private const string CacheKeyPrefix = "AccessList_";
    private readonly TimeSpan CacheExpiration = TimeSpan.FromMinutes(5);

    public PersonalityService(
        RoseDbContext context,
        ILogger<PersonalityService> logger,
        IMemoryCache cache,
        IConfiguration configuration)
    {
        _context = context;
        _logger = logger;
        _cache = cache;
        _configuration = configuration;
    }

    public async Task<AccessListEntry?> GetAccessListEntryAsync(string avatarKey)
    {
        var cacheKey = CacheKeyPrefix + avatarKey;

        if (_cache.TryGetValue(cacheKey, out AccessListEntry? cached))
        {
            return cached;
        }

        try
        {
            var entry = await _context.AccessList
                .FirstOrDefaultAsync(a => a.AvatarKey == avatarKey);

            if (entry != null)
            {
                _cache.Set(cacheKey, entry, CacheExpiration);
            }

            return entry;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving access list entry for {AvatarKey}", avatarKey);
            return null;
        }
    }

    public async Task<AccessListEntry> GetOrCreateAccessListEntryAsync(
        string avatarKey,
        string avatarName)
    {
        var entry = await GetAccessListEntryAsync(avatarKey);

        if (entry != null)
        {
            entry.LastSeen = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            _cache.Remove(CacheKeyPrefix + avatarKey);
            return entry;
        }

        var defaultOwnerKeys = _configuration.GetSection("Rose:DefaultOwnerKeys")
            .Get<List<string>>() ?? new List<string>();

        var isOwner = defaultOwnerKeys.Contains(avatarKey);

        entry = new AccessListEntry
        {
            AvatarKey = avatarKey,
            AvatarName = avatarName,
            Role = isOwner ? Role.Owner : Role.Visitor,
            CreatedAt = DateTime.UtcNow,
            LastSeen = DateTime.UtcNow
        };

        try
        {
            _context.AccessList.Add(entry);
            await _context.SaveChangesAsync();

            _logger.LogInformation(
                "Created new access list entry for {AvatarName} ({AvatarKey}) as {Role}",
                avatarName,
                avatarKey,
                entry.Role);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating access list entry for {AvatarKey}", avatarKey);
        }

        return entry;
    }

    public async Task<bool> UpdateAccessListEntryAsync(AccessListEntry entry)
    {
        try
        {
            var existing = await _context.AccessList.FindAsync(entry.Id);
            if (existing == null)
            {
                return false;
            }

            existing.AvatarName = entry.AvatarName;
            existing.Role = entry.Role;
            existing.PersonalityNotes = entry.PersonalityNotes;
            existing.FavoriteDrink = entry.FavoriteDrink;
            existing.LastSeen = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            _cache.Remove(CacheKeyPrefix + entry.AvatarKey);

            _logger.LogInformation("Updated access list entry for {AvatarKey}", entry.AvatarKey);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating access list entry");
            return false;
        }
    }

    public async Task<List<string>> GetOwnerKeysAsync()
    {
        try
        {
            return await _context.AccessList
                .Where(a => a.Role == Role.Owner)
                .Select(a => a.AvatarKey)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving owner keys");
            return new List<string>();
        }
    }

    public void ClearCache(string avatarKey)
    {
        _cache.Remove(CacheKeyPrefix + avatarKey);
    }
}
