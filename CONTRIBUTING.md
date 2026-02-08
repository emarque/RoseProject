# Contributing to Rose Receptionist System

Thank you for your interest in contributing to the Rose Receptionist System!

## Development Setup

### Prerequisites
- .NET 8.0 SDK
- Git
- Your favorite IDE (Visual Studio, VS Code, or Rider)

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/RoseProject.git
   cd RoseProject
   ```

2. **Install dependencies**
   ```bash
   cd RoseReceptionist.API
   dotnet restore
   ```

3. **Configure settings**
   - Copy `appsettings.json` to `appsettings.Development.json`
   - Add your Anthropic API key (optional for testing with fallback responses)

4. **Run the application**
   ```bash
   dotnet run
   ```

5. **Access Swagger UI**
   Open https://localhost:5001/swagger in your browser

## Project Structure

```
RoseProject/
├── RoseReceptionist.API/     # Backend .NET Web API
│   ├── Controllers/          # API endpoints
│   ├── Services/            # Business logic
│   ├── Models/              # Data models
│   └── Data/                # Database context
├── RoseReceptionist.LSL/    # Second Life scripts
└── Documentation/           # Additional docs
```

## Coding Standards

### C# (.NET Backend)
- Follow standard C# naming conventions
- Use async/await for all I/O operations
- Add XML documentation comments for public APIs
- Keep methods focused and single-purpose
- Use dependency injection

### LSL Scripts
- Keep scripts under 64KB each
- Use meaningful variable names
- Add comments for complex logic
- Test in Second Life before committing

## Testing

### Backend Tests
```bash
cd RoseReceptionist.API
dotnet test
```

### Manual Testing
Use the Swagger UI or curl to test endpoints:
```bash
curl -X POST http://localhost:5000/api/chat/arrival \
  -H "Content-Type: application/json" \
  -d '{"avatarKey":"test","avatarName":"Test User","location":"Office"}'
```

## Pull Request Process

1. **Fork the repository** and create your branch from `main`
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write clean, documented code
   - Add tests if applicable
   - Update documentation

3. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add feature: your feature description"
   ```

4. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Open a Pull Request**
   - Describe your changes clearly
   - Reference any related issues
   - Include screenshots for UI changes

## Common Contributions

### Adding New Features
- New conversation personalities
- Additional API endpoints
- Enhanced LSL functionality
- Database migrations

### Bug Fixes
- Always include a test that reproduces the bug
- Explain the root cause in your PR description
- Update documentation if behavior changes

### Documentation
- Fix typos or unclear sections
- Add examples
- Improve installation instructions
- Translate to other languages

## Code Review

All submissions require review. We'll look for:
- Code quality and readability
- Test coverage
- Documentation updates
- Performance considerations
- Security implications

## Questions?

Feel free to:
- Open an issue for discussion
- Ask in pull request comments
- Contact maintainers directly

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
