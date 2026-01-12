using Microsoft.EntityFrameworkCore;
using MayMessenger.Domain.Entities;

namespace MayMessenger.Infrastructure.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }
    
    public DbSet<User> Users { get; set; } = null!;
    public DbSet<Chat> Chats { get; set; } = null!;
    public DbSet<ChatParticipant> ChatParticipants { get; set; } = null!;
    public DbSet<Message> Messages { get; set; } = null!;
    public DbSet<MessageStatusEvent> MessageStatusEvents { get; set; } = null!;
    public DbSet<InviteLink> InviteLinks { get; set; } = null!;
    public DbSet<FcmToken> FcmTokens { get; set; } = null!;
    public DbSet<Contact> Contacts { get; set; } = null!;
    public DbSet<DeliveryReceipt> DeliveryReceipts { get; set; } = null!;
    public DbSet<PendingAck> PendingAcks { get; set; } = null!;
    public DbSet<Poll> Polls { get; set; } = null!;
    public DbSet<PollOption> PollOptions { get; set; } = null!;
    public DbSet<PollVote> PollVotes { get; set; } = null!;
    
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        
        // User configuration
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.PhoneNumber).IsUnique();
            entity.HasIndex(e => e.PhoneNumberHash); // Add index for contact sync
            entity.Property(e => e.PhoneNumber).IsRequired().HasMaxLength(20);
            entity.Property(e => e.PhoneNumberHash).IsRequired().HasMaxLength(64);
            entity.Property(e => e.DisplayName).IsRequired().HasMaxLength(100);
            entity.Property(e => e.PasswordHash).IsRequired();
            
            entity.HasOne(e => e.InvitedByUser)
                .WithMany()
                .HasForeignKey(e => e.InvitedBy)
                .OnDelete(DeleteBehavior.SetNull);
        });
        
        // Chat configuration
        modelBuilder.Entity<Chat>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Title).IsRequired().HasMaxLength(100);
        });
        
        // ChatParticipant configuration
        modelBuilder.Entity<ChatParticipant>(entity =>
        {
            entity.HasKey(e => new { e.ChatId, e.UserId });
            
            entity.HasOne(e => e.Chat)
                .WithMany(c => c.Participants)
                .HasForeignKey(e => e.ChatId)
                .OnDelete(DeleteBehavior.Cascade);
                
            entity.HasOne(e => e.User)
                .WithMany(u => u.ChatParticipants)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });
        
        // Message configuration
        modelBuilder.Entity<Message>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.ChatId, e.CreatedAt });
            
            // CRITICAL: Unique index on ClientMessageId for idempotency
            // Filters out NULL values to allow messages without ClientMessageId
            entity.HasIndex(e => e.ClientMessageId)
                .IsUnique()
                .HasFilter("\"ClientMessageId\" IS NOT NULL");
            
            entity.HasOne(e => e.Chat)
                .WithMany(c => c.Messages)
                .HasForeignKey(e => e.ChatId)
                .OnDelete(DeleteBehavior.Cascade);
                
            entity.HasOne(e => e.Sender)
                .WithMany(u => u.Messages)
                .HasForeignKey(e => e.SenderId)
                .OnDelete(DeleteBehavior.Restrict);
        });
        
        // MessageStatusEvent configuration (Event Sourcing)
        modelBuilder.Entity<MessageStatusEvent>(entity =>
        {
            entity.HasKey(e => e.Id);
            
            // Index for querying events by message
            entity.HasIndex(e => new { e.MessageId, e.Timestamp });
            
            // Index for querying events by user (for group chat status aggregation)
            entity.HasIndex(e => new { e.UserId, e.Timestamp });
            
            entity.Property(e => e.Source).IsRequired().HasMaxLength(50);
            
            entity.HasOne(e => e.Message)
                .WithMany()
                .HasForeignKey(e => e.MessageId)
                .OnDelete(DeleteBehavior.Cascade);
                
            entity.HasOne(e => e.User)
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.SetNull);
        });
        
        // InviteLink configuration
        modelBuilder.Entity<InviteLink>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Code).IsUnique();
            entity.Property(e => e.Code).IsRequired().HasMaxLength(50);
            
            entity.HasOne(e => e.Creator)
                .WithMany(u => u.CreatedInviteLinks)
                .HasForeignKey(e => e.CreatedBy)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // FcmToken configuration
        modelBuilder.Entity<FcmToken>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.UserId, e.Token });
            entity.Property(e => e.Token).IsRequired().HasMaxLength(500);
            entity.Property(e => e.DeviceInfo).HasMaxLength(200);
            
            entity.HasOne(e => e.User)
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Contact configuration
        modelBuilder.Entity<Contact>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.UserId, e.PhoneNumberHash });
            entity.HasIndex(e => e.PhoneNumberHash); // For quick lookup
            entity.Property(e => e.PhoneNumberHash).IsRequired().HasMaxLength(64);
            entity.Property(e => e.DisplayName).HasMaxLength(100);
            
            entity.HasOne(e => e.User)
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // DeliveryReceipt configuration
        modelBuilder.Entity<DeliveryReceipt>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.MessageId, e.UserId }).IsUnique();
            entity.HasIndex(e => e.MessageId); // For quick lookup of all receipts for a message
            
            entity.HasOne(e => e.Message)
                .WithMany()
                .HasForeignKey(e => e.MessageId)
                .OnDelete(DeleteBehavior.Cascade);
                
            entity.HasOne(e => e.User)
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // PendingAck configuration
        modelBuilder.Entity<PendingAck>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.CreatedAt); // For cleanup queries
            entity.HasIndex(e => new { e.MessageId, e.RecipientUserId, e.Type }); // For finding pending acks
            
            entity.HasOne(e => e.Message)
                .WithMany()
                .HasForeignKey(e => e.MessageId)
                .OnDelete(DeleteBehavior.Cascade);
                
            entity.HasOne(e => e.RecipientUser)
                .WithMany()
                .HasForeignKey(e => e.RecipientUserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Poll configuration
        modelBuilder.Entity<Poll>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.MessageId).IsUnique();
            entity.Property(e => e.Question).IsRequired().HasMaxLength(500);
            
            entity.HasOne(e => e.Message)
                .WithOne(m => m.Poll)
                .HasForeignKey<Poll>(e => e.MessageId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // PollOption configuration
        modelBuilder.Entity<PollOption>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.PollId, e.Order });
            entity.Property(e => e.Text).IsRequired().HasMaxLength(200);
            
            entity.HasOne(e => e.Poll)
                .WithMany(p => p.Options)
                .HasForeignKey(e => e.PollId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // PollVote configuration
        modelBuilder.Entity<PollVote>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.PollOptionId, e.UserId }).IsUnique();
            
            entity.HasOne(e => e.PollOption)
                .WithMany(o => o.Votes)
                .HasForeignKey(e => e.PollOptionId)
                .OnDelete(DeleteBehavior.Cascade);
                
            entity.HasOne(e => e.User)
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}


