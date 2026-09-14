import { StyleSheet, Text, View } from 'react-native';
import type { Article } from './articleContent';
import { ArticleFont, type ArticlePalette } from './articleTheme';

type Props = {
  article: Article;
  palette: ArticlePalette;
  gutter: number;
};

/**
 * The opening spread: kicker rule, display headline, deck and byline. It ends
 * on a hairline; the markdown body picks up directly below it with the hero
 * video, so the seam between app chrome and rendered markdown disappears.
 */
export function ArticleMasthead({ article, palette, gutter }: Props) {
  return (
    <View style={{ paddingHorizontal: gutter }}>
      <View style={styles.kickerRow}>
        <Text style={[styles.kicker, { color: palette.accent }]}>
          {article.kicker.toUpperCase()}
        </Text>
        <View style={[styles.hairline, { backgroundColor: palette.rule }]} />
      </View>

      <Text style={[styles.title, { color: palette.heading }]}>
        {article.title}
      </Text>

      <Text style={[styles.deck, { color: palette.muted }]}>
        {article.deck}
      </Text>

      <View style={styles.byline} accessible>
        <View
          style={[
            styles.monogram,
            {
              backgroundColor: palette.surface,
              borderColor: palette.rule,
            },
          ]}
        >
          <Text style={[styles.initials, { color: palette.accent }]}>
            {article.authorInitials}
          </Text>
        </View>
        <View style={styles.bylineText}>
          <Text style={[styles.author, { color: palette.heading }]}>
            {article.authorName}
          </Text>
          <Text style={[styles.meta, { color: palette.muted }]}>
            {article.publishedOn} · {article.readingTime}
          </Text>
        </View>
      </View>

      <View style={[styles.rule, { backgroundColor: palette.rule }]} />
    </View>
  );
}

const styles = StyleSheet.create({
  kickerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingTop: 18,
  },
  kicker: {
    fontFamily: ArticleFont.monoMedium,
    fontSize: 11,
    letterSpacing: 1.9,
  },
  hairline: {
    flex: 1,
    height: StyleSheet.hairlineWidth * 2,
  },
  title: {
    fontFamily: ArticleFont.display,
    fontSize: 48,
    lineHeight: 52,
    letterSpacing: -0.6,
    marginTop: 18,
  },
  deck: {
    fontFamily: ArticleFont.serifItalic,
    fontSize: 19,
    lineHeight: 28,
    marginTop: 14,
  },
  byline: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 13,
    marginTop: 26,
  },
  monogram: {
    width: 38,
    height: 38,
    borderRadius: 19,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  initials: {
    fontFamily: ArticleFont.monoMedium,
    fontSize: 12,
    letterSpacing: 0.5,
  },
  bylineText: {
    flex: 1,
    gap: 3,
  },
  author: {
    fontFamily: ArticleFont.monoMedium,
    fontSize: 13,
  },
  meta: {
    fontFamily: ArticleFont.mono,
    fontSize: 12,
  },
  rule: {
    height: 1,
    marginTop: 22,
    marginBottom: 26,
  },
});
