# Graph Report - .  (2026-08-09)

## Corpus Check
- 23 files · ~201,476 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 132 nodes · 166 edges · 15 communities (12 shown, 3 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 13 edges (avg confidence: 0.75)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Claude Code / OpenCode Config
- Qtile Bar Widgets
- CI/CD & Project Docs
- Dexcom Glucose Widget
- Qtile Core Config
- Bash & Git Permissions
- LLM Model Config
- Window Management Controls
- Desktop Philosophy & Specs
- Neon Sloth Wallpaper
- Color Utilities
- NixOS Theme Wallpaper
- Firefox Extension Docs
- Autostart Script
- Serena Config

## God Nodes (most connected - your core abstractions)
1. `bash` - 7 edges
2. `Bar` - 7 edges
3. `_Group` - 7 edges
4. `MyKeyboardLayout` - 7 edges
5. `NixOS + Home Manager Flake Architecture` - 6 edges
6. `options` - 5 edges
7. `code-reviewer` - 5 edges
8. `test` - 5 edges
9. `DESKTOP.md - Desktop Environment Requirements Spec` - 5 edges
10. `Neon Sloth Wallpaper` - 5 edges

## Surprising Connections (you probably didn't know these)
- `Check Flake Lock Workflow` --conceptually_related_to--> `NixOS + Home Manager Flake Architecture`  [INFERRED]
  .github/workflows/check-flake-lock.yml → CLAUDE.md
- `FlakeHub Publish Workflow` --conceptually_related_to--> `NixOS + Home Manager Flake Architecture`  [INFERRED]
  .github/workflows/push-flakhub.yml → CLAUDE.md
- `README.md - Dotfiles Overview and Installation` --references--> `NixOS + Home Manager Flake Architecture`  [EXTRACTED]
  README.md → CLAUDE.md
- `Stylix Unified Theming Principle` --conceptually_related_to--> `Tiling Layout as Default Principle`  [INFERRED]
  CLAUDE.md → DESKTOP.md
- `Qtile Dexcom Bar Integration` --conceptually_related_to--> `Tiling Layout as Default Principle`  [INFERRED]
  nix/modules/home/desktop/qtile/requirements.txt → DESKTOP.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **GitHub Actions CI Pipeline (flake lock, formatting, FlakeHub)** — _github_workflows_check_flake_lock_yml, _github_workflows_nix_formatting_yml, _github_workflows_push_flakhub_yml [EXTRACTED 1.00]
- **Desktop Environment Core Philosophy (tiling, Wayland-first, unified theming)** — desktop_tiling_layout_principle, desktop_wayland_first_principle, stylix_unified_theming [EXTRACTED 0.95]
- **NixOS Flake + Snowfall Lib + Home Manager Module System** — nixos_flake_architecture, snowfall_lib_convention, test_container_workflow [INFERRED 0.85]

## Communities (15 total, 3 thin omitted)

### Community 0 - "Claude Code / OpenCode Config"
Cohesion: 0.11
Nodes (17): agent, code-reviewer, description, model, prompt, tools, command, test (+9 more)

### Community 1 - "Qtile Bar Widgets"
Cohesion: 0.15
Nodes (8): BaseModel, # TODO: get gpu usage%, MyKeyboardLayout, GenPollText, __get_settings(), QtileSettings, mk_overrides(), overrite widget parameters

### Community 2 - "CI/CD & Project Docs"
Cohesion: 0.16
Nodes (15): Check Flake Lock Workflow, Nix Formatting Check Workflow, FlakeHub Publish Workflow, CLAUDE.md - Claude Code Project Instructions, CONTRIBUTE.md - Contribution Guide, DeterminateSystems/flake-checker-action, DeterminateSystems/flakehub-push, DeterminateSystems/nix-installer-action (+7 more)

### Community 3 - "Dexcom Glucose Widget"
Cohesion: 0.23
Nodes (9): Dexcom, GlucoseReading, Config, DexcomGlucose, DexcomHandler, DexcomInRangePercentage, get_config(), is_glucose_in_range() (+1 more)

### Community 4 - "Qtile Core Config"
Cohesion: 0.27
Nodes (4): Bar, autostart(), _Group, startup

### Community 5 - "Bash & Git Permissions"
Cohesion: 0.20
Nodes (10): git diff, git log, git status, ls *, man *, pwd, permission, bash (+2 more)

### Community 6 - "LLM Model Config"
Cohesion: 0.20
Nodes (10): options, gpt-5, models, include, reasoningEffort, reasoningSummary, textVerbosity, provider (+2 more)

### Community 7 - "Window Management Controls"
Cohesion: 0.47
Nodes (8): function, minimize_all(), _move_window_to_physical_screen(), Check if the app being launched is already running, if so focus it, spawn_or_focus(), window_to_next_screen(), window_to_prev_screen(), Qtile

### Community 8 - "Desktop Philosophy & Specs"
Cohesion: 0.32
Nodes (8): Idle/Power Pipeline (dim→lock→sleep), Desktop Key Bindings Specification, DESKTOP.md - Desktop Environment Requirements Spec, Tiling Layout as Default Principle, Wayland-First Desktop Philosophy, Qtile Python Dependencies, Qtile Dexcom Bar Integration, Stylix Unified Theming Principle

### Community 9 - "Neon Sloth Wallpaper"
Cohesion: 0.40
Nodes (6): Dark Jungle Foliage Background, Purple-Blue-Pink Neon Color Palette, Desktop Wallpaper Asset, Neon/Synthwave Digital Art Style, Neon Sloth Wallpaper, Sloth (Animal)

### Community 10 - "Color Utilities"
Cohesion: 0.50
Nodes (3): Color, get_gradient_color(), str

### Community 11 - "NixOS Theme Wallpaper"
Cohesion: 0.83
Nodes (4): Theme Color Palette (Coral, Rose-Pink, Blue-Gray Gradient), Blurred Gradient Background (Blue-Gray to Rose-Pink), NixOS Snowflake Logo (3D Isometric, Coral/Orange), Theme Wallpaper Image

## Knowledge Gaps
- **35 isolated node(s):** `$schema`, `theme`, `model`, `edit`, `git status` (+30 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `permission` connect `Bash & Git Permissions` to `Claude Code / OpenCode Config`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Why does `provider` connect `LLM Model Config` to `Claude Code / OpenCode Config`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Why does `Bar` connect `Qtile Core Config` to `Qtile Bar Widgets`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `Bar` (e.g. with `MyKeyboardLayout` and `_Group`) actually correct?**
  _`Bar` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `NixOS + Home Manager Flake Architecture` (e.g. with `Check Flake Lock Workflow` and `FlakeHub Publish Workflow`) actually correct?**
  _`NixOS + Home Manager Flake Architecture` has 4 INFERRED edges - model-reasoned connections that need verification._
- **What connects `$schema`, `theme`, `model` to the rest of the system?**
  _35 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Claude Code / OpenCode Config` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._