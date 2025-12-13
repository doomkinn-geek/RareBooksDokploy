using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Logging;

namespace MayMessenger.Application.Services;

public interface IFirebaseService
{
    Task<bool> SendNotificationAsync(string fcmToken, string title, string body, Dictionary<string, string>? data = null);
    Task<bool> SendToMultipleAsync(List<string> tokens, string title, string body, Dictionary<string, string>? data = null);
    void Initialize(string configPath);
    bool IsInitialized { get; }
}

public class FirebaseService : IFirebaseService
{
    private bool _isInitialized = false;
    private readonly ILogger<FirebaseService> _logger;
    private FirebaseApp? _app;

    public FirebaseService(ILogger<FirebaseService> logger)
    {
        _logger = logger;
    }

    public bool IsInitialized => _isInitialized;

    public void Initialize(string configPath)
    {
        try
        {
            if (_isInitialized)
            {
                _logger.LogWarning("Firebase already initialized");
                return;
            }

            if (!File.Exists(configPath))
            {
                _logger.LogWarning($"Firebase config file not found at {configPath}");
                return;
            }

            _app = FirebaseApp.Create(new AppOptions
            {
                Credential = GoogleCredential.FromFile(configPath)
            });

            _isInitialized = true;
            _logger.LogInformation("Firebase Admin SDK initialized successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize Firebase Admin SDK");
            _isInitialized = false;
        }
    }

    public async Task<bool> SendNotificationAsync(
        string fcmToken,
        string title,
        string body,
        Dictionary<string, string>? data = null)
    {
        if (!_isInitialized)
        {
            _logger.LogWarning("Firebase not initialized. Cannot send notification.");
            return false;
        }

        try
        {
            var message = new Message
            {
                Token = fcmToken,
                Notification = new Notification
                {
                    Title = title,
                    Body = body,
                },
                Data = data,
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        Sound = "default",
                        ChannelId = "messages"
                    }
                }
            };

            var response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
            _logger.LogInformation($"Successfully sent FCM message: {response}");
            return true;
        }
        catch (FirebaseMessagingException ex)
        {
            _logger.LogError(ex, $"Failed to send FCM message to token {fcmToken}. Error: {ex.MessagingErrorCode}");
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Unexpected error sending FCM message to token {fcmToken}");
            return false;
        }
    }

    public async Task<bool> SendToMultipleAsync(
        List<string> tokens,
        string title,
        string body,
        Dictionary<string, string>? data = null)
    {
        if (!_isInitialized)
        {
            _logger.LogWarning("Firebase not initialized. Cannot send notifications.");
            return false;
        }

        if (tokens == null || tokens.Count == 0)
        {
            _logger.LogWarning("No tokens provided for multicast message");
            return false;
        }

        try
        {
            var message = new MulticastMessage
            {
                Tokens = tokens,
                Notification = new Notification
                {
                    Title = title,
                    Body = body,
                },
                Data = data,
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        Sound = "default",
                        ChannelId = "messages"
                    }
                }
            };

            var response = await FirebaseMessaging.DefaultInstance.SendEachForMulticastAsync(message);
            _logger.LogInformation($"Multicast sent. Success: {response.SuccessCount}, Failed: {response.FailureCount}");
            
            return response.SuccessCount > 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send multicast FCM message");
            return false;
        }
    }
}
