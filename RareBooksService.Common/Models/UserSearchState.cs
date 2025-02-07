namespace RareBooksService.Common.Models
{
    /// <summary>
    /// Таблица для хранения последнего поискового запроса пользователя (чтобы не списывать лимит повторно).
    /// </summary>
    public class UserSearchState
    {
        public int Id { get; set; }

        // Чьё это состояние
        public string UserId { get; set; }
        public ApplicationUser User { get; set; }

        // "Title", "Description", "Category", "Seller", ...
        public string SearchType { get; set; }

        // Содержимое последнего запроса
        public string LastQuery { get; set; }

        // Когда мы последний раз обновили
        public DateTime UpdatedAt { get; set; }
    }
}
