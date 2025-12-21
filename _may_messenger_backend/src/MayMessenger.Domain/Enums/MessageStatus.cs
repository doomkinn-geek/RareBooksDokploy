namespace MayMessenger.Domain.Enums;

public enum MessageStatus
{
    Sending = 0,
    Sent = 1,
    Delivered = 2,
    Read = 3,
    Failed = 4,
    Played = 5  // For audio messages that have been played
}


