import { createHash } from 'node:crypto';
import { existsSync, lstatSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const names = { plan: 'plan', documents: 'documents', catalog: 'catalog', state: 'ownership' };
export const dataPath = (root, name) => path.join(root, 'youtube/.state', names[name] + '.norg');
export function readData(file) {
  const text = readFileSync(file, 'utf8');
  const block = /^@code json\n([\s\S]*?)\n@end\s*$/m.exec(text);
  return JSON.parse(file.endsWith('.norg') ? (block?.[1] ?? (() => { throw new Error('Invalid workspace data: ' + file); })()) : text);
}
function safe(file) {
  // Shared state is always regular files, never links into another workspace.
  for (let p = file; p !== path.dirname(p); p = path.dirname(p)) {
    try { if (lstatSync(p).isSymbolicLink()) throw new Error('Refusing workspace data symlink: ' + p); }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
}
export function writeData(file, value) {
  safe(file);
  let text = JSON.stringify(value, null, 2) + '\n';
  if (file.endsWith('.norg')) text = '@document.meta\ntitle: YouTube workspace data\n@end\n\n@code json\n' + text + '@end\n';
  if (existsSync(file) && readFileSync(file, 'utf8') === text) return;
  mkdirSync(path.dirname(file), { recursive: true });
  const temporary = file + '.' + process.pid + '.tmp';
  try { writeFileSync(temporary, text, { mode: 0o600 }); renameSync(temporary, file); }
  finally { rmSync(temporary, { force: true }); }
}
export function workspaceRoot(repoRoot) {
  if (existsSync(dataPath(repoRoot, 'catalog'))) return repoRoot;
  const pointer = path.join(repoRoot, 'private/work/youtube-notes/workspace.json');
  if (!existsSync(pointer)) return null;
  const root = readData(pointer).notesRoot;
  if (typeof root !== 'string' || !path.isAbsolute(root) || !existsSync(dataPath(root, 'catalog')))
    throw new Error('The shared YouTube notes workspace is unavailable; restore its notes checkout.');
  return root;
}
export const isReplica = (root) => workspaceRoot(root) === root;
export function metadataPath(repoRoot, name) {
  const root = workspaceRoot(repoRoot);
  return root ? dataPath(root, name) : path.join(repoRoot, name === 'state' ? 'private/work/youtube-notes/state.json' : `config/youtube-${name}.json`);
}
export function lockRoot(repoRoot) {
  const root = workspaceRoot(repoRoot);
  if (!root) return path.join(repoRoot, 'private/work/youtube-notes');
  return path.join(tmpdir(), 'youtube-notes-' + (process.getuid?.() ?? 'user') + '-' + createHash('sha256').update(root).digest('hex').slice(0, 20));
}
export function readCatalog(root) {
  const value = readData(dataPath(root, 'catalog'));
  if (value.version !== 1 || !Array.isArray(value.productions) || !Array.isArray(value.files)) throw new Error('Unsupported shared catalog');
  const files = new Map(value.files.map(file => {
    if (!file.source?.startsWith('docs/video-scripts/') || file.source.split('/').includes('..') || !file.note?.startsWith('youtube/') || file.note.split('/').includes('..')) throw new Error('Invalid shared catalog path');
    return [file.source, { ...file, absolute: path.join(root, file.source), text: '' }];
  }));
  const productions = new Map(value.productions.map(item => [item.id, { ...item, files: item.sources.map(source => {
    if (!files.has(source)) throw new Error('Missing shared catalog source: ' + source);
    return files.get(source);
  }) }]));
  return { files, productions };
}
export function publishCatalog(root, catalog, sourceTime, wordCount) {
  const files = [...catalog.files.values()].map(({ absolute, text, ...file }) => ({ ...file, updatedAt: sourceTime([{ absolute }]), words: wordCount(text) }));
  const productions = [...catalog.productions.values()].map(({ files, ...item }) => ({ ...item, sources: files.map(file => file.source) }));
  writeData(dataPath(root, 'catalog'), { version: 1, productions, files });
}
