# Resolving image sources

`resolveImageSource` optionally changes how native images download in
`flavor="github"` on iOS and Android. CommonMark and web do not support this API.
It receives image occurrences from the accepted native AST, including images in
lists, blockquotes, tables and links. It does not parse Markdown in JavaScript.

```tsx
const resolveImageSource = useCallback(async (asset: MarkdownMediaAsset) => {
  const source = await getDownloadSource(asset.url);
  return source ? { uri: source.uri, headers: source.headers } : null;
}, []);

<EnrichedMarkdownText
  markdown={markdown}
  flavor="github"
  resolveImageSource={resolveImageSource}
  imageRequestHeaders={{ Authorization: documentToken }}
/>
```

Omitting the callback keeps existing native behavior. Returning `null` selects
the original native source. While a callback is pending, throws, rejects, or
returns an empty URI, native rendering keeps its usual placeholder without
downloading the original URL. A changed callback or occurrence retries
resolution. There is no automatic retry after rejection.

Per-source headers override document `imageRequestHeaders` case-insensitively.
The effective URI and merged headers identify download and image-size caches.
Original URLs, alt text, titles, enclosing links, press events, accessibility and
selection exports remain semantic metadata. Resolved URIs are not copied into
Markdown or HTML exports.

Keep the callback stable with `useCallback` to reuse decisions. Each occurrence
resolves independently, even when URLs repeat. Up to four callbacks run at once
per component, including superseded promises until they settle. Width and style
changes reuse the result. Markdown edits and parser changes start a new document
revision and discard old results. Changed source identity and callback changes also discard old results.
Unmounted and superseded completions cannot update native sources. The callback
has no cancellation signal, so applications own any network cancellation.
