using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RoseReceptionist.API.Migrations
{
    /// <inheritdoc />
    public partial class AddSubscriberApiKeys : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "SubscriberApiKeys",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    ApiKey = table.Column<string>(type: "TEXT", nullable: false),
                    SubscriberId = table.Column<string>(type: "TEXT", nullable: false),
                    SubscriberName = table.Column<string>(type: "TEXT", nullable: false),
                    SubscriptionLevel = table.Column<int>(type: "INTEGER", nullable: false),
                    Notes = table.Column<string>(type: "TEXT", nullable: true),
                    OrderNumber = table.Column<string>(type: "TEXT", nullable: true),
                    IsActive = table.Column<bool>(type: "INTEGER", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "TEXT", nullable: true),
                    LastUsedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
                    RequestCount = table.Column<int>(type: "INTEGER", nullable: false),
                    CreditsUsed = table.Column<int>(type: "INTEGER", nullable: false),
                    CreditLimit = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SubscriberApiKeys", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_SubscriberApiKeys_ApiKey",
                table: "SubscriberApiKeys",
                column: "ApiKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SubscriberApiKeys_IsActive",
                table: "SubscriberApiKeys",
                column: "IsActive");

            migrationBuilder.CreateIndex(
                name: "IX_SubscriberApiKeys_SubscriberId",
                table: "SubscriberApiKeys",
                column: "SubscriberId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SubscriberApiKeys");
        }
    }
}
