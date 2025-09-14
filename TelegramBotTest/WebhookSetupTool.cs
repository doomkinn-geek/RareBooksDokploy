using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace TelegramBotTest
{
    public static class WebhookSetupTool
    {
        private static readonly string BOT_TOKEN = "7745135732:AAFp2cJs8boBZZDyb1myO1kcmjwk6K3Mi7U";
        private static readonly string BASE_URL = $"https://api.telegram.org/bot{BOT_TOKEN}";
        private static readonly HttpClient _httpClient = new HttpClient();

        public static async Task SetupWebhook()
        {
            Console.WriteLine("=== Настройка Webhook ===");
            
            // Проверяем текущий webhook
            await CheckCurrentWebhook();
            
            Console.WriteLine("\nВарианты настройки:");
            Console.WriteLine("1. Удалить webhook (использовать polling)");
            Console.WriteLine("2. Настроить webhook с ngrok");
            Console.WriteLine("3. Настроить webhook с публичным URL");
            Console.WriteLine("4. Назад");
            Console.Write("Выберите (1-4): ");
            
            var choice = Console.ReadLine();
            
            switch (choice)
            {
                case "1":
                    await DeleteWebhook();
                    break;
                case "2":
                    await SetupNgrokWebhook();
                    break;
                case "3":
                    await SetupPublicWebhook();
                    break;
                case "4":
                    return;
                default:
                    Console.WriteLine("❌ Неверный выбор!");
                    break;
            }
        }

        private static async Task CheckCurrentWebhook()
        {
            Console.WriteLine("--- Проверка текущего webhook ---");
            
            try
            {
                var response = await _httpClient.GetAsync($"{BASE_URL}/getWebhookInfo");
                var content = await response.Content.ReadAsStringAsync();
                
                if (response.IsSuccessStatusCode)
                {
                    var result = JsonDocument.Parse(content);
                    if (result.RootElement.GetProperty("ok").GetBoolean())
                    {
                        var webhookInfo = result.RootElement.GetProperty("result");
                        var url = webhookInfo.GetProperty("url").GetString();
                        var pendingUpdateCount = webhookInfo.GetProperty("pending_update_count").GetInt32();
                        
                        if (string.IsNullOrEmpty(url))
                        {
                            Console.WriteLine("🔴 Webhook не установлен (используется polling)");
                        }
                        else
                        {
                            Console.WriteLine($"🟢 Webhook установлен: {url}");
                            Console.WriteLine($"📦 Ожидающих обновлений: {pendingUpdateCount}");
                            
                            if (webhookInfo.TryGetProperty("last_error_date", out var lastErrorDate) && lastErrorDate.GetInt64() > 0)
                            {
                                var lastError = webhookInfo.GetProperty("last_error_message").GetString();
                                var errorDateTime = DateTimeOffset.FromUnixTimeSeconds(lastErrorDate.GetInt64());
                                Console.WriteLine($"❌ Последняя ошибка ({errorDateTime:yyyy-MM-dd HH:mm:ss}): {lastError}");
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Ошибка при проверке webhook: {ex.Message}");
            }
        }

        private static async Task DeleteWebhook()
        {
            Console.WriteLine("--- Удаление webhook ---");
            
            try
            {
                var response = await _httpClient.PostAsync($"{BASE_URL}/deleteWebhook", null);
                var content = await response.Content.ReadAsStringAsync();
                
                if (response.IsSuccessStatusCode)
                {
                    var result = JsonDocument.Parse(content);
                    if (result.RootElement.GetProperty("ok").GetBoolean())
                    {
                        Console.WriteLine("✅ Webhook успешно удален");
                        Console.WriteLine("ℹ️  Теперь бот работает в режиме polling (getUpdates)");
                        Console.WriteLine("⚠️  В этом режиме команды работать не будут, нужен запущенный сервер");
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Ошибка при удалении webhook: {ex.Message}");
            }
        }

        private static async Task SetupNgrokWebhook()
        {
            Console.WriteLine("--- Настройка webhook с ngrok ---");
            Console.WriteLine("\n📋 Инструкция:");
            Console.WriteLine("1. Установите ngrok: https://ngrok.com/");
            Console.WriteLine("2. Запустите RareBooksService.WebApi на порту 5000");
            Console.WriteLine("3. В новом терминале запустите: ngrok http 5000");
            Console.WriteLine("4. Скопируйте HTTPS URL из ngrok (например: https://abc123.ngrok.io)");
            Console.WriteLine();
            
            Console.Write("Введите ngrok HTTPS URL (без /api/telegram/webhook): ");
            var baseUrl = Console.ReadLine()?.Trim();
            
            if (string.IsNullOrEmpty(baseUrl))
            {
                Console.WriteLine("❌ URL не может быть пустым");
                return;
            }
            
            var webhookUrl = baseUrl.TrimEnd('/') + "/api/telegram/webhook";
            await SetWebhook(webhookUrl);
        }

        private static async Task SetupPublicWebhook()
        {
            Console.WriteLine("--- Настройка webhook с публичным URL ---");
            Console.WriteLine("\n⚠️  Убедитесь, что ваш сервер:");
            Console.WriteLine("   - Запущен и доступен по HTTPS");
            Console.WriteLine("   - Имеет валидный SSL сертификат");
            Console.WriteLine("   - Endpoint доступен по адресу: /api/telegram/webhook");
            Console.WriteLine();
            
            Console.Write("Введите базовый URL вашего сервера (например: https://yourdomain.com): ");
            var baseUrl = Console.ReadLine()?.Trim();
            
            if (string.IsNullOrEmpty(baseUrl))
            {
                Console.WriteLine("❌ URL не может быть пустым");
                return;
            }
            
            var webhookUrl = baseUrl.TrimEnd('/') + "/api/telegram/webhook";
            await SetWebhook(webhookUrl);
        }

        private static async Task SetWebhook(string webhookUrl)
        {
            Console.WriteLine($"--- Установка webhook: {webhookUrl} ---");
            
            try
            {
                var payload = new
                {
                    url = webhookUrl,
                    allowed_updates = new[] { "message", "callback_query" }
                };
                
                var json = JsonSerializer.Serialize(payload);
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                
                var response = await _httpClient.PostAsync($"{BASE_URL}/setWebhook", content);
                var responseContent = await response.Content.ReadAsStringAsync();
                
                Console.WriteLine($"Status Code: {response.StatusCode}");
                Console.WriteLine($"Response: {responseContent}");
                
                if (response.IsSuccessStatusCode)
                {
                    var result = JsonDocument.Parse(responseContent);
                    if (result.RootElement.GetProperty("ok").GetBoolean())
                    {
                        Console.WriteLine("✅ Webhook успешно установлен!");
                        Console.WriteLine("\n🎯 Что теперь делать:");
                        Console.WriteLine("1. Убедитесь, что RareBooksService.WebApi запущен");
                        Console.WriteLine("2. Попробуйте написать боту команду /start");
                        Console.WriteLine("3. Проверьте логи сервера на наличие входящих запросов");
                        
                        // Проверяем webhook через несколько секунд
                        Console.WriteLine("\n⏳ Проверяю установку через 3 секунды...");
                        await Task.Delay(3000);
                        await CheckCurrentWebhook();
                    }
                    else
                    {
                        Console.WriteLine("❌ Ошибка установки webhook");
                        if (result.RootElement.TryGetProperty("description", out var description))
                        {
                            Console.WriteLine($"Описание: {description.GetString()}");
                        }
                    }
                }
                else
                {
                    Console.WriteLine("❌ HTTP ошибка при установке webhook");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Ошибка при установке webhook: {ex.Message}");
            }
        }

        public static async Task TestWebhookConnection()
        {
            Console.WriteLine("=== Тестирование webhook соединения ===");
            Console.Write("Введите URL вашего webhook endpoint: ");
            var webhookUrl = Console.ReadLine()?.Trim();
            
            if (string.IsNullOrEmpty(webhookUrl))
            {
                Console.WriteLine("❌ URL не может быть пустым");
                return;
            }
            
            try
            {
                // Создаем тестовое обновление
                var testUpdate = new
                {
                    update_id = 123456789,
                    message = new
                    {
                        message_id = 1,
                        from = new
                        {
                            id = 494443219,
                            is_bot = false,
                            first_name = "Test",
                            username = "testuser"
                        },
                        chat = new
                        {
                            id = 494443219,
                            type = "private"
                        },
                        date = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
                        text = "/start"
                    }
                };
                
                var json = JsonSerializer.Serialize(testUpdate);
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                
                Console.WriteLine($"Отправляю тестовое обновление на: {webhookUrl}");
                
                var response = await _httpClient.PostAsync(webhookUrl, content);
                var responseContent = await response.Content.ReadAsStringAsync();
                
                Console.WriteLine($"Status Code: {response.StatusCode}");
                Console.WriteLine($"Response: {responseContent}");
                
                if (response.IsSuccessStatusCode)
                {
                    Console.WriteLine("✅ Webhook endpoint отвечает!");
                }
                else
                {
                    Console.WriteLine("❌ Проблемы с webhook endpoint");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Ошибка при тестировании: {ex.Message}");
            }
        }
    }
}
