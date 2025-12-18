using FluentValidation;
using MayMessenger.Application.DTOs;
using MayMessenger.Domain.Enums;

namespace MayMessenger.Application.Validators;

public class SendMessageDtoValidator : AbstractValidator<SendMessageDto>
{
    public SendMessageDtoValidator()
    {
        RuleFor(x => x.ChatId)
            .NotEmpty().WithMessage("Chat ID is required");

        RuleFor(x => x.Type)
            .IsInEnum().WithMessage("Invalid message type");

        RuleFor(x => x.Content)
            .NotEmpty()
            .WithMessage("Message content is required")
            .When(x => x.Type == MessageType.Text);

        RuleFor(x => x.Content)
            .MaximumLength(10000)
            .WithMessage("Message content must not exceed 10000 characters")
            .When(x => x.Type == MessageType.Text && !string.IsNullOrEmpty(x.Content));

        RuleFor(x => x.ClientMessageId)
            .MaximumLength(50)
            .WithMessage("ClientMessageId must not exceed 50 characters")
            .When(x => !string.IsNullOrEmpty(x.ClientMessageId));
    }
}

