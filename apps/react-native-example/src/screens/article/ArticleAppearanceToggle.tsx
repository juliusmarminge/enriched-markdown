import { Pressable, StyleSheet } from 'react-native';
import Svg, { Circle, Line, Path } from 'react-native-svg';
import type { ArticlePalette } from './articleTheme';

type Props = {
  palette: ArticlePalette;
  onPress: () => void;
};

/**
 * Inverted-ink disc in the bottom-right corner, kept clear of the text column
 * so a tap during a demo never lands on a link or a video.
 */
export function ArticleAppearanceToggle({ palette, onPress }: Props) {
  const isDark = palette.scheme === 'dark';

  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={isDark ? 'Switch to light' : 'Switch to dark'}
      testID="article-appearance-toggle"
      style={({ pressed }) => [
        styles.disc,
        {
          backgroundColor: palette.heading,
          borderColor: palette.paper,
          shadowOpacity: isDark ? 0.55 : 0.18,
          transform: [{ scale: pressed ? 0.94 : 1 }],
        },
      ]}
    >
      {isDark ? (
        <SunIcon color={palette.paper} />
      ) : (
        <MoonIcon color={palette.paper} />
      )}
    </Pressable>
  );
}

function SunIcon({ color }: { color: string }) {
  const rays = Array.from({ length: 8 }, (_, i) => (i * Math.PI) / 4);
  return (
    <Svg width={18} height={18} viewBox="0 0 24 24">
      <Circle cx={12} cy={12} r={4.2} fill={color} />
      {rays.map((a) => (
        <Line
          key={a}
          x1={12 + Math.cos(a) * 7.2}
          y1={12 + Math.sin(a) * 7.2}
          x2={12 + Math.cos(a) * 10}
          y2={12 + Math.sin(a) * 10}
          stroke={color}
          strokeWidth={2}
          strokeLinecap="round"
        />
      ))}
    </Svg>
  );
}

function MoonIcon({ color }: { color: string }) {
  return (
    <Svg width={18} height={18} viewBox="0 0 24 24">
      <Path d="M14.5 2.5a9.5 9.5 0 1 0 7 14.9 8 8 0 0 1-7-14.9z" fill={color} />
    </Svg>
  );
}

const styles = StyleSheet.create({
  disc: {
    position: 'absolute',
    right: 20,
    bottom: 28,
    width: 46,
    height: 46,
    borderRadius: 23,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 6 },
    elevation: 8,
  },
});
