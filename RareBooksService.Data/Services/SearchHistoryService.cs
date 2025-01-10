using RareBooksService.Data.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Data.Services
{
    public class SearchHistoryService : ISearchHistoryService
    {
        private readonly IRegularBaseBooksRepository _booksRepository;

        public SearchHistoryService(IRegularBaseBooksRepository booksRepository)
        {
            _booksRepository = booksRepository;
        }

        public async Task SaveSearchHistory(string userId, string query, string searchType)
        {
            await _booksRepository.SaveSearchHistoryAsync(userId, query, searchType);
        }
    }
}
