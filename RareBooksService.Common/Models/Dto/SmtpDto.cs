using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.Dto
{
    public class SmtpDto
    {
        public string Host { get; set; }
        public string Port { get; set; } 
        public string User { get; set; }
        public string Pass { get; set; }
    }
}
