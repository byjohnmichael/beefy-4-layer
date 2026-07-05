class_name DesignTokens
extends Resource
## Single source of truth for every color, radius, font size and duration in
## the UI. Restyle the game by editing tokens.tres - no hardcoded values in
## scene scripts.

@export_group("Colors")
@export var bg_top := Color("1e2a38")
@export var bg_bottom := Color("10161f")
@export var accent := Color("3ddc97")
@export var accent_soft := Color(0.24, 0.86, 0.59, 0.22)
@export var danger := Color("e0455a")
@export var card_face := Color("faf9f4")
@export var card_border := Color("dcdad0")
@export var card_red := Color("e0455a")
@export var card_black := Color("232a33")
@export var card_gold := Color("e8b54d")
@export var card_back := Color("2e6fe3")
@export var card_back_inner := Color("7ba3ef")
@export var slot_outline := Color(1.0, 1.0, 1.0, 0.18)
@export var hud_text := Color("e8edf2")
@export var hud_text_dim := Color(0.91, 0.93, 0.95, 0.55)
@export var overlay_dim := Color(0.02, 0.04, 0.07, 0.72)
@export var panel_bg := Color("1b2634")

@export_group("Shape")
@export var card_size := Vector2(160, 224)
@export var card_radius := 14.0
@export var card_border_width := 3.0
@export var select_border_width := 7.0
@export var slot_radius := 16.0
@export var button_radius := 18.0
@export var dim_alpha := 0.38

@export_group("Type")
@export var font_size_rank := 46
@export var font_size_hud := 36
@export var font_size_log := 30
@export var font_size_title := 130
@export var font_size_subtitle := 44
@export var font_size_button := 46
@export var font_size_overlay := 72

@export_group("Motion")
@export var dur_fast := 0.15
@export var dur_med := 0.22
@export var dur_slow := 0.3
@export var reveal_pause := 0.5
@export var bot_delay := 0.8
@export var bot_pile_delay := 0.45
@export var deal_stagger := 0.06
@export var banner_hold := 1.0
