using Microsoft.EntityFrameworkCore;
using System.Globalization;
using RareBooksService.Common.Models.Parsing;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Microsoft.EntityFrameworkCore.Diagnostics;
using RareBooksService.Common.Models;

namespace RareBooksService.Data.Parsing
{

    public class NullToZeroMaterializationInterceptor : IMaterializationInterceptor
    {
        public object InitializedInstance(MaterializationInterceptionData materializationData, object entity)
        {
            if (entity is ExtendedBookInfo book)
            {
                // Если значения null, заменить на 0
                book.FinalPrice = book.FinalPrice ?? 0;
                book.YearPublished = book.YearPublished ?? 0;
            }
            return entity;
        }
    }
    public class ExtendedBooksContext : DbContext
    {
        public DbSet<ExtendedBookInfo> BooksInfo { get; set; }
        public DbSet<ExtendedCategory> Categories { get; set; }
        string _dbName = "books_extended";

        public ExtendedBooksContext(DbContextOptions<ExtendedBooksContext> options) :  base(options)
        {            
        }
        public ExtendedBooksContext()
        {
            Database.EnsureCreated();
        }
        public ExtendedBooksContext(int dbNumber)
        {
            _dbName += dbNumber;
            Database.EnsureCreated();
        }

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            if (!optionsBuilder.IsConfigured)
            {
                optionsBuilder.UseSqlite($"Filename=./{_dbName}.db");
            }
        }
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<ExtendedBookInfo>()
                .HasOne(b => b.Category)
                .WithMany(c => c.Books)
                .HasForeignKey(b => b.CategoryId);

            modelBuilder.Entity<ExtendedBookInfo>()
                .Property(e => e.ImageUrls)
                .HasConversion(
                    v => string.Join(";", v),
                    v => v.Split(";", StringSplitOptions.RemoveEmptyEntries).ToList());
            modelBuilder.Entity<ExtendedBookInfo>()
                .Property(e => e.ThumbnailUrls)
                .HasConversion(
                    v => string.Join(";", v),
                    v => v.Split(";", StringSplitOptions.RemoveEmptyEntries).ToList());

            modelBuilder.Entity<ExtendedBookInfo>()
                .Property(e => e.Tags)
                .HasConversion(
                    v => string.Join(";", v),
                    v => v.Split(";", StringSplitOptions.RemoveEmptyEntries).ToList());

            modelBuilder.Entity<ExtendedBookInfo>()
                .Property(e => e.PicsRatio)
                .HasConversion(
                    v => string.Join(";", v.Select(p => p.ToString(CultureInfo.InvariantCulture))),
                    v => v.Split(";", StringSplitOptions.RemoveEmptyEntries)
                          .Select(s => float.Parse(s, CultureInfo.InvariantCulture))
                          .ToArray());


            //значение по умолчанию для null значений:
            var finalPriceConverter = new ValueConverter<double?, double?>(
                modelValue => modelValue, // При записи в базу сохраняем как есть
                providerValue => providerValue.HasValue ? providerValue.Value : 0 // При чтении из базы: если null -> 0
            );

            modelBuilder.Entity<ExtendedBookInfo>()
                .Property(e => e.FinalPrice)
                .HasConversion(finalPriceConverter);

            var yearPublishedConverter = new ValueConverter<int?, int?>(
                modelValue => modelValue,
                providerValue => providerValue.HasValue ? providerValue.Value : 0
            );

            modelBuilder.Entity<ExtendedBookInfo>()
                .Property(e => e.YearPublished)
                .HasConversion(yearPublishedConverter);

        }
    }
}
