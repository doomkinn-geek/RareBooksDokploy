using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Parser
{
    // 1) Интерфейс, который и LotFetchingService, и LotDataHandler, и HttpClientService могут вызывать:
    public interface IProgressReporter
    {
        void ReportInfo(string message, string? operation = null, int? lotId = null, string? title = null);
        void ReportError(Exception ex, string message, string? operation = null, int? lotId = null, string? title = null);
    }

    // 2) Класс-сущность лога
    public class LogEntry
    {
        public DateTime Timestamp { get; set; }
        public string Message { get; set; }
        public string? OperationName { get; set; }
        public int? LotId { get; set; }
        public string? LotTitle { get; set; }
        public bool IsError { get; set; }
        public string? ExceptionMessage { get; set; }
    }
}
