using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;

namespace RareBooksService.Data
{
    public class UsersDbContext : IdentityDbContext<ApplicationUser>
    {
        public DbSet<UserSearchHistory> UserSearchHistories { get; set; }
        public DbSet<Subscription> Subscriptions { get; set; }
        public DbSet<SubscriptionPlan> SubscriptionPlans { get; set; }
        public DbSet<UserSearchState> UserSearchStates { get; set; }
        public DbSet<UserFavoriteBook> UserFavoriteBooks { get; set; }

        public UsersDbContext(DbContextOptions<UsersDbContext> options)
            : base(options)
        { }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Связываем UserSearchHistory -> User
            modelBuilder.Entity<UserSearchHistory>()
                .HasKey(ush => ush.Id);

            modelBuilder.Entity<UserSearchHistory>()
                .HasOne(ush => ush.User)
                .WithMany(u => u.SearchHistory)
                .HasForeignKey(ush => ush.UserId);

            modelBuilder.Entity<Subscription>()
                .HasKey(s => s.Id);

            modelBuilder.Entity<Subscription>()
                .HasOne(s => s.User)
                .WithMany(u => u.Subscriptions) // <--- тут .WithMany(...)
                .HasForeignKey(s => s.UserId)
                .OnDelete(DeleteBehavior.Cascade);


            // SubscriptionPlan
            modelBuilder.Entity<SubscriptionPlan>(entity =>
            {
                entity.HasKey(p => p.Id);
                entity.Property(p => p.Name).HasMaxLength(200).IsRequired();
                entity.Property(p => p.Price).HasColumnType("decimal(18,2)");
            });

            modelBuilder.Entity<UserSearchState>()
               .HasIndex(s => new { s.UserId, s.SearchType })
               .IsUnique();

            // Настройка UserFavoriteBook
            modelBuilder.Entity<UserFavoriteBook>()
                .HasKey(fb => fb.Id);

            modelBuilder.Entity<UserFavoriteBook>()
                .HasOne(fb => fb.User)
                .WithMany(u => u.FavoriteBooks)
                .HasForeignKey(fb => fb.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            // Создаем индекс для быстрого поиска по UserId и BookId
            modelBuilder.Entity<UserFavoriteBook>()
                .HasIndex(fb => new { fb.UserId, fb.BookId })
                .IsUnique();
        }
    }
}
