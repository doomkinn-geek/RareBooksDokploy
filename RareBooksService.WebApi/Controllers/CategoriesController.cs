using Microsoft.AspNetCore.Mvc;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data;
using RareBooksService.Data.Interfaces;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CategoriesController : ControllerBase
    {
        private readonly IRegularBaseBooksRepository _booksRepository;

        public CategoriesController(IRegularBaseBooksRepository booksRepository)
        {
            _booksRepository = booksRepository;
        }

        [HttpGet]
        public async Task<ActionResult<List<CategoryDto>>> GetCategories()
        {
            var categories = await _booksRepository.GetCategoriesAsync();
            return Ok(categories);
        }
    }
}
