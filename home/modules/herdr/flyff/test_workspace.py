"""Exercise isolation/ownership failure cases using real disposable Git worktrees."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('workspace', Path(__file__).with_name('workspace.py'))
w = importlib.util.module_from_spec(spec)
spec.loader.exec_module(w)


class Workspaces(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        w.ROOT = Path(self.tmp.name)
        repo = w.ROOT / 'repo'
        repo.mkdir()
        subprocess.run(['git', 'init', '-q', '-b', 'main', str(repo)], check=True)
        (repo / 'server').mkdir(); (repo / 'website').mkdir()
        (repo / 'server/a.py').write_text('original\n')
        (repo / 'website/a.ts').write_text('original\n')
        (repo / '.gitignore').write_text('FLYFF-TASK.md\n.flyff-task/\n')
        w.git('add', '.')
        w.git('-c', 'user.name=Test', '-c', 'user.email=test@localhost', 'commit', '-qm', '[Flyff] Fixture')
        self.available = patch.object(w, 'availability', return_value='/bin/true')
        self.available.start(); self.addCleanup(self.available.stop)

    def create(self, task, area='game', scope=None, base='main'):
        return w.create_task(task, area, 'codex', 'A bounded test task', scope, base)

    def test_separate_checkout_and_scope_conflict(self):
        a = self.create('GAME-01', scope=['server'])
        with self.assertRaisesRegex(RuntimeError, 'Scope reserved'):
            self.create('GAME-02', scope=['server/a.py'])
        b = self.create('WEB-01', area='web', scope=['website'])
        (Path(a['worktree']) / 'server/a.py').write_text('changed\n')
        self.assertEqual((Path(b['worktree']) / 'server/a.py').read_text(), 'original\n')
        self.assertEqual((w.ROOT / 'repo/server/a.py').read_text(), 'original\n')

    def test_audit_tracks_committed_untracked_and_out_of_scope(self):
        t = self.create('GAME-01', scope=['server'])
        tree = Path(t['worktree'])
        (tree / 'website/a.ts').write_text('unexpected\n')
        (tree / 'new-secret.txt').write_text('synthetic marker\n')
        result = w.audit('GAME-01')
        self.assertEqual(result['outside_scope'], ['new-secret.txt', 'website/a.ts'])

    def test_review_freezes_base_and_does_not_reserve_writer_scope(self):
        t = self.create('GAME-01', scope=['server'])
        review = self.create('REVIEW-01', area='review', base='task/GAME-01')
        self.assertEqual(review['base'], t['base'])
        self.assertEqual(review['scope'], [])

    def test_ids_and_scope_cannot_escape_root(self):
        for bad in ['../outside', '/tmp/outside', 'x;date', 'x\nhello']:
            with self.assertRaises(ValueError): w.task_path(bad)
        for bad in ['../outside', '/tmp/outside', 'server/../website', '.git/config']:
            with self.assertRaises(ValueError): w.normalized_scope(bad)
        self.assertFalse(w.overlap('server/tools', 'server/toolset'))

    def test_busy_task_and_local_model_locks_are_rejected(self):
        with w.lock('strata'):
            with self.assertRaisesRegex(RuntimeError, 'in use'):
                with w.lock('strata'): pass

    def test_hermes_context_failure_does_not_reserve_a_task(self):
        with patch.object(w, 'local_model', return_value=('http://example/v1', 'qwen', 32768)):
            with self.assertRaisesRegex(RuntimeError, '64000'):
                w.create_task('HERMES-01', 'game', 'hermes', 'A task')
        self.assertFalse(w.task_path('HERMES-01').exists())
        self.assertFalse((w.ROOT / 'worktrees/HERMES-01').exists())

    def test_kimi_prompt_waits_for_the_expected_agent(self):
        self.create('GAME-01', scope=['server'])
        with patch.object(w, 'h', side_effect=[
            {'agent': {'agent': 'codex', 'agent_status': 'idle'}},
            {'agent': {'agent': 'kimi', 'agent_status': 'idle'}}, {}]) as api, patch.object(w.time, 'sleep'):
            w.deliver('GAME-01', 'w2:p3')
        self.assertEqual(api.call_count, 3)
        self.assertEqual(api.call_args.args[:3], ('agent', 'prompt', 'w2:p3'))

    def test_native_agents_have_separate_persistent_checkouts(self):
        a = w.agent_checkout('game', 'opencode')
        b = w.agent_checkout('game', 'kimi')
        (a / 'server/a.py').write_text('uncommitted work\n')
        self.assertEqual(w.agent_checkout('game', 'opencode'), a)
        self.assertEqual((a / 'server/a.py').read_text(), 'uncommitted work\n')
        self.assertEqual((b / 'server/a.py').read_text(), 'original\n')
        self.assertEqual((w.ROOT / 'repo/server/a.py').read_text(), 'original\n')

    def test_native_launch_does_not_submit_an_initial_task(self):
        for agent in ('codex', 'kimi', 'claude', 'opencode', 'devin'):
            command = w.native_command('game', agent, {})
            self.assertNotIn('--prompt', command)
            self.assertNotIn('--prompt-file', command)
            self.assertNotIn('menu', command)
        self.assertIn('read-only', w.native_command('review', 'codex', {}))

    def test_native_setup_leaves_active_agents_alone(self):
        info = {'panes': {'Codex': 'w2:p2'}}
        with patch.object(w, 'h', return_value={'process_info': {
            'shell_pid': 10, 'foreground_processes': [{'pid': 20, 'argv': ['codex']}]
        }}) as api:
            w.start_native_tabs('game', info)
        self.assertEqual(api.call_count, 1)

    def test_native_workspace_rejects_unrelated_directories(self):
        (w.ROOT / 'worktrees/game-codex').mkdir(parents=True)
        with self.assertRaises((RuntimeError, subprocess.CalledProcessError)):
            w.agent_checkout('game', 'codex')


if __name__ == '__main__': unittest.main()
