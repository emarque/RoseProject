namespace RoseReceptionist.API.Middleware;

/// <summary>
/// Middleware to handle X-Content-Type header for Second Life compatibility.
/// Second Life forces Content-Type to "text/plain; charset=utf-8" and doesn't allow custom values.
/// This middleware checks for X-Content-Type header and if set to "application/json",
/// it rewrites the Content-Type header so ASP.NET can properly parse the JSON body.
/// </summary>
public class ContentTypeHeaderMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ContentTypeHeaderMiddleware> _logger;
    
    // Allowlist of acceptable content types for security
    private static readonly HashSet<string> AllowedContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "application/json",
        "application/xml",
        "text/plain"
    };

    public ContentTypeHeaderMiddleware(RequestDelegate next, ILogger<ContentTypeHeaderMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Check for X-Content-Type header (our custom header for Second Life compatibility)
        if (context.Request.Headers.TryGetValue("X-Content-Type", out var xContentType))
        {
            var contentType = xContentType.ToString().Trim();
            
            // Validate against allowlist for security
            if (AllowedContentTypes.Contains(contentType))
            {
                // Log at Information level for production auditability
                _logger.LogInformation(
                    "X-Content-Type header override: {XContentType} -> Content-Type for request from {IP} to {Path}", 
                    contentType, 
                    context.Connection.RemoteIpAddress, 
                    context.Request.Path);
                
                // Override the Content-Type header so ASP.NET can properly parse the body
                context.Request.ContentType = contentType;
            }
            else
            {
                // Log security warning for invalid content type attempt
                _logger.LogWarning(
                    "Blocked X-Content-Type header with invalid value: {XContentType} from {IP} to {Path}. Only allowed: {AllowedTypes}", 
                    contentType,
                    context.Connection.RemoteIpAddress,
                    context.Request.Path,
                    string.Join(", ", AllowedContentTypes));
            }
        }

        await _next(context);
    }
}

public static class ContentTypeHeaderMiddlewareExtensions
{
    public static IApplicationBuilder UseContentTypeHeader(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<ContentTypeHeaderMiddleware>();
    }
}
