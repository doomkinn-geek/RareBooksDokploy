using System.ComponentModel.DataAnnotations;

namespace RareBooksService.Common.Models.Dto
{
    public class SelectReferenceRequest
    {
        [Required]
        public int ReferenceBookId { get; set; }
    }
}

