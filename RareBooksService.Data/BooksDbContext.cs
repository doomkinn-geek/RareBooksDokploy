using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Parsing;
using System.Globalization;

namespace RareBooksService.Data
{
    public class NullToZeroMaterializationInterceptor : IMaterializationInterceptor
    {
        public object InitializedInstance(MaterializationInterceptionData materializationData, object entity)
        {
            if (entity is RegularBaseBook book)
            {
                // Если значения null, заменить на 0
                book.FinalPrice = book.FinalPrice ?? 0;
                book.YearPublished = book.YearPublished ?? 0;
            }
            return entity;
        }
    }

    public class BooksDbContext : DbContext
    {
        public DbSet<RegularBaseBook> BooksInfo { get; set; }
        public DbSet<RegularBaseCategory> Categories { get; set; }

        public BooksDbContext(DbContextOptions<BooksDbContext> options)
            : base(options)
        { }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Пример связи "Book -> Category"
            modelBuilder.Entity<RegularBaseBook>()
                .HasOne(b => b.Category)
                .WithMany(c => c.Books)
                .HasForeignKey(b => b.CategoryId);

            // Пример ValueComparers для списков
            var stringListComparer = new ValueComparer<List<string>>(
                (c1, c2) => c1.SequenceEqual(c2),
                c => c.Aggregate(0, (a, v) => HashCode.Combine(a, v.GetHashCode())),
                c => c.ToList());

            var floatArrayComparer = new ValueComparer<float[]>(
                (c1, c2) => c1.SequenceEqual(c2),
                c => c.Aggregate(0, (a, v) => HashCode.Combine(a, v.GetHashCode())),
                c => c.ToArray());

            modelBuilder.Entity<RegularBaseBook>()
                .Property(e => e.ImageUrls)
                .HasConversion(
                    v => string.Join(";", v),
                    v => v.Split(";", StringSplitOptions.RemoveEmptyEntries).ToList())
                .Metadata.SetValueComparer(stringListComparer);

            modelBuilder.Entity<RegularBaseBook>()
                .Property(e => e.ThumbnailUrls)
                .HasConversion(
                    v => string.Join(";", v),
                    v => v.Split(";", StringSplitOptions.RemoveEmptyEntries).ToList())
                .Metadata.SetValueComparer(stringListComparer);

            modelBuilder.Entity<RegularBaseBook>()
                .Property(e => e.Tags)
                .HasConversion(
                    v => string.Join(";", v),
                    v => v.Split(";", StringSplitOptions.RemoveEmptyEntries).ToList())
                .Metadata.SetValueComparer(stringListComparer);

            modelBuilder.Entity<RegularBaseBook>()
                .Property(e => e.PicsRatio)
                .HasConversion(
                    v => string.Join(";", v.Select(p => p.ToString(CultureInfo.InvariantCulture))),
                    v => v.Split(";", StringSplitOptions.RemoveEmptyEntries)
                          .Select(s => float.Parse(s, CultureInfo.InvariantCulture))
                          .ToArray())
                .Metadata.SetValueComparer(floatArrayComparer);

            // Пример конвертера для FinalPrice (null -> 0)
            var finalPriceConverter = new ValueConverter<double?, double?>(
                modelValue => modelValue,
                providerValue => providerValue.HasValue ? providerValue.Value : 0
            );
            modelBuilder.Entity<RegularBaseBook>()
                .Property(e => e.FinalPrice)
                .HasConversion(finalPriceConverter);

            var yearPublishedConverter = new ValueConverter<int?, int?>(
                modelValue => modelValue,
                providerValue => providerValue.HasValue ? providerValue.Value : 0
            );
            modelBuilder.Entity<RegularBaseBook>()
                .Property(e => e.YearPublished)
                .HasConversion(yearPublishedConverter);
        }
    }
}
