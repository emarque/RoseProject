using Microsoft.EntityFrameworkCore;
using RoseReceptionist.API.Data;
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

// Ensure database is created
using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<RoseDbContext>();
    dbContext.Database.EnsureCreated();
}

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseSerilogRequestLogging();

app.UseCors();

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();

