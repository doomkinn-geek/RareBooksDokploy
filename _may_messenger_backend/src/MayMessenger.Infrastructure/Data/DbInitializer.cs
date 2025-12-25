using Microsoft.EntityFrameworkCore;
using MayMessenger.Application.Interfaces;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;

namespace MayMessenger.Infrastructure.Data;

public static class DbInitializer
{
    public static async Task InitializeAsync(AppDbContext context, IPasswordHasher passwordHasher)
    {
        // Применяем миграции
        await context.Database.MigrateAsync();

        // Проверяем, есть ли уже данные
        if (await context.Users.AnyAsync())
        {
            return; // БД уже заполнена
        }

        // Создаём админа
        var adminUser = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "+79604243127",
            DisplayName = "Administrator",
            PasswordHash = passwordHasher.HashPassword("ppAKiH1Y"),
            Role = UserRole.Admin,
            CreatedAt = DateTime.UtcNow
        };

        await context.Users.AddAsync(adminUser);

        // Создаём первый invite код
        var inviteLink = new InviteLink
        {
            Id = Guid.NewGuid(),
            Code = "WELCOME1",
            CreatedBy = adminUser.Id,
            UsesLeft = 100,
            ExpiresAt = null,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        await context.InviteLinks.AddAsync(inviteLink);

        // Создаём тестовых пользователей для проверки
        var testUser1 = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "+79111111111",
            DisplayName = "Тестовый Пользователь 1",
            PasswordHash = passwordHasher.HashPassword("test123"),
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow
        };

        var testUser2 = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "+79222222222",
            DisplayName = "Тестовый Пользователь 2",
            PasswordHash = passwordHasher.HashPassword("test123"),
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow
        };

        await context.Users.AddAsync(testUser1);
        await context.Users.AddAsync(testUser2);

        // Создаём групповой чат
        var groupChat = new Chat
        {
            Id = Guid.NewGuid(),
            Type = ChatType.Group,
            Title = "Тестовая группа",
            CreatedAt = DateTime.UtcNow
        };

        await context.Chats.AddAsync(groupChat);

        // Добавляем участников в групповой чат
        await context.ChatParticipants.AddAsync(new ChatParticipant
        {
            ChatId = groupChat.Id,
            UserId = adminUser.Id,
            IsAdmin = true,
            JoinedAt = DateTime.UtcNow
        });

        await context.ChatParticipants.AddAsync(new ChatParticipant
        {
            ChatId = groupChat.Id,
            UserId = testUser1.Id,
            IsAdmin = false,
            JoinedAt = DateTime.UtcNow
        });

        await context.ChatParticipants.AddAsync(new ChatParticipant
        {
            ChatId = groupChat.Id,
            UserId = testUser2.Id,
            IsAdmin = false,
            JoinedAt = DateTime.UtcNow
        });

        // Создаём личный чат между testUser1 и testUser2
        var privateChat = new Chat
        {
            Id = Guid.NewGuid(),
            Type = ChatType.Private,
            CreatedAt = DateTime.UtcNow
        };

        await context.Chats.AddAsync(privateChat);

        await context.ChatParticipants.AddAsync(new ChatParticipant
        {
            ChatId = privateChat.Id,
            UserId = testUser1.Id,
            IsAdmin = false,
            JoinedAt = DateTime.UtcNow
        });

        await context.ChatParticipants.AddAsync(new ChatParticipant
        {
            ChatId = privateChat.Id,
            UserId = testUser2.Id,
            IsAdmin = false,
            JoinedAt = DateTime.UtcNow
        });

        // Добавляем тестовые сообщения в групповой чат
        await context.Messages.AddAsync(new Message
        {
            Id = Guid.NewGuid(),
            ChatId = groupChat.Id,
            SenderId = adminUser.Id,
            Type = MessageType.Text,
            Content = "Добро пожаловать в тестовую группу!",
            Status = MessageStatus.Sent,
            CreatedAt = DateTime.UtcNow.AddMinutes(-10)
        });

        await context.Messages.AddAsync(new Message
        {
            Id = Guid.NewGuid(),
            ChatId = groupChat.Id,
            SenderId = testUser1.Id,
            Type = MessageType.Text,
            Content = "Привет всем!",
            Status = MessageStatus.Sent,
            CreatedAt = DateTime.UtcNow.AddMinutes(-5)
        });

        await context.Messages.AddAsync(new Message
        {
            Id = Guid.NewGuid(),
            ChatId = groupChat.Id,
            SenderId = testUser2.Id,
            Type = MessageType.Text,
            Content = "Здравствуйте!",
            Status = MessageStatus.Sent,
            CreatedAt = DateTime.UtcNow.AddMinutes(-2)
        });

        // Добавляем тестовые сообщения в личный чат
        await context.Messages.AddAsync(new Message
        {
            Id = Guid.NewGuid(),
            ChatId = privateChat.Id,
            SenderId = testUser1.Id,
            Type = MessageType.Text,
            Content = "Привет! Как дела?",
            Status = MessageStatus.Sent,
            CreatedAt = DateTime.UtcNow.AddMinutes(-15)
        });

        await context.Messages.AddAsync(new Message
        {
            Id = Guid.NewGuid(),
            ChatId = privateChat.Id,
            SenderId = testUser2.Id,
            Type = MessageType.Text,
            Content = "Привет! Всё отлично, спасибо!",
            Status = MessageStatus.Sent,
            CreatedAt = DateTime.UtcNow.AddMinutes(-12)
        });

        await context.SaveChangesAsync();
    }
}

