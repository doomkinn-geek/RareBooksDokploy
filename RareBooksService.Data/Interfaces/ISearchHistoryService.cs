using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Data.Interfaces
{
    public interface ISearchHistoryService
    {
        Task SaveSearchHistory(string userId, string query, string searchType);
    }
}
