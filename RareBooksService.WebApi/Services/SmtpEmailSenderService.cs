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
            try
            {
                // Читаем настройки SMTP из appsettings.json
                var smtpHost = _configuration["Smtp:Host"];  // например, "smtp.example.com"
                var smtpPort = 587;                          // или тянете из конфига, если там так записано
                var smtpUser = _configuration["Smtp:User"];
                var smtpPass = _configuration["Smtp:Pass"];

                using (var client = new SmtpClient(smtpHost, smtpPort))
                {
                    client.UseDefaultCredentials = false;
                    client.Credentials = new NetworkCredential(smtpUser, smtpPass);

                    // Для STARTTLS: EnableSsl = true
                    client.EnableSsl = true;

                    // Можно установить таймаут, чтобы не «висло» бесконечно при ошибке
                    client.Timeout = 2000; 

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
            catch (Exception ex)
            {
                ;
            }
        }
    }
}
