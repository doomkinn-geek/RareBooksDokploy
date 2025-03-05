using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data;
using RareBooksService.Data.Interfaces;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CategoriesController : ControllerBase
    {
        private readonly IRegularBaseBooksRepository _booksRepository;
        private readonly ILogger<CategoriesController> _logger;

        public CategoriesController(IRegularBaseBooksRepository booksRepository, ILogger<CategoriesController> logger)
        {
            _booksRepository = booksRepository;
            _logger = logger;
        }

        [HttpGet]
        public async Task<ActionResult<List<CategoryDto>>> GetCategories()
        {
            try
            {
                _logger.LogInformation("Начало запроса GetCategories");
                var stopwatch = Stopwatch.StartNew();

                _logger.LogInformation("Выполняем вызов _booksRepository.GetCategoriesAsync()");
                var categories = await _booksRepository.GetCategoriesAsync();
                
                stopwatch.Stop();
                _logger.LogInformation("Запрос GetCategories выполнен успешно. Получено {count} категорий. Время выполнения: {elapsed}мс", 
                    categories?.Count ?? 0, stopwatch.ElapsedMilliseconds);
                
                return Ok(categories);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Критическая ошибка в методе GetCategories: {Message}", ex.Message);
                
                // Логируем дополнительную информацию для отладки
                if (ex.InnerException != null)
                {
                    _logger.LogError("Inner Exception: {InnerException}", ex.InnerException.Message);
                    _logger.LogError("Inner Exception Stack Trace: {StackTrace}", ex.InnerException.StackTrace);
                }

                _logger.LogError("Stack Trace: {StackTrace}", ex.StackTrace);
                
                // Пытаемся получить и залогировать информацию о состоянии БД
                try
                {
                    _logger.LogWarning("Проверяем доступность репозитория и БД");
                    var repoAvailable = _booksRepository != null;
                    _logger.LogInformation("Репозиторий доступен: {available}", repoAvailable);
                }
                catch (Exception dbEx)
                {
                    _logger.LogError(dbEx, "Ошибка при проверке состояния репозитория: {Message}", dbEx.Message);
                }

                // Возвращаем стандартную ошибку 500 с подробной информацией
                return StatusCode(500, new 
                { 
                    error = "Произошла критическая ошибка при получении категорий",
                    message = ex.Message,
                    stackTrace = ex.StackTrace
                });
            }
        }
    }
}
