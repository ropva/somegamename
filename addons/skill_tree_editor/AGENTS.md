# Skill Tree Editor — Agent Instructions

This file is for coding agents modifying `addons/skill_tree_editor`. Read it before changing addon code, scenes, resources or tests.

## Objective

Keep this directory copyable into any Godot 4.0+ project. The addon is tested with Godot 4.8. Enabling the plugin must provide an editor and runtime skill-tree system without host-project dependencies.

## Hard invariants

1. `SkillTree` is the only addon autoload and the only supported runtime API for game code.
2. `SkillTreeStorageService` and `SkillProgressionService` stay separate classes but are private children of `SkillTreeService`. Never register, look up or require them as `/root` autoloads.
3. Do not reference `Platform`, `Data`, `Refs`, `G`, `Enums`, Steam, project themes, project assets or host input actions from inside the addon.
4. Every `res://` reference in addon files must start with `res://addons/skill_tree_editor/`.
5. The addon contains tools and reusable runtime only. Do not add game-specific `.tres`, demo trees, default game icons or user save data.
6. Static authoring data lives in `SkillTreeData`; mutable progression lives in `SkillTreeState` and local JSON. Do not duplicate either source of truth.
7. User-facing editable UI is represented by `.tscn` scenes with named nodes. Runtime scripts update data, state and responsive layout but do not create the scene hierarchy programmatically.
8. Add an English `##` Inspector description directly before every `@export` or `@export_range` variable.

## Architecture map

| Area | Primary files | Ownership |
| --- | --- | --- |
| Plugin/editor entry | `plugin.gd`, `skill_tree_editor.gd`, `editor/` | Adds only `SkillTree`, provides GraphEdit authoring UI. |
| Public runtime API | `runtime/skill_tree_service.gd` | Configures one active tree/slot; owns internal services and re-emits signals. |
| State/save | `runtime/skill_tree_state.gd`, `runtime/skill_tree_storage.gd` | JSON at `user://skill_tree/<slot>/<tree_id>.json`; atomic temporary-write then rename. |
| Progression | `runtime/skill_progression_service.gd` | Validates purchase, applies effects, rolls back on failed save. |
| Runtime UI | `runtime/skill_tree_view.gd`, `runtime/skill_node.gd`, `runtime/skill_details_panel.gd`, `scenes/` | Displays and interacts with the configured tree. |
| Static schema | `scripts/skill_tree_data.gd`, `skill_data.gd`, currency/stat/effect/requirement resources | Tree, graph, currencies, stats and effects. |
| Localization | `translations/`, `_register_runtime_translations()` | Static UI translations plus runtime tree currency/stat messages. |

## Public API contract

Game scripts may use only `SkillTree`:

```gdscript
SkillTree.configure(tree_data, save_slot)
SkillTree.purchase_skill(skill_id)
SkillTree.add_currency(currency_key, amount)
SkillTree.get_value(value_key, fallback)
SkillTree.export_state()
```

Keep these API groups working:

- configuration: `configure`, `get_tree_data`, `get_save_slot`;
- skill state: `get_level`, `get_skill_state`, `is_visible`, `prerequisites_met`, `get_missing_prerequisites`;
- skill actions: `purchase_skill`, toggle methods;
- currencies: get/set/add/can_afford/spend;
- values: `get_value`, `set_value`, `player_data`;
- persistence: export/import/clear current/clear one/clear all.

Relay configuration, currency, purchase, toggle, skill-state, purchase-failure and storage-state signals from `SkillTree`.

## Data and save compatibility

- Currency keys are lowercase `[a-z_][a-z0-9_]*` identifiers and must remain stable after creation.
- `SkillTreeState.VERSION` is currently 3. State format: `version`, `tree_id`, `currencies`, `levels`, `values`, `spent_currencies`.
- Legacy v1/v2 state is intentionally reset when first loaded for v3; never invent a refund from current prices.
- Values must retain declared types. Numeric effects reject invalid targets and division by zero. Clamp is active only when `use_clamp` is true.
- Purchases must be transactional: save failure restores currency, level and effect values.
- The local state is intentionally not host-authoritative and has no built-in cloud/Steam/Web SDK synchronization.

## UI and graph constraints

- A closed editor `GraphNode` must be 384×384 without clipping its natural content. Expanded sections may increase height, never compact width.
- Grid size is 96 px. The origin is `(0, 0)`. A centered 384×384 node has top-left `(-192, -192)`.
- Origin is a dedicated `GraphElement`; it must pan/zoom with `GraphEdit`, not be an overlay.
- Runtime `SkillNode` is a `PanelContainer` with a full-size action button. Non-button visual controls pass mouse input through.
- `DIRECT_PURCHASE` uses `BigIconRect`; `DETAILS_PANEL` uses `SmallIconRect` on the compact card.
- Details panel root passes outside-clicks to `SkillTreeView`; its active card and controls stop input. A click inside the panel or on a skill must not close it or start pan.
- Details first open slides from the correct edge/bottom; refresh, purchase, language change and resize must not replay slide or flash at the centre.

## Localization rules

- Use `tr("KEY")` for addon-owned static strings; do not hard-code user-facing UI text.
- Keep RU and EN rows in `translations/skill_tree_translations.csv` in sync.
- Currency messages use `CURRENCY_<KEY>` and `CURRENCY_<KEY>_SHORT`.
- Stat messages use authored `title_key`; collection messages are registered at runtime.
- User-authored titles, descriptions and categories are never machine-translated.

## Change workflow

1. Read relevant code and scenes before editing. Preserve unrelated host-project changes.
2. Make the smallest data-driven change that keeps the invariants above.
3. Update both user guides when setup, public API, workflow or behavior changes.
4. Update addon README links if documentation moves.
5. Update project-level `docs/IMPLEMENTATION_PLAN.md` and `docs/SYSTEMS.md` if architecture changes in the host project.
6. Run checks appropriate to the change.

## Verification commands

From the host project root, when those smoke scripts are present:

```powershell
godot --headless --path . --script res://tests/skill_tree_runtime_smoke.gd --quit-after 20
godot --headless --path . --script res://tests/skill_tree_runtime_ui_smoke.gd --quit-after 20
```

Also statically check that addon paths remain internal, no legacy `/root/SkillTreeStorage` or `/root/SkillProgression` lookups remain, and every export has a direct `##` documentation line.

## Do not do this

- Do not add a second autoload for convenience.
- Do not read/write game-specific player data from the addon.
- Do not mutate host `InputMap` or create generic actions such as `scroll_up`, `scroll_down` or `reset_data`.
- The plugin may add the namespaced debug action `reset_skilltree_data` with Ctrl+R; preserve an existing host binding instead of overwriting it.
- Do not put user-created trees, icons or save files under the addon directory.
- Do not use a nested `project.godot` inside this repository for smoke tests; Godot treats it as another project and emits a warning.
