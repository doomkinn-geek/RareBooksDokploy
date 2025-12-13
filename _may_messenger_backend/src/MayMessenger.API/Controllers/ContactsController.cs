using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class ContactsController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;

    public ContactsController(IUnitOfWork unitOfWork)
    {
        _unitOfWork = unitOfWork;
    }

    private Guid GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.Parse(userIdClaim ?? throw new UnauthorizedAccessException());
    }

    private string ComputePhoneNumberHash(string phoneNumber)
    {
        using var sha256 = SHA256.Create();
        var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(phoneNumber));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    [HttpPost("sync")]
    public async Task<IActionResult> SyncContacts([FromBody] SyncContactsRequest request)
    {
        var userId = GetCurrentUserId();

        // Save contacts to database
        var contactsToSync = request.Contacts
            .Select(c => (c.PhoneNumberHash, c.DisplayName))
            .ToList();

        await _unitOfWork.Contacts.SyncContactsAsync(userId, contactsToSync);

        // Find which contacts are registered users
        var phoneHashes = request.Contacts.Select(c => c.PhoneNumberHash).ToList();
        var registeredUsers = await _unitOfWork.Contacts.FindUsersByPhoneHashesAsync(phoneHashes);

        var response = registeredUsers.Select(u => new RegisteredContactDto
        {
            UserId = u.Id,
            PhoneNumberHash = u.PhoneNumberHash,
            DisplayName = u.DisplayName
        }).ToList();

        return Ok(response);
    }

    [HttpGet("registered")]
    public async Task<IActionResult> GetRegisteredContacts()
    {
        var userId = GetCurrentUserId();
        var contacts = await _unitOfWork.Contacts.GetUserContactsAsync(userId);

        // Get all phone hashes
        var phoneHashes = contacts.Select(c => c.PhoneNumberHash).ToList();
        var registeredUsers = await _unitOfWork.Contacts.FindUsersByPhoneHashesAsync(phoneHashes);

        // Match contacts with registered users and include display names from contacts
        var response = registeredUsers.Select(u =>
        {
            var contact = contacts.FirstOrDefault(c => c.PhoneNumberHash == u.PhoneNumberHash);
            return new RegisteredContactDto
            {
                UserId = u.Id,
                PhoneNumberHash = u.PhoneNumberHash,
                DisplayName = contact?.DisplayName ?? u.DisplayName // Prefer contact's display name
            };
        }).ToList();

        return Ok(response);
    }
}

public class SyncContactsRequest
{
    public List<ContactDto> Contacts { get; set; } = new();
}

public class ContactDto
{
    public string PhoneNumberHash { get; set; } = string.Empty;
    public string? DisplayName { get; set; }
}

public class RegisteredContactDto
{
    public Guid UserId { get; set; }
    public string PhoneNumberHash { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
}
