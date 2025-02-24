using AutoMapper;
using Newtonsoft.Json;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Data;
using RareBooksService.Common.Models.FromMeshok;
using System.Net;
using RareBooksService.Common.Models.Interfaces;

namespace RareBooksService.Parser.Services
{
    public interface ILotFetchingService
    {
        Task FetchFreeListData(List<int> ids);
        Task FetchAllNewData(CancellationToken token);
        Task FetchAllOldDataExtended(int groupNumber);
        Task FetchAllOldDataWithLetterGroup(char groupLetter);
        Task FetchSoldFixedPriceLotsAsync(CancellationToken token);
        Task RefreshLotsWithEmptyImageUrlsAsync(CancellationToken token);
        Task UpdateFinishedAuctionsStartPriceOneAsync(CancellationToken token);
        Task UpdateFinishedFixedPriceAsync(CancellationToken token);
    }

    public class LotFetchingService : ILotFetchingService
    {
        private readonly ILotDataWebService _lotDataService;
        private readonly ILotDataHandler _lotDataHandler;
        private readonly IMapper _mapper;
        private readonly ILogger<LotFetchingService> _logger;
        private readonly BooksDbContext _context;

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
            BooksDbContext context)
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
                    .Where(b => b.Type == "fixedPrice")// && b.SoldQuantity > 0) //&& b.EndDate < (DateTime.Now - TimeSpan.FromDays(14)))
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

            int counter = 0;
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
                    counter++;
                    Console.Title = $"{counter} of {lastIdInDB - lastProcessedId}";
                    ProgressChanged?.Invoke(0, $"{counter} of {lastIdInDB - lastProcessedId}");
                    //await Task.Delay(25); // Replacing Thread.Sleep

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

        public async Task UpdateFinishedFixedPriceAsync(CancellationToken token)
        {
            // Выбираем только те книги, у которых тип = "auction", startPrice = 1,
            // аукцион уже закончился (EndDate < DateTime.UtcNow) и при этом IsMonitored ещё = true
            var booksToUpdate = await _context.BooksInfo
                .Where(b => /*b.Type == "fixedPrice"
                            && */b.SoldQuantity == 0
                            && b.BeginDate > (DateTime.UtcNow - TimeSpan.FromDays(30)))
                .ToListAsync();

            int counter = 0;

            foreach (var book in booksToUpdate)
            {
                counter++;
                Console.Title = $"Обработка лота {counter} из {booksToUpdate.Count}";
                ProgressChanged?.Invoke(book.Id, $"Обработка лота {counter} из {booksToUpdate.Count}");
                //if (counter < 48000)
                //    continue;
                // проверка отмены
                token.ThrowIfCancellationRequested();

                try
                {
                    // Запрашиваем актуальные данные по лоту
                    var updatedLotData = await _lotDataService.GetLotDataAsync(book.Id);
                    if (updatedLotData?.result != null)
                    {
                        if (updatedLotData.result.soldQuantity > 0)
                        {
                            // Полный апдейт через SaveLotDataAsync
                            await _lotDataHandler.SaveLotDataAsync(
                                lotData: updatedLotData.result,
                                categoryId: updatedLotData.result.categoryId,
                                categoryName: "unknown",
                                downloadImages: true,
                                isLessValuableLot: book.IsLessValuable
                            );

                            // снимаем с мониторинга
                            /*book.IsMonitored = false;

                            // при необходимости обновляем FinalPrice
                            if (updatedLotData.result.normalizedPrice.HasValue)
                            {
                                book.FinalPrice = updatedLotData.result.normalizedPrice.Value;
                            }

                            await _context.SaveChangesAsync();*/
                            _logger.LogInformation(
                                "[UpdateFinishedAuctionsStartPriceOneAsync] Обновили лот {LotId}, финальная цена = {FinalPrice}.",
                                book.Id,
                                book.FinalPrice);
                        }
                    }

                }
                catch (Exception ex)
                {
                    _logger.LogError(ex,
                        "[UpdateFinishedAuctionsStartPriceOneAsync] Ошибка при обновлении лота {LotId}",
                        book.Id
                    );
                }
            }
        }

        public async Task UpdateFinishedAuctionsStartPriceOneAsync(CancellationToken token)
        {
            // Выбираем только те книги, у которых тип = "auction", startPrice = 1,
            // аукцион уже закончился (EndDate < DateTime.UtcNow) и при этом IsMonitored ещё = true
            var booksToUpdate = await _context.BooksInfo
                .Where(b => b.Type == "auction"
                            && b.SoldQuantity == 0
                            && b.EndDate < DateTime.UtcNow)
                .ToListAsync();

            int counter = 0;

            foreach (var book in booksToUpdate)
            {
                counter++;
                Console.Title = $"Обработка лота {counter} из {booksToUpdate.Count}";
                ProgressChanged?.Invoke(book.Id, $"Обработка лота {counter} из {booksToUpdate.Count}");
                //if (counter < 48000)
                //    continue;
                // проверка отмены
                token.ThrowIfCancellationRequested();

                try
                {
                    // Запрашиваем актуальные данные по лоту
                    var updatedLotData = await _lotDataService.GetLotDataAsync(book.Id);
                    if (updatedLotData?.result != null)
                    {
                        // Полный апдейт через SaveLotDataAsync
                        await _lotDataHandler.SaveLotDataAsync(
                            lotData: updatedLotData.result,
                            categoryId: updatedLotData.result.categoryId,
                            categoryName: "unknown",
                            downloadImages: false,  // обычно повторная закачка картинок не нужна
                            isLessValuableLot: book.IsLessValuable
                        );

                        // снимаем с мониторинга
                        /*book.IsMonitored = false;

                        // при необходимости обновляем FinalPrice
                        if (updatedLotData.result.normalizedPrice.HasValue)
                        {
                            book.FinalPrice = updatedLotData.result.normalizedPrice.Value;
                        }

                        await _context.SaveChangesAsync();*/
                        _logger.LogInformation(
                            "[UpdateFinishedAuctionsStartPriceOneAsync] Обновили лот {LotId}, финальная цена = {FinalPrice}.",
                            book.Id,
                            book.FinalPrice);
                    }
                    
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex,
                        "[UpdateFinishedAuctionsStartPriceOneAsync] Ошибка при обновлении лота {LotId}",
                        book.Id
                    );
                }
            }
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

        public async Task RefreshLotsWithEmptyImageUrlsAsync(CancellationToken token)
        {
            _logger.LogInformation("Начинаем обновление лотов, у которых нет URL изображений.");

            // 1) Собираем список ID лотов у которых пустой список ImageUrls
            var nullUrls = _context.BooksInfo
                // делаем AsNoTracking() или без него — по ситуации, если хотим затем 
                // только вручную обновлять/добавлять
                .AsEnumerable()
                .Where(x => x.ImageUrls != null && x.ImageUrls.Count == 0 && x.SoldQuantity > 0)
                .Select(x => x.Id)
                .ToList();

            _logger.LogInformation("Найдено {Count} лотов с пустым списком изображений.", nullUrls.Count);

            // 2) По каждому ID заново запрашиваем данные и обновляем
            int counter = 0;
            foreach (var lotId in nullUrls)
            {
                counter++;
                try
                {
                    if (token.IsCancellationRequested || (_checkCancellationFunc?.Invoke() == true))
                    {
                        Console.WriteLine("Операция прервана (RefreshLotsWithEmptyImageUrlsAsync).");
                        break;
                    }
                    _logger.LogInformation("Обновляем лот {LotId} ({Current}/{Total})", lotId, counter, nullUrls.Count);

                    // Получаем данные лота
                    var lotResponse = await _lotDataService.GetLotDataAsync(lotId);
                    if (lotResponse?.result == null)
                    {
                        _logger.LogWarning("Не удалось получить данные лота {LotId} (null result)", lotId);
                        continue;
                    }

                    // 3) Сохраняем (или обновляем) через существующий LotDataHandler.
                    //    Обычно внутри SaveLotDataAsync есть логика проверки: если лот уже есть, 
                    //    то делаем апдейт, если нет – создаём новую запись (Upsert).
                    //    Обратите внимание на флаги downloadImages / isLessValuableLot 
                    //    в зависимости от вашей бизнес-логики. 
                    await _lotDataHandler.SaveLotDataAsync(
                        lotResponse.result,
                        lotResponse.result.categoryId,
                        categoryName: "unknown",  // Можно поставить любое служебное имя
                        downloadImages: true,             // Включаем скачивание картинок
                        isLessValuableLot: false          // Или задайте логику, если нужно
                    );
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Ошибка при обновлении лота {LotId}.", lotId);
                }
            }

            _logger.LogInformation("Завершили обновление лотов с пустыми URL изображений.");
        }



        public async Task FetchFreeListData(List<int> ids)
        {
            _logger.LogInformation("Starting FetchFreeListData with {IdCount} IDs.", ids.Count);

            /*List<int> wrongData = _context.BooksInfo
                .Where(x => x.Category.CategoryId == 1847) //&& x.StartPrice == 1)
                .Select(x => x.Id).ToList();

            using (StreamWriter w = new StreamWriter("wrong_data_lots_1847.txt", false, System.Text.Encoding.UTF8))
            {
                foreach (int i in wrongData)
                {                
                    w.WriteLine($"{i}.zip");
                }
            }

            var booksToDelete = _context.BooksInfo
                .Where(x => wrongData.Contains(x.Id))
                .ToList();

            _context.BooksInfo.RemoveRange(booksToDelete);
            await _context.SaveChangesAsync();*/

            //try
            //{

                var nullUrls = _context.BooksInfo
                                .AsEnumerable() // Switch to in-memory LINQ
                                .Where(x => x.ImageUrls != null && x.ImageUrls.Count == 0)
                                .Select(x => x.Id)
                                .ToList();

            //}
            //catch (Exception e)
            //{
            //    int i = 0;
            //}


            try
            {
                int counter = 0;
                foreach (int id in ids)
                {
                    counter++;
                    _logger.LogInformation($"*/*/*/*/*//*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/=========Processing lot ID {id}. {counter} OF {ids.Count}");
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
                    var currentLotInDb = _context.BooksInfo
                        .Where(b => b.Id == lotId)
                        .FirstOrDefault();
                    if (currentLotInDb != null) continue;
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
            var lotData = await _lotDataService.GetLotDataAsync(lotId);
            if (lotData == null || lotData.result == null)
            {
                // Нет данных
                return;
            }

            bool isInterestedCategory = InterestedCategories.Contains(lotData.result.categoryId);
            bool isSovietCategory = SovietCategories.Contains(lotData.result.categoryId);

            // Если категория не относится ни к интересующим, ни к советским — пропускаем
            if (!isInterestedCategory && !isSovietCategory)
            {
                return;
            }

            // ---------------------------------------------------------------
            // Новая ветка: если лот (status == 2) и (soldQuantity == 0),
            // то просто сохраняем в базу, но не скачиваем изображения.
            // ---------------------------------------------------------------
            if (lotData.result.status == 2 && lotData.result.soldQuantity == 0) // <-- добавлено
            {
                _logger.LogInformation(
                    $"Lot {lotData.result.id}: статус=2, но soldQuantity=0. Сохраняем без скачивания изображений."
                );

                // Сохраняем в БД (downloadImages = false)
                await _lotDataHandler.SaveLotDataAsync(
                    lotData.result,
                    lotData.result.categoryId,
                    categoryName: isInterestedCategory ? "interested" : "unknown",
                    downloadImages: false,              // <-- не скачиваем изображения
                    isLessValuableLot: false
                );

                return; // Заканчиваем обработку лота.
            }

            // ---------------------------------------------------------------
            // Старая логика "meetsMainCondition":
            // (A) startPrice == 1 ИЛИ (B) status=2 && soldQuantity>0
            // ---------------------------------------------------------------
            bool meetsMainCondition =
                (lotData.result.startPrice == 1)
                || (lotData.result.status == 2 && lotData.result.soldQuantity > 0);

            if (!meetsMainCondition)
            {
                // Если не попадает ни под какое условие — пропускаем
                return;
            }

            try
            {
                // ----- Ветка "ИНТЕРЕСУЮЩИЕ ЛОТЫ" (InterestedCategories) ------
                if (isInterestedCategory)
                {
                    _logger.LogInformation(
                        $"Lot {lotData.result.id}: Found an INTERESTED book '{lotData.result.title}'"
                    );

                    // meetsMainCondition => не малоценное => скачиваем
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
                    bool isLittleValue = (lotData.result.price < 1500);
                    if (isLittleValue)
                    {
                        // При желании пишем lotId в файл
                        if (!string.IsNullOrWhiteSpace(nonStandardPricesSovietFilePath))
                        {
                            WriteNonStandardPriceToFile(lotData.result.id, nonStandardPricesSovietFilePath);
                        }

                        _logger.LogInformation(
                            $"Lot {lotData.result.id}: SOVIET book < 1500 '{lotData.result.title}' (little-value)."
                        );

                        // Сохраняем в БД, но без скачивания
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
                        _logger.LogInformation(
                            $"Lot {lotData.result.id}: SOVIET book >= 1500 '{lotData.result.title}'."
                        );

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
