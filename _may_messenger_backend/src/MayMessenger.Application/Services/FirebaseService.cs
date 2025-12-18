using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Logging;

namespace MayMessenger.Application.Services;

public interface IFirebaseService
{
    Task<(bool success, bool shouldDeactivateToken)> SendNotificationAsync(string fcmToken, string title, string body, Dictionary<string, string>? data = null);
    Task<(int successCount, List<string> tokensToDeactivate)> SendToMultipleAsync(List<string> tokens, string title, string body, Dictionary<string, string>? data = null);
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

    public async Task<(bool success, bool shouldDeactivateToken)> SendNotificationAsync(
        string fcmToken,
        string title,
        string body,
        Dictionary<string, string>? data = null)
    {
        if (!_isInitialized)
        {
            _logger.LogWarning("Firebase not initialized. Cannot send notification.");
            return (false, false);
        }

        try
        {
            // Prepare data payload (merging provided data with title/body)
            var messageData = data != null 
                ? new Dictionary<string, string>(data) 
                : new Dictionary<string, string>();
            
            // Add title and body to data payload for custom handling on client
            messageData["title"] = title;
            messageData["body"] = body;

            var message = new Message
            {
                Token = fcmToken,
                // We don't send Notification payload anymore to give full control to the app
                // This makes it a "Data Message" which triggers background handler even when app is killed
                Data = messageData,
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    // No Notification object here either
                }
            };

            var response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
            _logger.LogInformation($"Successfully sent FCM message: {response}");
            return (true, false);
        }
        catch (FirebaseMessagingException ex)
        {
            _logger.LogError(ex, $"Failed to send FCM message to token {fcmToken}. Error: {ex.MessagingErrorCode}");
            
            // Check if token should be deactivated
            var shouldDeactivate = ex.MessagingErrorCode == MessagingErrorCode.InvalidArgument ||
                                   ex.MessagingErrorCode == MessagingErrorCode.Unregistered ||
                                   ex.MessagingErrorCode == MessagingErrorCode.SenderIdMismatch;
            
            if (shouldDeactivate)
            {
                _logger.LogWarning($"Token {fcmToken} should be deactivated. ErrorCode: {ex.MessagingErrorCode}");
            }
            
            return (false, shouldDeactivate);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Unexpected error sending FCM message to token {fcmToken}");
            return (false, false);
        }
    }

    public async Task<(int successCount, List<string> tokensToDeactivate)> SendToMultipleAsync(
        List<string> tokens,
        string title,
        string body,
        Dictionary<string, string>? data = null)
    {
        if (!_isInitialized)
        {
            _logger.LogWarning("Firebase not initialized. Cannot send notifications.");
            return (0, new List<string>());
        }

        if (tokens == null || tokens.Count == 0)
        {
            _logger.LogWarning("No tokens provided for multicast message");
            return (0, new List<string>());
        }

        try
        {
            // Prepare data payload (merging provided data with title/body)
            var messageData = data != null 
                ? new Dictionary<string, string>(data) 
                : new Dictionary<string, string>();
            
            // Add title and body to data payload
            messageData["title"] = title;
            messageData["body"] = body;

            var message = new MulticastMessage
            {
                Tokens = tokens,
                // Data-only message
                Data = messageData,
                Android = new AndroidConfig
                {
                    Priority = Priority.High
                }
            };

            var response = await FirebaseMessaging.DefaultInstance.SendEachForMulticastAsync(message);
            _logger.LogInformation($"Multicast sent. Success: {response.SuccessCount}, Failed: {response.FailureCount}");
            
            // Collect tokens that should be deactivated
            var tokensToDeactivate = new List<string>();
            
            if (response.FailureCount > 0)
            {
                for (int i = 0; i < response.Responses.Count; i++)
                {
                    var sendResponse = response.Responses[i];
                    if (!sendResponse.IsSuccess && sendResponse.Exception is FirebaseMessagingException fcmEx)
                    {
                        var shouldDeactivate = fcmEx.MessagingErrorCode == MessagingErrorCode.InvalidArgument ||
                                               fcmEx.MessagingErrorCode == MessagingErrorCode.Unregistered ||
                                               fcmEx.MessagingErrorCode == MessagingErrorCode.SenderIdMismatch;
                        
                        if (shouldDeactivate && i < tokens.Count)
                        {
                            tokensToDeactivate.Add(tokens[i]);
                            _logger.LogWarning($"Token {tokens[i]} should be deactivated. ErrorCode: {fcmEx.MessagingErrorCode}");
                        }
                    }
                }
            }
            
            return (response.SuccessCount, tokensToDeactivate);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send multicast FCM message");
            return (0, new List<string>());
        }
    }
}
