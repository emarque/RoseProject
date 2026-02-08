# Use the official .NET 8 SDK image for building
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project file and restore dependencies
COPY RoseReceptionist.API/RoseReceptionist.API.csproj RoseReceptionist.API/
RUN dotnet restore RoseReceptionist.API/RoseReceptionist.API.csproj

# Copy remaining source code
COPY RoseReceptionist.API/ RoseReceptionist.API/

# Build the application
WORKDIR /src/RoseReceptionist.API
RUN dotnet build -c Release -o /app/build

# Publish the application
FROM build AS publish
RUN dotnet publish -c Release -o /app/publish

# Create the runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Install SQLite (if needed)
RUN apt-get update && apt-get install -y sqlite3 && rm -rf /var/lib/apt/lists/*

# Copy published application
COPY --from=publish /app/publish .

# Create directory for database and logs
RUN mkdir -p /app/data /app/logs

# Set environment variables
ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Production

# Expose port
EXPOSE 5000

# Run the application
ENTRYPOINT ["dotnet", "RoseReceptionist.API.dll"]
