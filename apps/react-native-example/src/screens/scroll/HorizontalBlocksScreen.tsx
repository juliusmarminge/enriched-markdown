import { ScrollView, Text, View, StyleSheet } from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const CODE =
  '```typescript\nconst message = "A long code line makes the native code block scroll horizontally across the screen.";\nconsole.log(message);\n```';
const TABLE =
  '| First | Second | Third | Fourth |\n| --- | --- | --- | --- |\n| A wide first column of text | A wide second column of text | A wide third column of text | A wide fourth column of text |';
const MATH =
  '$$\\underbrace{a+b+c+d+e+f+g+h+i+j+k+l+m+n+o+p+q+r+s+t+u+v+w+x+y+z}_{\\text{a wide equation}}$$';

export default function HorizontalBlocksScreen() {
  return (
    <ScrollView
      contentContainerStyle={styles.content}
      testID="horizontal-blocks-screen"
    >
      <Text style={styles.instructions}>
        Scroll a block inward, then back to its left edge: it keeps its bounce.
        After it settles, a new rightward swipe goes back.
      </Text>
      {[
        { label: 'Code', markdown: CODE },
        { label: 'Table', markdown: TABLE },
        { label: 'Math', markdown: MATH },
      ].map(({ label, markdown }) => (
        <View key={label} testID={`horizontal-${label.toLowerCase()}`}>
          <Text style={styles.label}>{label}</Text>
          <EnrichedMarkdownText
            markdown={markdown}
            flavor="github"
            markdownStyle={{
              codeBlock: { fontSize: 16, backgroundColor: '#f3f4f6' },
              table: { cellPaddingHorizontal: 12, cellPaddingVertical: 8 },
              math: { fontSize: 20 },
            }}
          />
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { padding: 16, gap: 24 },
  instructions: { fontSize: 15, color: '#374151' },
  label: { fontSize: 17, fontWeight: '600', marginBottom: 8 },
});
