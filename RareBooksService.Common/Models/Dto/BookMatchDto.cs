using System;

namespace RareBooksService.Common.Models.Dto
{
    /// <summary>
    /// DTO для найденного аналога книги
    /// </summary>
    public class BookMatchDto
    {
        public int Id { get; set; }
        public int MatchedBookId { get; set; }
        public double MatchScore { get; set; }
        public DateTime FoundDate { get; set; }
        public bool IsSelected { get; set; }
        public BookSearchResultDto MatchedBook { get; set; }
    }
}

