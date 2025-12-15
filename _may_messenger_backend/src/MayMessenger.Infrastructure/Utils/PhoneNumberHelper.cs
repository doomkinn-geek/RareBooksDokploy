using System.Text.RegularExpressions;

namespace MayMessenger.Infrastructure.Utils;

public static class PhoneNumberHelper
{
    /// <summary>
    /// Нормализует номер телефона перед хешированием.
    /// Удаляет все символы кроме цифр, заменяет начальную "8" на "+7".
    /// Примеры:
    /// "+7 (909) 492-41-90" -> "+79094924190"
    /// "8 (909) 492-41-90"  -> "+79094924190"
    /// "8-909-492-41-90"    -> "+79094924190"
    /// </summary>
    public static string Normalize(string phoneNumber)
    {
        if (string.IsNullOrWhiteSpace(phoneNumber))
        {
            return string.Empty;
        }

        // Удаляем все символы кроме цифр и +
        var cleaned = Regex.Replace(phoneNumber, @"[^\d+]", "");
        
        // Заменяем начальную 8 на +7 (для российских номеров)
        if (cleaned.StartsWith("8") && cleaned.Length == 11)
        {
            cleaned = "+7" + cleaned.Substring(1);
        }
        
        // Если номер начинается с 7 (без +), добавляем +
        if (cleaned.StartsWith("7") && cleaned.Length == 11 && !cleaned.StartsWith("+"))
        {
            cleaned = "+" + cleaned;
        }
        
        return cleaned;
    }
}
