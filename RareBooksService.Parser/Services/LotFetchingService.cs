using AutoMapper;
using Newtonsoft.Json;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Data;
using RareBooksService.Common.Models.FromMeshok;

namespace RareBooksService.Parser.Services
{
    public interface ILotFetchingService
    {
        Task FetchFreeListData(List<int> ids);
        Task FetchAllNewData(CancellationToken token);
        Task FetchAllOldDataExtended(int groupNumber);
        Task FetchAllOldDataWithLetterGroup(char groupLetter);
        Task FetchSoldFixedPriceLotsAsync(CancellationToken token);
    }

    public class LotFetchingService : ILotFetchingService
    {
        private readonly ILotDataWebService _lotDataService;
        private readonly ILotDataHandler _lotDataHandler;
        private readonly IMapper _mapper;
        private readonly ILogger<LotFetchingService> _logger;
        private readonly RegularBaseBooksContext _context;

        private static readonly string LastProcessedFixedPriceIdFilePath = "lastProcessedFixedPriceId.txt";
        private static readonly string LastProcessedIdFilePath = "lastProcessedId.txt";
        private static readonly List<int> InterestedCategories = new List<int> { 13870, 13871, 13872, 13873 };
        private static readonly List<int> SovietCategories = new List<int> { 13874, 13875, 13876 };

        public delegate void ProgressChangedHandler(int currentLotId, string? currentTitle);
        public event ProgressChangedHandler ProgressChanged;

        private Func<bool>? _checkCancellationFunc;

        public LotFetchingService(
            ILotDataWebService lotDataService,
            ILotDataHandler lotDataHandler,
            IMapper mapper,
            ILogger<LotFetchingService> logger,
            RegularBaseBooksContext context)
        {
            _lotDataService = lotDataService;
            _lotDataHandler = lotDataHandler;
            _mapper = mapper;
            _logger = logger;
            _context = context;

            // Подписываемся на событие LotDataHandler
            _lotDataHandler.ProgressChanged += OnLotDataHandlerProgressChanged;
        }

        public void SetCancellationCheckFunc(Func<bool>? fn)
        {
            _checkCancellationFunc = fn;
        }

        private void OnLotDataHandlerProgressChanged(int lotId, string message)
        {
            // Здесь мы можем вызвать свое событие ProgressChanged (что уже есть в LotFetchingService),
            // чтобы BookUpdateService мог слушать общий прогресс.
            ProgressChanged?.Invoke(lotId, message);
        }

        private void OnProgressChanged(int currentLotId)
        {
            ProgressChanged?.Invoke(currentLotId, "");
            //_logger.LogInformation("Progress updated: currentLotId = {LotId}", currentLotId);
            Console.Title = $"Processing lot: {currentLotId}";
        }

        // Новый метод для загрузки проданных лотов с фиксированной ценой
        public async Task FetchSoldFixedPriceLotsAsync(CancellationToken token)
        {
            _logger.LogInformation("Начинаем загрузку проданных лотов с фиксированной ценой.");

            int lastProcessedId = _context.BooksInfo
                    .Where(b => b.Type == "fixedPrice")
                    .OrderByDescending(b => b.Id)
                    .Select(b => b.Id)
                    .FirstOrDefault();
            int lastIdInDB = _context.BooksInfo
                    .OrderByDescending(b  => b.Id)
                    .Select(b => b.Id)
                    .FirstOrDefault();
            int currentId = lastProcessedId + 1;
            //int noDataCount = 0;
            //int noDataLimit = 1000; // Останавливаемся после 1000 подряд отсутствующих лотов

            string nonStandardPricesFilePath = $"extendedNonStandardPrices_Group_NEW.txt";
            string nonStandardPricesSovietFilePath = $"extendedNonStandardPricesSoviet_Group_NEW.txt";

            while (true)
            {
                // сначала проверка внешняя (через token) или внутренняя:
                if (token.IsCancellationRequested || (_checkCancellationFunc?.Invoke() == true))
                {
                    Console.WriteLine("Операция прервана (после завершения предыдущего лота).");
                    break; // выходим из цикла, тем самым останавливая процесс
                }
                try
                {
                    await ProcessLotAsync(currentId++, nonStandardPricesFilePath, nonStandardPricesSovietFilePath);
                    await Task.Delay(25); // Replacing Thread.Sleep

                    if (currentId >= lastIdInDB)
                    {                    
                        break;
                    }

                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Ошибка при обработке лота с ID {LotId}", currentId);
                    currentId++;
                }
            }

            _logger.LogInformation("Завершена загрузка проданных лотов с фиксированной ценой.");
        }

        public async Task FetchAllNewData(CancellationToken token)
        {
            _logger.LogInformation("Starting FetchAllNewData.");

            // Собираем все категории в один список:
            var allCategories = InterestedCategories.Concat(SovietCategories).ToList();

            // Можно вывести общее число категорий (при желании).
            int totalCategories = allCategories.Count;
            int categoryIndex = 0;

            // Для каждой категории получаем список лотов и обрабатываем
            foreach (var categoryId in allCategories)
            {
                // Проверка отмены
                if (token.IsCancellationRequested || (_checkCancellationFunc?.Invoke() == true))
                {
                    Console.WriteLine("Операция прервана (FetchAllNewData).");
                    break;
                }

                categoryIndex++;
                _logger.LogInformation("Fetching lots list for categoryId = {CategoryId} (категория {Index} из {Total})",
                    categoryId, categoryIndex, totalCategories);

                var (categoryName, lotIds) = await _lotDataService.GetLotsListAsync(categoryId);

                _logger.LogInformation("Fetched {LotCount} lots for category '{CategoryName}' (ID: {CategoryId})",
                    lotIds.Count, categoryName, categoryId);

                // Далее обрабатываем лоты (с передачей общего числа лотов и т.д.)
                await FetchAndSaveLotsDataAsync(lotIds, token, categoryName);
            }

            _logger.LogInformation("Completed FetchAllNewData.");
        }


        public async Task FetchFreeListData(List<int> ids)
        {
            _logger.LogInformation("Starting FetchFreeListData with {IdCount} IDs.", ids.Count);

            try
            {
                int counter = 0;
                foreach (int id in ids)
                {
                    counter++;
                    _logger.LogInformation($"Processing lot ID {id}. {counter} OF {ids.Count}");
                    await ProcessLotAsync(id, string.Empty, string.Empty);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching free list data.");
            }

            _logger.LogInformation("Completed FetchFreeListData.");
        }

        public async Task FetchAllOldDataExtended(int groupNumber)
        {
            _logger.LogInformation("Starting FetchAllOldDataExtended for groupNumber = {GroupNumber}", groupNumber);

            int startId = 290000000 + (groupNumber - 1) * 5000000;
            int endId = 290000000 + groupNumber * 5000000 - 1;

            string lastProcessedIdFilePath = $"lastProcessedId_Group_{groupNumber}.txt";
            string nonStandardPricesFilePath = $"extendedNonStandardPrices_Group_{groupNumber}.txt";
            string nonStandardPricesSovietFilePath = $"extendedNonStandardPricesSoviet_Group_{groupNumber}.txt";

            int lastProcessedId = ReadLastProcessedId(lastProcessedIdFilePath);
            if (lastProcessedId == 0) lastProcessedId = startId;
            int currentId = lastProcessedId + 1;

            while (currentId <= endId)
            {
                try
                {
                    _logger.LogInformation("Processing lot ID {LotId}", currentId);

                    await ProcessLotAsync(currentId, nonStandardPricesFilePath, nonStandardPricesSovietFilePath);
                    SaveLastProcessedId(currentId, lastProcessedIdFilePath);

                    currentId++;
                }
                catch (JsonReaderException ex)
                {
                    _logger.LogError(ex, "JSON parsing error for lot ID {LotId}", currentId);
                    currentId++;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error processing lot ID {LotId}", currentId);
                    currentId++;
                }
            }

            _logger.LogInformation("Completed FetchAllOldDataExtended for groupNumber = {GroupNumber}", groupNumber);
        }

        public async Task FetchAllOldDataWithLetterGroup(char groupLetter)
        {
            _logger.LogInformation("Starting FetchAllOldDataWithLetterGroup for groupLetter = {GroupLetter}", groupLetter);

            int startId = 290000000; // Adjust according to your logic
            int endId = 1; // Adjust according to your logic

            string lastProcessedIdFilePath = $"lastProcessedId_Group_{groupLetter}.txt";
            string nonStandardPricesFilePath = $"extendedNonStandardPrices_Group_{groupLetter}.txt";
            string nonStandardPricesSovietFilePath = $"extendedNonStandardPricesSoviet_Group_{groupLetter}.txt";

            int lastProcessedId = ReadLastProcessedId(lastProcessedIdFilePath);
            if (lastProcessedId == 0) lastProcessedId = startId;
            int currentId = lastProcessedId - 1;

            while (currentId >= endId)
            {
                try
                {
                    _logger.LogInformation("Processing lot ID {LotId}", currentId);

                    await ProcessLotAsync(currentId, nonStandardPricesFilePath, nonStandardPricesSovietFilePath);
                    SaveLastProcessedId(currentId, lastProcessedIdFilePath);

                    await Task.Delay(25); // Replacing Thread.Sleep

                    currentId--;
                }
                catch (JsonReaderException ex)
                {
                    _logger.LogError(ex, "JSON parsing error for lot ID {LotId}", currentId);
                    currentId--;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error processing lot ID {LotId}", currentId);
                    currentId--;
                }
            }

            _logger.LogInformation("Completed FetchAllOldDataWithLetterGroup for groupLetter = {GroupLetter}", groupLetter);
        }

        private async Task FetchAndSaveLotsDataAsync(List<int> lotIds, CancellationToken token, string categoryName = "unknown")
        {
            _logger.LogInformation("Fetching and saving data for {LotCount} lots in category '{CategoryName}'",
                lotIds.Count, categoryName);

            int totalLots = lotIds.Count;
            int processedCount = 0;

            foreach (var lotId in lotIds)
            {
                // Проверка отмены
                if (token.IsCancellationRequested || (_checkCancellationFunc?.Invoke() == true))
                {
                    Console.WriteLine("Операция прервана (FetchAndSaveLotsDataAsync).");
                    break;
                }

                processedCount++;

                _logger.LogDebug("Fetching data for lot ID {LotId}", lotId);

                try
                {
                    var queryResult = await _lotDataService.GetLotDataAsync(lotId);
                    if (queryResult != null)
                    {
                        _logger.LogDebug("Saving data for lot ID {LotId}", lotId);

                        await _lotDataHandler.SaveLotDataAsync(
                            queryResult.result,
                            queryResult.result.categoryId,
                            categoryName
                        );
                    }
                    else
                    {
                        _logger.LogWarning("Lot data is null for lot ID {LotId}", lotId);
                    }

                    // Вызов события ProgressChanged: передаём ID и текст для верхнего уровня
                    ProgressChanged?.Invoke(
                        lotId,
                        $"Category '{categoryName}': processed {processedCount} of {totalLots} (lot {lotId})."
                    );
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error fetching and saving data for lot ID {LotId}", lotId);
                }
            }

            _logger.LogInformation("Completed fetching and saving data for category '{CategoryName}'", categoryName);
        }



        private async Task ProcessLotAsync(int lotId,
                                            string nonStandardPricesFilePath = "",
                                            string nonStandardPricesSovietFilePath = "")
        {
            OnProgressChanged(lotId);

            var lotData = await _lotDataService.GetLotDataAsync(lotId);
            if (lotData == null || lotData.result == null)
            {
                // Нет данных
                return;
            }

            // Если категория не относится ни к интересующим, ни к советским — пропускаем
            bool isInterestedCategory = InterestedCategories.Contains(lotData.result.categoryId);
            bool isSovietCategory = SovietCategories.Contains(lotData.result.categoryId);
            if (!isInterestedCategory && !isSovietCategory)
            {
                return;
            }

            // Логика выбора:
            // (A) startPrice >= 1  ИЛИ  (B) статус=2 и soldQuantity>0
            bool meetsMainCondition =
                (lotData.result.startPrice >= 1)
                || (lotData.result.status == 2 && lotData.result.soldQuantity > 0);

            if (!meetsMainCondition)
            {
                // Если не попадает ни под какое условие — пропускаем
                // (при желании можно писать в файл)
                return;
            }

            try
            {
                // ----- Ветка "ИНТЕРЕСУЮЩИЕ ЛОТЫ" (InterestedCategories) ------
                // Всё, что meetsMainCondition => сохраняем как «обычный»
                if (isInterestedCategory)
                {
                    // (при желании — логика записи в файл nonStandardPricesFilePath, если хочется)
                    _logger.LogInformation($"Lot {lotData.result.id}: Found an INTERESTED book '{lotData.result.title}'");

                    // Всё, что подходит под meetsMainCondition => не малоценное => скачиваем и архивируем
                    // => передаём downloadImages = true, isLessValuableLot = false
                    await _lotDataHandler.SaveLotDataAsync(
                        lotData.result,
                        lotData.result.categoryId,
                        categoryName: "interested",
                        downloadImages: true,
                        isLessValuableLot: false
                    );
                }
                // ----- Ветка "СОВЕТСКИЕ ЛОТЫ" (SovietCategories) -------------
                else if (isSovietCategory)
                {
                    // Если цена < 1000 — считаем малоценным
                    bool isLittleValue = (lotData.result.price < 1500);

                    if (isLittleValue)
                    {
                        // Пишем, если нужно, в nonStandardPricesSovietFilePath
                        if (!string.IsNullOrWhiteSpace(nonStandardPricesSovietFilePath))
                        {
                            WriteNonStandardPriceToFile(lotData.result.id, nonStandardPricesSovietFilePath);
                        }

                        _logger.LogInformation($"Lot {lotData.result.id}: SOVIET book <1000 '{lotData.result.title}' (little-value).");

                        // Сохраняем в БД, но без скачивания изображений
                        await _lotDataHandler.SaveLotDataAsync(
                            lotData.result,
                            lotData.result.categoryId,
                            categoryName: "unknown",
                            downloadImages: false,
                            isLessValuableLot: true
                        );
                    }
                    else
                    {
                        _logger.LogInformation($"Lot {lotData.result.id}: SOVIET book >=1000 '{lotData.result.title}'.");

                        // Сохраняем как «обычный» (архивируем)
                        await _lotDataHandler.SaveLotDataAsync(
                            lotData.result,
                            lotData.result.categoryId,
                            categoryName: "unknown",
                            downloadImages: true,
                            isLessValuableLot: false
                        );
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing lot ID {LotId}", lotId);
            }
        }


        private void WriteNonStandardPriceToFile(int lotId, string filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath))
            {
                _logger.LogDebug("File path is empty. Skipping writing non-standard price for lot ID {LotId}", lotId);
                return;
            }

            try
            {
                using (StreamWriter writer = new StreamWriter(filePath, true))
                {
                    writer.WriteLine(lotId);
                }

                _logger.LogInformation("Written lot ID {LotId} to file '{FilePath}'", lotId, filePath);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error writing lot ID {LotId} to file '{FilePath}'", lotId, filePath);
            }
        }

        private int ReadLastProcessedId(string filePath)
        {
            try
            {
                if (File.Exists(filePath))
                {
                    var content = File.ReadAllText(filePath);
                    if (int.TryParse(content, out int lastId))
                    {
                        _logger.LogInformation("Read last processed ID {LastId} from file '{FilePath}'", lastId, filePath);
                        return lastId;
                    }
                    else
                    {
                        _logger.LogWarning("Invalid content in file '{FilePath}'. Content: '{Content}'", filePath, content);
                    }
                }
                else
                {
                    _logger.LogInformation("File '{FilePath}' does not exist. Starting from default ID.", filePath);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error reading last processed ID from file '{FilePath}'", filePath);
            }

            return 0;
        }

        private void SaveLastProcessedId(int id, string filePath)
        {
            try
            {
                File.WriteAllText(filePath, id.ToString());
                _logger.LogInformation("Saved last processed ID {LastId} to file '{FilePath}'", id, filePath);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error saving last processed ID {LastId} to file '{FilePath}'", id, filePath);
            }
        }
    }
}
