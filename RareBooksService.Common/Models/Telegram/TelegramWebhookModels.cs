using System.Text.Json.Serialization;

namespace RareBooksService.Common.Models.Telegram
{
    /// <summary>
    /// Основная модель для обновлений от Telegram
    /// </summary>
    public class TelegramUpdate
    {
        [JsonPropertyName("update_id")]
        public long UpdateId { get; set; }

        [JsonPropertyName("message")]
        public TelegramMessage Message { get; set; }

        [JsonPropertyName("callback_query")]
        public TelegramCallbackQuery CallbackQuery { get; set; }
    }

    /// <summary>
    /// Модель сообщения Telegram
    /// </summary>
    public class TelegramMessage
    {
        [JsonPropertyName("message_id")]
        public int MessageId { get; set; }

        [JsonPropertyName("from")]
        public TelegramUser From { get; set; }

        [JsonPropertyName("chat")]
        public TelegramChat Chat { get; set; }

        [JsonPropertyName("date")]
        public long Date { get; set; }

        [JsonPropertyName("text")]
        public string Text { get; set; }

        [JsonPropertyName("reply_markup")]
        public TelegramInlineKeyboardMarkup ReplyMarkup { get; set; }
    }

    /// <summary>
    /// Модель пользователя Telegram
    /// </summary>
    public class TelegramUser
    {
        [JsonPropertyName("id")]
        public long Id { get; set; }

        [JsonPropertyName("is_bot")]
        public bool IsBot { get; set; }

        [JsonPropertyName("first_name")]
        public string FirstName { get; set; }

        [JsonPropertyName("last_name")]
        public string LastName { get; set; }

        [JsonPropertyName("username")]
        public string Username { get; set; }

        [JsonPropertyName("language_code")]
        public string LanguageCode { get; set; }
    }

    /// <summary>
    /// Модель чата Telegram
    /// </summary>
    public class TelegramChat
    {
        [JsonPropertyName("id")]
        public long Id { get; set; }

        [JsonPropertyName("type")]
        public string Type { get; set; }

        [JsonPropertyName("first_name")]
        public string FirstName { get; set; }

        [JsonPropertyName("last_name")]
        public string LastName { get; set; }

        [JsonPropertyName("username")]
        public string Username { get; set; }
    }

    /// <summary>
    /// Модель callback query (нажатие на inline кнопку)
    /// </summary>
    public class TelegramCallbackQuery
    {
        [JsonPropertyName("id")]
        public string Id { get; set; }

        [JsonPropertyName("from")]
        public TelegramUser From { get; set; }

        [JsonPropertyName("message")]
        public TelegramMessage Message { get; set; }

        [JsonPropertyName("data")]
        public string Data { get; set; }
    }

    /// <summary>
    /// Inline клавиатура
    /// </summary>
    public class TelegramInlineKeyboardMarkup
    {
        [JsonPropertyName("inline_keyboard")]
        public List<List<TelegramInlineKeyboardButton>> InlineKeyboard { get; set; }

        public TelegramInlineKeyboardMarkup()
        {
            InlineKeyboard = new List<List<TelegramInlineKeyboardButton>>();
        }
    }

    /// <summary>
    /// Inline кнопка клавиатуры
    /// </summary>
    public class TelegramInlineKeyboardButton
    {
        [JsonPropertyName("text")]
        public string Text { get; set; }

        [JsonPropertyName("callback_data")]
        public string CallbackData { get; set; }

        [JsonPropertyName("url")]
        public string Url { get; set; }
    }

    /// <summary>
    /// Обычная клавиатура
    /// </summary>
    public class TelegramReplyKeyboardMarkup
    {
        [JsonPropertyName("keyboard")]
        public List<List<TelegramKeyboardButton>> Keyboard { get; set; }

        [JsonPropertyName("resize_keyboard")]
        public bool ResizeKeyboard { get; set; } = true;

        [JsonPropertyName("one_time_keyboard")]
        public bool OneTimeKeyboard { get; set; } = false;

        public TelegramReplyKeyboardMarkup()
        {
            Keyboard = new List<List<TelegramKeyboardButton>>();
        }
    }

    /// <summary>
    /// Кнопка обычной клавиатуры
    /// </summary>
    public class TelegramKeyboardButton
    {
        [JsonPropertyName("text")]
        public string Text { get; set; }

        [JsonPropertyName("request_contact")]
        public bool RequestContact { get; set; } = false;

        [JsonPropertyName("request_location")]
        public bool RequestLocation { get; set; } = false;
    }

    /// <summary>
    /// Удаление клавиатуры
    /// </summary>
    public class TelegramReplyKeyboardRemove
    {
        [JsonPropertyName("remove_keyboard")]
        public bool RemoveKeyboard { get; set; } = true;
    }

    /// <summary>
    /// Состояние пользователя в боте
    /// </summary>
    public class TelegramUserState
    {
        public int Id { get; set; }
        public string TelegramId { get; set; }
        public string State { get; set; }
        public string StateData { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }

    /// <summary>
    /// Константы состояний пользователя
    /// </summary>
    public static class TelegramBotStates
    {
        public const string None = "none";
        public const string CreatingNotification = "creating_notification";
        public const string EditingKeywords = "editing_keywords";
        public const string EditingPrice = "editing_price";
        public const string EditingYears = "editing_years";
        public const string EditingCities = "editing_cities";
        public const string EditingCategories = "editing_categories";
        public const string EditingFrequency = "editing_frequency";
        public const string DeletingNotification = "deleting_notification";
    }

    /// <summary>
    /// Константы callback data для inline кнопок
    /// </summary>
    public static class TelegramCallbacks
    {
        public const string ShowSettings = "show_settings";
        public const string CreateNotification = "create_notification";
        public const string EditNotification = "edit_notification_";
        public const string DeleteNotification = "delete_notification_";
        public const string ConfirmDelete = "confirm_delete_";
        public const string CancelDelete = "cancel_delete";
        public const string EditKeywords = "edit_keywords_";
        public const string EditPrice = "edit_price_";
        public const string EditYears = "edit_years_";
        public const string EditCities = "edit_cities_";
        public const string EditCategories = "edit_categories_";
        public const string EditFrequency = "edit_frequency_";
        public const string ToggleEnabled = "toggle_enabled_";
        public const string BackToSettings = "back_to_settings";
        public const string Help = "help";
        public const string Cancel = "cancel";
    }
}
