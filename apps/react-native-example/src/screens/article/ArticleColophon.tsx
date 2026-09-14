import { Image, StyleSheet, Text, View } from 'react-native';
import { ArticleFont, type ArticlePalette } from './articleTheme';

type Props = {
  palette: ArticlePalette;
  gutter: number;
};

/** Foot of the page: a rule, the library's mark, and one line on what was rendered. */
export function ArticleColophon({ palette, gutter }: Props) {
  return (
    <View style={[styles.container, { paddingHorizontal: gutter }]}>
      <View style={[styles.rule, { backgroundColor: palette.rule }]} />
      <View style={styles.row}>
        {/* The mark is navy on green; on the dark ground it sits on a paper
            badge so the brace stays visible, exactly as it reads in light. */}
        <View
          style={[
            styles.badge,
            palette.scheme === 'dark' && styles.badgeOnDark,
          ]}
        >
          <Image
            source={require('../../assets/logo_icon.png')}
            style={styles.mark}
            resizeMode="contain"
          />
        </View>
        <View style={styles.text}>
          <Text style={[styles.label, { color: palette.heading }]}>
            ENRICHED MARKDOWN
          </Text>
          <Text style={[styles.note, { color: palette.muted }]}>
            Prose, LaTeX, native video, tables and code — one markdown source,
            rendered natively on iOS, macOS, Android and Web.
          </Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 18,
  },
  rule: {
    height: 1,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 13,
  },
  badge: {
    width: 36,
    height: 36,
    borderRadius: 9,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badgeOnDark: {
    backgroundColor: '#F7F7F5',
  },
  mark: {
    width: 26,
    height: 24,
  },
  text: {
    flex: 1,
    gap: 5,
  },
  label: {
    fontFamily: ArticleFont.monoMedium,
    fontSize: 11,
    letterSpacing: 1.7,
  },
  note: {
    fontFamily: ArticleFont.mono,
    fontSize: 12,
    lineHeight: 18,
  },
});
