using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace RoseReceptionist.API.Authorization;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public class RequireSubscriberKeyAttribute : Attribute, IAuthorizationFilter
{
    public void OnAuthorization(AuthorizationFilterContext context)
    {
        // Check if the request has been marked as authorized by middleware
        if (context.HttpContext.Items.TryGetValue("SubscriberApiKey", out var subscriberKey) 
            && subscriberKey != null)
        {
            return;
        }

        context.Result = new UnauthorizedObjectResult(new { error = "Valid subscriber API key required" });
    }
}
