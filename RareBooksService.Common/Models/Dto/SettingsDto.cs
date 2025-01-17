using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.Dto
{
    public class SettingsDto
    {
        public YandexKassaDto? YandexKassa { get; set; }
        public YandexDiskDto? YandexDisk { get; set; }
        public TypeOfAccessImagesDto? TypeOfAccessImages { get; set; }
        public YandexCloudDto? YandexCloud { get; set; }
        // Новый блок настроек SMTP
        public SmtpDto? Smtp { get; set; }
    }
}
