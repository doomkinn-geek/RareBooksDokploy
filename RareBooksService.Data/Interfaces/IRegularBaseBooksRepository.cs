﻿using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Data.Interfaces
{
    public interface IRegularBaseBooksRepository
    {
        Task<PagedResultDto<BookSearchResultDto>> GetBooksByTitleAsync(string title, int page, int pageSize, bool exactPhrase = false, List<int>? categoryIds = null);
        Task<PagedResultDto<BookSearchResultDto>> GetBooksByDescriptionAsync(string description, int page, int pageSize, bool exactPhrase = false, List<int>? categoryIds = null);
        Task<PagedResultDto<BookSearchResultDto>> GetBooksByCategoryAsync(int categoryId, int page, int pageSize);
        Task<PagedResultDto<BookSearchResultDto>> GetBooksByPriceRangeAsync(double minPrice, double maxPrice, int page, int pageSize);
        Task<(int totalFound, List<string> firstTwoTitles)> GetPartialInfoByPriceRangeAsync(double minPrice, double maxPrice);
        Task<PagedResultDto<BookSearchResultDto>> GetBooksBySellerAsync(string sellerName, int page, int pageSize);
        Task<BookDetailDto> GetBookByIdAsync(int id);
        Task<RegularBaseBook> GetBookEntityByIdAsync(int id);
        Task<List<CategoryDto>> GetCategoriesAsync();
        Task<CategoryDto> GetCategoryByIdAsync(int id);
        Task<RegularBaseCategory> GetCategoryEntityByIdAsync(int id);
        Task SaveSearchHistoryAsync(string userId, string query, string searchType);
        
        /// <summary>
        /// Возвращает QueryAble коллекцию книг для создания сложных запросов
        /// </summary>
        IQueryable<RegularBaseBook> GetQueryable();
    }
}
