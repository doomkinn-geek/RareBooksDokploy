using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace TelegramBotTest
{
    public static class TelegramTestMethods
    {
        private static readonly string BOT_TOKEN = "7745135732:AAFp2cJs8boBZZDyb1myO1kcmjwk6K3Mi7U";
        private static readonly string BASE_URL = $"https://api.telegram.org/bot{BOT_TOKEN}";
        private static readonly HttpClient _httpClient = new HttpClient();

        public static async Task TestBotConnection()
        {
            Console.WriteLine("--- Проверка подключения к боту ---");
            
            var response = await _httpClient.GetAsync($"{BASE_URL}/getMe");
            var content = await response.Content.ReadAsStringAsync();
            
            Console.WriteLine($"Status Code: {response.StatusCode}");
            Console.WriteLine($"Response: {content}");
            
            if (response.IsSuccessStatusCode)
            {
                var result = JsonDocument.Parse(content);
                if (result.RootElement.GetProperty("ok").GetBoolean())
                {
                    var botInfo = result.RootElement.GetProperty("result");
                    Console.WriteLine($"✅ Бот активен!");
                    Console.WriteLine($"ID: {botInfo.GetProperty("id").GetInt64()}");
                    Console.WriteLine($"Имя: {botInfo.GetProperty("first_name").GetString()}");
                    Console.WriteLine($"Username: @{botInfo.GetProperty("username").GetString()}");
                }
                else
                {
                    Console.WriteLine("❌ Ошибка в ответе API");
                }
            }
            else
            {
                Console.WriteLine("❌ Не удалось подключиться к боту");
            }
        }

        public static async Task SendTestMessage()
        {
            Console.WriteLine("--- Отправка тестового сообщения ---");
            Console.Write("Введите ID чата (или ваш Telegram ID): ");
            var chatId = Console.ReadLine();

            if (string.IsNullOrWhiteSpace(chatId))
            {
                Console.WriteLine("❌ ID чата не может быть пустым");
                return;
            }

            var message = new
            {
                chat_id = chatId,
                text = $"🤖 Тестовое сообщение от бота\nВремя: {DateTime.Now:yyyy-MM-dd HH:mm:ss}",
                parse_mode = "Markdown"
            };

            var json = JsonSerializer.Serialize(message);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync($"{BASE_URL}/sendMessage", content);
            var responseContent = await response.Content.ReadAsStringAsync();

            Console.WriteLine($"Status Code: {response.StatusCode}");
            Console.WriteLine($"Response: {responseContent}");

            if (response.IsSuccessStatusCode)
            {
                var result = JsonDocument.Parse(responseContent);
                if (result.RootElement.GetProperty("ok").GetBoolean())
                {
                    Console.WriteLine("✅ Сообщение отправлено успешно!");
                }
                else
                {
                    Console.WriteLine("❌ Ошибка отправки сообщения");
                }
            }
            else
            {
                Console.WriteLine("❌ HTTP ошибка при отправке");
            }
        }

        public static async Task TestKeyboard()
        {
            Console.WriteLine("--- Тестирование клавиатуры ---");
            Console.Write("Введите ID чата: ");
            var chatId = Console.ReadLine();

            if (string.IsNullOrWhiteSpace(chatId))
            {
                Console.WriteLine("❌ ID чата не может быть пустым");
                return;
            }

            var inlineKeyboard = new
            {
                chat_id = chatId,
                text = "Выберите действие:",
                reply_markup = new
                {
                    inline_keyboard = new[]
                    {
                        new[]
                        {
                            new { text = "📝 Создать настройку", callback_data = "create_notification" },
                            new { text = "📋 Мои настройки", callback_data = "list_notifications" }
                        },
                        new[]
                        {
                            new { text = "❓ Помощь", callback_data = "help" }
                        }
                    }
                }
            };

            var json = JsonSerializer.Serialize(inlineKeyboard);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync($"{BASE_URL}/sendMessage", content);
            var responseContent = await response.Content.ReadAsStringAsync();

            Console.WriteLine($"Status Code: {response.StatusCode}");
            Console.WriteLine($"Response: {responseContent}");

            if (response.IsSuccessStatusCode)
            {
                Console.WriteLine("✅ Сообщение с клавиатурой отправлено!");
                Console.WriteLine("Попробуйте нажать кнопки в Telegram");
            }
        }

        public static async Task SimulateWebhookUpdate()
        {
            Console.WriteLine("--- Симуляция webhook обновления ---");

            // Симулируем различные типы обновлений
            var updates = new[]
            {
                // Обычное текстовое сообщение
                CreateTextMessageUpdate("123456789", "TestUser", "/start"),
                
                // Callback query (нажатие inline кнопки)
                CreateCallbackQueryUpdate("123456789", "TestUser", "create_notification"),
                
                // Текстовое сообщение с ключевыми словами
                CreateTextMessageUpdate("123456789", "TestUser", "пушкин, поэзия")
            };

            Console.WriteLine("Доступные симуляции:");
            Console.WriteLine("1. Команда /start");
            Console.WriteLine("2. Нажатие кнопки 'Создать настройку'");
            Console.WriteLine("3. Ввод ключевых слов");
            Console.Write("Выберите (1-3): ");
            
            var choice = Console.ReadLine();
            if (!int.TryParse(choice, out int index) || index < 1 || index > 3)
            {
                Console.WriteLine("❌ Неверный выбор");
                return;
            }

            var selectedUpdate = updates[index - 1];
            var json = JsonSerializer.Serialize(selectedUpdate, new JsonSerializerOptions 
            { 
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
            });

            Console.WriteLine("\n--- Симулируемое обновление ---");
            Console.WriteLine(json);
            Console.WriteLine("\n--- Обработка обновления ---");

            // Здесь бы мы вызвали наш TelegramBotService
            await ProcessUpdateSimulation(selectedUpdate);
        }

        private static object CreateTextMessageUpdate(string userId, string username, string text)
        {
            return new
            {
                update_id = Random.Shared.Next(1000000),
                message = new
                {
                    message_id = Random.Shared.Next(1000),
                    from = new
                    {
                        id = long.Parse(userId),
                        is_bot = false,
                        first_name = "Test",
                        username = username
                    },
                    chat = new
                    {
                        id = long.Parse(userId),
                        type = "private"
                    },
                    date = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
                    text = text
                }
            };
        }

        private static object CreateCallbackQueryUpdate(string userId, string username, string callbackData)
        {
            return new
            {
                update_id = Random.Shared.Next(1000000),
                callback_query = new
                {
                    id = Guid.NewGuid().ToString(),
                    from = new
                    {
                        id = long.Parse(userId),
                        is_bot = false,
                        first_name = "Test",
                        username = username
                    },
                    message = new
                    {
                        message_id = Random.Shared.Next(1000),
                        chat = new
                        {
                            id = long.Parse(userId),
                            type = "private"
                        }
                    },
                    data = callbackData
                }
            };
        }

        private static async Task ProcessUpdateSimulation(object update)
        {
            // Простая симуляция обработки обновления
            var json = JsonSerializer.Serialize(update);
            var updateObj = JsonDocument.Parse(json);

            if (updateObj.RootElement.TryGetProperty("message", out var messageProperty))
            {
                var text = messageProperty.GetProperty("text").GetString();
                var userId = messageProperty.GetProperty("from").GetProperty("id").GetInt64().ToString();
                
                Console.WriteLine($"📨 Получено сообщение: '{text}' от пользователя {userId}");
                
                if (text == "/start")
                {
                    Console.WriteLine("🎯 Обрабатываем команду /start");
                    Console.WriteLine("➡️ Должны показать главное меню");
                }
                else if (text?.Contains(",") == true)
                {
                    Console.WriteLine("🎯 Обрабатываем ввод ключевых слов");
                    Console.WriteLine($"➡️ Ключевые слова: {text}");
                    Console.WriteLine("➡️ Должны сохранить настройку и перейти к вводу цены");
                }
            }
            else if (updateObj.RootElement.TryGetProperty("callback_query", out var callbackProperty))
            {
                var data = callbackProperty.GetProperty("data").GetString();
                var userId = callbackProperty.GetProperty("from").GetProperty("id").GetInt64().ToString();
                
                Console.WriteLine($"🔘 Получено нажатие кнопки: '{data}' от пользователя {userId}");
                
                if (data == "create_notification")
                {
                    Console.WriteLine("🎯 Обрабатываем создание настройки");
                    Console.WriteLine("➡️ Должны запросить ввод ключевых слов");
                }
            }

            // Симулируем задержку обработки
            await Task.Delay(500);
            Console.WriteLine("✅ Обработка завершена");
        }
    }
}
