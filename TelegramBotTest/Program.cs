using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace TelegramBotTest
{
    class Program
    {

        static async Task Main(string[] args)
        {
            Console.WriteLine("=== Telegram Bot Test ===");
            Console.WriteLine();

            while (true)
            {
                Console.WriteLine("Выберите действие:");
                Console.WriteLine("1. Проверить подключение к боту (getMe)");
                Console.WriteLine("2. Отправить тестовое сообщение");
                Console.WriteLine("3. Симулировать webhook обновление");
                Console.WriteLine("4. Тестировать клавиатуру");
                Console.WriteLine("5. 🔧 Настроить webhook");
                Console.WriteLine("6. 🧪 Протестировать webhook соединение");
                Console.WriteLine("7. Выход");
                Console.Write("Ваш выбор: ");

                var choice = Console.ReadLine();

                try
                {
                    switch (choice)
                    {
                        case "1":
                            await TelegramTestMethods.TestBotConnection();
                            break;
                        case "2":
                            await TelegramTestMethods.SendTestMessage();
                            break;
                        case "3":
                            await TelegramTestMethods.SimulateWebhookUpdate();
                            break;
                        case "4":
                            await TelegramTestMethods.TestKeyboard();
                            break;
                        case "5":
                            await WebhookSetupTool.SetupWebhook();
                            break;
                        case "6":
                            await WebhookSetupTool.TestWebhookConnection();
                            break;
                        case "7":
                            return;
                        default:
                            Console.WriteLine("Неверный выбор!");
                            break;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Ошибка: {ex.Message}");
                }

                Console.WriteLine();
            }
        }
    }
}
