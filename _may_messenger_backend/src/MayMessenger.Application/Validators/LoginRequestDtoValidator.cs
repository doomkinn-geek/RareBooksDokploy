using FluentValidation;
using MayMessenger.Application.DTOs;

namespace MayMessenger.Application.Validators;

public class LoginRequestDtoValidator : AbstractValidator<LoginRequestDto>
{
    public LoginRequestDtoValidator()
    {
        RuleFor(x => x.PhoneNumber)
            .NotEmpty().WithMessage("Введите номер телефона")
            .Matches(@"^\+?[1-9]\d{1,14}$").WithMessage("Номер телефона должен быть в формате +7XXXXXXXXXX");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Введите пароль");
    }
}

