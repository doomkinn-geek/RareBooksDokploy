using FluentValidation;
using MayMessenger.Application.DTOs;

namespace MayMessenger.Application.Validators;

public class CreateChatDtoValidator : AbstractValidator<CreateChatDto>
{
    public CreateChatDtoValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty().WithMessage("Chat title is required")
            .MinimumLength(1).WithMessage("Chat title must be at least 1 character")
            .MaximumLength(100).WithMessage("Chat title must not exceed 100 characters");

        RuleFor(x => x.ParticipantIds)
            .NotNull().WithMessage("Participant list is required")
            .NotEmpty().WithMessage("At least one participant is required")
            .Must(ids => ids.Count <= 100).WithMessage("Cannot add more than 100 participants at once")
            .ForEach(participantRule =>
            {
                participantRule.NotEmpty().WithMessage("Participant ID cannot be empty");
            });
    }
}

