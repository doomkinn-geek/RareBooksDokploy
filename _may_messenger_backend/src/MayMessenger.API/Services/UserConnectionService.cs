using System.Collections.Concurrent;

namespace MayMessenger.API.Services;

/// <summary>
/// Service to track SignalR connection IDs for each user.
/// Used to exclude sender from receiving their own messages via SignalR.
/// </summary>
public class UserConnectionService
{
    // Thread-safe dictionary: userId -> set of connectionIds (user can have multiple connections)
    private readonly ConcurrentDictionary<Guid, HashSet<string>> _userConnections = new();
    private readonly object _lock = new();

    /// <summary>
    /// Register a connection for a user
    /// </summary>
    public void AddConnection(Guid userId, string connectionId)
    {
        lock (_lock)
        {
            if (!_userConnections.TryGetValue(userId, out var connections))
            {
                connections = new HashSet<string>();
                _userConnections[userId] = connections;
            }
            connections.Add(connectionId);
            Console.WriteLine($"[UserConnectionService] Added connection {connectionId} for user {userId}. Total connections: {connections.Count}");
        }
    }

    /// <summary>
    /// Remove a connection for a user
    /// </summary>
    public void RemoveConnection(Guid userId, string connectionId)
    {
        lock (_lock)
        {
            if (_userConnections.TryGetValue(userId, out var connections))
            {
                connections.Remove(connectionId);
                Console.WriteLine($"[UserConnectionService] Removed connection {connectionId} for user {userId}. Remaining: {connections.Count}");
                
                // Clean up empty entries
                if (connections.Count == 0)
                {
                    _userConnections.TryRemove(userId, out _);
                }
            }
        }
    }

    /// <summary>
    /// Get all connection IDs for a user
    /// </summary>
    public IReadOnlyCollection<string> GetConnections(Guid userId)
    {
        lock (_lock)
        {
            if (_userConnections.TryGetValue(userId, out var connections))
            {
                return connections.ToList().AsReadOnly();
            }
            return Array.Empty<string>();
        }
    }

    /// <summary>
    /// Check if user has any active connections
    /// </summary>
    public bool IsConnected(Guid userId)
    {
        lock (_lock)
        {
            return _userConnections.TryGetValue(userId, out var connections) && connections.Count > 0;
        }
    }

    /// <summary>
    /// Get all active users
    /// </summary>
    public IReadOnlyCollection<Guid> GetConnectedUsers()
    {
        lock (_lock)
        {
            return _userConnections.Keys.ToList().AsReadOnly();
        }
    }
}

