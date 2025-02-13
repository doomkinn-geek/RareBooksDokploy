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
        private readonly ILotDataHandler _lotHandler;
        private readonly BooksDbContext _context;

        public AuctionService(ILotDataWebService lotDataService, 
            ILogger<AuctionService> logger,
            BooksDbContext context,
            ILotDataHandler lotHandler)
        {
            _lotDataService = lotDataService;
            _logger = logger;
            _context = context;
            _lotHandler = lotHandler;
        }

        //18.12.2024 случайно обнаружил, что финальные цены записываются не в ту базу данных
        //записывается в старую базу SQLite. Меняю так, чтобы данные были заполнены верно.
        /*public async Task UpdateCompletedAuctionsAsync(CancellationToken token)
        {            
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
        }*/

        public async Task UpdateCompletedAuctionsAsync(CancellationToken token)
        {
            var booksToUpdate = await _context.BooksInfo
                .Where(b => b.EndDate < DateTime.UtcNow && b.IsMonitored)
                .ToListAsync();

            foreach (var book in booksToUpdate)
            {
                token.ThrowIfCancellationRequested();  // проверка отмены из вне, если нужно
                try
                {
                    // Получаем актуальные данные о лоте
                    var updatedLotData = await _lotDataService.GetLotDataAsync(book.Id);
                    if (updatedLotData?.result != null)
                    {
                        // Здесь делаем полный апдейт через LotDataHandler.
                        //   1) Передаём полученный MeshokBook
                        //   2) Указываем categoryId (из самого лота)
                        //   3) Ставим downloadImages = false (т.к. аукцион завершён, заново качать изображения обычно не требуется,
                        //      но при желании можно поставить true)
                        //   4) Флаг малоценности (isLessValuableLot) возьмём из текущего объекта, чтобы не потерять
                        //      уже установленную в БД отметку.
                        await _lotHandler.SaveLotDataAsync(
                            lotData: updatedLotData.result,
                            categoryId: updatedLotData.result.categoryId,
                            categoryName: "unknown",
                            downloadImages: false,
                            isLessValuableLot: book.IsLessValuable
                        );

                        // Так как аукцион завершился, сбрасываем мониторинг
                        book.IsMonitored = false;

                        // Дополнительно, если хочется явно зафиксировать «финальную» цену в БД,
                        // даже если она не выросла, можно сделать так:
                        if (updatedLotData.result.normalizedPrice.HasValue)
                        {
                            book.FinalPrice = updatedLotData.result.normalizedPrice.Value;
                        }

                        await _context.SaveChangesAsync();

                        _logger.LogInformation($"[UpdateCompletedAuctionsAsync] Updated lot {book.Id} with final price {book.FinalPrice}.");
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "UpdateCompletedAuctionsAsync: ошибка при обновлении лота {LotId}", book.Id);
                }
            }
        }

    }


}
