#!/usr/bin/env python3
"""Refresh reviewed plugin snapshots, or verify their recorded content hashes."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

root = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true')
parser.add_argument('--neorg-view', type=Path)
parser.add_argument('--youtube-repository', type=Path)
args = parser.parse_args()
manifest_path = root / 'sources.json'
previous = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'sources': {}}

def files(folder):
    return {str(p.relative_to(folder)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(folder.rglob('*')) if p.is_file() and p.name != 'tags'}

if args.check:
    for name, expected in previous['sources'].items():
        assert files(root / 'sources' / name) == expected, f'Snapshot differs: {name}'
    print('Plugin source snapshots match their manifest.')
else:
    if not args.neorg_view or not args.youtube_repository:
        parser.error('Both source paths are required when refreshing snapshots')
    snapshots = {
        'neorg-view.nvim': {
            str(p.relative_to(args.neorg_view)): p
            for base in ['lua', 'tests', 'doc', 'integration']
            for p in (args.neorg_view / base).rglob('*') if p.is_file() and p.name != 'tags'
        },
        'youtube-notes.nvim': {
            str(p.relative_to(args.youtube_repository / 'nvim/youtube-notes')): p
            for p in (args.youtube_repository / 'nvim/youtube-notes/lua').rglob('*.lua')
        },
    }
    for name in ['README.md', 'LICENSE', 'Makefile']:
        snapshots['neorg-view.nvim'][name] = args.neorg_view / name
    for name in ['youtube-notes.mjs', 'youtube-documents.mjs', 'youtube-workspace.mjs',
                 'youtube-notes-structure.mjs', 'notes-index.mjs', 'norg-table.mjs',
                 'youtube-notes.test.mjs', 'youtube-dashboard.test.lua']:
        snapshots['youtube-notes.nvim']['scripts/' + name] = args.youtube_repository / 'scripts' / name
    # The packaged YouTube README/license describe this distribution and are
    # maintained here. The source checkout does not carry its desktop bootstrap.
    for name, source_files in snapshots.items():
        folder = root / 'sources' / name
        for relative in previous['sources'].get(name, {}):
            if relative not in source_files and not (name == 'youtube-notes.nvim' and relative in ['README.md', 'LICENSE', 'Makefile']):
                (folder / relative).unlink(missing_ok=True)
        for relative, source in source_files.items():
            dest = folder / relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest)
    manifest_path.write_text(json.dumps({'version': 1, 'sources': {
        name: files(root / 'sources' / name) for name in snapshots
    }}, indent=2) + '\n')
    print('Refreshed snapshots. Review the diff, then build and test the editor.')
