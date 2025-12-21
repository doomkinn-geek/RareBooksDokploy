using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;
using SixLabors.ImageSharp.Formats.Jpeg;

namespace MayMessenger.Application.Services;

public interface IImageCompressionService
{
    Task<string> CompressAndSaveImageAsync(Stream imageStream, string originalFileName, string outputDirectory);
}

public class ImageCompressionService : IImageCompressionService
{
    private const int MaxWidth = 1920;
    private const int MaxHeight = 1920;
    private const int JpegQuality = 85;

    public async Task<string> CompressAndSaveImageAsync(Stream imageStream, string originalFileName, string outputDirectory)
    {
        // Ensure output directory exists
        Directory.CreateDirectory(outputDirectory);

        // Generate unique filename
        var extension = Path.GetExtension(originalFileName).ToLowerInvariant();
        var fileName = $"{Guid.NewGuid()}.jpg"; // Always save as JPEG for consistency and compression
        var outputPath = Path.Combine(outputDirectory, fileName);

        using (var image = await Image.LoadAsync(imageStream))
        {
            // Calculate new dimensions while maintaining aspect ratio
            var originalWidth = image.Width;
            var originalHeight = image.Height;

            if (originalWidth > MaxWidth || originalHeight > MaxHeight)
            {
                var ratioX = (double)MaxWidth / originalWidth;
                var ratioY = (double)MaxHeight / originalHeight;
                var ratio = Math.Min(ratioX, ratioY);

                var newWidth = (int)(originalWidth * ratio);
                var newHeight = (int)(originalHeight * ratio);

                image.Mutate(x => x.Resize(newWidth, newHeight));
            }

            // Save with JPEG compression
            var encoder = new JpegEncoder
            {
                Quality = JpegQuality
            };

            await image.SaveAsJpegAsync(outputPath, encoder);
        }

        return fileName;
    }
}

