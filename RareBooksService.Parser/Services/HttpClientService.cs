using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Parser.Services
{
    public class HttpClientService : IDisposable
    {
        private HttpClient _httpClient;
        private HttpClientHandler _httpClientHandler;
        private bool _disposed = false;

        // Добавляем SemaphoreSlim для ограничения параллелизма
        private readonly SemaphoreSlim _semaphore = new SemaphoreSlim(1);

        public HttpClientService()
        {
            try
            {
                InitializeHttpClientAsync().GetAwaiter().GetResult();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to initialize HttpClientService: {ex.Message}");
                // Можно либо повторить попытку, либо просто пропустить инициализацию cookies.
                // Например, можно попытаться повторить еще раз:
                // Retry logic или просто пропустить.
            }
        }

        private async Task InitializeHttpClientAsync()
        {
            _httpClientHandler?.Dispose();
            _httpClient?.Dispose();

            _httpClientHandler = new HttpClientHandler()
            {
                UseCookies = true,
                CookieContainer = new System.Net.CookieContainer()
            };

            _httpClient = new HttpClient(_httpClientHandler, disposeHandler: true)
            {
                Timeout = TimeSpan.FromSeconds(30) // Устанавливаем таймаут 30 секунд (можно настроить)
            };

            ConfigureDefaultHeaders();
            try
            {
                await FetchInitialCookies();
            }
            catch (HttpRequestException ex)
            {
                // Логируем и не бросаем исключение дальше, чтобы не ронять конструктор
                Console.WriteLine($"Failed to fetch initial cookies: {ex.Message}");
                // Можно при желании повторить попытку несколько раз или просто продолжить.
            }
        }

        private void ConfigureDefaultHeaders()
        {
            _httpClient.DefaultRequestHeaders.Clear();
            _httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 ...");
            _httpClient.DefaultRequestHeaders.Add("Accept", "application/json, text/plain, */*");
            _httpClient.DefaultRequestHeaders.Add("meshok-locale", "ru");
        }
        public async Task FetchInitialCookies()
        {
            var initialUrl = "https://meshok.net/listing?a_o=8&good=13870";
            await GetStringAsync(initialUrl);
        }

        public async Task<T> PostAsync<T>(string url, object requestBody)
        {
            await _semaphore.WaitAsync();
            try
            {
                return await SendRequestWithRetries<T>(async () =>
                {
                    var requestJson = JsonConvert.SerializeObject(requestBody);
                    var response = await _httpClient.PostAsync(url, new StringContent(requestJson, Encoding.UTF8, "application/json"));

                    if (response.IsSuccessStatusCode)
                    {
                        // Проверяем и исправляем кодировку в Content-Type
                        var contentType = response.Content.Headers.ContentType;
                        if (contentType != null && contentType.CharSet != null && contentType.CharSet.Equals("utf8", StringComparison.OrdinalIgnoreCase))
                        {
                            contentType.CharSet = "utf-8";
                        }

                        var responseJson = await response.Content.ReadAsStringAsync();
                        var result = JsonConvert.DeserializeObject<T>(responseJson);
                        return result;
                    }

                    throw new HttpRequestException($"Request to {url} failed with status code {response.StatusCode}.");
                });
            }
            finally
            {
                _semaphore.Release();
            }
        }

        public async Task<string> GetStringAsync(string url)
        {
            await _semaphore.WaitAsync();
            try
            {
                return await SendRequestWithRetries<string>(async () =>
                {
                    var response = await _httpClient.GetAsync(url);
                    if (response.IsSuccessStatusCode)
                    {
                        return await response.Content.ReadAsStringAsync();
                    }

                    throw new HttpRequestException($"Request to {url} failed with status code {response.StatusCode}.");
                });
            }
            finally
            {
                _semaphore.Release();
            }
        }

        private async Task<T> SendRequestWithRetries<T>(Func<Task<T>> requestFunc, int maxRetries = 3)
        {
            int delayMilliseconds = 200; // Начальная задержка

            for (int attempt = 1; attempt <= maxRetries; attempt++)
            {
                try
                {
                    return await requestFunc();
                }
                catch (TaskCanceledException ex)
                {
                    if (attempt == maxRetries)
                    {
                        throw new TimeoutException($"Request timed out after {maxRetries} attempts.", ex);
                    }

                    // Логируем и ждем перед повторной попыткой
                    Console.WriteLine($"Attempt {attempt} of {maxRetries} failed due to timeout. Retrying after {delayMilliseconds}ms...");
                    await Task.Delay(delayMilliseconds);
                    delayMilliseconds *= 2; // Экспоненциальная задержка
                }
                catch (HttpRequestException ex)
                {
                    if (attempt == maxRetries)
                    {
                        throw;
                    }

                    Console.WriteLine($"Attempt {attempt} of {maxRetries} failed with HttpRequestException. Retrying after {delayMilliseconds}ms...");
                    await Task.Delay(delayMilliseconds);
                    delayMilliseconds *= 2;
                }
            }

            throw new Exception("Unexpected error in SendRequestWithRetries.");
        }

        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (!_disposed)
            {
                if (disposing)
                {
                    _httpClientHandler?.Dispose();
                    _httpClient?.Dispose();
                    _semaphore?.Dispose();
                }

                _disposed = true;
            }
        }
    }
}
