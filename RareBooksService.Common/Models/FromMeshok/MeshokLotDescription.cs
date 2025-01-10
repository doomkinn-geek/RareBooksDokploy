using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.FromMeshok
{
    public class MeshokLotDescription
    {
        public string? correlationId { get; set; }
        public Result? result { get; set; }
    }

    public class Result
    {
        public string? deliveryDetails { get; set; }
        public string? description { get; set; }
    }

}
