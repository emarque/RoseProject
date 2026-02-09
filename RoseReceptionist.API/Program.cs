using Microsoft.EntityFrameworkCore;
using RoseReceptionist.API.Data;
using RoseReceptionist.API.Middleware;
using RoseReceptionist.API.Models;
using RoseReceptionist.API.Services;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .WriteTo.Console()
    .WriteTo.File("logs/rose-.txt", rollingInterval: RollingInterval.Day)
    .CreateLogger();

builder.Host.UseSerilog();

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add HTTP client for Claude API
builder.Services.AddHttpClient();

// Add memory cache
builder.Services.AddMemoryCache();

// Add DbContext
builder.Services.AddDbContext<RoseDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("RoseDb")));

// Add application services
builder.Services.AddScoped<ConversationContextService>();
builder.Services.AddScoped<ClaudeService>();
builder.Services.AddScoped<PersonalityService>();
builder.Services.AddScoped<MessageQueueService>();
builder.Services.AddScoped<DailyReportService>();

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Ensure database is created and migrations are applied
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    try
    {
        var context = services.GetRequiredService<RoseDbContext>();
        var logger = services.GetRequiredService<ILogger<Program>>();
        
        logger.LogInformation("Checking database...");
        
        // This will create the database if it doesn't exist and apply any pending migrations
        context.Database.Migrate();
        
        logger.LogInformation("Database ready");
        
        // Seed default data if needed
        await SeedDefaultData(context, logger);
    }
    catch (Exception ex)
    {
        var logger = services.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "An error occurred while creating/migrating the database.");
        throw;
    }
}

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseSerilogRequestLogging();

app.UseCors();

app.UseApiKeyAuthentication();

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();

static async Task SeedDefaultData(RoseDbContext context, Microsoft.Extensions.Logging.ILogger logger)
{
    // Check if we need to seed
    if (await context.Settings.AnyAsync())
    {
        return; // Already seeded
    }
    
    logger.LogInformation("Seeding default data...");
    
    // Add default settings
    context.Settings.AddRange(
        new Setting { Key = "ReceptionistName", Value = "Rose" },
        new Setting { Key = "OfficeLocation", Value = "Virtual Office" },
        new Setting { Key = "WelcomeMessage", Value = "Welcome to our virtual office!" },
        new Setting { Key = "OfflineMessage", Value = "I'm sorry, the owners are currently unavailable. I'll pass along your message!" }
    );
    
    await context.SaveChangesAsync();
    logger.LogInformation("Default data seeded successfully");
}

