using Microsoft.AspNetCore.Mvc;
using System.Linq;

namespace Controllers
{
    public class CategoriesController : Controller
    {
        private readonly IBookRepository _bookRepository;
        private readonly ICategoryRepository _categoryRepository;

        public CategoriesController(IBookRepository bookRepository, ICategoryRepository categoryRepository)
        {
            _bookRepository = bookRepository;
            _categoryRepository = categoryRepository;
        }

        public IActionResult GetCategories()
        {
            // Получаем все книги с SoldQuantity > 0
            var soldBooks = _bookRepository.GetBooks().Where(b => b.SoldQuantity > 0).ToList();
            
            // Получаем все категории
            var allCategories = _categoryRepository.GetAllCategories();
            
            // Формируем список категорий с количеством проданных книг
            var categoriesWithBookCount = allCategories
                .Select(category => new {
                    Id = category.Id,
                    Name = category.Name,
                    BookCount = soldBooks.Count(book => book.CategoryId == category.Id)
                })
                .Where(c => c.BookCount > 0) // Фильтруем только категории с проданными книгами
                .ToList();
            
            return Ok(categoriesWithBookCount);
        }
    }
} 