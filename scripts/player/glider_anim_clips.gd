class_name GliderAnimClips

const LOCOMOTION: Array[String] = [
	"Eve_Idle",
	"Eve_Idle_To_Forward",
	"Eve_Forward",
	"Eve_Turn_Left",
	"Eve_Turn_Right",
]
const AIR: Array[String] = ["Eve_Jump", "Eve_Glide", "Eve_Land"]
const BOOST: Array[String] = ["Eve_Forward_To_Boost", "Eve_Boost"]
const BRAKE: Array[String] = ["Eve_Forward", "Eve_Boost"]
const SAIL: Array[String] = ["Sail_Deploy", "Sail_Up", "Sail_Down"]

const ALL_WIRED: Array[String] = [
	"Eve_Idle",
	"Eve_Idle_To_Forward",
	"Eve_Forward",
	"Eve_Turn_Left",
	"Eve_Turn_Right",
	"Eve_Jump",
	"Eve_Glide",
	"Eve_Land",
	"Eve_Forward_To_Boost",
	"Eve_Boost",
	"Sail_Deploy",
	"Sail_Up",
	"Sail_Down",
]


static func is_wired(clip_name: String) -> bool:
	return clip_name in ALL_WIRED
