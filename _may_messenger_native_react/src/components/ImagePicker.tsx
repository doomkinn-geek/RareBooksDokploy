import React from 'react';
import { Alert } from 'react-native';
// import { launchImageLibrary } from 'react-native-image-picker';

interface ImagePickerProps {
  onImageSelected: (uri: string) => void;
}

const useImagePicker = (onImageSelected: (uri: string) => void) => {
  const pickImage = () => {
    // Simplified - actual implementation would use react-native-image-picker
    Alert.alert('Выбор изображения', 'Функция в разработке');
    // launchImageLibrary({ mediaType: 'photo' }, (response) => {
    //   if (response.assets && response.assets[0]) {
    //     onImageSelected(response.assets[0].uri);
    //   }
    // });
  };

  return { pickImage };
};

export default useImagePicker;

