using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.Settings
{
    public class CacheSettings
    {
        public string LocalCachePath { get; set; }
        public int DaysToKeep { get; set; }
        public int MaxCacheSizeMB { get; set; }
    }

}
