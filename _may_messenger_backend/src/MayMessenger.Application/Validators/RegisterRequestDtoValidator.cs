using FluentValidation;
using MayMessenger.Application.DTOs;

namespace MayMessenger.Application.Validators;

public class RegisterRequestDtoValidator : AbstractValidator<RegisterRequestDto>
{
    public RegisterRequestDtoValidator()
    {
        RuleFor(x => x.PhoneNumber)
            .NotEmpty().WithMessage("Введите номер телефона")
            .Matches(@"^\+?[1-9]\d{1,14}$").WithMessage("Номер телефона должен быть в формате +7XXXXXXXXXX");

        RuleFor(x => x.DisplayName)
            .NotEmpty().WithMessage("Введите ваше имя")
            .MinimumLength(2).WithMessage("Имя должно быть не менее 2 символов")
            .MaximumLength(50).WithMessage("Имя должно быть не более 50 символов");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Введите пароль")
            .MinimumLength(6).WithMessage("Пароль должен быть не менее 6 символов")
            .MaximumLength(100).WithMessage("Пароль должен быть не более 100 символов");

        RuleFor(x => x.InviteCode)
            .NotEmpty().WithMessage("Введите код приглашения")
            .MinimumLength(6).WithMessage("Код приглашения должен быть не менее 6 символов")
            .MaximumLength(20).WithMessage("Код приглашения должен быть не более 20 символов")
            .Matches(@"^[A-Za-z0-9]+$").WithMessage("Код приглашения должен содержать только буквы и цифры");
    }
}

