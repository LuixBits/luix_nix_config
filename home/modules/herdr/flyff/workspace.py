"""Native coding-agent workspaces in the dedicated Flyff Herdr session."""
import argparse
from contextlib import contextmanager, ExitStack
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time
import urllib.request

ROOT = Path(os.environ.get('FLYFF_WORKSPACE_ROOT', str(Path.home() / 'projects/flyff-agents')))
SESSION = 'herdr-flyff'
AGENTS = {'codex': 'Codex', 'kimi': 'Kimi', 'claude': 'Claude',
          'opencode': 'OpenCode Local', 'hermes': 'Hermes Local', 'devin': 'Devin'}
AREAS = {'game': ('Game - Server and Client', ['server', 'client', 'content', 'gameplay', 'database', 'server-integration']),
         'web': ('Web - Frontend and Backend', ['website', 'commerce']),
         'review': ('Review and Integration', [])}
HERMES = Path.home() / '.local/share/hermes-greenhouse/runtime/bin/hermes'


def execute(args, **kw):
    return subprocess.check_output([str(a) for a in args], text=True, **kw).strip()


def git(*args, cwd=None):
    return execute(['git', '-C', cwd or ROOT / 'repo', *args])


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.new')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


@contextmanager
def lock(name, wait=False):
    directory = ROOT / 'locks'
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / (name + '.lock')).open('a') as f:
        try:
            fcntl.flock(f, fcntl.LOCK_EX | (0 if wait else fcntl.LOCK_NB))
        except BlockingIOError:
            raise RuntimeError(f'{name} is in use; finish that session first') from None
        yield


def task_path(task):
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{1,63}', task):
        raise ValueError('Task ID: 2–64 letters, digits, underscores or hyphens; start with a letter')
    return ROOT / 'tasks' / (task + '.json')


def load_task(task):
    return json.loads(task_path(task).read_text())


def tasks():
    return [json.loads(p.read_text()) for p in sorted((ROOT / 'tasks').glob('*.json'))]


def normalized_scope(value):
    value = value.rstrip('/')
    p = Path(value)
    if not value or p.is_absolute() or any(s in {'.', '..', '.git'} for s in value.split('/')):
        raise ValueError(f'Invalid relative source scope: {value}')
    return p.as_posix()


def overlap(a, b):
    return a == b or a.startswith(b + '/') or b.startswith(a + '/')


def availability(agent):
    command = {'opencode': 'opencode-local', 'hermes': str(HERMES)}.get(agent, agent)
    return shutil.which(command)


def agent_checkout(area, agent):
    if area not in AREAS or agent not in AGENTS:
        raise ValueError('Unknown Flyff area or agent')
    tree = ROOT / 'worktrees' / f'{area}-{agent}'
    with lock('worktree-creation', wait=True):
        if tree.exists():
            if git('rev-parse', '--show-toplevel', cwd=tree) != str(tree):
                raise RuntimeError(f'Refusing to reuse an unrelated directory: {tree}')
        else:
            branch = f'agent/{area}/{agent}'
            exists = subprocess.run(['git', '-C', str(ROOT / 'repo'), 'show-ref',
                                     '--verify', '--quiet', 'refs/heads/' + branch]).returncode == 0
            git('worktree', 'add', tree, branch) if exists else git('worktree', 'add', '-b', branch, tree, 'main')
        guidance = tree / 'FLYFF-TASK.md'
        if not guidance.exists():
            scope = ', '.join(AREAS[area][1]) if area != 'review' else 'Read-only review of the commit/diff named by the user'
            guidance.write_text(f'''# Flyff agent workspace

Area: {area}. Agent: {agent}. Checkout: {tree}.
Scope: {scope}.
The user gives tasks directly in this CLI. Wait for their prompt; no task-ID
menu, registration command or automatic backlog is required. Handle one bounded
request at a time and ask before extending it into shared interfaces or another area.
Read AGENTS.md, Agent.md, the full SESSION-HANDOFF.md and component instructions.
This is a development checkout. Keep the live project, its databases/processes,
other agent checkouts and Greenhouse untouched. Preserve immutable upstream and
use the project's reviewed server patch workflow. No automatic merge or deployment.
Coordinate shared protocol/API/schema/migration/patch-number changes. Use isolated
test data and single-worker builds; only run one local-model task at a time.
Report the diff, checks and remaining issues. For reviews, name the exact commit
and report findings without editing application source.
''')
        (tree / '.flyff-task/tmp').mkdir(parents=True, exist_ok=True)
    return tree


def native_command(area, agent, env):
    review = area == 'review'
    if agent == 'codex':
        return ['codex', '--no-daemon', '-s', 'read-only' if review else 'workspace-write', '-a', 'on-request']
    if agent == 'kimi':
        return ['kimi', *(['--plan'] if review else [])]
    if agent == 'claude':
        return ['claude', '--permission-mode', 'plan' if review else 'default']
    if agent == 'opencode':
        return ['opencode-local', *(['--agent', 'plan'] if review else [])]
    if agent == 'devin':
        return ['devin']
    if agent == 'hermes':
        base, model, context = local_model()
        if context < 64000:
            raise RuntimeError(f'Hermes requires 64K context; Strata reports {context}')
        home = ROOT / 'hermes'
        home.mkdir(mode=0o700, exist_ok=True)
        config = home / 'config.yaml'
        if not config.exists():
            config.write_text('model:\n  provider: custom\nagent:\n  max_turns: 30\nterminal:\n  backend: local\n')
        env.update(HERMES_HOME=str(home), OPENAI_BASE_URL=base, OPENAI_API_KEY='local')
        return [str(HERMES), 'chat', '--cli', '--provider', 'custom', '--base-url', base,
                '--api-key', 'local', '--model', model, '--toolsets', 'terminal,file']
    raise ValueError(agent)


def open_agent(area, agent):
    if not availability(agent):
        raise RuntimeError(f'{AGENTS[agent]} is not installed')
    tree = agent_checkout(area, agent)
    env = dict(os.environ)
    env['TMPDIR'] = str(tree / '.flyff-task/tmp')
    command = native_command(area, agent, env)
    with lock(f'agent-{area}-{agent}'):
        return subprocess.call(command, cwd=tree, env=env)


def start_native_tabs(area, info):
    for agent, label in AGENTS.items():
        pane = info['panes'].get(label)
        if not pane:
            continue
        process = h('pane', 'process-info', '--pane', pane)['process_info']
        foreground = process['foreground_processes']
        menus = [p for p in foreground if 'menu' in p.get('argv', [])
                 and any(str(a).endswith('workspace.py') for a in p.get('argv', []))]
        if menus and len(menus) == len(foreground):
            # Migrate only our old menu, never an actual agent/editor or shell job.
            h('pane', 'send-keys', pane, 'ctrl+c')
            for _ in range(50):
                time.sleep(.1)
                process = h('pane', 'process-info', '--pane', pane)['process_info']
                if all(p['pid'] == process['shell_pid'] for p in process['foreground_processes']):
                    break
        if not all(p['pid'] == process['shell_pid'] for p in process['foreground_processes']):
            continue
        h('pane', 'run', pane, shlex.join(['flyff', 'open', area, agent]))
        time.sleep(.2)


def create_task(task, area, agent, objective, scope=None, base='main', acceptance='Relevant focused checks pass; report remaining limitations.'):
    path = task_path(task)
    if not objective.strip():
        raise ValueError('An objective is required')
    if not availability(agent):
        raise RuntimeError(f'{AGENTS[agent]} is not installed')
    if agent == 'hermes':
        _, _, context = local_model()
        if context < 64000:
            raise RuntimeError(f'Hermes requires at least 64000 context tokens; Strata reports {context}. Apply the prepared PC configuration first.')
    scopes = [normalized_scope(s) for s in (scope or AREAS[area][1])]
    if area == 'review':
        scopes = []
    with lock('assignments', wait=True):
        if path.exists():
            raise RuntimeError(f'{task} already exists; use flyff run {task}')
        for other in tasks():
            if other['state'] != 'released' and any(overlap(a, b) for a in scopes for b in other['scope']):
                raise RuntimeError(f"Scope reserved by {other['id']} ({other['state']}); narrow the paths or finish/release it")
        commit = git('rev-parse', '--verify', '--end-of-options', base + '^{commit}')
        worktree = ROOT / 'worktrees' / task
        git('worktree', 'add', '-b', 'task/' + task, worktree, commit)
        record = {'id': task, 'area': area, 'agent': agent, 'objective': objective,
                  'acceptance': acceptance, 'scope': scopes, 'base': commit,
                  'worktree': str(worktree), 'state': 'ready', 'created': time.time()}
        save(path, record)
        (worktree / '.flyff-task/tmp').mkdir(parents=True)
        (worktree / 'FLYFF-TASK.md').write_text(brief(record))
        print(f'Created {task}: {worktree}\nAgent: {AGENTS[agent]}\nBase: {commit}')
        return record


def brief(t):
    scope = ', '.join(t['scope']) if t['scope'] else 'READ-ONLY REVIEW: do not edit application source'
    return f'''# {t['id']}

Objective: {t['objective']}
Acceptance: {t['acceptance']}
Owner: {t['agent']}; area: {t['area']}
Checkout: {t['worktree']}
Branch: task/{t['id']}; exact base: {t['base']}
Allowed source changes: {scope}

Read AGENTS.md, Agent.md, all of SESSION-HANDOFF.md, PROJECT-STATUS.md and
the relevant component guidance. This explicit task defines current work;
older release/health observations do not authorize live operations.
Stay in this checkout. Never modify the live project, its processes/databases,
other worktrees, Greenhouse, the shared baseline, or global CLI configuration.
Do not push, merge, deploy, restart services, or invent follow-on tasks.
Use synthetic/disposable test data; give each test process its own ports.
Keep server/upstream and client intake immutable; server changes use patches.
Coordinate shared protocol, API, auth, schema, lockfile, migration or patch-number
changes before expanding scope. A folder restriction is a task contract, not a
filesystem sandbox. Keep native permission checks enabled.
Run heavy builds/tests through: flyff build {t['id']} -- COMMAND ARGUMENTS
Stop with a reviewable diff, test results and remaining limitations. A finished
agent turn is review-ready, not accepted. Report any unavailable snapshot inputs.
'''


def h(*args):
    env = {k: v for k, v in os.environ.items() if not k.startswith('HERDR_')}
    env['HERDR_CONFIG_PATH'] = str(ROOT / 'control/herdr.toml')
    output = execute(['herdr', '--session', SESSION, *args], env=env)
    return json.loads(output)['result'] if output else {}


def ensure_server():
    try:
        return h('workspace', 'list')
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        env = {k: v for k, v in os.environ.items() if not k.startswith('HERDR_')}
        env['HERDR_CONFIG_PATH'] = str(ROOT / 'control/herdr.toml')
        with (ROOT / 'control/herdr-server.log').open('a') as log:
            subprocess.Popen(['herdr', '--session', SESSION, 'server'], env=env,
                             cwd=ROOT / 'control', stdin=subprocess.DEVNULL,
                             stdout=log, stderr=log, start_new_session=True)
        for _ in range(60):
            time.sleep(.15)
            try:
                return h('workspace', 'list')
            except (subprocess.CalledProcessError, json.JSONDecodeError):
                pass
        raise RuntimeError('Flyff Herdr server did not start; inspect control/herdr-server.log')


def setup():
    if not (ROOT / 'repo/.git').is_dir():
        raise RuntimeError('Create the reviewed source baseline before setting up Herdr')
    control = ROOT / 'control'
    control.mkdir(parents=True, exist_ok=True)
    config = control / 'herdr.toml'
    if not config.exists():
        source = Path(os.environ.get('FLYFF_HERDR_CONFIG', str(Path(__file__).with_name('config.toml'))))
        shutil.copyfile(source, config)
    guide = Path(os.environ.get('FLYFF_GUIDE_PATH', str(Path(__file__).with_name('README.md'))))
    shutil.copyfile(guide, control / 'README.md')
    ensure_server()
    state_path = control / 'layout.json'
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    existing = {w['workspace_id'] for w in h('workspace', 'list')['workspaces']}
    for area, label in [('control', 'Flyff Control')] + [(a, v[0]) for a, v in AREAS.items()]:
        info = state.get(area)
        directory = control if area == 'control' else ROOT / 'areas' / area
        directory.mkdir(parents=True, exist_ok=True)
        (directory / 'README.md').write_text(f'# {label}\n\n'+guide.read_text()) if area != 'control' else None
        if info and info['workspace'] in existing and info.get('complete'):
            if area != 'control':
                start_native_tabs(area, info)
            continue  # Active agents and other foreground work remain untouched.
        if info and info['workspace'] in existing:
            wid = info['workspace']
            # Continue a partial setup without sending input into any old pane.
            tid = h('tab', 'list', '--workspace', wid)['tabs'][0]['tab_id']
        else:
            result = h('workspace', 'create', '--cwd', str(directory), '--label', label, '--no-focus')
            wid = result['workspace']['workspace_id']
            pane = result['root_pane']['pane_id']
            tid = result['tab']['tab_id']
            info = {'workspace': wid, 'tabs': {'Nvim': tid}, 'panes': {'Nvim': pane}}
            state[area] = info
            save(state_path, state)
            h('tab', 'rename', tid, 'Nvim')
            h('pane', 'run', pane, 'nvim -R README.md')
        entries = [('Board', ['flyff', 'board', '--watch'])] if area == 'control' else [
            (name, ['flyff', 'open', area, agent]) for agent, name in AGENTS.items()]
        entries.append(('CLI', None))
        for name, command in entries:
            if name in info['tabs']:
                continue
            tab = h('tab', 'create', '--workspace', wid, '--cwd', str(directory), '--label', name, '--no-focus')
            tab_id = tab['tab']['tab_id']; pane_id = tab['root_pane']['pane_id']
            info['tabs'][name] = tab_id; info['panes'][name] = pane_id
            save(state_path, state)
            if command:
                h('pane', 'run', pane_id, shlex.join(command))
        h('tab', 'focus', tid)
        info['complete'] = True
        save(state_path, state)
    h('tab', 'focus', state['control']['tabs']['Board'])
    print(f'Ready: {SESSION}; use herdr-flyff')


def local_model():
    base = os.environ.get('STRATA_BASE_URL', 'http://192.168.18.10:8080/v1').rstrip('/')
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(base + '/models', timeout=10) as response:
        data = json.load(response)['data']
    models = [m for m in data if m['id'] in ('qwen3.8-flash-next-normal', 'qwen3.8-flash-next-abliterated')]
    if len(models) != 1:
        raise RuntimeError('Strata must report exactly one active Qwen model')
    context = int(models[0].get('meta', {}).get('n_ctx', 0))
    return base, models[0]['id'], context


def launch_command(t, env):
    agent = t['agent']
    prompt = f"Read FLYFF-TASK.md and follow its task contract. Complete only task {t['id']}. Objective: {t['objective']}"
    review = t['area'] == 'review'
    if agent == 'codex':
        return ['codex', '--no-daemon', '-s', 'read-only' if review else 'workspace-write', '-a', 'on-request', prompt]
    if agent == 'kimi':
        # Current Kimi 2.x has no initial interactive-prompt flag. Herdr delivers
        # the prompt after its TUI reaches an idle state (see deliver()).
        return ['kimi', *(['--plan'] if review else [])]
    if agent == 'claude':
        return ['claude', '--permission-mode', 'plan' if review else 'default', prompt]
    if agent == 'opencode':
        return ['opencode-local', *(['--agent', 'plan'] if review else []), '--prompt', prompt]
    if agent == 'hermes':
        base, model, context = local_model()
        if context < 64000:
            raise RuntimeError(f'Hermes needs 64K context; Strata currently reports {context}. Apply the PC configuration first.')
        home = ROOT / 'hermes'
        home.mkdir(mode=0o700, exist_ok=True)
        # Use a new profile: do not import Greenhouse settings, tools or credentials.
        env['HERMES_HOME'] = str(home)
        env['OPENAI_BASE_URL'] = base
        env['OPENAI_API_KEY'] = 'local'
        config = home / 'config.yaml'
        if not config.exists():
            config.write_text('model:\n  provider: custom\nagent:\n  max_turns: 30\nterminal:\n  backend: local\n')
        return [str(HERMES), 'chat', '--cli', '--provider', 'custom', '--base-url', base,
                '--api-key', 'local', '--model', model, '--max-turns', '30',
                '--toolsets', 'terminal,file', '--query-file', str(Path(t['worktree']) / 'FLYFF-TASK.md')]
    if agent == 'devin':
        return ['devin', '--prompt-file', str(Path(t['worktree']) / 'FLYFF-TASK.md')]
    raise ValueError(agent)


def deliver(task, pane):
    t = load_task(task)
    for _ in range(120):
        try:
            result = h('agent', 'get', pane)
            if (result['agent'].get('agent') == 'kimi'
                    and result['agent'].get('agent_status') in ('idle', 'done')):
                h('agent', 'prompt', pane, 'Read FLYFF-TASK.md and carry out only the assigned task. ' + t['objective'])
                return
        except (subprocess.CalledProcessError, KeyError):
            pass
        time.sleep(.5)
    print('Kimi initial prompt was not delivered; type: Read FLYFF-TASK.md and begin.')


def run_task(task):
    t = load_task(task)
    if t['state'] == 'released':
        raise RuntimeError('Task was released; create a new assignment')
    with ExitStack() as stack:
        stack.enter_context(lock('task-' + task))
        if t['agent'] in ('opencode', 'hermes'):
            stack.enter_context(lock('strata'))
        # At most two implementers plus one independent reviewer through this launcher.
        slots = ['reviewer'] if t['area'] == 'review' else ['implementer-1', 'implementer-2']
        for i, slot in enumerate(slots):
            try:
                stack.enter_context(lock(slot)); break
            except RuntimeError:
                if i == len(slots) - 1:
                    raise RuntimeError('All agent slots are busy; finish a session first') from None
        env = dict(os.environ)
        env['TMPDIR'] = str(Path(t['worktree']) / '.flyff-task/tmp')
        env['FLYFF_TASK_ID'] = task
        command = launch_command(t, env)
        t['state'] = 'active'
        save(task_path(task), t)
        delivery = None
        if t['agent'] == 'kimi' and os.environ.get('HERDR_PANE_ID'):
            with (ROOT / 'tasks' / (task + '.delivery.log')).open('a') as log:
                delivery = subprocess.Popen(['flyff', '_deliver', task, os.environ['HERDR_PANE_ID']], stdout=log, stderr=log)
        print(f"{task}: {t['worktree']}\nNative agent permissions remain enabled.", flush=True)
        try:
            code = subprocess.call(command, cwd=t['worktree'], env=env)
        finally:
            if delivery and delivery.poll() is None:
                delivery.terminate(); delivery.wait()
            t['state'] = 'review'
            save(task_path(task), t)
        audit(task)
        return code


def audit(task):
    t = load_task(task)
    tree = t['worktree']
    changed = set(filter(None, git('diff', '--name-only', '--no-renames', t['base'], cwd=tree).splitlines()))
    changed.update(filter(None, git('ls-files', '--others', '--exclude-standard', cwd=tree).splitlines()))
    out = sorted(p for p in changed if p.startswith(('server/upstream/', 'client/quarantine/'))
                 or not any(p == s or p.startswith(s + '/') for s in t['scope']))
    diff = git('diff', '--binary', t['base'], cwd=tree)
    result = {'task': task, 'head': git('rev-parse', 'HEAD', cwd=tree), 'base': t['base'],
              'changed': sorted(changed), 'outside_scope': out,
              'tracked_diff_sha256': hashlib.sha256(diff.encode()).hexdigest(),
              'note': 'Scope report only; not test, security, or acceptance evidence.'}
    save(ROOT / 'tasks' / (task + '.audit'), result)
    print(json.dumps(result, indent=2))
    return result


def board(watch=False):
    while True:
        if watch:
            print('\033[2J\033[H', end='')
        print('FLYFF — development workspaces\n')
        for agent, label in AGENTS.items():
            status = 'installed (provider login may be required)' if availability(agent) else 'not installed'
            if agent == 'hermes' and availability(agent):
                try:
                    _, _, context = local_model()
                    status = 'local endpoint ready' if context >= 64000 else f'needs Strata 64K context (current: {context})'
                except Exception:
                    status = 'local endpoint unavailable'
            print(f'{label:16} {status}')
        registered = tasks()
        if registered:
            print('\nLEGACY TASK          AREA     AGENT      STATE       OBJECTIVE')
        for t in registered:
            print(f"{t['id']:20} {t['area']:8} {t['agent']:10} {t['state']:11} {t['objective'][:90]}")
        print('\nAgent tabs open the real CLIs. Type your request directly; no task ID required.')
        print('Game: server/client. Web: frontend/backend. Review: check changes before merging.')
        print('Each agent has a separate checkout. Coordinate shared interfaces and patch numbers.')
        print('Run one local-model task at a time. Integration and deployment remain manual.')
        print(f'Root: {ROOT}\nGuide: {ROOT}/control/README.md', flush=True)
        if not watch:
            return
        time.sleep(5)


def menu(area, agent):
    while True:
        print(f'\n{AREAS[area][0]} / {AGENTS[agent]}')
        print('New task: enter an ID. Existing task: enter its ID to reopen. q: return to shell.')
        try:
            task = input('Task ID: ').strip()
            if task.lower() == 'q':
                return
            if not task_path(task).exists():
                objective = input('Objective: ').strip()
                acceptance = input('Acceptance criteria: ').strip() or 'Focused checks pass; report limitations.'
                base = input('Review commit/ref: ').strip() if area == 'review' else 'main'
                if not base:
                    raise ValueError('Reviews require an explicit commit/ref')
                scope = input('Allowed paths, comma-separated (Enter = whole area): ').strip() if area != 'review' else ''
                create_task(task, area, agent, objective, [s.strip() for s in scope.split(',')] if scope else None, base, acceptance)
            else:
                t = load_task(task)
                if t['area'] != area or t['agent'] != agent:
                    raise ValueError(f"Task belongs to {t['area']} / {t['agent']}; open that tab")
            run_task(task)
        except (ValueError, RuntimeError, OSError, subprocess.CalledProcessError) as error:
            print(f'Cannot start: {error}')
        except (EOFError, KeyboardInterrupt):
            print(); return


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='command', required=True)
    sub.add_parser('setup'); sub.add_parser('attach')
    b = sub.add_parser('board'); b.add_argument('--watch', action='store_true')
    m = sub.add_parser('menu'); m.add_argument('area', choices=AREAS); m.add_argument('agent', choices=AGENTS)
    op = sub.add_parser('open'); op.add_argument('area', choices=AREAS); op.add_argument('agent', choices=AGENTS)
    c = sub.add_parser('create'); c.add_argument('task'); c.add_argument('--area', choices=AREAS, required=True)
    c.add_argument('--agent', choices=AGENTS, required=True); c.add_argument('--objective', required=True)
    c.add_argument('--scope', action='append'); c.add_argument('--base', default='main')
    c.add_argument('--acceptance', default='Focused checks pass; report remaining limitations.')
    for name in ('run', 'audit'):
        sub.add_parser(name).add_argument('task')
    r = sub.add_parser('release'); r.add_argument('task'); r.add_argument('--reason', required=True)
    bu = sub.add_parser('build'); bu.add_argument('task'); bu.add_argument('args', nargs=argparse.REMAINDER)
    d = sub.add_parser('_deliver'); d.add_argument('task'); d.add_argument('pane')
    a = p.parse_args()
    if a.command == 'setup': setup()
    elif a.command == 'attach':
        ensure_server()
        env = dict(os.environ); env['HERDR_CONFIG_PATH'] = str(ROOT / 'control/herdr.toml')
        os.execvpe('herdr', ['herdr', '--session', SESSION], env)
    elif a.command == 'board': board(a.watch)
    elif a.command == 'open': return open_agent(a.area, a.agent)
    elif a.command == 'menu': menu(a.area, a.agent)
    elif a.command == 'create': create_task(a.task, a.area, a.agent, a.objective, a.scope, a.base, a.acceptance)
    elif a.command == 'run': return run_task(a.task)
    elif a.command == 'audit': return bool(audit(a.task)['outside_scope'])
    elif a.command == 'release':
        task_path(a.task)
        with lock('task-' + a.task), lock('assignments', wait=True):
            t = load_task(a.task); t['state'] = 'released'; t['release_reason'] = a.reason
            save(task_path(a.task), t)
            print('Reservation released. Worktree and branch preserved.')
    elif a.command == 'build':
        t = load_task(a.task)
        command = a.args[1:] if a.args[:1] == ['--'] else a.args
        if not command: raise ValueError('A build/test command is required')
        with lock('build', wait=True):
            return subprocess.call(command, cwd=t['worktree'])
    elif a.command == '_deliver': deliver(a.task, a.pane)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f'flyff: {error}', file=sys.stderr)
        sys.exit(1)
