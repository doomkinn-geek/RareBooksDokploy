import React, { useEffect } from 'react';
import { StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  Easing,
} from 'react-native-reanimated';

interface AnimatedMessageBubbleProps {
  children: React.ReactNode;
  isOwnMessage: boolean;
}

const AnimatedMessageBubble: React.FC<AnimatedMessageBubbleProps> = ({
  children,
  isOwnMessage,
}) => {
  const scale = useSharedValue(0);
  const opacity = useSharedValue(0);
  const translateX = useSharedValue(isOwnMessage ? 50 : -50);

  useEffect(() => {
    // Animate in
    scale.value = withSpring(1, {
      damping: 15,
      stiffness: 150,
    });
    
    opacity.value = withTiming(1, {
      duration: 300,
      easing: Easing.out(Easing.ease),
    });
    
    translateX.value = withSpring(0, {
      damping: 20,
      stiffness: 90,
    });
  }, []);

  const animatedStyle = useAnimatedStyle(() => {
    return {
      transform: [
        { scale: scale.value },
        { translateX: translateX.value },
      ],
      opacity: opacity.value,
    };
  });

  return (
    <Animated.View style={[styles.container, animatedStyle]}>
      {children}
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginVertical: 4,
  },
});

export default AnimatedMessageBubble;

