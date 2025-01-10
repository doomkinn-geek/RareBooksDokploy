using System.ComponentModel.DataAnnotations.Schema;

namespace RareBooksService.Common.Models.FromMeshok
{
    public class BookOld
    {
        public int Id { get; set; }
        public string? Title { get; set; }
        public string? Description { get; set; }
        public List<string> ImageUrls { get; set; } = new List<string>();
        public int BidsCount { get; set; }
        public decimal Price { get; set; }
        public DateTime BeginDate { get; set; }
        public DateTime EndDate { get; set; }
    }



    public class BookItemFromMeshok
    {
        public string correlationId { get; set; }
        public MeshokBook? result { get; set; }
    }

    public class MeshokBook
    {
        [NotMapped]
        public object[]? additionalProperties { get; set; }
        public DateTime? beginDate { get; set; }
        public int? bidsCount { get; set; }
        public int categoryId { get; set; }
        public City? city { get; set; }
        public int? condition { get; set; }
        public string? currency { get; set; }
        public Delivery? delivery { get; set; }
        public DateTime? endDate { get; set; }
        public int? watchCount { get; set; }
        public int? hitsCount { get; set; }
        public int id { get; set; }
        public int? newId { get; set; }
        public bool? isAntisniperEnabled { get; set; }
        public bool? isEndDateExtended { get; set; }
        public bool? blocked { get; set; }
        public bool? banned { get; set; }
        public bool? isBargainAvailable { get; set; }
        public bool? isFeatured { get; set; }
        public int? minRating { get; set; }
        [NotMapped]
        public string[]? paymentMethods { get; set; }
        public int? picsCount { get; set; }
        public int? picsVersion { get; set; }

        public Picture[] pictures { get; set; }
        /*public string? ImagesJson { get; set; }

        [NotMapped]
        public string[] images
        {
            get => ImagesJson == null ? null : JsonConvert.DeserializeObject<string[]>(ImagesJson);
            set => ImagesJson = JsonConvert.SerializeObject(value);
        }
        public string? ThumbnailsSerialized { get; set; }
        [NotMapped]
        public string[] thumbnails
        {
            get => ThumbnailsSerialized == null ? null : JsonConvert.DeserializeObject<string[]>(ThumbnailsSerialized);
            set => ThumbnailsSerialized = JsonConvert.SerializeObject(value);
        }
        [NotMapped]
        public float[]? picsRatio { get; set; }
        public Picture[]? pictures { get; set; }*/
        public double? price { get; set; }
        public double? normalizedPrice { get; set; }
        public int? quantity { get; set; }
        public int? soldQuantity { get; set; }
        public int? status { get; set; }
        public Seller? seller { get; set; }
        public double? startPrice { get; set; }
        public double? strikePrice { get; set; }
        [NotMapped]
        public string[]? tags { get; set; }
        public string? title { get; set; }
        public string? type { get; set; }
        public bool? markedAsBold { get; set; }
        public bool? isTemporarilyBlocked { get; set; }
        public int? charityPercent { get; set; }
        public bool? hasReposts { get; set; }
        public bool? isPremium { get; set; }
        public string? ageCategory { get; set; }
    }

    public class City
    {
        public string? country { get; set; }
        public int? countryId { get; set; }
        public int? id { get; set; }
        public string? name { get; set; }
        public int? popularity { get; set; }
        public string? region { get; set; }
        public int? regionId { get; set; }
        public bool? isNameUnique { get; set; }
    }

    [NotMapped]
    public class Delivery
    {
        public int? abroadDelivery { get; set; }
        public double? countryPrice { get; set; }
        public int? localDelivery { get; set; }
        public double? localPrice { get; set; }
        public bool? soloDelivery { get; set; }
        public double? worldPrice { get; set; }
    }

    public class Seller
    {
        public string? displayName { get; set; }
        public int? id { get; set; }
        public int? rating { get; set; }
        public bool? isTrusted { get; set; }
        public bool? hasEconomyDelivery { get; set; }
        public string? pauseMessage { get; set; }
        public string? avatarURL { get; set; }
        public string? avatarThumbnailURL { get; set; }
        public bool? isBanned { get; set; }
        public bool? isOnHold { get; set; }
    }

    public class Picture
    {
        public string url { get; set; }
        public Thumbnail thumbnail { get; set; }
        public float ratio { get; set; }
    }

    public class Thumbnail
    {
        public string x1 { get; set; }
        public string x2 { get; set; }
    }

    /*public class Picture
    {
        public int Id { get; set; }
        public string? url { get; set; }
        public Thumbnail? thumbnail { get; set; }
        public float? ratio { get; set; }
    }

    public class Thumbnail
    {
        public int Id { get; set; }
        public string? x1 { get; set; }
        public string? x2 { get; set; }
    }*/
}
