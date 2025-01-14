using RareBooksService.Common.Models.FromMeshok;

namespace RareBooksService.Parser.Services
{
    public interface ILotDataWebService
    {
        public Task<BookItemFromMeshok> GetLotDataAsync(int lotId);
        public Task<string> GetBookDescriptionAsync(int lotId);
        public Task<(string, List<int>)> GetLotsListAsync(int categoryId);
    }
    public class LotDataWebService : ILotDataWebService
    {
        private static object excludedCategoryIds;
        private static object searchString;
        private static object timeline;
        private static object condition;
        private static object type;
        private static object quantity;
        private static object priceStart;
        private static object priceEnd;
        private static object properties;
        private static object tags;
        private static object excludedSellers;
        private static object sellerId;
        private static object bidderId;
        private static object soldStatus;
        private static object related;
        private static object fromT;
        private static object endsFromT;
        private static object tillT;
        private static object endsTillT;
        private static object fromD;
        private static object tillD;
        private static object endsFromD;
        private static object endsTillD;
        private static object standardDescriptionId;

        private readonly HttpClientService _httpClientService;

        private const string GetLotByIdUrl = "https://meshok.net/api/command/lots/get-lot-by-id";
        private const string GetLotDescriptionUrl = $"https://meshok.net/api/command/lots/get-description";
        private const string GetLotsListUrl = "https://meshok.net/api/command/lots/get-items";

        private int _requestCount = 0;
        private const int RequestsBeforeRenew = 30; // N запросов перед обновлением cookies

        public LotDataWebService()
        {
            _httpClientService = new HttpClientService();
        }
        private async Task RenewCookiesIfNeeded()
        {
            _requestCount++;
            if (_requestCount >= RequestsBeforeRenew)
            {                
                await _httpClientService.FetchInitialCookies(); // Обновление cookies
                _requestCount = 0; // Сброс счётчика запросов
            }
        }
        public async Task<BookItemFromMeshok> GetLotDataAsync(int lotId)
        {
            await RenewCookiesIfNeeded();
            try
            {
                await _httpClientService.EnsureInitializedAsync();
                return await _httpClientService.PostAsync<BookItemFromMeshok>(GetLotByIdUrl, new { lotId = lotId });
            }
            catch (TimeoutException ex)
            {
                Console.WriteLine($"TimeoutException for lotId {lotId}: {ex.Message}");
                // Обработка или повторная попытка может быть реализована здесь, если нужно
                return null;
            }
            catch (HttpRequestException ex)
            {
                Console.WriteLine($"HttpRequestException for lotId {lotId}: {ex.Message}");
                // Обработка или повторная попытка может быть реализована здесь, если нужно
                return null;
            }
        }
        public async Task<string> GetBookDescriptionAsync(int lotId)
        {
            await RenewCookiesIfNeeded();
            try
            {
                await _httpClientService.EnsureInitializedAsync();
                var descriptionObject = await _httpClientService.PostAsync<MeshokLotDescription>(GetLotDescriptionUrl, new { lotId = lotId });
                return descriptionObject?.result.description;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error getting description for lotId {lotId}: {ex.Message}");
                return string.Empty;
            }
        }
        public async Task<(string, List<int>)> GetLotsListAsync(int categoryId)
        {
            await RenewCookiesIfNeeded();

            string categoryName = "";
            List<int> allLotIds = new List<int>();
            int page = 1;
            const int pageSize = 200;

            while (true)
            {
                var filter = new
                {
                    categoryId = categoryId,
                    excludedCategoryIds,
                    searchString,
                    status = "active",
                    showOnly = new string[] { "allForCoin" },
                    timeline,
                    location = new { cityId = 32, option = "all", freeDelivery = false, economyDelivery = false, pickup = false },
                    condition,
                    type,
                    priceStart,
                    priceEnd,
                    quantity,
                    properties,
                    tags,
                    excludedSellers,
                    sellerId,
                    bidderId,
                    related,
                    soldStatus,
                    fromT,
                    tillT,
                    endsFromT,
                    endsTillT,
                    fromD,
                    tillD,
                    endsFromD,
                    endsTillD,
                    standardDescriptionId,
                    page = page,
                    pageSize = pageSize,
                    sort = new { field = "endDate", direction = 0 }
                };

                var requestBody = new
                {
                    sellerMode = false,
                    filter = filter,
                    includes = new { lots = true, stats = true },
                    saveSearchRequest = false,
                    featuredLotsFirst = true,
                    onlyWithPicture = false
                };

                try
                {
                    await _httpClientService.EnsureInitializedAsync();
                    var lotsResponse = await _httpClientService.PostAsync<LotsParsedFromMeshok>(GetLotsListUrl, requestBody);

                    if (lotsResponse != null && lotsResponse.result.lots.Any())
                    {
                        if (page == 1)
                        {
                            categoryName = lotsResponse.result.stats.categories[2]?.name ?? "";
                        }

                        allLotIds.AddRange(lotsResponse.result.lots.Select(lot => lot.id));
                        page++;
                    }
                    else
                    {
                        break; // Выход из цикла, если страницы закончились или не удалось получить данные
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error fetching lots list on page {page}: {ex.Message}");
                    break; // Или можете реализовать повторные попытки
                }
            }

            return (categoryName, allLotIds);
        }
    }
}
