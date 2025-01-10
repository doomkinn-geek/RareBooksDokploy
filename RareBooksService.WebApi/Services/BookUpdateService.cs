using RareBooksService.Parser.Services;

namespace RareBooksService.WebApi.Services
{
    public class BookUpdateService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<BookUpdateService> _logger;

        public BookUpdateService(IServiceProvider serviceProvider,
            ILogger<BookUpdateService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            // Run the task once immediately on startup
            await UpdateBooksAsync();

            // Schedule the task to run daily
            while (!stoppingToken.IsCancellationRequested)
            {
                var nextRunTime = DateTime.UtcNow.Date.AddDays(3).AddHours(0); // Midnight UTC next day
                var delay = nextRunTime - DateTime.UtcNow;

                if (delay < TimeSpan.Zero)
                    delay = TimeSpan.Zero;

                await Task.Delay(delay, stoppingToken);

                if (!stoppingToken.IsCancellationRequested)
                {
                    await UpdateBooksAsync();
                }
            }
        }

        private async Task UpdateBooksAsync()
        {
            using (var scope = _serviceProvider.CreateScope())
            {
                var lotFetchingService = scope.ServiceProvider.GetRequiredService<ILotFetchingService>();
                var auctionService = scope.ServiceProvider.GetRequiredService<IAuctionService>();

                try
                {
                    // Fetch new data
                    await lotFetchingService.FetchAllNewData();

                    // Update completed auctions
                    await auctionService.UpdateCompletedAuctionsAsync();

                    await lotFetchingService.FetchSoldFixedPriceLotsAsync();
                }
                catch (Exception ex)
                {
                    //var errorHandler = scope.ServiceProvider.GetRequiredService<IErrorHandler>();
                    //errorHandler.HandleError(ex);
                    _logger.LogError("ошибка получения новых данных с meshok.net", ex);
                }
            }
        }
    }
}
