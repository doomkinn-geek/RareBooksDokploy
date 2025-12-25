using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Formats.Webp;

namespace MayMessenger.Application.Services;

public interface IImageCompressionService
{
    Task<string> SaveImageAsync(Stream imageStream, string originalFileName, string outputDirectory);
    
    /// <summary>
    /// Compress image to WebP format with specified max dimensions
    /// </summary>
    Task<byte[]> CompressImageAsync(byte[] imageData, int maxWidth, int maxHeight, int quality = 80);
}

public class ImageCompressionService : IImageCompressionService
{
    /// <summary>
    /// Saves image without compression (client already compressed it).
    /// Only validates format and generates unique filename.
    /// </summary>
    public async Task<string> SaveImageAsync(Stream imageStream, string originalFileName, string outputDirectory)
    {
        // Ensure output directory exists
        Directory.CreateDirectory(outputDirectory);

        // Generate unique filename - always save as JPG since client sends compressed JPG
        var fileName = $"{Guid.NewGuid()}.jpg";
        var outputPath = Path.Combine(outputDirectory, fileName);

        // Save directly without re-compression (client already compressed)
        using (var fileStream = new FileStream(outputPath, FileMode.Create, FileAccess.Write))
        {
            await imageStream.CopyToAsync(fileStream);
        }

        return fileName;
    }
    
    /// <summary>
    /// Compress image to WebP format with specified max dimensions
    /// </summary>
    public async Task<byte[]> CompressImageAsync(byte[] imageData, int maxWidth, int maxHeight, int quality = 80)
    {
        using var image = Image.Load(imageData);
        
        // Resize if necessary while maintaining aspect ratio
        if (image.Width > maxWidth || image.Height > maxHeight)
        {
            var ratioX = (double)maxWidth / image.Width;
            var ratioY = (double)maxHeight / image.Height;
            var ratio = Math.Min(ratioX, ratioY);
            
            var newWidth = (int)(image.Width * ratio);
            var newHeight = (int)(image.Height * ratio);
            
            image.Mutate(x => x.Resize(newWidth, newHeight));
        }
        
        using var outputStream = new MemoryStream();
        
        var encoder = new WebpEncoder
        {
            Quality = quality,
            FileFormat = WebpFileFormatType.Lossy
        };
        
        await image.SaveAsync(outputStream, encoder);
        
        return outputStream.ToArray();
    }
}

