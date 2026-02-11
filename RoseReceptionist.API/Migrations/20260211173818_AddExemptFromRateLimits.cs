using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RoseReceptionist.API.Migrations
{
    /// <inheritdoc />
    public partial class AddExemptFromRateLimits : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "ExemptFromRateLimits",
                table: "SubscriberApiKeys",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ExemptFromRateLimits",
                table: "SubscriberApiKeys");
        }
    }
}
