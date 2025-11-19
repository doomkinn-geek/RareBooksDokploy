using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Telegram;

namespace RareBooksService.Data
{
    public class UsersDbContext : IdentityDbContext<ApplicationUser>
    {
        public DbSet<UserSearchHistory> UserSearchHistories { get; set; }
        public DbSet<Subscription> Subscriptions { get; set; }
        public DbSet<SubscriptionPlan> SubscriptionPlans { get; set; }
        public DbSet<UserSearchState> UserSearchStates { get; set; }
        public DbSet<UserFavoriteBook> UserFavoriteBooks { get; set; }
        public DbSet<UserNotificationPreference> UserNotificationPreferences { get; set; }
        public DbSet<BookNotification> BookNotifications { get; set; }
        public DbSet<TelegramUserState> TelegramUserStates { get; set; }
        public DbSet<TelegramLinkToken> TelegramLinkTokens { get; set; }
        public DbSet<UserCollectionBook> UserCollectionBooks { get; set; }
        public DbSet<UserCollectionBookImage> UserCollectionBookImages { get; set; }
        public DbSet<UserCollectionBookMatch> UserCollectionBookMatches { get; set; }

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

            // Настройка UserNotificationPreference
            modelBuilder.Entity<UserNotificationPreference>()
                .HasKey(np => np.Id);

            modelBuilder.Entity<UserNotificationPreference>()
                .HasOne(np => np.User)
                .WithMany(u => u.NotificationPreferences)
                .HasForeignKey(np => np.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<UserNotificationPreference>()
                .Property(np => np.Keywords)
                .HasMaxLength(2000);

            modelBuilder.Entity<UserNotificationPreference>()
                .Property(np => np.CategoryIds)
                .HasMaxLength(500);

            modelBuilder.Entity<UserNotificationPreference>()
                .Property(np => np.Cities)
                .HasMaxLength(1000);

            modelBuilder.Entity<UserNotificationPreference>()
                .Property(np => np.MinPrice)
                .HasColumnType("decimal(18,2)");

            modelBuilder.Entity<UserNotificationPreference>()
                .Property(np => np.MaxPrice)
                .HasColumnType("decimal(18,2)");

            // Настройка BookNotification
            modelBuilder.Entity<BookNotification>()
                .HasKey(bn => bn.Id);

            modelBuilder.Entity<BookNotification>()
                .HasOne(bn => bn.User)
                .WithMany(u => u.BookNotifications)
                .HasForeignKey(bn => bn.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<BookNotification>()
                .HasOne(bn => bn.UserNotificationPreference)
                .WithMany()
                .HasForeignKey(bn => bn.UserNotificationPreferenceId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<BookNotification>()
                .Property(bn => bn.BookPrice)
                .HasColumnType("decimal(18,2)");

            modelBuilder.Entity<BookNotification>()
                .Property(bn => bn.BookFinalPrice)
                .HasColumnType("decimal(18,2)");

            modelBuilder.Entity<BookNotification>()
                .Property(bn => bn.BookTitle)
                .HasMaxLength(500)
                .IsRequired();

            modelBuilder.Entity<BookNotification>()
                .Property(bn => bn.BookDescription)
                .HasMaxLength(5000);

            modelBuilder.Entity<BookNotification>()
                .Property(bn => bn.BookCity)
                .HasMaxLength(100);

            modelBuilder.Entity<BookNotification>()
                .Property(bn => bn.Subject)
                .HasMaxLength(200);

            modelBuilder.Entity<BookNotification>()
                .Property(bn => bn.Content)
                .HasMaxLength(10000);

            modelBuilder.Entity<BookNotification>()
                .Property(bn => bn.RecipientAddress)
                .HasMaxLength(200);

            modelBuilder.Entity<BookNotification>()
                .Property(bn => bn.ErrorMessage)
                .HasMaxLength(1000);

            modelBuilder.Entity<BookNotification>()
                .Property(bn => bn.MatchedKeywords)
                .HasMaxLength(500);

            // Индексы для эффективного поиска
            modelBuilder.Entity<BookNotification>()
                .HasIndex(bn => bn.UserId);

            modelBuilder.Entity<BookNotification>()
                .HasIndex(bn => bn.BookId);

            modelBuilder.Entity<BookNotification>()
                .HasIndex(bn => bn.Status);

            modelBuilder.Entity<BookNotification>()
                .HasIndex(bn => bn.CreatedAt);

            modelBuilder.Entity<UserNotificationPreference>()
                .HasIndex(np => np.UserId);

            modelBuilder.Entity<UserNotificationPreference>()
                .HasIndex(np => np.IsEnabled);

            // Настройка TelegramUserState
            modelBuilder.Entity<TelegramUserState>()
                .HasKey(tus => tus.Id);

            modelBuilder.Entity<TelegramUserState>()
                .Property(tus => tus.TelegramId)
                .HasMaxLength(50)
                .IsRequired();

            modelBuilder.Entity<TelegramUserState>()
                .Property(tus => tus.State)
                .HasMaxLength(100);

            modelBuilder.Entity<TelegramUserState>()
                .Property(tus => tus.StateData)
                .HasMaxLength(2000);

            modelBuilder.Entity<TelegramUserState>()
                .HasIndex(tus => tus.TelegramId)
                .IsUnique();

            // Настройка UserCollectionBook
            modelBuilder.Entity<UserCollectionBook>()
                .HasKey(cb => cb.Id);

            modelBuilder.Entity<UserCollectionBook>()
                .HasOne(cb => cb.User)
                .WithMany(u => u.CollectionBooks)
                .HasForeignKey(cb => cb.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<UserCollectionBook>()
                .Property(cb => cb.Title)
                .HasMaxLength(500)
                .IsRequired();

            modelBuilder.Entity<UserCollectionBook>()
                .Property(cb => cb.Author)
                .HasMaxLength(300);

            modelBuilder.Entity<UserCollectionBook>()
                .Property(cb => cb.Description)
                .HasMaxLength(2000);

            modelBuilder.Entity<UserCollectionBook>()
                .Property(cb => cb.Notes)
                .HasMaxLength(2000);

            modelBuilder.Entity<UserCollectionBook>()
                .Property(cb => cb.EstimatedPrice)
                .HasColumnType("decimal(18,2)");

            modelBuilder.Entity<UserCollectionBook>()
                .HasIndex(cb => cb.UserId);

            modelBuilder.Entity<UserCollectionBook>()
                .HasIndex(cb => cb.AddedDate);

            // Настройка UserCollectionBookImage
            modelBuilder.Entity<UserCollectionBookImage>()
                .HasKey(img => img.Id);

            modelBuilder.Entity<UserCollectionBookImage>()
                .HasOne(img => img.UserCollectionBook)
                .WithMany(cb => cb.Images)
                .HasForeignKey(img => img.UserCollectionBookId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<UserCollectionBookImage>()
                .Property(img => img.FileName)
                .HasMaxLength(255)
                .IsRequired();

            modelBuilder.Entity<UserCollectionBookImage>()
                .Property(img => img.FilePath)
                .HasMaxLength(1000)
                .IsRequired();

            modelBuilder.Entity<UserCollectionBookImage>()
                .HasIndex(img => img.UserCollectionBookId);

            // Настройка UserCollectionBookMatch
            modelBuilder.Entity<UserCollectionBookMatch>()
                .HasKey(m => m.Id);

            modelBuilder.Entity<UserCollectionBookMatch>()
                .HasOne(m => m.UserCollectionBook)
                .WithMany(cb => cb.SuggestedMatches)
                .HasForeignKey(m => m.UserCollectionBookId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<UserCollectionBookMatch>()
                .HasIndex(m => m.UserCollectionBookId);

            modelBuilder.Entity<UserCollectionBookMatch>()
                .HasIndex(m => m.MatchedBookId);

            modelBuilder.Entity<UserCollectionBookMatch>()
                .HasIndex(m => new { m.UserCollectionBookId, m.MatchedBookId })
                .IsUnique();

            // Игнорируем навигационные свойства, которые ссылаются на другую БД (BooksDb)
            // MatchedBook и ReferenceBook находятся в BooksDb, а не в UsersDb
            modelBuilder.Entity<UserCollectionBookMatch>()
                .Ignore(m => m.MatchedBook);

            modelBuilder.Entity<UserCollectionBook>()
                .Ignore(cb => cb.ReferenceBook);
        }
    }
}
