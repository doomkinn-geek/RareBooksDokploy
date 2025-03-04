using System.Threading.Tasks;
using System.Collections.Generic;
using RareBooksService.Common.Models.Dto;

namespace RareBooksService.Data.Interfaces
{
    /// <summary>
    /// Интерфейс для сервиса очистки категорий
    /// </summary>
    public interface ICategoryCleanupService
    {
        /// <summary>
        /// Подсчитывает количество категорий и книг, которые будут удалены
        /// </summary>
        /// <param name="categoryNames">Массив названий категорий для анализа</param>
        /// <returns>Результат анализа, содержащий количество категорий и книг</returns>
        Task<(int categoriesCount, int booksCount, int[] categoryIds)> CountCategoriesAndBooksByNamesAsync(string[] categoryNames);

        /// <summary>
        /// Подсчитывает количество "нежелательных" категорий и книг, которые будут удалены
        /// </summary>
        /// <returns>Результат анализа, содержащий количество категорий и книг</returns>
        Task<(int categoriesCount, int booksCount, int[] categoryIds)> CountUnwantedCategoriesAndBooksAsync();

        /// <summary>
        /// Удаляет категории с указанными названиями и все связанные с ними книги
        /// </summary>
        /// <param name="categoryNames">Массив названий категорий для удаления</param>
        /// <returns>Результат операции, содержащий количество удаленных категорий и книг</returns>
        Task<(int deletedCategoriesCount, int deletedBooksCount)> DeleteCategoriesByNamesAsync(string[] categoryNames);
        
        /// <summary>
        /// Удаляет все категории с названиями "unknown" и "interested" и связанные с ними книги
        /// </summary>
        /// <returns>Результат операции, содержащий количество удаленных категорий и книг</returns>
        Task<(int deletedCategoriesCount, int deletedBooksCount)> DeleteUnwantedCategoriesAsync();

        /// <summary>
        /// Получает список всех категорий с информацией о количестве книг
        /// </summary>
        /// <returns>Информация о категориях и количестве книг</returns>
        Task<IEnumerable<CategoryInfoDto>> GetAllCategoriesWithBooksCountAsync();
    }
} 