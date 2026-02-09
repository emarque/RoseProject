using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace RoseReceptionist.API.Authorization;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public class RequireSystemKeyAttribute : Attribute, IAuthorizationFilter
{
    public void OnAuthorization(AuthorizationFilterContext context)
    {
        // Check if the request has been marked as authorized by middleware
        if (context.HttpContext.Items.TryGetValue("IsSystemAdmin", out var isAdmin) 
            && isAdmin is bool admin && admin)
        {
            return;
        }

        context.Result = new UnauthorizedObjectResult(new { error = "System admin access required" });
    }
}
