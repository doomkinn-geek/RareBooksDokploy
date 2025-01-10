using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.FromMeshok
{
    class MeshokLots
    {
    }


    public class LotsParsedFromMeshok
    {
        public string? correlationId { get; set; }
        public LotResult? result { get; set; }
    }


    public class LotResult
    {
        public Lot[] lots { get; set; }
        public Stats stats { get; set; }
        public Suggest suggest { get; set; }
        public object[] lastSortValues { get; set; }
    }

    public class Stats
    {
        public Category[] categories { get; set; }
        public Count count { get; set; }
        public Price price { get; set; }
        public object selectedSeller { get; set; }
        public object selectedBidder { get; set; }
        public object standardDescriptionName { get; set; }
    }

    public class Count
    {
        public int overall { get; set; }
        public Properties properties { get; set; }
        public Dictionary<string, int> tags { get; set; }
        public int isPremium { get; set; }
    }

    public class Properties
    {
    }

    public class Price
    {
        public int max { get; set; }
        public int min { get; set; }
    }

    public class Category
    {
        public int?[] childs { get; set; }
        public string extraName { get; set; }
        public int id { get; set; }
        public int level { get; set; }
        public int lotsCount { get; set; }
        public string name { get; set; }
        public int parentId { get; set; }
    }

    public class Suggest
    {
        public object text { get; set; }
        public object[] words { get; set; }
        public object[] categories { get; set; }
        public object[] queries { get; set; }
    }

    public class Lot
    {
        public object[] additionalProperties { get; set; }
        public DateTime beginDate { get; set; }
        public int bidsCount { get; set; }
        public int? categoryId { get; set; }
        public City? city { get; set; }
        public int condition { get; set; }
        public string? currency { get; set; }
        public Delivery delivery { get; set; }
        public DateTime? endDate { get; set; }
        public int watchCount { get; set; }
        public int hitsCount { get; set; }
        public int id { get; set; }
        public object newId { get; set; }
        public string[] images { get; set; }
        public string[] thumbnails { get; set; }
        public float[] picsRatio { get; set; }
        public Picture[] pictures { get; set; }
        public bool isAntisniperEnabled { get; set; }
        public bool isEndDateExtended { get; set; }
        public bool blocked { get; set; }
        public bool banned { get; set; }
        public bool isBargainAvailable { get; set; }
        public bool isFeatured { get; set; }
        public int minRating { get; set; }
        public string[] paymentMethods { get; set; }
        public int picsCount { get; set; }
        public int picsVersion { get; set; }
        public int price { get; set; }
        public double? normalizedPrice { get; set; }
        public int quantity { get; set; }
        public int soldQuantity { get; set; }
        public int status { get; set; }
        public Seller seller { get; set; }
        public int startPrice { get; set; }
        public double? strikePrice { get; set; }
        public string[] tags { get; set; }
        public string title { get; set; }
        public string type { get; set; }
        public bool markedAsBold { get; set; }
        public bool isTemporarilyBlocked { get; set; }
        public int charityPercent { get; set; }
        public bool hasReposts { get; set; }
        public bool isPremium { get; set; }
        public string ageCategory { get; set; }
    }
}
