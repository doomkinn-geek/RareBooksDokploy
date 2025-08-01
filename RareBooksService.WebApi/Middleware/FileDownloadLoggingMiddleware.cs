using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using System.Diagnostics;

namespace RareBooksService.WebApi.Middleware
{
    public class FileDownloadLoggingMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<FileDownloadLoggingMiddleware> _logger;

        public FileDownloadLoggingMiddleware(RequestDelegate next, ILogger<FileDownloadLoggingMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var isFileDownload = context.Request.Path.StartsWithSegments("/api/admin/download-exported-file");
            
            if (!isFileDownload)
            {
                await _next(context);
                return;
            }

            var stopwatch = Stopwatch.StartNew();
            var originalResponseStream = context.Response.Body;
            
            try
            {
                using var responseBuffer = new MemoryStream();
                context.Response.Body = responseBuffer;
                
                _logger.LogInformation($"Начинается обработка файла для скачивания: {context.Request.Path}");
                
                await _next(context);
                
                stopwatch.Stop();
                
                var responseSize = responseBuffer.Length;
                var responseSizeMB = responseSize / (1024.0 * 1024.0);
                
                _logger.LogInformation($"Файл подготовлен к отправке: размер {responseSizeMB:F2} MB, статус {context.Response.StatusCode}, время {stopwatch.ElapsedMilliseconds}ms");
                
                // Копируем данные обратно в оригинальный поток ответа
                responseBuffer.Seek(0, SeekOrigin.Begin);
                
                // Отслеживаем прогресс копирования
                var buffer = new byte[81920]; // 80KB буфер
                long totalBytesSent = 0;
                int bytesRead;
                
                while ((bytesRead = await responseBuffer.ReadAsync(buffer, 0, buffer.Length)) > 0)
                {
                    try
                    {
                        await originalResponseStream.WriteAsync(buffer, 0, bytesRead);
                        await originalResponseStream.FlushAsync();
                        
                        totalBytesSent += bytesRead;
                        
                        // Логируем прогресс каждые 10MB
                        if (totalBytesSent % (10 * 1024 * 1024) < bytesRead)
                        {
                            var progressMB = totalBytesSent / (1024.0 * 1024.0);
                            var progressPercent = (double)totalBytesSent / responseSize * 100;
                            _logger.LogInformation($"Отправлено {progressMB:F2} MB ({progressPercent:F1}%) файла");
                        }
                    }
                    catch (Exception ex) when (ex is OperationCanceledException || 
                                             ex.Message.Contains("client disconnected") ||
                                             ex.Message.Contains("connection reset"))
                    {
                        var sentMB = totalBytesSent / (1024.0 * 1024.0);
                        var sentPercent = (double)totalBytesSent / responseSize * 100;
                        _logger.LogWarning($"Клиент отключился во время загрузки файла. Отправлено: {sentMB:F2} MB ({sentPercent:F1}%) из {responseSizeMB:F2} MB");
                        throw;
                    }
                }
                
                stopwatch.Stop();
                _logger.LogInformation($"Файл успешно отправлен клиенту: {responseSizeMB:F2} MB за {stopwatch.ElapsedMilliseconds}ms");
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                _logger.LogError(ex, $"Ошибка при отправке файла клиенту за {stopwatch.ElapsedMilliseconds}ms");
                throw;
            }
            finally
            {
                context.Response.Body = originalResponseStream;
            }
        }
    }
} 