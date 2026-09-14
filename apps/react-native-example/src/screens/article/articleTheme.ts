import { Platform } from 'react-native';
import type { MarkdownStyle } from 'react-native-enriched-markdown';

/**
 * Type families bundled for the Article screen (see `assets/fonts`).
 *
 * Instrument Serif is a display face and only appears in the headline, where
 * its hairlines survive. Spectral carries the prose — KaTeX-style math is set
 * in a Computer Modern-like serif, so serif body text lets formulas sit inside
 * a paragraph instead of looking pasted onto it. IBM Plex Mono handles the
 * small mechanical labels (kicker, byline, captions, table headers) and code.
 */
export const ArticleFont = {
  display: 'InstrumentSerif-Regular',
  displayItalic: 'InstrumentSerif-Italic',
  serif: 'Spectral-Regular',
  serifItalic: 'Spectral-Italic',
  serifSemibold: 'Spectral-SemiBold',
  mono: 'IBMPlexMono-Regular',
  monoMedium: 'IBMPlexMono-Medium',
} as const;

export type ArticleScheme = 'dark' | 'light';

/**
 * Observatory palette: near-black ink with one amber accent, in a dark cut
 * (the default — space footage wants a dark ground) and a cool-paper light cut.
 */
export type ArticlePalette = {
  scheme: ArticleScheme;
  /** Page ground. */
  paper: string;
  /** Raised-but-quiet ground: blockquotes, math blocks, table headers, chips. */
  surface: string;
  /** Alternating table rows — one step from `paper`, never two. */
  surfaceAlt: string;
  body: string;
  heading: string;
  muted: string;
  rule: string;
  /** Links, inline code, kicker — the one saturated color on the page. */
  accent: string;
  /** The accent where it decorates rather than signals: quote bar, bullets. */
  accentSoft: string;
  /** Marker wash behind a highlighted span, and the ink drawn over it. */
  highlight: string;
  highlightInk: string;
  /** Text selection wash. Android wants an opaque, lighter tint. */
  selection: string;
  codeText: string;
  codeBackground: string;
  codeBorder: string;
};

export const darkPalette: ArticlePalette = {
  scheme: 'dark',
  paper: '#0D0F14',
  surface: '#171A22',
  surfaceAlt: '#12151C',
  body: '#D3D2CB',
  heading: '#F3F0E8',
  muted: '#858B97',
  rule: '#232833',
  accent: '#E9B65C',
  accentSoft: '#C99A4E',
  highlight: '#3B2F13',
  highlightInk: '#F7E5BE',
  selection: Platform.OS === 'ios' ? 'rgba(233,182,92,0.35)' : '#4A3A18',
  codeText: '#D8DBE2',
  codeBackground: '#080A0E',
  codeBorder: '#1F2430',
};

export const lightPalette: ArticlePalette = {
  scheme: 'light',
  paper: '#F7F7F5',
  surface: '#ECEDEA',
  surfaceAlt: '#F1F1EE',
  body: '#26292F',
  heading: '#101216',
  muted: '#6B717C',
  rule: '#DFE1DE',
  accent: '#A5641C',
  accentSoft: '#C48A3F',
  highlight: '#F6E5C2',
  highlightInk: '#3E2A0C',
  selection: Platform.OS === 'ios' ? 'rgba(165,100,28,0.3)' : '#F3DFB5',
  codeText: '#26292F',
  codeBackground: '#EEEFEC',
  codeBorder: '#DFE1DE',
};

export function paletteForScheme(scheme: ArticleScheme): ArticlePalette {
  return scheme === 'dark' ? darkPalette : lightPalette;
}

type SyntaxColors = NonNullable<
  NonNullable<MarkdownStyle['codeBlock']>['syntaxColors']
>;

/** Token colors for the dark code ground. */
const darkSyntaxColors: SyntaxColors = {
  keyword: '#C9A3F5',
  operator: '#AEB4C0',
  punctuation: '#7F8592',
  string: '#9FD39B',
  number: '#F0A86B',
  constant: '#F0A86B',
  comment: '#646B78',
  function: '#8CC4F5',
  type: '#E9B65C',
  variable: '#D8DBE2',
  property: '#B7D3F0',
};

/** The same hues, deepened so they hold contrast on paper. */
const lightSyntaxColors: SyntaxColors = {
  keyword: '#6F42C1',
  operator: '#5A6170',
  punctuation: '#7A8090',
  string: '#2E7D32',
  number: '#B25E09',
  constant: '#B25E09',
  comment: '#8A909B',
  function: '#0B63C4',
  type: '#9A5A0E',
  variable: '#26292F',
  property: '#1F5F99',
};

const lh = (ios: number, android: number) =>
  Platform.select({ ios, android, default: android });

/**
 * The article's markdown theme: Spectral on a 30pt baseline, one amber accent,
 * native video players styled to sit flush with the text column.
 */
export function articleMarkdownStyle(p: ArticlePalette): MarkdownStyle {
  return {
    paragraph: {
      fontFamily: ArticleFont.serif,
      fontSize: 18,
      color: p.body,
      lineHeight: lh(30, 31),
      marginBottom: 20,
    },
    h1: {
      fontFamily: ArticleFont.display,
      fontSize: 34,
      color: p.heading,
      lineHeight: lh(41, 42),
      marginBottom: 12,
    },
    h2: {
      fontFamily: ArticleFont.serifSemibold,
      fontSize: 26,
      color: p.heading,
      lineHeight: lh(33, 34),
      marginTop: 40,
      marginBottom: 14,
    },
    h3: {
      fontFamily: ArticleFont.serifSemibold,
      fontSize: 20,
      color: p.heading,
      lineHeight: lh(27, 28),
      marginTop: 30,
      marginBottom: 8,
    },
    h4: {
      fontFamily: ArticleFont.serifSemibold,
      fontSize: 18,
      color: p.heading,
      lineHeight: lh(26, 27),
      marginBottom: 8,
    },
    h5: {
      fontFamily: ArticleFont.serifSemibold,
      fontSize: 16,
      color: p.heading,
      lineHeight: lh(24, 25),
      marginBottom: 8,
    },
    // h6 doubles as the figure caption: a small mono label under each video.
    h6: {
      fontFamily: ArticleFont.mono,
      fontSize: 12,
      color: p.muted,
      lineHeight: lh(18, 19),
      marginTop: 0,
      marginBottom: 28,
    },
    // Set in italic, so the bold lead-in of the abstract resolves to an
    // upright semibold against an italic run — the editorial convention.
    blockquote: {
      fontFamily: ArticleFont.serifItalic,
      fontSize: 18,
      color: p.body,
      lineHeight: lh(30, 31),
      borderColor: p.accentSoft,
      borderWidth: 2,
      backgroundColor: p.surface,
      gapWidth: 20,
      marginTop: 6,
      marginBottom: 26,
    },
    list: {
      fontFamily: ArticleFont.serif,
      fontSize: 18,
      color: p.body,
      lineHeight: lh(30, 31),
      bulletColor: p.accentSoft,
      bulletSize: 5,
      markerColor: p.muted,
      markerMinWidth: 20,
      gapWidth: 12,
      marginLeft: 20,
      marginBottom: 24,
    },
    table: {
      fontFamily: ArticleFont.serif,
      fontSize: 15,
      color: p.body,
      lineHeight: lh(24, 25),
      headerFontFamily: ArticleFont.monoMedium,
      headerBackgroundColor: p.surface,
      headerTextColor: p.heading,
      rowEvenBackgroundColor: p.surfaceAlt,
      rowOddBackgroundColor: p.paper,
      borderColor: p.rule,
      borderWidth: 1,
      borderRadius: 12,
      cellPaddingHorizontal: 14,
      cellPaddingVertical: 12,
      marginTop: 8,
      marginBottom: 28,
    },
    codeBlock: {
      fontFamily: ArticleFont.mono,
      fontSize: 13,
      color: p.codeText,
      backgroundColor: p.codeBackground,
      borderColor: p.codeBorder,
      borderWidth: 1,
      borderRadius: 14,
      padding: 18,
      lineHeight: lh(22, 23),
      marginTop: 6,
      marginBottom: 28,
      syntaxColors: p.scheme === 'dark' ? darkSyntaxColors : lightSyntaxColors,
    },
    code: {
      fontFamily: ArticleFont.mono,
      fontSize: 15,
      color: p.accent,
      backgroundColor: p.surface,
      borderColor: p.rule,
    },
    // Native players: AVPlayerViewController on iOS, ExoPlayer on Android.
    // 16:9 fills the column; the black ground shows only while a clip loads.
    video: {
      aspectRatio: 16 / 9,
      borderRadius: 14,
      backgroundColor: '#000000',
      marginTop: 4,
      marginBottom: 12,
    },
    image: {
      aspectRatio: 16 / 9,
      borderRadius: 14,
      marginTop: 4,
      marginBottom: 12,
    },
    link: {
      color: p.accent,
      underline: true,
    },
    strong: {
      fontFamily: ArticleFont.serifSemibold,
      fontWeight: 'normal',
      color: p.heading,
    },
    em: {
      fontFamily: ArticleFont.serifItalic,
      fontStyle: 'normal',
    },
    thematicBreak: {
      color: p.rule,
      height: 1,
      marginTop: 40,
      marginBottom: 32,
    },
    // Display math shares the blockquote's quiet ground, which also bounds the
    // region a long formula scrolls within.
    math: {
      fontSize: 19,
      color: p.heading,
      backgroundColor: p.surface,
      padding: 16,
      marginTop: 4,
      marginBottom: 20,
      textAlign: 'center',
    },
    inlineMath: {
      color: p.body,
    },
    // The wash is painted over the whole line box, so it stays close to the
    // paper; the ink does the emphasizing.
    highlight: {
      color: p.highlightInk,
      backgroundColor: p.highlight,
    },
  };
}
