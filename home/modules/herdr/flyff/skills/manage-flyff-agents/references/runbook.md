# Using Flyff agents

The main PC runs the local model. The mini PC runs Herdr and the coding agents.
No rebuild is needed for everyday use. Greenhouse is disconnected.

## 1. Open from the main PC

```sh
herdr --remote luix@192.168.18.13 --session herdr-flyff
```

On the mini PC directly, use `herdr-flyff` instead. Both open the same session.
Commands inside its tabs execute on the mini PC.

## 2. Pick a space and agent

- **Game:** server, client, protocol and gameplay.
- **Web:** website, backend, accounts and admin.
- **Review and Integration:** independent checks and combining accepted changes.
- **Control:** guide, status and coordination shell.

Open Codex, Kimi, Claude, OpenCode Local, Hermes Local or Devin and type a normal
prompt. There is no task-ID menu. Native login/trust screens may appear first.
Each agent has its own source checkout. Example first prompt:

> Read AGENTS.md and the full SESSION-HANDOFF.md. Summarize the current state and
> suggest three small next tasks. Do not change files or run live operations.

Assign one bounded change per agent. Coordinate shared protocols, APIs, schemas
and patch numbers. Run one local-model request and one heavy build at a time.

## 3. Review, then integrate

Have the implementer explain its diff/checks and commit intended source files.
Give a second agent that exact commit hash to review. All checkouts share Git
history; the reviewer's working files are not automatically at that commit.

Integrate accepted commits into `~/projects/flyff-agents/repo` and test them
together. This updates the development baseline, not the running Flyff server.
Ask an agent to handle those Git operations if preferred; only one agent should
integrate into the baseline at a time.

## 4. Reconnect or recover

Detach with **Ctrl+B**, then **Q**. Agents keep running. Reuse step 1 to reconnect.
After a mini-PC reboot/full Herdr restart, run from the main PC:

```sh
ssh luix@192.168.18.13 'flyff setup'
```

This reopens idle agent tabs and preserves active processes. A new launch starts
a new conversation in the retained checkout; native history handles resume.

## Connection/login checks if needed

From the main PC:

```sh
ssh luix@192.168.18.13 'opencode-local --status'
ssh luix@192.168.18.13 'devin auth status'
```

Keep the main PC awake for local inference. Hermes needs at least 64,000 context
tokens. As checked on 2026-11-03, Strata reports 65,536 and Devin is authenticated;
recheck if troubleshooting. Only if Devin requests login:

```sh
ssh -t luix@192.168.18.13 'devin auth login --force-manual-token-flow'
```

Enter credentials only into its native login flow. Other cloud CLIs use their
own provider accounts.

The skill is installed on both machines. In a fresh Codex conversation:

```text
Use $manage-flyff-agents to check the setup and help me assign the next task.
```
