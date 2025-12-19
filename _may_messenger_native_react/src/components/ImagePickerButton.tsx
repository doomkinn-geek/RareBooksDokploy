import React from 'react';
import { Alert, Platform } from 'react-native';
import { IconButton } from 'react-native-paper';
import { launchImageLibrary, ImageLibraryOptions } from 'react-native-image-picker';
import { PermissionsAndroid } from 'react-native';

interface ImagePickerButtonProps {
  onImageSelected: (uri: string, fileName: string) => void;
}

const ImagePickerButton: React.FC<ImagePickerButtonProps> = ({ onImageSelected }) => {
  const requestPermissions = async () => {
    if (Platform.OS === 'android') {
      try {
        const granted = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
          {
            title: 'Доступ к фото',
            message: 'Приложению нужен доступ к вашим фото',
            buttonNeutral: 'Спросить позже',
            buttonNegative: 'Отмена',
            buttonPositive: 'OK',
          },
        );
        return granted === PermissionsAndroid.RESULTS.GRANTED;
      } catch (err) {
        console.warn(err);
        return false;
      }
    }
    return true;
  };

  const pickImage = async () => {
    const hasPermission = await requestPermissions();
    if (!hasPermission) {
      Alert.alert('Ошибка', 'Нет доступа к фото');
      return;
    }

    // Настройки сжатия изображения перед отправкой
    const options: ImageLibraryOptions = {
      mediaType: 'photo',
      quality: 0.7, // Сжатие до 70% качества (баланс качество/размер)
      maxWidth: 1920, // Максимальная ширина
      maxHeight: 1920, // Максимальная высота
      includeBase64: false, // Не нужна base64 для экономии памяти
      selectionLimit: 1, // Только одно изображение за раз
    };

    launchImageLibrary(options, (response) => {
      if (response.didCancel) {
        console.log('User cancelled image picker');
      } else if (response.errorCode) {
        console.log('ImagePicker Error: ', response.errorMessage);
        Alert.alert('Ошибка', 'Не удалось выбрать изображение');
      } else if (response.assets && response.assets[0]) {
        const asset = response.assets[0];
        
        // Проверка размера файла (макс 10MB после сжатия)
        if (asset.fileSize && asset.fileSize > 10 * 1024 * 1024) {
          Alert.alert(
            'Файл слишком большой',
            'Размер изображения не должен превышать 10 МБ. Попробуйте выбрать другое изображение.',
          );
          return;
        }
        
        if (asset.uri && asset.fileName) {
          console.log(`Image selected: ${asset.fileName}, size: ${(asset.fileSize || 0) / 1024} KB`);
          onImageSelected(asset.uri, asset.fileName);
        }
      }
    });
  };

  return (
    <IconButton
      icon="image"
      size={24}
      onPress={pickImage}
      iconColor="#2196F3"
    />
  );
};

export default ImagePickerButton;

