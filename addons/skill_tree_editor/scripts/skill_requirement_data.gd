@tool
class_name SkillRequirementData
extends Resource

## Identifier of the prerequisite skill.
@export var parent_skill_id: String = ""
## Minimum prerequisite level required for purchase.
@export_range(1, 999, 1) var required_level: int = 1
