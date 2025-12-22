# PWA Icons

Place the following icon files in the `/public` directory:

- `icon-72.png` (72x72px)
- `icon-96.png` (96x96px)
- `icon-128.png` (128x128px)
- `icon-144.png` (144x144px)
- `icon-152.png` (152x152px)
- `icon-192.png` (192x192px)
- `icon-384.png` (384x384px)
- `icon-512.png` (512x512px)

## Generating Icons

You can generate these from a single source image using tools like:
- [PWA Asset Generator](https://github.com/onderceylan/pwa-asset-generator)
- [RealFaviconGenerator](https://realfavicongenerator.net/)
- [App Icon Generator](https://appicon.co/)

## Quick Command (if you have ImageMagick):

```bash
# From a 512x512 source icon:
convert icon-512.png -resize 72x72 icon-72.png
convert icon-512.png -resize 96x96 icon-96.png
convert icon-512.png -resize 128x128 icon-128.png
convert icon-512.png -resize 144x144 icon-144.png
convert icon-512.png -resize 152x152 icon-152.png
convert icon-512.png -resize 192x192 icon-192.png
convert icon-512.png -resize 384x384 icon-384.png
```

