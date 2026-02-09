using Microsoft.EntityFrameworkCore;
using RoseReceptionist.API.Data;
using RoseReceptionist.API.Models;

namespace RoseReceptionist.API.Middleware;

public class ApiKeyAuthenticationMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ApiKeyAuthenticationMiddleware> _logger;

    public ApiKeyAuthenticationMiddleware(RequestDelegate next, ILogger<ApiKeyAuthenticationMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context, RoseDbContext dbContext, IConfiguration configuration)
    {
        // Skip authentication for health check, swagger, and other non-API endpoints
        var path = context.Request.Path.Value?.ToLower() ?? "";
        if (path.StartsWith("/swagger") || path.StartsWith("/health") || !path.StartsWith("/api"))
        {
            await _next(context);
            return;
        }

        // Extract API key from header
        if (!context.Request.Headers.TryGetValue("X-API-Key", out var extractedApiKey) || 
            string.IsNullOrWhiteSpace(extractedApiKey))
        {
            _logger.LogWarning("API request without API key from {IP}", context.Connection.RemoteIpAddress);
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(new { error = "API key required" });
            return;
        }

        var apiKey = extractedApiKey.ToString();
        
        // Check if it's the master key
        var masterKey = configuration["ApiAuthentication:MasterApiKey"];
        if (!string.IsNullOrEmpty(masterKey) && apiKey == masterKey)
        {
            context.Items["IsSystemAdmin"] = true;
            _logger.LogInformation("System admin access from {IP}", context.Connection.RemoteIpAddress);
            await _next(context);
            return;
        }

        // Check if it's a subscriber key
        var subscriberKey = await dbContext.SubscriberApiKeys
            .FirstOrDefaultAsync(k => k.ApiKey == apiKey);

        if (subscriberKey == null)
        {
            _logger.LogWarning("Invalid API key attempted from {IP}", context.Connection.RemoteIpAddress);
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(new { error = "Invalid API key" });
            return;
        }

        if (!subscriberKey.IsActive)
        {
            _logger.LogWarning("Inactive API key attempted: {SubscriberName}", subscriberKey.SubscriberName);
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsJsonAsync(new { error = "API key is inactive" });
            return;
        }

        if (subscriberKey.ExpiresAt.HasValue && subscriberKey.ExpiresAt.Value < DateTime.UtcNow)
        {
            _logger.LogWarning("Expired API key attempted: {SubscriberName}", subscriberKey.SubscriberName);
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsJsonAsync(new { error = "API key has expired" });
            return;
        }

        // Check credit limits (only for non-system endpoints)
        if (subscriberKey.CreditLimit > 0 && subscriberKey.CreditsUsed >= subscriberKey.CreditLimit)
        {
            _logger.LogWarning("Credit limit exceeded for: {SubscriberName}", subscriberKey.SubscriberName);
            context.Response.StatusCode = StatusCodes.Status429TooManyRequests;
            await context.Response.WriteAsJsonAsync(new { error = "Credit limit exceeded" });
            return;
        }

        // Store subscriber information in context
        context.Items["SubscriberApiKey"] = subscriberKey;

        // Update usage statistics
        subscriberKey.RequestCount++;
        subscriberKey.LastUsedAt = DateTime.UtcNow;
        
        // Credit calculation: 1 credit per request (can be customized per endpoint)
        subscriberKey.CreditsUsed++;
        
        await dbContext.SaveChangesAsync();

        _logger.LogInformation("API request from subscriber: {SubscriberName} ({Level})", 
            subscriberKey.SubscriberName, 
            (SubscriptionLevel)subscriberKey.SubscriptionLevel);

        await _next(context);
    }
}

public static class ApiKeyAuthenticationMiddlewareExtensions
{
    public static IApplicationBuilder UseApiKeyAuthentication(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<ApiKeyAuthenticationMiddleware>();
    }
}
