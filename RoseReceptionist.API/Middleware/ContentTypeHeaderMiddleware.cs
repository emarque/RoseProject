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
            var contentType = xContentType.ToString();
            
            // If X-Content-Type is application/json, override the actual Content-Type header
            if (contentType.Equals("application/json", StringComparison.OrdinalIgnoreCase))
            {
                _logger.LogDebug("X-Content-Type header detected: {ContentType}. Overriding Content-Type for JSON parsing.", contentType);
                
                // Override the Content-Type header so ASP.NET can properly parse JSON
                context.Request.ContentType = "application/json";
            }
            else
            {
                _logger.LogDebug("X-Content-Type header detected: {ContentType}", contentType);
                context.Request.ContentType = contentType;
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
