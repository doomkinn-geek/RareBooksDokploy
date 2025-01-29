namespace RareBooksService.Common.Models
{
    /// <summary>
    /// Отражает конкретную подписку (активную или историческую) пользователя на сервис.
    /// </summary>
    public class Subscription
    {
        public int Id { get; set; }

        /// <summary>
        /// Ссылка на конкретного пользователя
        /// </summary>
        public string UserId { get; set; }
        public ApplicationUser User { get; set; }

        /// <summary>
        /// Ссылка на план подписки
        /// </summary>
        public int SubscriptionPlanId { get; set; }
        public SubscriptionPlan SubscriptionPlan { get; set; }

        /// <summary>
        /// Дата начала подписки
        /// </summary>
        public DateTime StartDate { get; set; }

        /// <summary>
        /// Дата окончания подписки
        /// </summary>
        public DateTime EndDate { get; set; }

        /// <summary>
        /// Флаг, что подписка активна
        /// </summary>
        public bool IsActive { get; set; }

        /// <summary>
        /// Флаг автопродления
        /// </summary>
        public bool AutoRenew { get; set; }

        /// <summary>
        /// Идентификатор платежа в ЮKassa (для удобства можем хранить)
        /// </summary>
        public string? PaymentId { get; set; }

        /// <summary>
        /// Сумма, по которой пользователь оформил подписку (фиксируем, чтобы
        /// в будущем не зависеть от изменения цены в планах).
        /// </summary>
        public decimal PriceAtPurchase { get; set; }
    }
}
