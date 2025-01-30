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

    public class RegularBaseBooksContext : IdentityDbContext<ApplicationUser>
    {
        public DbSet<RegularBaseBook> BooksInfo { get; set; }
        public DbSet<RegularBaseCategory> Categories { get; set; }
        public DbSet<UserSearchHistory> UserSearchHistories { get; set; }
        public DbSet<Subscription> Subscriptions { get; set; }
        public DbSet<SubscriptionPlan> SubscriptionPlans { get; set; }

        public RegularBaseBooksContext(DbContextOptions<RegularBaseBooksContext> options) : base(options) { }

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            if (!optionsBuilder.IsConfigured)
            {
                // Ensure the connection string is provided through configuration or parameters
                throw new InvalidOperationException("The connection string is not configured. Please use 'UseNpgsql' with a valid connection string.");
            }
            
            // Добавляем интерцептор
            //optionsBuilder.AddInterceptors(new NullToZeroMaterializationInterceptor());
            //19.12.2024 - добавление интерцептора в каждом экземпляре вызывает исключение после нескольких запросов к api
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Define relationships and constraints
            modelBuilder.Entity<RegularBaseBook>()
                .HasOne(b => b.Category)
                .WithMany(c => c.Books)
                .HasForeignKey(b => b.CategoryId);

            // Value Comparers for list and array properties
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

            // Configure UserSearchHistory
            modelBuilder.Entity<UserSearchHistory>()
                .HasKey(ush => ush.Id);

            modelBuilder.Entity<UserSearchHistory>()
                .HasOne(ush => ush.User)
                .WithMany(u => u.SearchHistory)
                .HasForeignKey(ush => ush.UserId);

            // Configure Subscription
            modelBuilder.Entity<Subscription>()
                .HasKey(s => s.Id);
            // Configure UserSearchHistory relationships
            modelBuilder.Entity<UserSearchHistory>()
                .HasKey(ush => ush.Id);

            modelBuilder.Entity<UserSearchHistory>()
                .HasOne(ush => ush.User)
                .WithMany(u => u.SearchHistory)
                .HasForeignKey(ush => ush.UserId);

            //для null значений вставляем 0 по умолчанию
            var finalPriceConverter = new ValueConverter<double?, double?>(
                modelValue => modelValue, // При записи в базу сохраняем как есть
                providerValue => providerValue.HasValue ? providerValue.Value : 0 // При чтении из базы: если null -> 0
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

            // SubscriptionPlan
            modelBuilder.Entity<SubscriptionPlan>(entity =>
            {
                entity.HasKey(p => p.Id);
                entity.Property(p => p.Name).HasMaxLength(200).IsRequired();
                entity.Property(p => p.Price).HasColumnType("decimal(18,2)");
            });            

            modelBuilder.Entity<ApplicationUser>()
                .HasOne(u => u.CurrentSubscription)
                .WithOne(s => s.User) // Subscription тоже должно иметь public ApplicationUser User { get; set; }
                .HasForeignKey<ApplicationUser>(u => u.CurrentSubscriptionId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Subscription>()
                .HasOne(s => s.User)
                .WithOne(u => u.CurrentSubscription)
                .HasForeignKey<Subscription>(s => s.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
