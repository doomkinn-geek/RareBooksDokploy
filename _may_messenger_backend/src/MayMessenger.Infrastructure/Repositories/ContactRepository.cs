using Microsoft.EntityFrameworkCore;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;

namespace MayMessenger.Infrastructure.Repositories;

public class ContactRepository : IContactRepository
{
    private readonly AppDbContext _context;

    public ContactRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<Contact>> GetUserContactsAsync(Guid userId)
    {
        return await _context.Contacts
            .Where(c => c.UserId == userId)
            .Include(c => c.User)
            .OrderBy(c => c.DisplayName)
            .ToListAsync();
    }

    public async Task<List<User>> FindUsersByPhoneHashesAsync(List<string> phoneHashes)
    {
        return await _context.Users
            .Where(u => phoneHashes.Contains(u.PhoneNumberHash))
            .ToListAsync();
    }

    public async Task SyncContactsAsync(Guid userId, List<(string phoneHash, string? displayName)> contacts)
    {
        // Get existing contacts
        var existingContacts = await _context.Contacts
            .Where(c => c.UserId == userId)
            .ToListAsync();

        // Add or update contacts
        foreach (var (phoneHash, displayName) in contacts)
        {
            var existing = existingContacts.FirstOrDefault(c => c.PhoneNumberHash == phoneHash);
            if (existing != null)
            {
                existing.DisplayName = displayName;
                existing.SyncedAt = DateTime.UtcNow;
                existing.UpdatedAt = DateTime.UtcNow;
            }
            else
            {
                var contact = new Contact
                {
                    UserId = userId,
                    PhoneNumberHash = phoneHash,
                    DisplayName = displayName,
                    SyncedAt = DateTime.UtcNow
                };
                await _context.Contacts.AddAsync(contact);
            }
        }

        await _context.SaveChangesAsync();
    }

    public async Task<Contact?> GetByUserAndPhoneHashAsync(Guid userId, string phoneHash)
    {
        return await _context.Contacts
            .Where(c => c.UserId == userId && c.PhoneNumberHash == phoneHash)
            .Include(c => c.User)
            .FirstOrDefaultAsync();
    }
}
