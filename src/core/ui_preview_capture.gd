# res://src/core/ui_preview_capture.gd
# GDScript / ui_preview_capture.gd / Godot 4.7 / Automated UI Preview Capture
extends SceneTree

const GAME_SCENE_PATH: String = "res://assets/ui/game_scene.tscn"
const OUTPUT_PATH: String = "res://tasks/ui_preview.png"

func _initialize() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	var window: Window = root
	window.size = Vector2i(1920, 1080)
	window.content_scale_size = Vector2i(1920, 1080)

	var controller: GameController = null
	if ResourceLoader.exists(GAME_SCENE_PATH):
		var packed: PackedScene = load(GAME_SCENE_PATH) as PackedScene
		if packed != null:
			controller = packed.instantiate() as GameController
	if controller == null:
		controller = GameController.new()

	root.add_child(controller)
	controller.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Wait 2 frames for _ready() & layout
	await process_frame
	await process_frame

	var tm: TurnManager = controller.turn_manager

	# 1) Curated player hand (6 cards: mix of Active & Passive)
	tm.white_engine.hand.clear()
	var showcase_ids: Array[String] = [
		"ACTIVE_04", "ACTIVE_18", "ACTIVE_25", "ACTIVE_30", "PASSIVE_05", "PASSIVE_15"
	]
	for cid in showcase_ids:
		var c: CardResource = CardDatabase.get_card(cid)
		if c != null:
			tm.white_engine.hand.append(c)

	# 2) Pending manual draw on DeckSlot (Glow pulse active!)
	tm.white_engine.manual_draw_mode = true
	tm.white_engine.pending_draws = 1

	# 3) Play 1 Active card into PlayerActiveSlot
	var cast_card: CardResource = CardDatabase.get_card("ACTIVE_04")
	if cast_card != null:
		controller._animate_active_slot_trigger(PieceData.Team.WHITE, cast_card)

	# 4) Place 2 Passive cards (slot 0 ready -> Glow-to-Click Pulse)
	var p1: CardResource = CardDatabase.get_card("PASSIVE_06")
	var p2: CardResource = CardDatabase.get_card("PASSIVE_18")
	if p1 != null:
		tm.passive_manager.place_passive(PieceData.Team.WHITE, p1, 1)
		var white_slots: Array[Dictionary] = tm.passive_manager.get_slots(PieceData.Team.WHITE)
		if white_slots.size() > 0:
			white_slots[0]["is_ready_to_trigger"] = true
	if p2 != null:
		tm.passive_manager.place_passive(PieceData.Team.WHITE, p2, 1)

	# 5) Place a Black pawn at d3 (3, 2) for capture ring + apply Lock (2 turns) & Curse (3 turns) on Black Queen at d5 (3, 4)
	tm.board.set_piece(Vector2i(3, 2), PieceData.new(PieceData.PieceType.PAWN, PieceData.Team.BLACK))
	var cursed_queen: PieceData = PieceData.new(PieceData.PieceType.QUEEN, PieceData.Team.BLACK)
	cursed_queen.is_locked = true
	cursed_queen.locked_turns = 2
	cursed_queen.is_cursed = true
	cursed_queen.curse_turns = 3
	tm.board.set_piece(Vector2i(3, 4), cursed_queen)

	controller._update_all_ui()
	controller.board_view.select_cell(Vector2i(4, 1))
	controller.show_message("ĐẾN LƯỢT RÚT BÀI — BẤM VÀO DECK ĐỂ RÚT!")

	# Wait frames so tile layout/rects finalize before positioning StatusTooltip
	await process_frame
	await process_frame

	var q_grid_idx: int = controller.board_view.board_to_grid(Vector2i(3, 4))
	if q_grid_idx >= 0 and q_grid_idx < controller.board_view.tile_controls.size():
		var q_tile: Control = controller.board_view.tile_controls[q_grid_idx]
		controller._on_tile_hovered(Vector2i(3, 4), q_tile.get_global_rect())

	# Wait several frames for textures, shaders, and draw calls to render
	for _i in range(6):
		await process_frame

	var tex: ViewportTexture = root.get_texture()
	if tex != null:
		var img: Image = tex.get_image()
		if img != null and not img.is_empty():
			var err: Error = img.save_png(OUTPUT_PATH)
			if err == OK:
				print("[PREVIEW] Saved UI preview to %s (%dx%d)" % [OUTPUT_PATH, img.get_width(), img.get_height()])
			else:
				print("[PREVIEW] Failed to save PNG, err=%d" % int(err))
		else:
			print("[PREVIEW] Viewport image is empty (headless driver has no rasterizer).")
	else:
		print("[PREVIEW] Viewport texture is null.")

	quit(0)
