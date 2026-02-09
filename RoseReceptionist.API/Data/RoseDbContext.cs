using Microsoft.EntityFrameworkCore;
using RoseReceptionist.API.Models;

namespace RoseReceptionist.API.Data;

public class RoseDbContext : DbContext
{
    public RoseDbContext(DbContextOptions<RoseDbContext> options) : base(options)
    {
    }

    public DbSet<AccessListEntry> AccessList { get; set; }
    public DbSet<Message> Messages { get; set; }
    public DbSet<ConversationContext> ConversationHistory { get; set; }
    public DbSet<Setting> Settings { get; set; }
    public DbSet<ActivityLog> ActivityLogs { get; set; }
    public DbSet<DailyReport> DailyReports { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Configure AccessListEntry
        modelBuilder.Entity<AccessListEntry>()
            .HasIndex(e => e.AvatarKey);

        // Configure Message
        modelBuilder.Entity<Message>()
            .HasIndex(e => new { e.ToAvatarKey, e.IsDelivered });

        // Configure ConversationContext
        modelBuilder.Entity<ConversationContext>()
            .HasIndex(e => new { e.AvatarKey, e.SessionId });

        modelBuilder.Entity<ConversationContext>()
            .HasIndex(e => e.Timestamp);

        // Configure Setting
        modelBuilder.Entity<Setting>()
            .HasKey(e => e.Key);

        // Configure ActivityLog
        modelBuilder.Entity<ActivityLog>()
            .HasIndex(e => e.StartTime);

        modelBuilder.Entity<ActivityLog>()
            .HasIndex(e => new { e.StartTime, e.EndTime });

        // Configure DailyReport
        modelBuilder.Entity<DailyReport>()
            .HasIndex(e => e.ReportDate);
    }
}
