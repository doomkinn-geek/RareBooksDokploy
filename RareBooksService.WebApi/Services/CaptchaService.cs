using SixLabors.Fonts;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Drawing.Processing;
using SixLabors.ImageSharp.Processing;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Drawing.Processing;

namespace RareBooksService.WebApi.Services
{
    public interface ICaptchaService
    {
        (byte[] imageData, string captchaCode) GenerateCaptchaImage();
    }
    public class CaptchaService : ICaptchaService
    {
        private static readonly string chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz123456789";
        public (byte[] imageData, string captchaCode) GenerateCaptchaImage()
        {
            try
            {
                var random = new Random();
                //генерируем код из 5ти символов
                var code = new string(Enumerable.Repeat(chars, 5).Select(s => s[random.Next(s.Length)]).ToArray());                

                int width = 120;
                int height = 40;

                using var image = new Image<Rgba32>(width, height, new Rgba32(255, 255, 255));
                var fontCollection = new FontCollection();
                var fontFamily = fontCollection.Add("ARIALBD.TTF");
                var font = fontFamily.CreateFont(20, FontStyle.Bold);
                var textColor = new Rgba32(0, 0, 0);

                var textOptions = new RichTextOptions(font)
                {
                    VerticalAlignment = VerticalAlignment.Center,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    Origin = new PointF(width / 2, height / 2)
                };

                image.Mutate(x =>
                {
                    x.DrawText(textOptions, code, textColor);
                    //шум - несколько линий
                    for (int i = 0; i < 10; i++)
                    {
                        int x1 = random.Next(width);
                        int y1 = random.Next(height);
                        int x2 = random.Next(width);
                        int y2 = random.Next(height);

                        x.DrawLine(Color.Gray, (float)0.8, new PointF(x1, y1), new PointF(x2, y2));
                    }
                });

                using var ms = new MemoryStream();
                image.SaveAsPng(ms);
                var imageBytes = ms.ToArray();

                return (imageBytes, code);
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                return (new byte[255], "");
            }
        }
    }
}
