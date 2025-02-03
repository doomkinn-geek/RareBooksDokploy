using Newtonsoft.Json;
using System;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace RareBooksService.Parser.Services
{
    public class HttpClientService : IDisposable
    {
        private HttpClient _httpClient;
        private HttpClientHandler _httpClientHandler;
        private bool _disposed = false;
        private bool _initialized = false;
        private readonly SemaphoreSlim _semaphore = new SemaphoreSlim(1);

        public HttpClientService()
        {
            try
            {
                // Инициализация теперь производится «лениво» (отложено до вызова EnsureInitializedAsync)
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to initialize HttpClientService: {ex.Message}");
            }
        }

        public async Task EnsureInitializedAsync()
        {
            if (_initialized) return;
            _initialized = true;

            _httpClientHandler?.Dispose();
            _httpClient?.Dispose();

            _httpClientHandler = new HttpClientHandler()
            {
                UseCookies = true,
                CookieContainer = new CookieContainer()
            };

            _httpClient = new HttpClient(_httpClientHandler, disposeHandler: true)
            {
                Timeout = TimeSpan.FromSeconds(30)
            };

            ConfigureDefaultHeaders();

            try
            {
                await FetchInitialCookies();
            }
            catch (HttpRequestException ex)
            {
                Console.WriteLine($"Failed to fetch initial cookies: {ex.Message}");
            }
        }

        private void ConfigureDefaultHeaders()
        {
            _httpClient.DefaultRequestHeaders.Clear();
            // Указываем реальный User-Agent, похожий на запрос браузера
            _httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36");
            _httpClient.DefaultRequestHeaders.Add("Accept", "application/json, text/plain, */*");
            // Добавляем Referer и Accept-Language
            _httpClient.DefaultRequestHeaders.Add("Referer", "https://meshok.net/");
            _httpClient.DefaultRequestHeaders.Add("Accept-Language", "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7");
        }

        public async Task FetchInitialCookies()
        {
            // Используем главную страницу для инициализации cookies
            var initialUrl = "https://meshok.net/";
            await GetStringAsync(initialUrl);
            // Небольшая задержка для имитации естественного поведения пользователя
            await Task.Delay(500);
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
                        // Корректировка кодировки в Content-Type
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
                    Console.WriteLine($"Attempt {attempt} of {maxRetries} failed due to timeout. Retrying after {delayMilliseconds}ms...");
                    await Task.Delay(delayMilliseconds);
                    delayMilliseconds *= 2;
                }
                catch (HttpRequestException ex)
                {
                    if (attempt == maxRetries)
                    {
                        throw;
                    }
                    // Если получен Forbidden, повторно инициализируем cookies и увеличиваем задержку
                    if (ex.Message.Contains("Forbidden"))
                    {
                        Console.WriteLine($"Attempt {attempt} of {maxRetries} failed with Forbidden. Reinitializing cookies and retrying after {delayMilliseconds * 10}ms...");
                        await FetchInitialCookies();
                        await Task.Delay(delayMilliseconds * 10);
                        delayMilliseconds *= 2;
                    }
                    else
                    {
                        Console.WriteLine($"Attempt {attempt} of {maxRetries} failed with HttpRequestException. Retrying after {delayMilliseconds}ms...");
                        await Task.Delay(delayMilliseconds);
                        delayMilliseconds *= 2;
                    }
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
