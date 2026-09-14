import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  Alert,
  Animated,
  Linking,
  StatusBar,
  StyleSheet,
  View,
  type LayoutChangeEvent,
} from 'react-native';
import {
  EnrichedMarkdownText,
  type LatexErrorEvent,
  type LinkPressEvent,
} from 'react-native-enriched-markdown';
import type { RootStackScreenProps } from '../../navigation/types';
import { featuredArticle } from './articleContent';
import {
  ArticleFont,
  articleMarkdownStyle,
  paletteForScheme,
  type ArticleScheme,
} from './articleTheme';
import { ArticleMasthead } from './ArticleMasthead';
import { ArticleColophon } from './ArticleColophon';
import { ArticleReadingProgress } from './ArticleReadingProgress';
import { ArticleAppearanceToggle } from './ArticleAppearanceToggle';

type Props = RootStackScreenProps<'Article'>;

/** Text column margin. */
const GUTTER = 24;

/** The light/dark toggle in the corner; off for a dark-only recording. */
const SHOW_APPEARANCE_TOGGLE = false;

/**
 * Long-form article rendered from a single markdown string — prose, LaTeX
 * math, two native video players, a table and a code block — to show the
 * library carrying a real document rather than a feature checklist.
 *
 * The masthead and the colophon are React Native; everything between them is
 * one `EnrichedMarkdownText` on the same ground and the same 30pt baseline.
 * The hero figure is the first block of the markdown, so the video player
 * itself is what hands the masthead off to the body.
 */
export default function ArticleScreen({ navigation }: Props) {
  const article = featuredArticle;

  // Dark by default: the clips are space footage and want a dark ground. The
  // toggle in the corner flips to the light cut for the second half of a demo.
  const [scheme, setScheme] = useState<ArticleScheme>('dark');
  const palette = useMemo(() => paletteForScheme(scheme), [scheme]);
  const markdownStyle = useMemo(() => articleMarkdownStyle(palette), [palette]);

  const scrollY = useRef(new Animated.Value(0)).current;
  const [contentHeight, setContentHeight] = useState(0);
  const [viewportHeight, setViewportHeight] = useState(0);
  const scrollable = Math.max(contentHeight - viewportHeight, 0);

  // Masthead fades and rises into place on first appearance.
  const appear = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.timing(appear, {
      toValue: 1,
      duration: 450,
      delay: 60,
      useNativeDriver: true,
    }).start();
  }, [appear]);

  // The running head takes over once the printed headline has scrolled off.
  const runningTitleOpacity = useMemo(
    () =>
      scrollY.interpolate({
        inputRange: [110, 170],
        outputRange: [0, 1],
        extrapolate: 'clamp',
      }),
    [scrollY]
  );

  useLayoutEffect(() => {
    navigation.setOptions({
      headerStyle: { backgroundColor: palette.paper },
      headerTintColor: palette.accent,
      headerShadowVisible: false,
      // React Navigation's API for a custom title is a render function.
      // eslint-disable-next-line react/no-unstable-nested-components
      headerTitle: () => (
        <Animated.Text
          numberOfLines={1}
          style={[
            styles.runningTitle,
            { color: palette.heading, opacity: runningTitleOpacity },
          ]}
        >
          {article.title}
        </Animated.Text>
      ),
    });
  }, [navigation, palette, runningTitleOpacity, article.title]);

  const onScroll = useMemo(
    () =>
      Animated.event([{ nativeEvent: { contentOffset: { y: scrollY } } }], {
        useNativeDriver: true,
      }),
    [scrollY]
  );

  const onViewportLayout = useCallback((event: LayoutChangeEvent) => {
    setViewportHeight(event.nativeEvent.layout.height);
  }, []);

  const onContentSizeChange = useCallback((_width: number, height: number) => {
    setContentHeight(height);
  }, []);

  const handleLinkPress = useCallback(({ url }: LinkPressEvent) => {
    Alert.alert('Link Pressed!', `You tapped on: ${url}`, [
      { text: 'Open in Browser', onPress: () => Linking.openURL(url) },
      { text: 'Cancel', style: 'cancel' },
    ]);
  }, []);

  const handleLatexError = useCallback(
    ({ source, message }: LatexErrorEvent) => {
      console.warn(`[Article] LaTeX failed to render: ${message}\n${source}`);
    },
    []
  );

  const toggleScheme = useCallback(() => {
    setScheme((current) => (current === 'dark' ? 'light' : 'dark'));
  }, []);

  return (
    <View
      style={[styles.screen, { backgroundColor: palette.paper }]}
      testID="article-screen"
    >
      <StatusBar
        barStyle={scheme === 'dark' ? 'light-content' : 'dark-content'}
      />

      <ArticleReadingProgress
        scrollY={scrollY}
        scrollable={scrollable}
        palette={palette}
      />

      <Animated.ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        onScroll={onScroll}
        scrollEventThrottle={16}
        onLayout={onViewportLayout}
        onContentSizeChange={onContentSizeChange}
        showsVerticalScrollIndicator={false}
        contentInsetAdjustmentBehavior="never"
      >
        <Animated.View
          style={{
            opacity: appear,
            transform: [
              {
                translateY: appear.interpolate({
                  inputRange: [0, 1],
                  outputRange: [12, 0],
                }),
              },
            ],
          }}
        >
          <ArticleMasthead
            article={article}
            palette={palette}
            gutter={GUTTER}
          />
        </Animated.View>

        <View style={styles.body}>
          <EnrichedMarkdownText
            flavor="github"
            markdown={article.body}
            markdownStyle={markdownStyle}
            md4cFlags={{ highlight: true }}
            onLinkPress={handleLinkPress}
            onLatexError={handleLatexError}
            selectionColor={palette.selection}
            selectionHandleColor={palette.accent}
          />
        </View>

        <ArticleColophon palette={palette} gutter={GUTTER} />
      </Animated.ScrollView>

      {/* Hidden while the demo is dark-only; flip to true to expose the light cut. */}
      {SHOW_APPEARANCE_TOGGLE && (
        <ArticleAppearanceToggle palette={palette} onPress={toggleScheme} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
  },
  scroll: {
    flex: 1,
  },
  content: {
    paddingBottom: 96,
  },
  body: {
    paddingHorizontal: GUTTER,
    paddingBottom: 8,
  },
  runningTitle: {
    fontFamily: ArticleFont.serif,
    fontSize: 17,
  },
});
