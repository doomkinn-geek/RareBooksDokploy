using Amazon.Runtime.Internal.Util;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using RareBooksService.Data;
using RareBooksService.Data.Parsing;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Parser.Services
{
    public interface IAuctionService
    {
        Task UpdateCompletedAuctionsAsync(CancellationToken token);
    }
    public class AuctionService : IAuctionService
    {        
        private readonly ILotDataWebService _lotDataService;
        private readonly ILogger<AuctionService> _logger;
        private readonly BooksDbContext _context;

        public AuctionService(ILotDataWebService lotDataService, 
            ILogger<AuctionService> logger,
            BooksDbContext context)
        {
            _lotDataService = lotDataService;
            _logger = logger;
            _context = context;
        }

        //18.12.2024 случайно обнаружил, что финальные цены записываются не в ту базу данных
        //записывается в старую базу SQLite. Меняю так, чтобы данные были заполнены верно.
        public async Task UpdateCompletedAuctionsAsync(CancellationToken token)
        {
            //using (ExtendedBooksContext context = new ExtendedBooksContext())
            //using (RegularBaseBooksContext context = new RegularBaseBooksContext())
            //{
                var booksToUpdate = await _context.BooksInfo
                    .Where(b => b.EndDate < DateTime.UtcNow && b.IsMonitored)
                    .ToListAsync();

                foreach (var book in booksToUpdate)
                {
                    token.ThrowIfCancellationRequested();  // проверка отмены
                    try
                    {
                        var updatedLotData = await _lotDataService.GetLotDataAsync(book.Id);
                        if (updatedLotData != null && updatedLotData.result != null)
                        {
                            if (book.FinalPrice < updatedLotData.result.normalizedPrice)
                            {
                                book.Price = (double)updatedLotData.result.price;
                                book.FinalPrice = updatedLotData.result.normalizedPrice;
                                book.IsMonitored = false;
                                await _context.SaveChangesAsync();
                            }
                        }
                        _logger.LogInformation($"Updated lot {book.Id} with final price {book.FinalPrice}.");
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError("UpdateCompletedAuctionsAsync", ex);
                    }
                }
            //}
        }
    }


}
