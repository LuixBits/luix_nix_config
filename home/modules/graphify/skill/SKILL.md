---
name: graphify
description: Use existing Graphify knowledge graphs for repository architecture, cross-file relationships, change impact, and cross-project discovery. Use when understanding a flow or blast radius requires more than a simple source search; do not use it as a substitute for reading source files.
---

# Graphify

Use Graphify as a structural index before broad repository exploration.

- Resolve the repository root with `git rev-parse --show-toplevel`; for a non-Git project, use its absolute root directory.
- Prefer the Graphify MCP tools for architecture, symbol relationships, execution paths, hubs, and change-impact questions. Pass the absolute repository root as `project_path` for a project graph. Omit `project_path` only for an intentional cross-project query of the merged global graph.
- Keep queries narrow and follow useful graph results by opening the cited source files. The graph can be incomplete or stale and is never the source of truth.
- If MCP is unavailable, use the `graphify` CLI against `<project>/graphify-out/graph.json`.
- After changing supported source files, refresh an existing graph with `graphify-project update <project-root>` before handoff. Use `graphify-project build <project-root>` only when the user wants a new graph.
- The managed graphs are code-only. Do not send documents, source, images, audio, or video to an external semantic-extraction backend without explicit user approval.
- Graphify 0.9.48 does not index Nix or GDScript. For those files, use normal source inspection and report the limitation instead of implying complete graph coverage.

Do not install Graphify, upgrade it, add Git hooks, or edit MCP configuration from this skill. Those are managed declaratively by the Nix configuration.
