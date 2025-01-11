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

        public delegate void ProgressChangedHandler(int currentLotId);
        public event ProgressChangedHandler ProgressChanged;

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
        }

        private void OnProgressChanged(int currentLotId)
        {
            ProgressChanged?.Invoke(currentLotId);
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
                token.ThrowIfCancellationRequested();  // проверка отмены
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

            foreach (var categoryId in InterestedCategories.Concat(SovietCategories))
            {
                token.ThrowIfCancellationRequested();  // проверка отмены
                try
                {
                    _logger.LogInformation("Fetching lots list for categoryId = {CategoryId}", categoryId);

                    var (categoryName, lotIds) = await _lotDataService.GetLotsListAsync(categoryId);

                    _logger.LogInformation("Fetched {LotCount} lots for category '{CategoryName}' (ID: {CategoryId})", lotIds.Count, categoryName, categoryId);

                    await FetchAndSaveLotsDataAsync(lotIds, categoryName);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error fetching new data for categoryId = {CategoryId}", categoryId);
                }
            }

            _logger.LogInformation("Completed FetchAllNewData.");
        }

        public async Task FetchFreeListData(List<int> ids)
        {
            _logger.LogInformation("Starting FetchFreeListData with {IdCount} IDs.", ids.Count);

            try
            {
                foreach (int id in ids)
                {
                    _logger.LogInformation("Processing lot ID {LotId}", id);
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

        private async Task FetchAndSaveLotsDataAsync(List<int> lotIds, string categoryName = "unknown")
        {
            _logger.LogInformation("Fetching and saving data for {LotCount} lots in category '{CategoryName}'", lotIds.Count, categoryName);

            foreach (var lotId in lotIds)
            {
                try
                {
                    _logger.LogDebug("Fetching data for lot ID {LotId}", lotId);

                    var queryResult = await _lotDataService.GetLotDataAsync(lotId);
                    if (queryResult != null)
                    {
                        _logger.LogDebug("Saving data for lot ID {LotId}", lotId);

                        await _lotDataHandler.SaveLotDataAsync(queryResult.result, queryResult.result.categoryId, categoryName);
                    }
                    else
                    {
                        _logger.LogWarning("Lot data is null for lot ID {LotId}", lotId);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error fetching and saving data for lot ID {LotId}", lotId);
                }
            }

            _logger.LogInformation("Completed fetching and saving data for category '{CategoryName}'", categoryName);
        }
        

        private async Task ProcessLotAsync(int lotId, string nonStandardPricesFilePath = "", string nonStandardPricesSovietFilePath = "")
        {
            OnProgressChanged(lotId);

            //_logger.LogDebug("Processing lot ID {LotId}", lotId);

            var lotData = await _lotDataService.GetLotDataAsync(lotId);
            if (lotData == null || lotData.result == null)
            {
                //_logger.LogWarning("Lot data is null or result is null for lot ID {LotId}", lotId);
                return;
            }

            if (!SovietCategories.Contains(lotData.result.categoryId) && !InterestedCategories.Contains(lotData.result.categoryId))
            {
                //_logger.LogDebug("Lot ID {LotId} is not in interested categories.", lotId);
                return;
            }

            bool isInterestedCategory = InterestedCategories.Contains(lotData.result.categoryId);
            bool isSovietCategory = SovietCategories.Contains(lotData.result.categoryId);

            try
            {
                if ((lotData.result.startPrice == 1 || (lotData.result.status == 2 && lotData.result.soldQuantity > 0)) && isInterestedCategory)
                {
                    _logger.LogInformation("{LotId} - Found a book '{Title}' in interested category.", lotData.result.id, lotData.result.title);

                    await _lotDataHandler.SaveLotDataAsync(lotData.result, lotData.result.categoryId);

                    await Task.Delay(500); // Replacing Thread.Sleep
                }
                else
                {
                    _logger.LogInformation("**** Found a book '{Title}' not starting from one unit.", lotData.result.title);
                    if (nonStandardPricesFilePath.Trim().Length > 0)
                    {
                        WriteNonStandardPriceToFile(lotData.result.id, nonStandardPricesFilePath);
                    }
                }

                if ((lotData.result.startPrice == 1 && lotData.result.price > 1500) && isSovietCategory)
                {
                    _logger.LogInformation("{LotId} - Found a SOVIET book '{Title}'", lotData.result.id, lotData.result.title);

                    await _lotDataHandler.SaveLotDataAsync(lotData.result, lotData.result.categoryId);

                    await Task.Delay(500); // Replacing Thread.Sleep
                }
                else
                {
                    _logger.LogInformation("**** Found a SOVIET book '{Title}' (other)", lotData.result.title);
                    if (nonStandardPricesSovietFilePath.Trim().Length > 0)
                    {
                        WriteNonStandardPriceToFile(lotData.result.id, nonStandardPricesSovietFilePath);
                    }
                    //await _lotDataHandler.SaveLotDataAsync(lotData.result, lotData.result.categoryId, "unknown",  true, true);
                    //await Task.Delay(100); // Replacing Thread.Sleep
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
