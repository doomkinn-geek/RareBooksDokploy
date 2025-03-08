using System;

namespace RareBooksService.Common.Models.Dto
{
    /// <summary>
    /// DTO для передачи информации об избранных книгах пользователя
    /// </summary>
    public class UserFavoriteBookDto
    {
        /// <summary>
        /// Идентификатор записи в избранном
        /// </summary>
        public int Id { get; set; }

        /// <summary>
        /// Идентификатор книги
        /// </summary>
        public int BookId { get; set; }

        /// <summary>
        /// Дата добавления книги в избранное
        /// </summary>
        public DateTime AddedDate { get; set; }
    }
} 