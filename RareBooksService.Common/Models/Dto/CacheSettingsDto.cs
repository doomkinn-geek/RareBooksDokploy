using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.Dto
{
    public class CacheSettingsDto
    {
        public string LocalCachePath { get; set; }        // "image_cache" / "D:/cache"
        public int DaysToKeep { get; set; }               // 30
        public int MaxCacheSizeMB { get; set; }           // 200
    }
}
