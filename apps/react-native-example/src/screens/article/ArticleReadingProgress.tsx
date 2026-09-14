import { Animated, StyleSheet, View } from 'react-native';
import type { ArticlePalette } from './articleTheme';

type Props = {
  /** Scroll offset of the article, driven on the native thread. */
  scrollY: Animated.Value;
  /** Total scrollable distance; the bar is full once this has been travelled. */
  scrollable: number;
  palette: ArticlePalette;
};

/** Hairline reading indicator pinned under the navigation bar. */
export function ArticleReadingProgress({
  scrollY,
  scrollable,
  palette,
}: Props) {
  const scaleX = scrollY.interpolate({
    inputRange: [0, Math.max(scrollable, 1)],
    outputRange: [0, 1],
    extrapolate: 'clamp',
  });

  return (
    <View
      style={[styles.track, { backgroundColor: palette.rule }]}
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    >
      <Animated.View
        style={[
          styles.fill,
          { backgroundColor: palette.accent, transform: [{ scaleX }] },
        ]}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  track: {
    height: 2,
    width: '100%',
  },
  fill: {
    height: 2,
    width: '100%',
    transformOrigin: 'left',
  },
});
