using AutoMapper;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.FromMeshok;
using RareBooksService.Common.Models.Interfaces;
using RareBooksService.Common.Models.Parsing;

namespace RareBooksService.Parser
{
    public class AutoMapperProfile : Profile
    {        
        public AutoMapperProfile()
        {
            CreateMap<MeshokBook, RegularBaseBook>()
                .ForMember(dest => dest.Id, opt => opt.MapFrom(src => src.id))
                .ForMember(dest => dest.Title, opt => opt.MapFrom(src => src.title))
                .ForMember(dest => dest.NormalizedTitle, opt => opt.MapFrom(src => src.title.ToLower()))
                .ForMember(dest => dest.BeginDate, opt => opt.MapFrom(src => src.beginDate))
                .ForMember(dest => dest.EndDate, opt => opt.MapFrom(src => src.endDate))
                .ForMember(dest => dest.ImageUrls, opt => opt.MapFrom(src => src.pictures.Select(p => p.url).ToList()))
                .ForMember(dest => dest.ThumbnailUrls, opt => opt.MapFrom(src => src.pictures.Select(p => p.thumbnail.x1).ToList()))
                .ForMember(dest => dest.Price, opt => opt.MapFrom(src => src.price))
                .ForMember(dest => dest.City, opt => opt.MapFrom(src => src.city.name))
                .ForMember(dest => dest.Tags, opt => opt.MapFrom(src => src.tags))
                .ForMember(dest => dest.PicsRatio, opt => opt.MapFrom(src => src.pictures.Select(p => p.ratio).ToList()))
                .ForMember(dest => dest.Status, opt => opt.MapFrom(src => src.status))
                .ForMember(dest => dest.StartPrice, opt => opt.MapFrom(src => src.startPrice))
                .ForMember(dest => dest.Type, opt => opt.MapFrom(src => src.type))
                .ForMember(dest => dest.SoldQuantity, opt => opt.MapFrom(src => src.soldQuantity))
                .ForMember(dest => dest.BidsCount, opt => opt.MapFrom(src => src.bidsCount))
                .ForMember(dest => dest.SellerName, opt => opt.MapFrom(src => src.seller.displayName))
                .ForMember(dest => dest.PicsCount, opt => opt.MapFrom(src => src.picsCount));

            CreateMap<Common.Models.FromMeshok.Category, RegularBaseCategory>()
                .ForMember(dest => dest.CategoryId, opt => opt.MapFrom(src => src.id))
                .ForMember(dest => dest.Name, opt => opt.MapFrom(src => src.name));
        }
    }
}
