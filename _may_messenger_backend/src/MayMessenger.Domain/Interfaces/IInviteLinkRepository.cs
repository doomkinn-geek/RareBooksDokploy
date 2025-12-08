using MayMessenger.Domain.Entities;

namespace MayMessenger.Domain.Interfaces;

public interface IInviteLinkRepository : IRepository<InviteLink>
{
    Task<InviteLink?> GetByCodeAsync(string code, CancellationToken cancellationToken = default);
    Task<bool> ValidateInviteCodeAsync(string code, CancellationToken cancellationToken = default);
}


