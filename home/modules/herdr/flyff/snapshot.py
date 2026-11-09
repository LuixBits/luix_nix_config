"""Create a source-only, provenance-recorded Flyff development repository."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


OMIT_DIRS = {'.git', 'node_modules', 'quarantine', 'private', 'bin', 'obj',
             'build', '.svelte-kit', '__pycache__', 'evidence', 'work', 'runtime',
             'backups', 'secrets', 'graphify-out', '.cache', '.venv'}
OMIT_ROOTS = {'artifacts'}
OMIT_EXT = {'.log', '.sqlite', '.db', '.sqlite-wal', '.sqlite-shm', '.key', '.pem',
            '.pfx', '.p12', '.bak', '.dmp', '.zip', '.7z', '.tar', '.gz', '.exe',
            '.dll', '.so', '.pyc', '.png', '.woff2'}
TEXT_EXT = {'.md', '.json', '.py', '.cs', '.mjs', '.csv', '.ts', '.patch', '.svelte',
            '.go', '.txt', '.css', '.sql', '.svg', '.csproj', '.yaml', '.nix', '.sln',
            '.ps1', '.html', '.inc', '.rgn', '.wld', '.yml', '.lua', '.desktop',
            '.fragment', '.sh', '.mod', '.h', '.toml', '.props', '.targets', '.config'}


def exclusion(rel):
    parts = rel.parts
    if parts[0] in OMIT_ROOTS or any(p in OMIT_DIRS for p in parts):
        return 'runtime, generated, or evidence directory'
    name = rel.name.lower()
    if name.startswith('.env') and name != '.env.example':
        return 'private environment'
    if any(word in name for word in ('credential', 'secret', 'actual-client-profile')):
        return 'credential or live-profile filename'
    # Website assets are authored inputs. Other binary assets stay in the intake.
    if parts[:2] == ('website', 'static') and rel.suffix in {'.png', '.woff2', '.ico', '.webp', '.jpg'}:
        return None
    if rel.suffix.lower() in OMIT_EXT:
        return 'runtime/binary extension'
    if parts[:2] == ('server', 'lab') and rel.suffix != '.md':
        return 'live lab configuration/state'
    if rel.suffix.lower() not in TEXT_EXT and name not in {
        '.gitignore', '.editorconfig', '.env.example', 'license',
        'dockerfile', 'makefile', 'justfile', 'nuget.config', 'global.json'}:
        return 'unclassified input'
    return None


def create(source, destination):
    source, destination = Path(source).resolve(), Path(destination).resolve()
    if destination.exists():
        raise RuntimeError(f'Refusing to replace existing baseline: {destination}')
    destination.mkdir(parents=True)
    included, omitted, hashes = [], [], {}
    try:
        for parent, dirs, files in os.walk(source):
            relparent = Path(parent).relative_to(source)
            for d in list(dirs):
                rel = relparent / d
                if d in OMIT_DIRS or rel.parts[0] in OMIT_ROOTS or (source / rel).is_symlink():
                    dirs.remove(d)
                    omitted.append({'path': str(rel) + '/', 'reason': 'excluded directory'})
            for name in sorted(files):
                rel = relparent / name
                src = source / rel
                reason = 'symlink' if src.is_symlink() else exclusion(rel)
                if reason:
                    omitted.append({'path': str(rel), 'reason': reason})
                    continue
                data = src.read_bytes()
                if len(data) > 8_000_000:
                    omitted.append({'path': str(rel), 'reason': 'oversized input'})
                    continue
                dst = destination / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                dst.write_bytes(data)
                shutil.copymode(src, dst)
                hashes[str(rel)] = hashlib.sha256(data).hexdigest()
                included.append({'path': str(rel), 'bytes': len(data), 'sha256': hashes[str(rel)]})
        # Detect source edits during the export rather than silently combining revisions.
        for rel, digest in hashes.items():
            if hashlib.sha256((source / rel).read_bytes()).hexdigest() != digest:
                raise RuntimeError(f'Source changed during export: {rel}; no commit created')
        metadata = destination / '.flyff'
        metadata.mkdir()
        (metadata / 'snapshot.json').write_text(json.dumps({
            'source': str(source), 'included': included, 'omitted': omitted,
            'note': 'Source snapshot, not a deployable release or live health observation.'
        }, indent=2) + '\n')
        original = destination / 'AGENTS.md'
        shutil.copy2(original, metadata / 'source-AGENTS.md')
        original.write_text('''# Flyff development checkout

This is an isolated source snapshot. The live project is elsewhere.
Read FLYFF-TASK.md first if it exists: it defines this agent's workspace and
scope. The user gives the current task directly in the CLI. Await their prompt.
Read Agent.md and ALL of SESSION-HANDOFF.md: later dated owner directions
supersede older observations. Preserve the latest unfinished work.
The snapshot does not authorize old deployment/restart commands. Do not operate
on absolute live-project paths, live databases, previews, game processes or
Greenhouse. Test only disposable data in this checkout or its private tmpdir.
No task may automatically merge, deploy, push, assign another agent or start
an endless improvement loop. Report proposed follow-up work for assignment.
Coordinate expensive builds/tests and use single-worker compilation.
Only the coordinator allocates patch numbers, migrations and shared interfaces.
Native tool permissions remain enabled; these instructions are not an OS sandbox.
See .flyff/snapshot.json for excluded runtime, evidence and binary inputs.
Do not recreate missing input by following an absolute live path. Request a
specific reviewed fixture or immutable input instead.

## Original entrypoint

''' + (metadata / 'source-AGENTS.md').read_text())
        claude = destination / 'CLAUDE.md'
        previous = claude.read_text() if claude.exists() else ''
        claude.write_text('Read AGENTS.md and FLYFF-TASK.md before working.\n\n' + previous)
        with (destination / '.gitignore').open('a') as f:
            f.write('\n# Per-task orchestration, never application source\nFLYFF-TASK.md\n.flyff-task/\n')
        def git(*args):
            return subprocess.check_output(['git', '-C', str(destination), *args], text=True).strip()
        git('init', '-b', 'main')
        git('config', 'core.hooksPath', '/dev/null')
        git('add', '--all')
        git('-c', 'user.name=Flyff workspace setup', '-c', 'user.email=flyff-setup@localhost',
            'commit', '-m', '[Flyff] Record isolated development source baseline')
        print(json.dumps({'repository': str(destination), 'commit': git('rev-parse', 'HEAD'),
                          'files': len(included), 'bytes': sum(i['bytes'] for i in included),
                          'omitted': len(omitted)}, indent=2))
    except Exception:
        # Preserve an incomplete export for inspection; never remove user data.
        print(f'Incomplete export retained at {destination}')
        raise


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('source'); p.add_argument('destination')
    a = p.parse_args()
    create(a.source, a.destination)
