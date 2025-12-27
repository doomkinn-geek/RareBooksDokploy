using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RareBooksService.Data.Interfaces;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme, Roles = "Admin")]
    public class CategoryCleanupController : ControllerBase
    {
        private readonly ICategoryCleanupService _categoryCleanupService;

        public CategoryCleanupController(ICategoryCleanupService categoryCleanupService)
        {
            _categoryCleanupService = categoryCleanupService;
        }

        /// <summary>
        /// Анализирует количество категорий и книг, которые будут удалены, по указанным названиям категорий
        /// </summary>
        /// <param name="categoryNames">Массив названий категорий для анализа</param>
        /// <returns>Информация о количестве категорий и книг, которые будут удалены</returns>
        [HttpPost("analyze")]
        public async Task<IActionResult> AnalyzeCategoriesByNames([FromBody] string[] categoryNames)
        {
            if (categoryNames == null || categoryNames.Length == 0)
            {
                return BadRequest("Необходимо указать хотя бы одно название категории для анализа");
            }

            var result = await _categoryCleanupService.CountCategoriesAndBooksByNamesAsync(categoryNames);

            return Ok(new
            {
                categoriesCount = result.categoriesCount,
                booksCount = result.booksCount,
                categoryIds = result.categoryIds,
                message = $"Будет удалено категорий: {result.categoriesCount}, книг: {result.booksCount}"
            });
        }

        /// <summary>
        /// Анализирует количество "нежелательных" категорий и книг, которые будут удалены
        /// </summary>
        /// <returns>Информация о количестве категорий и книг, которые будут удалены</returns>
        [HttpGet("analyze-unwanted")]
        public async Task<IActionResult> AnalyzeUnwantedCategories()
        {
            var result = await _categoryCleanupService.CountUnwantedCategoriesAndBooksAsync();

            return Ok(new
            {
                categoriesCount = result.categoriesCount,
                booksCount = result.booksCount,
                categoryIds = result.categoryIds,
                message = $"Будет удалено нежелательных категорий: {result.categoriesCount}, книг: {result.booksCount}"
            });
        }

        /// <summary>
        /// Удаляет категории с указанными названиями и все связанные с ними книги
        /// </summary>
        /// <param name="categoryNames">Массив названий категорий для удаления</param>
        /// <returns>Результат операции, содержащий количество удаленных категорий и книг</returns>
        [HttpDelete("byNames")]
        public async Task<IActionResult> DeleteCategoriesByNames([FromBody] string[] categoryNames)
        {
            if (categoryNames == null || categoryNames.Length == 0)
            {
                return BadRequest("Необходимо указать хотя бы одно название категории для удаления");
            }

            // Сначала выполняем анализ, чтобы показать администратору, что будет удалено
            var analysisResult = await _categoryCleanupService.CountCategoriesAndBooksByNamesAsync(categoryNames);

            if (analysisResult.categoriesCount == 0)
            {
                return NotFound($"Категории с названиями {string.Join(", ", categoryNames)} не найдены");
            }

            var result = await _categoryCleanupService.DeleteCategoriesByNamesAsync(categoryNames);

            return Ok(new
            {
                deletedCategoriesCount = result.deletedCategoriesCount,
                deletedBooksCount = result.deletedBooksCount,
                message = $"Успешно удалено категорий: {result.deletedCategoriesCount}, книг: {result.deletedBooksCount}"
            });
        }

        /// <summary>
        /// Удаляет все категории с названиями "unknown" и "interested" и связанные с ними книги
        /// </summary>
        /// <returns>Результат операции, содержащий количество удаленных категорий и книг</returns>
        [HttpDelete("unwanted")]
        public async Task<IActionResult> DeleteUnwantedCategories()
        {
            // Сначала выполняем анализ, чтобы показать администратору, что будет удалено
            var analysisResult = await _categoryCleanupService.CountUnwantedCategoriesAndBooksAsync();

            if (analysisResult.categoriesCount == 0)
            {
                return NotFound("Нежелательные категории не найдены");
            }

            var result = await _categoryCleanupService.DeleteUnwantedCategoriesAsync();

            return Ok(new
            {
                deletedCategoriesCount = result.deletedCategoriesCount,
                deletedBooksCount = result.deletedBooksCount,
                message = $"Успешно удалено нежелательных категорий: {result.deletedCategoriesCount}, книг: {result.deletedBooksCount}"
            });
        }

        /// <summary>
        /// Получает список всех категорий с информацией о количестве книг
        /// </summary>
        /// <returns>Список категорий с информацией о количестве книг</returns>
        [HttpGet("categories")]
        public async Task<IActionResult> GetAllCategories()
        {
            var categories = await _categoryCleanupService.GetAllCategoriesWithBooksCountAsync();
            return Ok(categories);
        }
    }
}