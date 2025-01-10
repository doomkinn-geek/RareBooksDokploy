using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace RareBooksService.Parser.Services
{
    public static class PublishingYearExtractor
    {
        public static int? ExtractYearFromDescription(string description)
        {
            // Исключаем нежелательные фразы
            var excludedPatterns = new string[]
            {
                @"до\s+(\d{4})",
                @"-\s*(\d{4})",
                @"(\d{4})\s*-",
                @"от\s+(\d{4})"
            };

            foreach (var pattern in excludedPatterns)
            {
                var regex = new Regex(pattern);
                description = regex.Replace(description, ""); // Удаляем исключенные фразы из описания
            }

            // Попытка найти год в контексте фраз, указывающих на год издания
            var contextPatterns = new string[]
            {
                @"в\s+(\d{4})\b",
                @"(\d{4})\s+г\.?",
                @"(\d{4})г\.?"
                // Добавьте другие шаблоны по мере необходимости
            };

            foreach (var pattern in contextPatterns)
            {
                var regex = new Regex(pattern);
                var match = regex.Match(description);
                if (match.Success && int.TryParse(match.Groups[1].Value, out int year))
                {
                    // Проверяем, что год находится в разумных пределах
                    if (year >= 1500 && year <= DateTime.Now.Year)
                    {
                        return year;
                    }
                }
            }

            // Если контекстный поиск не дал результатов, ищем любое упоминание четырех цифр
            var fallbackRegex = new Regex(@"\b(1[5-9]\d{2}|20[0-1]\d)\b");
            var fallbackMatch = fallbackRegex.Match(description);
            if (fallbackMatch.Success && int.TryParse(fallbackMatch.Value, out int fallbackYear))
            {
                return fallbackYear;
            }

            return null; // В случае, если год не найден
        }
    }


}
