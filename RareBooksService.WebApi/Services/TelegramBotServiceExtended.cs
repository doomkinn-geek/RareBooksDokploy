using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Telegram;
using RareBooksService.Data;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace RareBooksService.WebApi.Services
{
    /// <summary>
    /// Расширение TelegramBotService с полным функционалом управления настройками
    /// </summary>
    public partial class TelegramBotService
    {
        // Полноценные методы для создания и редактирования настроек

        private async Task StartCreateNotificationAsync(string chatId, string telegramId, CancellationToken cancellationToken)
        {
            var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
            if (user == null)
            {
                await _telegramService.SendNotificationAsync(chatId, 
                    "❌ Аккаунт не найден. Обратитесь в поддержку.", 
                    cancellationToken);
                return;
            }

            // Создаем базовую настройку для редактирования
            var newPreference = new
            {
                keywords = "",
                minPrice = 0,
                maxPrice = 0,
                minYear = 0,
                maxYear = 0,
                cities = "",
                categoryIds = "",
                frequency = 60
            };

            await _telegramService.SetUserStateAsync(telegramId, TelegramBotStates.CreatingNotification, 
                JsonSerializer.Serialize(newPreference), cancellationToken);

            var message = new StringBuilder();
            message.AppendLine("📝 <b>Создание новой настройки уведомлений</b>");
            message.AppendLine();
            message.AppendLine("Пошагово настроим критерии поиска интересных книг:");
            message.AppendLine();
            message.AppendLine("📚 <b>Шаг 1: Ключевые слова</b>");
            message.AppendLine("Введите ключевые слова через запятую:");
            message.AppendLine();
            message.AppendLine("<i>Примеры:</i>");
            message.AppendLine("• Пушкин, прижизненное издание");
            message.AppendLine("• Достоевский, первое издание");
            message.AppendLine("• автограф, редкость");
            message.AppendLine();
            message.AppendLine("Или отправьте <b>пропустить</b> чтобы не задавать ключевые слова.");

            var keyboard = new TelegramInlineKeyboardMarkup();
            keyboard.InlineKeyboard.Add(new List<TelegramInlineKeyboardButton>
            {
                new TelegramInlineKeyboardButton 
                { 
                    Text = "❌ Отменить", 
                    CallbackData = TelegramCallbacks.Cancel 
                }
            });

            await _telegramService.SendMessageWithKeyboardAsync(chatId, message.ToString(), keyboard, cancellationToken);
        }

        private async Task ShowEditNotificationMenuAsync(string chatId, string telegramId, int preferenceId, CancellationToken cancellationToken)
        {
            var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
            if (user == null) return;

            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var preference = await context.UserNotificationPreferences
                .FirstOrDefaultAsync(p => p.Id == preferenceId && p.UserId == user.Id, cancellationToken);

            if (preference == null)
            {
                await _telegramService.SendNotificationAsync(chatId, 
                    "❌ Настройка не найдена.", 
                    cancellationToken);
                return;
            }

            var message = new StringBuilder();
            message.AppendLine($"⚙️ <b>Настройка #{preference.Id}</b>");
            message.AppendLine();

            var status = preference.IsEnabled ? "✅ Включена" : "❌ Отключена";
            message.AppendLine($"<b>Статус:</b> {status}");
            
            var keywords = string.IsNullOrEmpty(preference.Keywords) ? "Не заданы" : preference.Keywords;
            message.AppendLine($"<b>Ключевые слова:</b> {keywords}");
            
            if (preference.MinPrice > 0 || preference.MaxPrice > 0)
            {
                var priceRange = $"{preference.MinPrice}₽ - {preference.MaxPrice}₽";
                if (preference.MinPrice == 0) priceRange = $"до {preference.MaxPrice}₽";
                if (preference.MaxPrice == 0) priceRange = $"от {preference.MinPrice}₽";
                message.AppendLine($"<b>Цена:</b> {priceRange}");
            }
            
            if (preference.MinYear > 0 || preference.MaxYear > 0)
            {
                var yearRange = $"{preference.MinYear} - {preference.MaxYear}";
                if (preference.MinYear == 0) yearRange = $"до {preference.MaxYear}";
                if (preference.MaxYear == 0) yearRange = $"от {preference.MinYear}";
                message.AppendLine($"<b>Годы издания:</b> {yearRange}");
            }

            if (!string.IsNullOrEmpty(preference.Cities))
            {
                message.AppendLine($"<b>Города:</b> {preference.Cities}");
            }

            message.AppendLine($"<b>Частота:</b> {preference.NotificationFrequencyMinutes} мин");

            if (preference.LastNotificationSent.HasValue)
            {
                message.AppendLine($"<b>Последнее уведомление:</b> {preference.LastNotificationSent.Value:dd.MM.yyyy HH:mm}");
            }

            var keyboard = CreateEditNotificationKeyboard(preference);
            await _telegramService.SendMessageWithKeyboardAsync(chatId, message.ToString(), keyboard, cancellationToken);
        }

        private async Task ShowDeleteConfirmationAsync(string chatId, string telegramId, int preferenceId, CancellationToken cancellationToken)
        {
            var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
            if (user == null) return;

            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var preference = await context.UserNotificationPreferences
                .FirstOrDefaultAsync(p => p.Id == preferenceId && p.UserId == user.Id, cancellationToken);

            if (preference == null)
            {
                await _telegramService.SendNotificationAsync(chatId, 
                    "❌ Настройка не найдена.", 
                    cancellationToken);
                return;
            }

            var keywords = string.IsNullOrEmpty(preference.Keywords) ? "Без ключевых слов" : preference.Keywords;
            var message = $"🗑️ <b>Удаление настройки</b>\n\n" +
                         $"<b>Настройка:</b> {keywords}\n" +
                         $"<b>Частота:</b> {preference.NotificationFrequencyMinutes} мин\n\n" +
                         $"⚠️ Вы уверены, что хотите удалить эту настройку?";

            var keyboard = new TelegramInlineKeyboardMarkup();
            keyboard.InlineKeyboard.Add(new List<TelegramInlineKeyboardButton>
            {
                new TelegramInlineKeyboardButton 
                { 
                    Text = "🗑️ Да, удалить", 
                    CallbackData = TelegramCallbacks.ConfirmDelete + preferenceId 
                },
                new TelegramInlineKeyboardButton 
                { 
                    Text = "❌ Отменить", 
                    CallbackData = TelegramCallbacks.CancelDelete 
                }
            });

            await _telegramService.SendMessageWithKeyboardAsync(chatId, message, keyboard, cancellationToken);
        }

        private async Task DeleteNotificationAsync(string chatId, string telegramId, int preferenceId, CancellationToken cancellationToken)
        {
            var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
            if (user == null) return;

            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var preference = await context.UserNotificationPreferences
                .FirstOrDefaultAsync(p => p.Id == preferenceId && p.UserId == user.Id, cancellationToken);

            if (preference == null)
            {
                await _telegramService.SendNotificationAsync(chatId, 
                    "❌ Настройка не найдена.", 
                    cancellationToken);
                return;
            }

            context.UserNotificationPreferences.Remove(preference);
            await context.SaveChangesAsync(cancellationToken);

            await _telegramService.SendNotificationAsync(chatId, 
                "✅ Настройка успешно удалена!", 
                cancellationToken);
        }

        private async Task ToggleNotificationAsync(string chatId, string telegramId, int preferenceId, CancellationToken cancellationToken)
        {
            var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
            if (user == null) return;

            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var preference = await context.UserNotificationPreferences
                .FirstOrDefaultAsync(p => p.Id == preferenceId && p.UserId == user.Id, cancellationToken);

            if (preference == null)
            {
                await _telegramService.SendNotificationAsync(chatId, 
                    "❌ Настройка не найдена.", 
                    cancellationToken);
                return;
            }

            preference.IsEnabled = !preference.IsEnabled;
            preference.UpdatedAt = DateTime.UtcNow;
            await context.SaveChangesAsync(cancellationToken);

            var status = preference.IsEnabled ? "включена" : "отключена";
            await _telegramService.SendNotificationAsync(chatId, 
                $"✅ Настройка #{preferenceId} {status}!", 
                cancellationToken);

            // Показываем обновленное меню редактирования
            await ShowEditNotificationMenuAsync(chatId, telegramId, preferenceId, cancellationToken);
        }

        private async Task StartEditKeywordsAsync(string chatId, string telegramId, int preferenceId, CancellationToken cancellationToken)
        {
            await _telegramService.SetUserStateAsync(telegramId, TelegramBotStates.EditingKeywords, 
                preferenceId.ToString(), cancellationToken);

            var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var preference = await context.UserNotificationPreferences
                .FirstOrDefaultAsync(p => p.Id == preferenceId && p.UserId == user.Id, cancellationToken);

            var currentKeywords = string.IsNullOrEmpty(preference?.Keywords) ? "не заданы" : preference.Keywords;
            
            var message = $"📝 <b>Редактирование ключевых слов</b>\n\n" +
                         $"<b>Текущие ключевые слова:</b> {currentKeywords}\n\n" +
                         $"Введите новые ключевые слова через запятую:\n\n" +
                         $"<i>Примеры:</i>\n" +
                         $"• Пушкин, прижизненное издание\n" +
                         $"• Достоевский, первое издание\n" +
                         $"• автограф, редкость\n\n" +
                         $"Или отправьте <b>очистить</b> чтобы убрать все ключевые слова.";

            var keyboard = new TelegramInlineKeyboardMarkup();
            keyboard.InlineKeyboard.Add(new List<TelegramInlineKeyboardButton>
            {
                new TelegramInlineKeyboardButton 
                { 
                    Text = "❌ Отменить", 
                    CallbackData = TelegramCallbacks.EditNotification + preferenceId 
                }
            });

            await _telegramService.SendMessageWithKeyboardAsync(chatId, message, keyboard, cancellationToken);
        }

        private async Task StartEditPriceAsync(string chatId, string telegramId, int preferenceId, CancellationToken cancellationToken)
        {
            await _telegramService.SetUserStateAsync(telegramId, TelegramBotStates.EditingPrice, 
                preferenceId.ToString(), cancellationToken);

            var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var preference = await context.UserNotificationPreferences
                .FirstOrDefaultAsync(p => p.Id == preferenceId && p.UserId == user.Id, cancellationToken);

            var currentRange = "не задан";
            if (preference != null && (preference.MinPrice > 0 || preference.MaxPrice > 0))
            {
                if (preference.MinPrice > 0 && preference.MaxPrice > 0)
                    currentRange = $"{preference.MinPrice}₽ - {preference.MaxPrice}₽";
                else if (preference.MinPrice > 0)
                    currentRange = $"от {preference.MinPrice}₽";
                else if (preference.MaxPrice > 0)
                    currentRange = $"до {preference.MaxPrice}₽";
            }
            
            var message = $"💰 <b>Редактирование ценового диапазона</b>\n\n" +
                         $"<b>Текущий диапазон:</b> {currentRange}\n\n" +
                         $"Введите новый диапазон в одном из форматов:\n\n" +
                         $"• <b>1000-5000</b> (от 1000₽ до 5000₽)\n" +
                         $"• <b>1000-</b> (от 1000₽ и выше)\n" +
                         $"• <b>-5000</b> (до 5000₽)\n" +
                         $"• <b>очистить</b> (убрать ограничения по цене)";

            var keyboard = new TelegramInlineKeyboardMarkup();
            keyboard.InlineKeyboard.Add(new List<TelegramInlineKeyboardButton>
            {
                new TelegramInlineKeyboardButton 
                { 
                    Text = "❌ Отменить", 
                    CallbackData = TelegramCallbacks.EditNotification + preferenceId 
                }
            });

            await _telegramService.SendMessageWithKeyboardAsync(chatId, message, keyboard, cancellationToken);
        }

        // Обработка состояний пользователей

        private async Task ProcessCreateNotificationStateAsync(string chatId, string telegramId, string messageText, TelegramUserState userState, CancellationToken cancellationToken)
        {
            // В данной версии упрощено - создание через веб-интерфейс
            await _telegramService.SendNotificationAsync(chatId, 
                "📝 Для создания детальных настроек рекомендуем использовать веб-интерфейс.\n\n" +
                "Перейдите на сайт в раздел \"Уведомления\" для полного управления настройками.", 
                cancellationToken);

            await _telegramService.ClearUserStateAsync(telegramId, cancellationToken);
            await ShowMainMenuAsync(chatId, telegramId, cancellationToken);
        }

        private async Task ProcessEditKeywordsStateAsync(string chatId, string telegramId, string messageText, TelegramUserState userState, CancellationToken cancellationToken)
        {
            var preferenceId = int.Parse(userState.StateData);
            var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
            
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var preference = await context.UserNotificationPreferences
                .FirstOrDefaultAsync(p => p.Id == preferenceId && p.UserId == user.Id, cancellationToken);

            if (preference == null)
            {
                await _telegramService.SendNotificationAsync(chatId, "❌ Настройка не найдена.", cancellationToken);
                await _telegramService.ClearUserStateAsync(telegramId, cancellationToken);
                return;
            }

            if (messageText.ToLower() == "очистить")
            {
                preference.Keywords = "";
            }
            else
            {
                // Базовая валидация ключевых слов
                var keywords = messageText.Trim();
                if (keywords.Length > 500)
                {
                    await _telegramService.SendNotificationAsync(chatId, 
                        "❌ Слишком длинные ключевые слова. Максимум 500 символов.", 
                        cancellationToken);
                    return;
                }
                preference.Keywords = keywords;
            }

            preference.UpdatedAt = DateTime.UtcNow;
            await context.SaveChangesAsync(cancellationToken);

            await _telegramService.ClearUserStateAsync(telegramId, cancellationToken);
            await _telegramService.SendNotificationAsync(chatId, "✅ Ключевые слова обновлены!", cancellationToken);
            
            await ShowEditNotificationMenuAsync(chatId, telegramId, preferenceId, cancellationToken);
        }

        private async Task ProcessEditPriceStateAsync(string chatId, string telegramId, string messageText, TelegramUserState userState, CancellationToken cancellationToken)
        {
            var preferenceId = int.Parse(userState.StateData);
            var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
            
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var preference = await context.UserNotificationPreferences
                .FirstOrDefaultAsync(p => p.Id == preferenceId && p.UserId == user.Id, cancellationToken);

            if (preference == null)
            {
                await _telegramService.SendNotificationAsync(chatId, "❌ Настройка не найдена.", cancellationToken);
                await _telegramService.ClearUserStateAsync(telegramId, cancellationToken);
                return;
            }

            var input = messageText.ToLower().Trim();

            if (input == "очистить")
            {
                preference.MinPrice = 0;
                preference.MaxPrice = 0;
            }
            else
            {
                // Парсинг ценового диапазона
                if (!TryParsePriceRange(input, out decimal minPrice, out decimal maxPrice))
                {
                    await _telegramService.SendNotificationAsync(chatId, 
                        "❌ Неверный формат. Используйте: 1000-5000, 1000-, -5000 или 'очистить'", 
                        cancellationToken);
                    return;
                }

                preference.MinPrice = minPrice;
                preference.MaxPrice = maxPrice;
            }

            preference.UpdatedAt = DateTime.UtcNow;
            await context.SaveChangesAsync(cancellationToken);

            await _telegramService.ClearUserStateAsync(telegramId, cancellationToken);
            await _telegramService.SendNotificationAsync(chatId, "✅ Ценовой диапазон обновлен!", cancellationToken);
            
            await ShowEditNotificationMenuAsync(chatId, telegramId, preferenceId, cancellationToken);
        }

        // Вспомогательные методы

        private TelegramInlineKeyboardMarkup CreateEditNotificationKeyboard(UserNotificationPreference preference)
        {
            var keyboard = new TelegramInlineKeyboardMarkup();

            // Статус (включить/выключить)
            var statusText = preference.IsEnabled ? "❌ Отключить" : "✅ Включить";
            keyboard.InlineKeyboard.Add(new List<TelegramInlineKeyboardButton>
            {
                new TelegramInlineKeyboardButton 
                { 
                    Text = statusText, 
                    CallbackData = TelegramCallbacks.ToggleEnabled + preference.Id 
                }
            });

            // Редактирование полей
            keyboard.InlineKeyboard.Add(new List<TelegramInlineKeyboardButton>
            {
                new TelegramInlineKeyboardButton 
                { 
                    Text = "📝 Ключевые слова", 
                    CallbackData = TelegramCallbacks.EditKeywords + preference.Id 
                },
                new TelegramInlineKeyboardButton 
                { 
                    Text = "💰 Цена", 
                    CallbackData = TelegramCallbacks.EditPrice + preference.Id 
                }
            });

            // Удаление и назад
            keyboard.InlineKeyboard.Add(new List<TelegramInlineKeyboardButton>
            {
                new TelegramInlineKeyboardButton 
                { 
                    Text = "🗑️ Удалить", 
                    CallbackData = TelegramCallbacks.DeleteNotification + preference.Id 
                },
                new TelegramInlineKeyboardButton 
                { 
                    Text = "🔙 Назад", 
                    CallbackData = TelegramCallbacks.BackToSettings 
                }
            });

            return keyboard;
        }

        private bool TryParsePriceRange(string input, out decimal minPrice, out decimal maxPrice)
        {
            minPrice = 0;
            maxPrice = 0;

            try
            {
                if (input.Contains("-"))
                {
                    var parts = input.Split('-');
                    if (parts.Length == 2)
                    {
                        if (!string.IsNullOrWhiteSpace(parts[0]))
                        {
                            if (!decimal.TryParse(parts[0].Trim(), out minPrice))
                                return false;
                        }

                        if (!string.IsNullOrWhiteSpace(parts[1]))
                        {
                            if (!decimal.TryParse(parts[1].Trim(), out maxPrice))
                                return false;
                        }

                        return true;
                    }
                }
                else
                {
                    // Одно число - это минимальная цена
                    if (decimal.TryParse(input, out minPrice))
                    {
                        return true;
                    }
                }
            }
            catch
            {
                return false;
            }

            return false;
        }
    }
}

