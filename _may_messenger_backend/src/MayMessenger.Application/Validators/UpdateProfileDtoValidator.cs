using FluentValidation;
using MayMessenger.Application.DTOs;

namespace MayMessenger.Application.Validators;

public class UpdateProfileDtoValidator : AbstractValidator<UpdateProfileDto>
{
    public UpdateProfileDtoValidator()
    {
        RuleFor(x => x.DisplayName)
            .MinimumLength(2).WithMessage("Имя должно быть не менее 2 символов")
            .MaximumLength(50).WithMessage("Имя должно быть не более 50 символов")
            .When(x => !string.IsNullOrEmpty(x.DisplayName));

        RuleFor(x => x.Bio)
            .MaximumLength(500).WithMessage("Описание должно быть не более 500 символов")
            .When(x => !string.IsNullOrEmpty(x.Bio));

        RuleFor(x => x.Status)
            .MaximumLength(100).WithMessage("Статус должен быть не более 100 символов")
            .When(x => !string.IsNullOrEmpty(x.Status));
    }
}

