using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data.Interfaces;
using RareBooksService.WebApi.Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class StatisticsController : BaseController
    {
        private readonly IRegularBaseBooksRepository _booksRepository;
        private readonly ISubscriptionService _subscriptionService;
        private readonly ILogger<StatisticsController> _logger;

        public StatisticsController(
            IRegularBaseBooksRepository booksRepository,
            ISubscriptionService subscriptionService,
            UserManager<ApplicationUser> userManager,
            ILogger<StatisticsController> logger) : base(userManager)
        {
            _booksRepository = booksRepository;
            _subscriptionService = subscriptionService;
            _logger = logger;
        }

        /// <summary>
        /// Возвращает статистику цен книг, опционально по категории
        /// </summary>
        [HttpGet("prices")]
        public async Task<ActionResult<PriceStatisticsDto>> GetPriceStatistics([FromQuery] int? categoryId = null)
        {
            try
            {
                _logger.LogInformation("Получение статистики цен. CategoryId: {CategoryId}", categoryId);
                
                var user = await GetCurrentUserAsync();
                if (user == null)
                {
                    _logger.LogWarning("Unauthorized access attempt to price statistics");
                    return Unauthorized();
                }

                // Проверка подписки
                var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
                bool hasSubscription = (subDto != null && subDto.IsActive);
                if (!hasSubscription)
                {
                    _logger.LogWarning("User {UserId} attempted to access price statistics without an active subscription", user.Id);
                    return Unauthorized(new { message = "Требуется активная подписка для доступа к статистике цен" });
                }

                _logger.LogInformation("Формирование статистики цен для пользователя {UserId}", user.Id);
                
                var statistics = new PriceStatisticsDto();
                
                // Получаем книги с учетом фильтра по категории
                var query = _booksRepository.GetQueryable();
                if (categoryId.HasValue)
                {
                    _logger.LogDebug("Применение фильтра по категории: {CategoryId}", categoryId.Value);
                    query = query.Where(b => b.CategoryId == categoryId.Value);
                }

                // Только книги с указанной финальной ценой
                query = query.Where(b => b.FinalPrice.HasValue && b.FinalPrice.Value > 0);
                
                _logger.LogDebug("Выполнение запроса к базе данных");
                var books = await query.ToListAsync();
                
                _logger.LogInformation("Получено {Count} книг для расчета статистики", books.Count);
                
                if (books.Any())
                {
                    // Рассчитываем базовую статистику
                    var prices = books.Select(b => b.FinalPrice.Value).ToList();
                    statistics.AveragePrice = prices.Average();
                    statistics.MedianPrice = CalculateMedian(prices);
                    statistics.MaxPrice = prices.Max();
                    statistics.MinPrice = prices.Min();
                    statistics.TotalBooks = books.Count;
                    statistics.TotalSales = books.Count(b => b.FinalPrice.HasValue && b.Status == 2); // Предполагаем, что Status 2 означает "продано"
                    
                    // Расчет диапазонов цен
                    statistics.PriceRanges = CalculatePriceRanges(prices);
                    
                    // Расчет средних цен по категориям
                    if (!categoryId.HasValue)
                    {
                        _logger.LogDebug("Расчет средних цен по всем категориям");
                        statistics.CategoryAveragePrices = await CalculateCategoryAveragePrices();
                    }
                    
                    _logger.LogInformation("Статистика цен успешно рассчитана. AveragePrice: {AveragePrice}, MedianPrice: {MedianPrice}",
                        statistics.AveragePrice, statistics.MedianPrice);
                }
                else
                {
                    _logger.LogWarning("Не найдено данных для расчета статистики цен");
                }
                
                return Ok(statistics);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении статистики цен: {Message}", ex.Message);
                if (ex.InnerException != null)
                {
                    _logger.LogError("Inner Exception: {InnerMessage}", ex.InnerException.Message);
                }
                
                return StatusCode(500, new { error = "Ошибка при получении статистики цен", message = ex.Message });
            }
        }
        
        /// <summary>
        /// Вспомогательный метод для вычисления медианы
        /// </summary>
        private double CalculateMedian(List<double> values)
        {
            var sortedValues = values.OrderBy(v => v).ToList();
            int count = sortedValues.Count;
            
            if (count == 0)
                return 0;
                
            if (count % 2 == 0)
            {
                // Четное количество - берем среднее двух средних значений
                return (sortedValues[count / 2 - 1] + sortedValues[count / 2]) / 2;
            }
            else
            {
                // Нечетное количество - берем среднее значение
                return sortedValues[count / 2];
            }
        }
        
        /// <summary>
        /// Рассчитывает распределение книг по ценовым диапазонам
        /// </summary>
        private Dictionary<string, int> CalculatePriceRanges(List<double> prices)
        {
            var ranges = new Dictionary<string, int>
            {
                { "0-1000", 0 },
                { "1000-5000", 0 },
                { "5000-10000", 0 },
                { "10000-50000", 0 },
                { "50000+", 0 }
            };
            
            foreach (var price in prices)
            {
                if (price < 1000) ranges["0-1000"]++;
                else if (price < 5000) ranges["1000-5000"]++;
                else if (price < 10000) ranges["5000-10000"]++;
                else if (price < 50000) ranges["10000-50000"]++;
                else ranges["50000+"]++;
            }
            
            return ranges;
        }
        
        /// <summary>
        /// Рассчитывает средние цены по категориям
        /// </summary>
        private async Task<Dictionary<string, double>> CalculateCategoryAveragePrices()
        {
            var result = new Dictionary<string, double>();
            
            try
            {
                var categoriesWithPrices = await _booksRepository.GetQueryable()
                    .Where(b => b.FinalPrice.HasValue && b.FinalPrice.Value > 0)
                    .GroupBy(b => b.CategoryId)
                    .Select(g => new 
                    {
                        CategoryId = g.Key,
                        AveragePrice = g.Average(b => b.FinalPrice.Value)
                    })
                    .ToListAsync();
                    
                foreach (var item in categoriesWithPrices)
                {
                    var category = await _booksRepository.GetCategoryByIdAsync(item.CategoryId);
                    if (category != null)
                    {
                        result[category.Name] = item.AveragePrice;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при расчете средних цен по категориям: {Message}", ex.Message);
            }
            
            return result;
        }
    }
} 