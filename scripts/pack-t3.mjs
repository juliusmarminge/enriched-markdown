import { execFileSync } from 'node:child_process';
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.join(root, 'packages/react-native-enriched-markdown');
const output = path.resolve(process.argv[2] ?? '.');
const git = (...args) =>
  execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
if (git('status', '--porcelain'))
  throw new Error('Commit source changes before packing the fork.');
if (!existsSync(path.join(source, 'lib/module/index.js')))
  throw new Error('Run yarn prepare before packing.');
const staging = mkdtempSync(path.join(tmpdir(), 'enriched-t3-pack-'));
try {
  const skip = new Set([
    'build',
    '.cxx',
    '.gradle',
    'Pods',
    'vendor',
    '__tests__',
    '__mocks__',
    '__fixtures__',
  ]);
  for (const entry of [
    'src',
    'lib',
    'android',
    'ios',
    'jest.js',
    'jest.d.ts',
    'react-native.config.js',
    'postinstall.mjs',
    'ReactNativeEnrichedMarkdown.podspec',
  ]) {
    const input = path.join(source, entry);
    if (existsSync(input))
      cpSync(input, path.join(staging, entry), {
        recursive: true,
        filter: (file) => !skip.has(path.basename(file)),
      });
  }
  cpSync(path.join(root, 'packages/core/cpp'), path.join(staging, 'cpp'), {
    recursive: true,
    filter: (file) =>
      !['grammars', 'tree-sitter', 'build'].includes(path.basename(file)),
  });
  for (const entry of ['gen-registry.mjs', 'grammar-versions.json'])
    cpSync(
      path.join(root, 'vendor', entry),
      path.join(staging, 'cpp/highlight', entry)
    );
  for (const entry of [
    'vendor-grammars.mjs',
    'vendor-ratex.mjs',
    'ratex-version.json',
  ])
    cpSync(path.join(root, 'vendor', entry), path.join(staging, entry));
  cpSync(path.join(root, 'LICENSE'), path.join(staging, 'LICENSE'));
  cpSync(path.join(root, 'docs-md'), path.join(staging, 'docs'), {
    recursive: true,
  });
  cpSync(path.join(source, 'docs'), path.join(staging, 'docs'), {
    recursive: true,
  });
  const pkg = JSON.parse(
    readFileSync(path.join(source, 'package.json'), 'utf8')
  );
  delete pkg.scripts.prepare;
  delete pkg.scripts.prepack;
  delete pkg.scripts.postpack;
  writeFileSync(
    path.join(staging, 'package.json'),
    JSON.stringify(pkg, null, 2) + '\n'
  );
  writeFileSync(
    path.join(staging, 't3-fork.json'),
    JSON.stringify(
      {
        repository: 'https://github.com/juliusmarminge/enriched-markdown',
        commit: git('rev-parse', 'HEAD'),
        upstreamCommit: '7afb1b0eb9b6f842e4853216adcb955aac187bac',
        version: pkg.version,
      },
      null,
      2
    ) + '\n'
  );
  mkdirSync(output, { recursive: true });
  execFileSync(
    'npm',
    ['pack', '--ignore-scripts', '--pack-destination', output],
    { cwd: staging, stdio: 'inherit' }
  );
} finally {
  rmSync(staging, { recursive: true, force: true });
}
