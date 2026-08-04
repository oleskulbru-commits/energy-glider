class_name CargoTypes
extends RefCounted

enum Type {
	NONE,
	ANTENNA_PART,
	SCRAP,
}

const LABELS := {
	Type.NONE: "",
	Type.ANTENNA_PART: "ANTENNA PART",
	Type.SCRAP: "SCRAP",
}


static func label_for(type: Type) -> String:
	return LABELS.get(type, "")
