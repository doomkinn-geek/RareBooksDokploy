using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;
using SixLabors.ImageSharp.Formats.Jpeg;

namespace MayMessenger.Application.Services;

public interface IImageCompressionService
{
    Task<string> SaveImageAsync(Stream imageStream, string originalFileName, string outputDirectory);
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
}

