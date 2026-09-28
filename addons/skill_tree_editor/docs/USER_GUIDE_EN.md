# Skill Tree Editor — User Guide

This guide explains how to install, author, run, save and customize a tree without changing addon code.

## 1. Install

1. Copy the complete `addons/skill_tree_editor` folder into the target project's `addons` folder.
2. Open the project in Godot 4.0 or newer. The addon is tested with Godot 4.8.
3. Enable **Skill Tree** in **Project > Project Settings > Plugins**.
4. Confirm that Godot added one autoload named `SkillTree`. Do not add `SkillTreeStorage` or `SkillProgression` yourself; they are internal services.

The addon does not require Platform, Data, Refs, G, Steam, a project theme or custom input actions.

## 2. Create a tree resource

1. Open the **Skill Tree** main-screen tab.
2. Press **New**. A new tree includes the `skillpoints` currency and one root skill.
3. Edit the tree name and save the resource as a `.tres` file outside `addons/skill_tree_editor`; for example, `res://content/skill_trees/player_tree.tres`.
4. Use **Open** to continue editing that resource later. Use normal **Save** to overwrite it safely.

The graph origin is world position `(0, 0)`. A new root skill has top-left position `(-192, -192)`, so its 384×384 card is centred at the origin. The **Center/Origin** command puts `(0, 0)` in the centre of the editor viewport.

## 3. Configure languages and categories

Use the **Languages** panel to add or remove locales. Russian and English are created by default. Static addon UI is translated by the addon; your authored titles, descriptions, categories, currencies and stat names are entered by you for each required locale.

Use the **Categories** panel to create the skill categories used by your tree. Categories are stored in the tree resource, not hard-coded in the addon.

## 4. Configure currencies

Open **Currencies** in the toolbar.

For every currency, configure:

- a lowercase key, such as `skillpoints`, `gold` or `research_token`;
- full name and abbreviation for every tree language;
- optional icon;
- initial amount for a new save state.

The key cannot be changed after creation because saves and skills use it. At least one currency must remain. If you delete a currency used by skills, those skills move to the first remaining currency.

At runtime a non-free cost is rendered as an amount with the currency icon when an icon is assigned, otherwise with the localized abbreviation. A zero cost is shown as `FREE`.

## 5. Configure player values and effects

Open the player-stat editor and create values that skills can modify. A stat has:

- a stable key, for example `carry_capacity`;
- a type: Int, Float, Bool, Array or Dictionary;
- a base value used for a new save;
- localized title and optional localized collection entries.

On a skill, create effects that target these stat keys. Numeric effects support add, subtract, multiply, divide and set. Clamp applies only when enabled. `ADD_UNIQUE` is for Dictionary values; invalid operations and division by zero are rejected by validation/runtime.

Use a Bool `SET` effect with `toggle_mode` when a max-level skill should act as Enable/Disable after it is purchased.

## 6. Configure skills and connections

Right-click an empty graph area to add a skill. Configure the card preview directly:

- title, description, category and icon;
- maximum level;
- selected currency, base cost, cost growth or manual per-level prices;
- **Visible immediately**;
- requirements and effects.

`Visible immediately` controls only visibility. A skill with no requirements is purchasable immediately. Requirements control whether it is locked. Drag an output port to another skill's input port to create a requirement connection. The validator detects invalid IDs, missing references, cycles, incompatible effects and invalid currency keys.

Use the context action **Move to center** to place a selected card at `(-192, -192)`.

## 7. Add runtime UI to a game scene

1. Add `res://addons/skill_tree_editor/scenes/skill_tree_view.tscn` as a child of your UI `Control`/`CanvasLayer`.
2. Assign the saved `SkillTreeData` resource to `skill_tree_data`.
3. Set a `save_slot`, usually `default` or a profile identifier.
4. Choose `DIRECT_PURCHASE` or `DETAILS_PANEL` interaction mode.
5. Call `open()` and `close()` from your own game UI.

`SkillTreeView` configures the active tree when it becomes ready. It has built-in pan, mouse-wheel zoom, WASD/arrow keyboard pan, connections, card UI and optional details panel. The default scenes are editable: duplicate or modify them in your project, then assign the replacement scene through the exported properties.

## 8. Use runtime data in game code

Use only the `SkillTree` autoload. It is the supported API boundary.

```gdscript
# Reward a player.
SkillTree.add_currency("skillpoints", 3)

# Read a value changed by effects.
var capacity := int(SkillTree.get_value("carry_capacity", 4))

# Query or buy a skill.
if SkillTree.prerequisites_met("sprint") and SkillTree.purchase_skill("sprint"):
    print("Purchased")

# Save state for a future platform/cloud adapter.
var state: Dictionary = SkillTree.export_state()
```

Available groups include:

- skill queries: `get_level`, `get_skill_state`, `is_visible`, `prerequisites_met`, `get_missing_prerequisites`;
- skill actions: `purchase_skill`, `toggle_skill`, `is_toggle_skill_active`, `set_toggle_skill_active`;
- currencies: `get_currency`, `set_currency`, `add_currency`, `can_afford`, `spend_currency`;
- values: `get_value`, `set_value`, `player_data`;
- persistence: `export_state`, `import_state`, `clear_current_state`, `clear_state`, `clear_all_states`.

Signals include `configured`, `currency_changed`, `skill_purchased`, `skill_toggled`, `skill_state_changed`, `skill_purchase_failed` and `state_changed`.

## 9. Save data and migration

Static tree data lives in your `.tres` resource. Runtime state is saved after purchases and explicit state changes to:

`user://skill_tree/<save_slot>/<tree_id>.json`

The state contains `version`, `tree_id`, `currencies`, `levels` and `values`. Old version-1 files containing `skill_points` migrate once to `currencies.skillpoints`. New saves are local only: cloud synchronization, Steam/Web SDK integration and multiplayer host authority belong to the host project.

To reset state intentionally, call `SkillTree.clear_current_state()` or another explicit clear method. The addon never binds reset keys in the host project.

## 10. Customize safely

The editor **Settings** panel contains Categories, Player Stats, Currencies, Languages and Colors. It also contains the refund percentage used by the gameplay reset; new trees default to 50%.

At runtime, currency balances are shown in the bottom-left VBox. The reset button is in the top-right corner. It opens a confirmation panel and returns the configured percentage of the exact amounts spent on skills. `Ctrl+R` is a debug-only reset action installed as `reset_skilltree_data`; it clears the active tree save and gives no refund.

You can customize without touching runtime logic by assigning your own:

- `SkillNode` scene;
- connection `Line2D` scene;
- details-panel scene;
- icons, fonts and theme resources;
- `SkillTreeData` colors, currencies, stats and locales.

Keep the named nodes and required scripts when adapting supplied scenes. If you change code, read `../AGENTS.md` first: it documents invariants that preserve addon portability and save compatibility.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `SkillTree` is missing | Enable the plugin and resolve an existing conflicting autoload named `SkillTree`. |
| A skill is not purchasable | Check requirements, current currency balance, max level and effect validation. |
| A skill is hidden | Enable Visible immediately or make at least one requirement parent meet its required level. |
| Costs show a key | Add the currency's localized full/short names for the current locale. |
| Changes do not persist | Confirm the `.tres` is saved and inspect `user://skill_tree/<slot>/<tree_id>.json`. |
