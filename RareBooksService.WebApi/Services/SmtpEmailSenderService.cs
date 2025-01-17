using System.Net;
using System.Net.Mail;
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
            // Читаем настройки SMTP из appsettings.json
            var smtpHost = _configuration["Smtp:Host"];
            var smtpPort = int.Parse(_configuration["Smtp:Port"] ?? "25");
            var smtpUser = _configuration["Smtp:User"];
            var smtpPass = _configuration["Smtp:Pass"];

            using (var client = new SmtpClient(smtpHost, smtpPort))
            {
                client.Credentials = new NetworkCredential(smtpUser, smtpPass);
                client.EnableSsl = true; // если нужен SSL

                var mail = new MailMessage
                {
                    From = new MailAddress(smtpUser),
                    Subject = subject,
                    Body = body,
                    IsBodyHtml = false
                };
                mail.To.Add(toEmail);

                await client.SendMailAsync(mail);
            }
        }
    }
}
