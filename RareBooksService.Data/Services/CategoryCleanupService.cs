using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace RareBooksService.Data.Services
{
    /// <summary>
    /// Сервис для очистки нежелательных категорий и связанных с ними книг
    /// </summary>
    public class CategoryCleanupService : ICategoryCleanupService
    {
        private readonly BooksDbContext _context;
        private readonly ILogger<CategoryCleanupService> _logger;
        private readonly string[] _unwantedCategoryNames = { "unknown", "interested" };

        public CategoryCleanupService(BooksDbContext context, ILogger<CategoryCleanupService> logger)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        /// <summary>
        /// Подсчитывает количество категорий и книг, которые будут удалены
        /// </summary>
        public async Task<(int categoriesCount, int booksCount, int[] categoryIds)> CountCategoriesAndBooksByNamesAsync(string[] categoryNames)
        {
            if (categoryNames == null || !categoryNames.Any())
            {
                _logger.LogWarning("Не указаны названия категорий для анализа");
                return (0, 0, Array.Empty<int>());
            }

            try
            {
                _logger.LogInformation($"Анализ категорий: {string.Join(", ", categoryNames)}");

                // Находим все категории с указанными именами (включая дубликаты)
                var categories = await _context.Categories
                    .Where(c => categoryNames.Contains(c.Name))
                    .Select(c => new
                    {
                        c.Id,
                        c.Name,
                        BooksCount = c.Books.Count
                    })
                    .ToListAsync();

                if (!categories.Any())
                {
                    _logger.LogInformation("Категории с указанными названиями не найдены");
                    return (0, 0, Array.Empty<int>());
                }

                // Группируем категории по имени для подсчета дубликатов
                var categoryGroups = categories.GroupBy(c => c.Name).ToList();
                foreach (var group in categoryGroups.Where(g => g.Count() > 1))
                {
                    _logger.LogWarning($"Найдено {group.Count()} категорий с именем '{group.Key}'");
                }

                int totalBooksCount = categories.Sum(c => c.BooksCount);
                int[] categoryIds = categories.Select(c => c.Id).ToArray();

                // Выводим детальную информацию по каждой категории
                foreach (var category in categories)
                {
                    _logger.LogInformation($"Категория '{category.Name}' (ID: {category.Id}) содержит {category.BooksCount} книг");
                }

                _logger.LogInformation($"Всего: {categories.Count} категорий, {totalBooksCount} книг");
                return (categories.Count, totalBooksCount, categoryIds);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при анализе категорий");
                throw;
            }
        }

        /// <summary>
        /// Подсчитывает количество "нежелательных" категорий и книг, которые будут удалены
        /// </summary>
        public async Task<(int categoriesCount, int booksCount, int[] categoryIds)> CountUnwantedCategoriesAndBooksAsync()
        {
            _logger.LogInformation($"Анализ нежелательных категорий: {string.Join(", ", _unwantedCategoryNames)}");
            return await CountCategoriesAndBooksByNamesAsync(_unwantedCategoryNames);
        }

        /// <summary>
        /// Удаляет категории с указанными названиями и все связанные с ними книги
        /// </summary>
        public async Task<(int deletedCategoriesCount, int deletedBooksCount)> DeleteCategoriesByNamesAsync(string[] categoryNames)
        {
            if (categoryNames == null || !categoryNames.Any())
            {
                _logger.LogWarning("Не указаны названия категорий для удаления");
                return (0, 0);
            }

            try
            {
                _logger.LogInformation($"Начало удаления категорий: {string.Join(", ", categoryNames)}");

                // Сначала выполняем анализ, чтобы получить количество категорий и книг
                var analysisResult = await CountCategoriesAndBooksByNamesAsync(categoryNames);

                if (analysisResult.categoriesCount == 0)
                {
                    return (0, 0);
                }

                // Находим все категории с указанными именами (включая дубликаты)
                var categoriesToDelete = await _context.Categories
                    .Where(c => categoryNames.Contains(c.Name))
                    .Include(c => c.Books)
                    .ToListAsync();

                // Группируем категории по имени для логирования дубликатов
                var categoryGroups = categoriesToDelete.GroupBy(c => c.Name).ToList();
                foreach (var group in categoryGroups.Where(g => g.Count() > 1))
                {
                    _logger.LogWarning($"Удаляется {group.Count()} категорий с именем '{group.Key}'");
                }

                // Удаляем книги из каждой категории
                foreach (var category in categoriesToDelete)
                {
                    _logger.LogInformation($"Удаление категории '{category.Name}' (ID: {category.Id}) с {category.Books.Count} книгами");

                    // Удаляем книги для данной категории
                    _context.BooksInfo.RemoveRange(category.Books);
                }

                // Удаляем сами категории
                _context.Categories.RemoveRange(categoriesToDelete);

                // Сохраняем изменения в базе данных
                await _context.SaveChangesAsync();

                _logger.LogInformation($"Успешно удалено {categoriesToDelete.Count} категорий и {analysisResult.booksCount} книг");
                return (categoriesToDelete.Count, analysisResult.booksCount);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при удалении категорий");
                throw;
            }
        }

        /// <summary>
        /// Удаляет все категории с названиями "unknown" и "interested" и связанные с ними книги
        /// </summary>
        /// <returns>Результат операции, содержащий количество удаленных категорий и книг</returns>
        public async Task<(int deletedCategoriesCount, int deletedBooksCount)> DeleteUnwantedCategoriesAsync()
        {
            _logger.LogInformation($"Запуск удаления нежелательных категорий: {string.Join(", ", _unwantedCategoryNames)}");
            return await DeleteCategoriesByNamesAsync(_unwantedCategoryNames);
        }

        /// <summary>
        /// Получает список всех категорий с информацией о количестве книг
        /// </summary>
        /// <returns>Информация о категориях и количестве книг</returns>
        public async Task<IEnumerable<CategoryInfoDto>> GetAllCategoriesWithBooksCountAsync()
        {
            try
            {
                _logger.LogInformation("Запрос списка всех категорий с количеством книг");

                var categories = await _context.Categories
                    .Select(c => new CategoryInfoDto
                    {
                        Id = c.Id,
                        Name = c.Name,
                        BooksCount = c.Books.Count,
                        UniqueBooksCount = c.Books.Select(b => b.Id).Distinct().Count(),
                        /*ExclusiveBooksCount = c.Books.Count(b => b.Category?.Count == 1),*/
                        IsUnwanted = _unwantedCategoryNames.Contains(c.Name),
                        /*CreatedDate = c.CreatedDate,
                        LastUpdatedDate = c.LastUpdatedDate,*/
                        DuplicateCount = _context.Categories.Count(other => other.Name == c.Name)
                    })
                    .OrderBy(c => c.Name)
                    .ToListAsync();

                // Помечаем дубликаты
                var duplicateGroups = categories
                    .GroupBy(c => c.Name)
                    .Where(g => g.Count() > 1)
                    .ToList();

                foreach (var group in duplicateGroups)
                {
                    foreach (var category in group)
                    {
                        category.HasDuplicates = true;
                        category.DuplicateCount = group.Count();
                    }

                    _logger.LogWarning($"Категория '{group.Key}' имеет {group.Count()} дубликатов");
                }

                _logger.LogInformation($"Получено {categories.Count} категорий");
                if (duplicateGroups.Any())
                {
                    _logger.LogWarning($"Найдено {duplicateGroups.Count} групп категорий с дубликатами");
                }

                return categories;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении списка категорий");
                throw;
            }
        }
    }
}