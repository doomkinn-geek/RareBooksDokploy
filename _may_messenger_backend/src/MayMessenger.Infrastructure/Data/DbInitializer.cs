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
            Code = "WELCOME2024",
            CreatedBy = adminUser.Id,
            UsesLeft = 100,
            ExpiresAt = null,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        await context.InviteLinks.AddAsync(inviteLink);

        await context.SaveChangesAsync();
    }
}

