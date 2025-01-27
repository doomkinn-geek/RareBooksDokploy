namespace RareBooksService.Common.Models
{
    /// <summary>
    /// План подписки (тариф). Например, "500 руб/мес, 50 запросов" и т.д.
    /// </summary>
    public class SubscriptionPlan
    {
        public int Id { get; set; }

        /// <summary>
        /// Название плана, отображается пользователю.
        /// </summary>
        public string Name { get; set; }

        /// <summary>
        /// Стоимость плана (в рублях) в месяц.
        /// </summary>
        public decimal Price { get; set; }

        /// <summary>
        /// Лимит запросов в месяц (если нужно, иначе можете убрать).
        /// </summary>
        public int MonthlyRequestLimit { get; set; }

        /// <summary>
        /// Признак, что план активен и доступен к выбору.
        /// </summary>
        public bool IsActive { get; set; } = true;
    }
}
