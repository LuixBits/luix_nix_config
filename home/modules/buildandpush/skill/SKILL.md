---
name: verify-nixos-host
description: Verify the machine identity and matching NixOS flake target before suggesting, evaluating, building, deploying, or activating host-specific NixOS or Home Manager configuration. Use for nixos-rebuild, host-specific flake attributes, deployment tools, guarded rebuild wrappers, and handoff commands that name a machine.
---

# Verify the NixOS host

Treat a wrong host target as a destructive mistake. Never infer it from a
previous turn, an example command, a repository default, the most recently
evaluated configuration, or the machine where a change was originally made.

## Required preflight

For a command aimed at the machine running the agent:

1. Read the live hostname with `hostname` and
   `cat /proc/sys/kernel/hostname`. Also read `/etc/hostname` when available.
   Trim whitespace and require the available values to agree. If they do not,
   stop and report the ambiguity.
2. Use that detected name as the candidate flake target. Confirm that the flake
   contains it by evaluating
   `nixosConfigurations.<candidate>.config.networking.hostName`.
3. Require the evaluated hostname to equal the detected hostname exactly. A
   successful evaluation of some other host, or a successful check of every
   host, does not establish the activation target.
4. Check repository instructions and use any non-mutating, project-specific
   hardware or filesystem preflight that exists. This supplements the hostname
   match; it never replaces it.
5. Immediately before presenting or running a host-specific command, state the
   detected hostname and use exactly the verified target. Recheck if meaningful
   time passed or the execution context changed.

Never offer alternatives such as “use `pc` or `l`.” Give one verified command.
If the preflight cannot complete, do not provide or run an actionable activation
command; explain which identity check failed.

## Remote targets

When the user explicitly asks about another machine, distinguish the local
execution host from the intended remote target. Require an explicit remote
identity, verify the corresponding flake configuration, and verify the remote
hostname when access is available. Never replace an explicit remote target with
the local hostname or assume that a repository default names the remote host.

## Authorization

Host verification does not authorize activation or deployment. Follow the
repository's rules and the user's requested scope. Read-only evaluation and
build checks may validate a configuration without selecting it for activation.
