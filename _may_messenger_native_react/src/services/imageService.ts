import { launchCamera, launchImageLibrary, ImagePickerResponse } from 'react-native-image-picker';
import ImageResizer from 'react-native-image-resizer';

export interface ImageResult {
  uri: string;
  type: string;
  name: string;
}

export const imageService = {
  /**
   * Capture photo from camera
   */
  async capturePhoto(): Promise<ImageResult | null> {
    try {
      const result: ImagePickerResponse = await launchCamera({
        mediaType: 'photo',
        quality: 1,
        maxWidth: 1920,
        maxHeight: 1920,
        includeBase64: false,
      });

      if (result.didCancel || !result.assets || result.assets.length === 0) {
        return null;
      }

      const asset = result.assets[0];
      if (!asset.uri) {
        return null;
      }

      // Compress image
      const compressed = await this.compressImage(asset.uri);
      return compressed;
    } catch (error) {
      console.error('Failed to capture photo:', error);
      return null;
    }
  },

  /**
   * Pick photo from gallery
   */
  async pickPhoto(): Promise<ImageResult | null> {
    try {
      const result: ImagePickerResponse = await launchImageLibrary({
        mediaType: 'photo',
        quality: 1,
        maxWidth: 1920,
        maxHeight: 1920,
        includeBase64: false,
      });

      if (result.didCancel || !result.assets || result.assets.length === 0) {
        return null;
      }

      const asset = result.assets[0];
      if (!asset.uri) {
        return null;
      }

      // Compress image
      const compressed = await this.compressImage(asset.uri);
      return compressed;
    } catch (error) {
      console.error('Failed to pick photo:', error);
      return null;
    }
  },

  /**
   * Compress image to max 1920px and quality 0.8
   */
  async compressImage(uri: string): Promise<ImageResult> {
    try {
      const resized = await ImageResizer.createResizedImage(
        uri,
        1920,  // maxWidth
        1920,  // maxHeight
        'JPEG', // format
        80,    // quality (0-100)
        0,     // rotation
        undefined, // outputPath
        true,  // keepMeta
      );

      return {
        uri: resized.uri,
        type: 'image/jpeg',
        name: resized.name || `image_${Date.now()}.jpg`,
      };
    } catch (error) {
      console.error('Failed to compress image:', error);
      // Return original if compression fails
      return {
        uri,
        type: 'image/jpeg',
        name: `image_${Date.now()}.jpg`,
      };
    }
  },
};
