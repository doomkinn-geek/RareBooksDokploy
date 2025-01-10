using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models.Parsing;
using static System.Reflection.Metadata.BlobBuilder;


namespace RareBooksService.Data.Parsing
{
    public class BooksContext : DbContext
    {
        public DbSet<BookInfo> BooksInfo { get; set; }
        public DbSet<Category> Categories { get; set; }
        string _dbName = "books";

        public BooksContext()
        {
            Database.EnsureCreated();
        }
        public BooksContext(int dbNumber)
        {
            _dbName += dbNumber;
            Database.EnsureCreated();
        }

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            optionsBuilder.UseSqlite($"Filename=./{_dbName}.db");
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<BookInfo>()
                .HasOne(b => b.Category)
                .WithMany(c => c.Books)
                .HasForeignKey(b => b.CategoryId);

            modelBuilder.Entity<BookInfo>()
                .Property(e => e.ImageUrls)
                .HasConversion(
                    v => string.Join(";", v),
                    v => v.Split(";", StringSplitOptions.RemoveEmptyEntries).ToList());
            modelBuilder.Entity<BookInfo>()
                .Property(e => e.ThumbnailUrls)
                .HasConversion(
                    v => string.Join(";", v),
                    v => v.Split(";", StringSplitOptions.RemoveEmptyEntries).ToList());

            modelBuilder.Entity<BookInfo>()
                .Property(e => e.Tags)
                .HasConversion(
                    v => string.Join(";", v),
                    v => v.Split(";", StringSplitOptions.RemoveEmptyEntries).ToList());

            // Дополнительные настройки
        }
    }

}
