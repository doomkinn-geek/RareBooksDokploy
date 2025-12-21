import React from 'react';
import { View, StyleSheet, Text } from 'react-native';

interface AvatarProps {
  name: string;
  size?: number;
  userId?: string;
}

const Avatar: React.FC<AvatarProps> = ({ name, size = 40, userId }) => {
  // Get first letter of name
  const initial = name ? name.charAt(0).toUpperCase() : '?';
  
  // Generate color based on userId or name
  const colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#FFA07A', 
    '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E2',
    '#F8B195', '#6C5B7B'
  ];
  
  const hashCode = (str: string): number => {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      hash = str.charCodeAt(i) + ((hash << 5) - hash);
    }
    return Math.abs(hash);
  };
  
  const colorIndex = hashCode(userId || name) % colors.length;
  const backgroundColor = colors[colorIndex];

  return (
    <View 
      style={[
        styles.container, 
        { 
          width: size, 
          height: size, 
          borderRadius: size / 2,
          backgroundColor 
        }
      ]}
    >
      <Text style={[styles.initial, { fontSize: size / 2 }]}>
        {initial}
      </Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  initial: {
    color: 'white',
    fontWeight: 'bold',
  },
});

export default Avatar;

