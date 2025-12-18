using FluentValidation;
using MayMessenger.Application.DTOs;

namespace MayMessenger.Application.Validators;

public class LoginRequestDtoValidator : AbstractValidator<LoginRequestDto>
{
    public LoginRequestDtoValidator()
    {
        RuleFor(x => x.PhoneNumber)
            .NotEmpty().WithMessage("Phone number is required")
            .Matches(@"^\+?[1-9]\d{1,14}$").WithMessage("Phone number must be in E.164 format");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Password is required");
    }
}

