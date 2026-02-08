using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RoseReceptionist.API.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AccessList",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    AvatarKey = table.Column<string>(type: "TEXT", nullable: false),
                    AvatarName = table.Column<string>(type: "TEXT", nullable: false),
                    Role = table.Column<int>(type: "INTEGER", nullable: false),
                    PersonalityNotes = table.Column<string>(type: "TEXT", nullable: true),
                    FavoriteDrink = table.Column<string>(type: "TEXT", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    LastSeen = table.Column<DateTime>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AccessList", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ConversationHistory",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    AvatarKey = table.Column<string>(type: "TEXT", nullable: false),
                    AvatarName = table.Column<string>(type: "TEXT", nullable: false),
                    Role = table.Column<string>(type: "TEXT", nullable: false),
                    MessageText = table.Column<string>(type: "TEXT", nullable: false),
                    Response = table.Column<string>(type: "TEXT", nullable: false),
                    Timestamp = table.Column<DateTime>(type: "TEXT", nullable: false),
                    SessionId = table.Column<Guid>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ConversationHistory", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Messages",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    FromAvatarKey = table.Column<string>(type: "TEXT", nullable: false),
                    FromAvatarName = table.Column<string>(type: "TEXT", nullable: false),
                    ToAvatarKey = table.Column<string>(type: "TEXT", nullable: false),
                    MessageContent = table.Column<string>(type: "TEXT", nullable: false),
                    IsDelivered = table.Column<bool>(type: "INTEGER", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    DeliveredAt = table.Column<DateTime>(type: "TEXT", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Messages", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Settings",
                columns: table => new
                {
                    Key = table.Column<string>(type: "TEXT", nullable: false),
                    Value = table.Column<string>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Settings", x => x.Key);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AccessList_AvatarKey",
                table: "AccessList",
                column: "AvatarKey");

            migrationBuilder.CreateIndex(
                name: "IX_ConversationHistory_AvatarKey_SessionId",
                table: "ConversationHistory",
                columns: new[] { "AvatarKey", "SessionId" });

            migrationBuilder.CreateIndex(
                name: "IX_ConversationHistory_Timestamp",
                table: "ConversationHistory",
                column: "Timestamp");

            migrationBuilder.CreateIndex(
                name: "IX_Messages_ToAvatarKey_IsDelivered",
                table: "Messages",
                columns: new[] { "ToAvatarKey", "IsDelivered" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AccessList");

            migrationBuilder.DropTable(
                name: "ConversationHistory");

            migrationBuilder.DropTable(
                name: "Messages");

            migrationBuilder.DropTable(
                name: "Settings");
        }
    }
}
