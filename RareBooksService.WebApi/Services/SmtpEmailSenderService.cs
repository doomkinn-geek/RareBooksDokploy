using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Services
{
    public interface IEmailSenderService
    {
        Task SendEmailAsync(string toEmail, string subject, string body);
    }

    public class SmtpEmailSenderService : IEmailSenderService
    {
        private readonly IConfiguration _configuration;

        public SmtpEmailSenderService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public async Task SendEmailAsync(string toEmail, string subject, string body)
        {
            try
            {
                // Читаем настройки из appsettings.json
                var smtpHost = _configuration["Smtp:Host"];  // "smtp.yandex.ru"
                var smtpPort = int.Parse(_configuration["Smtp:Port"] ?? "465");
                var smtpUser = _configuration["Smtp:User"];  // "doomkinn" (без @yandex.ru)
                var smtpPass = _configuration["Smtp:Pass"];  // пароль приложения

                var message = new MimeMessage();
                message.From.Add(new MailboxAddress("Отправитель", "doomkinn@yandex.ru"));
                message.To.Add(MailboxAddress.Parse(toEmail));
                message.Subject = subject;
                message.Body = new TextPart("plain") { Text = body };

                using (var client = new SmtpClient())
                {
                    client.Timeout = 2000;
                    // Подключаемся без SSL, но указываем, что нужно "подняться" до TLS
                    // SecureSocketOptions.StartTls = сначала обычное, потом команда STARTTLS
                    // SecureSocketOptions.StartTlsWhenAvailable = попытается STARTTLS, если сервер его объявляет
                    await client.ConnectAsync(smtpHost, smtpPort, SecureSocketOptions.StartTls);

                    // После успешного STARTTLS делаем AUTH
                    await client.AuthenticateAsync(smtpUser, smtpPass);

                    await client.SendAsync(message);
                    await client.DisconnectAsync(true);
                }
            }
            catch (Exception ex) 
            {
                throw;
            }
        }
    }
}
