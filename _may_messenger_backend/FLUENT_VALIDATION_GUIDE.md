# FluentValidation Implementation Guide

## Overview

FluentValidation has been integrated into the MayMessenger backend to provide robust, maintainable input validation for all DTOs.

## What Was Implemented

### 1. Package Installation

Added FluentValidation packages:
- **MayMessenger.Application**: `FluentValidation` v11.9.0
- **MayMessenger.API**: `FluentValidation.AspNetCore` v11.3.0

### 2. Validators Created

Created validators in `MayMessenger.Application/Validators/`:

#### RegisterRequestDtoValidator
- **PhoneNumber**: Required, E.164 format
- **DisplayName**: Required, 2-50 characters
- **Password**: Required, 6-100 characters
- **InviteCode**: Required, exactly 8 characters

#### LoginRequestDtoValidator
- **PhoneNumber**: Required, E.164 format
- **Password**: Required

#### CreateChatDtoValidator
- **Title**: Required, 1-100 characters
- **ParticipantIds**: Required, non-empty, max 100 participants

#### SendMessageDtoValidator
- **ChatId**: Required
- **Type**: Must be valid enum value
- **Content**: Required for text messages, max 10000 characters

### 3. Configuration

In `Program.cs`:
```csharp
// Register all validators from Application assembly
builder.Services.AddValidatorsFromAssemblyContaining<RegisterRequestDtoValidator>();

// Enable automatic validation
builder.Services.AddFluentValidationAutoValidation();
```

## How It Works

### Automatic Validation

When a request is made to an API endpoint:
1. ASP.NET Core model binding occurs
2. FluentValidation automatically validates the DTO
3. If validation fails:
   - HTTP 400 (Bad Request) is returned
   - Validation errors are included in the response
4. If validation succeeds:
   - Controller action executes normally

### Example Error Response

```json
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errors": {
    "PhoneNumber": [
      "Phone number must be in E.164 format"
    ],
    "Password": [
      "Password must be at least 6 characters"
    ]
  }
}
```

## Adding New Validators

### Step 1: Create Validator

Create a new file in `MayMessenger.Application/Validators/`:

```csharp
using FluentValidation;
using MayMessenger.Application.DTOs;

namespace MayMessenger.Application.Validators;

public class MyNewDtoValidator : AbstractValidator<MyNewDto>
{
    public MyNewDtoValidator()
    {
        RuleFor(x => x.Property1)
            .NotEmpty().WithMessage("Property1 is required")
            .Length(1, 50).WithMessage("Property1 must be 1-50 characters");

        RuleFor(x => x.Property2)
            .GreaterThan(0).WithMessage("Property2 must be positive");
    }
}
```

### Step 2: Validator Auto-Discovery

No additional registration needed! `AddValidatorsFromAssemblyContaining` automatically discovers all validators in the assembly.

## Common Validation Rules

### String Validation
```csharp
RuleFor(x => x.Name)
    .NotEmpty()                           // Not null or empty
    .Length(2, 50)                        // Length between 2 and 50
    .Matches(@"^[a-zA-Z0-9]+$")           // Regex pattern
    .EmailAddress()                       // Valid email
```

### Numeric Validation
```csharp
RuleFor(x => x.Age)
    .GreaterThan(0)                       // > 0
    .LessThanOrEqualTo(120)               // <= 120
    .InclusiveBetween(18, 100)            // Between 18 and 100
```

### Collection Validation
```csharp
RuleFor(x => x.Items)
    .NotNull()                            // Not null
    .NotEmpty()                           // Has at least one item
    .Must(items => items.Count <= 100)    // Custom rule
    .ForEach(itemRule =>                  // Validate each item
    {
        itemRule.NotEmpty();
    });
```

### Conditional Validation
```csharp
RuleFor(x => x.Content)
    .NotEmpty()
    .When(x => x.Type == MessageType.Text); // Only when condition is true
```

### Enum Validation
```csharp
RuleFor(x => x.Type)
    .IsInEnum().WithMessage("Invalid type");
```

## Benefits

### ✅ Separation of Concerns
- Validation logic is separate from business logic
- Easy to test validators independently

### ✅ Reusability
- Validators can be used in multiple places
- Share validation rules across endpoints

### ✅ Maintainability
- Centralized validation rules
- Easy to update and extend

### ✅ Consistency
- Uniform error messages
- Consistent API responses

### ✅ Type Safety
- Compile-time checking
- IntelliSense support

## Testing Validators

```csharp
[Test]
public void Should_Have_Error_When_PhoneNumber_Is_Empty()
{
    var validator = new RegisterRequestDtoValidator();
    var dto = new RegisterRequestDto { PhoneNumber = "" };
    
    var result = validator.TestValidate(dto);
    
    result.ShouldHaveValidationErrorFor(x => x.PhoneNumber);
}

[Test]
public void Should_Not_Have_Error_When_PhoneNumber_Is_Valid()
{
    var validator = new RegisterRequestDtoValidator();
    var dto = new RegisterRequestDto { PhoneNumber = "+1234567890" };
    
    var result = validator.TestValidate(dto);
    
    result.ShouldNotHaveValidationErrorFor(x => x.PhoneNumber);
}
```

## Performance

FluentValidation is optimized for performance:
- Validators are created once and reused
- Rules are compiled for fast execution
- Minimal overhead compared to manual validation

## Documentation

- [FluentValidation Official Documentation](https://docs.fluentvalidation.net/)
- [ASP.NET Core Integration](https://docs.fluentvalidation.net/en/latest/aspnet.html)
- [Built-in Validators](https://docs.fluentvalidation.net/en/latest/built-in-validators.html)

## Troubleshooting

### Validation Not Working

1. Ensure packages are installed:
   ```bash
   dotnet restore
   ```

2. Check Program.cs registration:
   ```csharp
   builder.Services.AddValidatorsFromAssemblyContaining<RegisterRequestDtoValidator>();
   builder.Services.AddFluentValidationAutoValidation();
   ```

3. Verify validator class name ends with `Validator`

### Custom Error Messages Not Showing

Use `.WithMessage()` for custom messages:
```csharp
RuleFor(x => x.Email)
    .EmailAddress()
    .WithMessage("Please provide a valid email address");
```

## Next Steps

Consider adding validators for:
- [ ] UpdateUserProfileDto (if exists)
- [ ] CreateInviteLinkDto
- [ ] UpdateChatDto (if exists)
- [ ] Any other request DTOs

## Impact

✨ **All API endpoints with DTOs now have automatic validation**
🛡️ **Improved security** - Invalid data is rejected before processing
📝 **Better error messages** - Clear, specific validation feedback
🧪 **Easier testing** - Validators can be unit tested independently

