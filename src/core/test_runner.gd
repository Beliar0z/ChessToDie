# res://src/core/test_runner.gd
# GDScript / test_runner.gd / Godot 4.7 / Headless Test Runner
extends SceneTree

func _init() -> void:
	print("==================================================")
	print("CHESS TO DIE - AUTOMATED HEADLESS TEST SUITE")
	print("==================================================")

	var tests_passed: int = 0
	var total_tests: int = 20

	if test_standard_fide_moves():
		tests_passed += 1
		print("[PASS] 1/14: test_standard_fide_moves")
	else:
		print("[FAIL] 1/14: test_standard_fide_moves")
		quit(1)
		return

	if test_card_draw_engine():
		tests_passed += 1
		print("[PASS] 2/14: test_card_draw_engine")
	else:
		print("[FAIL] 2/14: test_card_draw_engine")
		quit(1)
		return

	if test_turn_restrictions():
		tests_passed += 1
		print("[PASS] 3/14: test_turn_restrictions")
	else:
		print("[FAIL] 3/14: test_turn_restrictions")
		quit(1)
		return

	if test_checkmate_hook_survival():
		tests_passed += 1
		print("[PASS] 4/14: test_checkmate_hook_survival")
	else:
		print("[FAIL] 4/14: test_checkmate_hook_survival")
		quit(1)
		return

	if test_death_ring_stalemate_resolution():
		tests_passed += 1
		print("[PASS] 5/14: test_death_ring_stalemate_resolution")
	else:
		print("[FAIL] 5/14: test_death_ring_stalemate_resolution")
		quit(1)
		return

	if test_holy_war_kings_combat():
		tests_passed += 1
		print("[PASS] 6/14: test_holy_war_kings_combat")
	else:
		print("[FAIL] 6/14: test_holy_war_kings_combat")
		quit(1)
		return

	if test_curse_countdown():
		tests_passed += 1
		print("[PASS] 7/14: test_curse_countdown")
	else:
		print("[FAIL] 7/14: test_curse_countdown")
		quit(1)
		return

	if test_ui_scene_integration():
		tests_passed += 1
		print("[PASS] 8/14: test_ui_scene_integration")
	else:
		print("[FAIL] 8/14: test_ui_scene_integration")
		quit(1)
		return

	if test_fan_arc_hand_layout():
		tests_passed += 1
		print("[PASS] 9/14: test_fan_arc_hand_layout")
	else:
		print("[FAIL] 9/14: test_fan_arc_hand_layout")
		quit(1)
		return

	if test_piece_position_history_and_queen_tether():
		tests_passed += 1
		print("[PASS] 10/14: test_piece_position_history_and_queen_tether")
	else:
		print("[FAIL] 10/14: test_piece_position_history_and_queen_tether")
		quit(1)
		return

	if test_passive_glow_to_click_and_triggers():
		tests_passed += 1
		print("[PASS] 11/14: test_passive_glow_to_click_and_triggers")
	else:
		print("[FAIL] 11/14: test_passive_glow_to_click_and_triggers")
		quit(1)
		return

	if test_active_one_per_turn_warning_and_slot_render():
		tests_passed += 1
		print("[PASS] 12/14: test_active_one_per_turn_warning_and_slot_render")
	else:
		print("[FAIL] 12/14: test_active_one_per_turn_warning_and_slot_render")
		quit(1)
		return

	if test_multi_target_sequencing():
		tests_passed += 1
		print("[PASS] 13/14: test_multi_target_sequencing")
	else:
		print("[FAIL] 13/14: test_multi_target_sequencing")
		quit(1)
		return

	if test_card_icons_and_vfx_integration():
		tests_passed += 1
		print("[PASS] 14/15: test_card_icons_and_vfx_integration")
	else:
		print("[FAIL] 14/15: test_card_icons_and_vfx_integration")
		quit(1)
		return

	if test_manual_draw_and_status_tooltip():
		tests_passed += 1
		print("[PASS] 15/20: test_manual_draw_and_status_tooltip")
	else:
		print("[FAIL] 15/20: test_manual_draw_and_status_tooltip")
		quit(1)
		return

	if test_active_01_double_move_queen():
		tests_passed += 1
		print("[PASS] 16/20: test_active_01_double_move_queen")
	else:
		print("[FAIL] 16/20: test_active_01_double_move_queen")
		quit(1)
		return

	if test_passive_20_ban_exact_two_turns():
		tests_passed += 1
		print("[PASS] 17/20: test_passive_20_ban_exact_two_turns")
	else:
		print("[FAIL] 17/20: test_passive_20_ban_exact_two_turns")
		quit(1)
		return

	if test_passive_next_turn_rule_and_burn_zone():
		tests_passed += 1
		print("[PASS] 18/20: test_passive_next_turn_rule_and_burn_zone")
	else:
		print("[FAIL] 18/20: test_passive_next_turn_rule_and_burn_zone")
		quit(1)
		return

	if test_gravity_vortex_and_castling_and_temp_summon():
		tests_passed += 1
		print("[PASS] 19/20: test_gravity_vortex_and_castling_and_temp_summon")
	else:
		print("[FAIL] 19/20: test_gravity_vortex_and_castling_and_temp_summon")
		quit(1)
		return

	if test_remaining_passives_11_12_14_17_18_19():
		tests_passed += 1
		print("[PASS] 20/20: test_remaining_passives_11_12_14_17_18_19")
	else:
		print("[FAIL] 20/20: test_remaining_passives_11_12_14_17_18_19")
		quit(1)
		return

	print("==================================================")
	print("ALL TESTS PASSED! (%d/%d)" % [tests_passed, total_tests])
	print("==================================================")
	quit(0)

# 1. Standard FIDE moves, captures, check and checkmate
func test_standard_fide_moves() -> bool:
	var board: BoardState = BoardState.new()
	board.setup_initial_board()

	# White pawn at e2 (4, 1) should be able to move 2 squares to e4 (4, 3)
	var pawn_moves: Array[Vector2i] = MoveValidator.get_legal_moves(board, Vector2i(4, 1), false)
	if not pawn_moves.has(Vector2i(4, 2)) or not pawn_moves.has(Vector2i(4, 3)):
		print("Pawn initial 2-step move failed.")
		return false

	board.move_piece(Vector2i(4, 1), Vector2i(4, 3))
	if board.get_piece(Vector2i(4, 3)) == null or board.get_piece(Vector2i(4, 1)) != null:
		print("Pawn movement execution failed.")
		return false

	# Black knight at b8 (1, 7) should be able to jump to c6 (2, 5)
	var knight_moves: Array[Vector2i] = MoveValidator.get_legal_moves(board, Vector2i(1, 7), false)
	if not knight_moves.has(Vector2i(2, 5)):
		print("Knight L-jump move failed.")
		return false
	board.move_piece(Vector2i(1, 7), Vector2i(2, 5))

	# Test diagonal capture: spawn Black pawn at d5 (3, 4)
	board.set_piece(Vector2i(3, 4), PieceData.new(PieceData.PieceType.PAWN, PieceData.Team.BLACK))
	var white_pawn_captures: Array[Vector2i] = MoveValidator.get_legal_moves(board, Vector2i(4, 3), false)
	if not white_pawn_captures.has(Vector2i(3, 4)):
		print("Pawn diagonal capture move generation failed.")
		return false

	var captured: PieceData = board.move_piece(Vector2i(4, 3), Vector2i(3, 4))
	if captured == null or captured.team != PieceData.Team.BLACK or not board.grave_black.has(captured):
		print("Pawn diagonal capture execution failed.")
		return false

	# Test checkmate detection
	var mate_board: BoardState = BoardState.new()
	mate_board._init_empty_grid()
	mate_board.set_piece(Vector2i(0, 0), PieceData.new(PieceData.PieceType.KING, PieceData.Team.WHITE))
	mate_board.set_piece(Vector2i(0, 1), PieceData.new(PieceData.PieceType.QUEEN, PieceData.Team.BLACK))
	mate_board.set_piece(Vector2i(0, 7), PieceData.new(PieceData.PieceType.ROOK, PieceData.Team.BLACK))
	mate_board.set_piece(Vector2i(1, 7), PieceData.new(PieceData.PieceType.ROOK, PieceData.Team.BLACK))
	mate_board.set_piece(Vector2i(7, 7), PieceData.new(PieceData.PieceType.KING, PieceData.Team.BLACK))

	var is_check: bool = MoveValidator.is_in_check(mate_board, PieceData.Team.WHITE)
	var is_mate: bool = MoveValidator.is_checkmate(mate_board, PieceData.Team.WHITE, false)
	if not is_check or not is_mate:
		print("Standard check/checkmate check failed: check=%s, mate=%s" % [is_check, is_mate])
		return false

	return true

# 2. Card draw engine: initial 6 cards, 1 draw per 2 self moves, 10 card hand cap
func test_card_draw_engine() -> bool:
	var engine: CardEngine = CardEngine.new(PieceData.Team.WHITE)
	engine.setup_default_deck()

	if engine.deck.size() != 27 or engine.hand.size() != 0:
		print("Default deck setup failed.")
		return false

	var initial_hand: Array[CardResource] = engine.draw_initial_hand()
	if initial_hand.size() != 6 or engine.hand.size() != 6 or engine.deck.size() != 21:
		print("Initial hand 6-card draw failed.")
		return false

	# Move 1: no draw
	var drew1: bool = engine.on_move_completed()
	if drew1 or engine.hand.size() != 6:
		print("Draw triggered unexpectedly on move 1.")
		return false

	# Move 2: 1 draw
	var drew2: bool = engine.on_move_completed()
	if not drew2 or engine.hand.size() != 7:
		print("Draw failed to trigger on move 2.")
		return false

	# Move 3: no draw
	var drew3: bool = engine.on_move_completed()
	if drew3 or engine.hand.size() != 7:
		print("Draw triggered unexpectedly on move 3.")
		return false

	# Move 4: 1 draw
	var drew4: bool = engine.on_move_completed()
	if not drew4 or engine.hand.size() != 8:
		print("Draw failed to trigger on move 4.")
		return false

	# Draw until hand reaches 10 cards
	engine.draw_card() # 9
	engine.draw_card() # 10
	if engine.hand.size() != 10:
		print("Failed to reach 10 cards hand.")
		return false

	# Hand is full (10 cards cap)
	var extra_draw: CardResource = engine.draw_card()
	if extra_draw != null or engine.hand.size() != 10:
		print("Hand exceeded 10 card cap on direct draw.")
		return false

	# Test 2 moves when hand is full
	engine.on_move_completed()
	engine.on_move_completed()
	if engine.hand.size() != 10:
		print("Hand exceeded 10 card cap on move-based draw.")
		return false

	return true

# 3. Turn restrictions: max 1 Active per turn, max 1 Passive placed per turn, max 4 Passive slots
func test_turn_restrictions() -> bool:
	var tm: TurnManager = TurnManager.new()
	tm.start_game()

	var card_a1: CardResource = CardDatabase.get_card("ACTIVE_04")
	var card_a2: CardResource = CardDatabase.get_card("ACTIVE_05")
	tm.white_engine.hand.append(card_a1)
	tm.white_engine.hand.append(card_a2)

	# 1st Active should succeed
	var res_a1: bool = tm.play_active_card(card_a1)
	if not res_a1:
		print("First Active card play failed.")
		return false

	# 2nd Active in same turn should fail
	var res_a2: bool = tm.play_active_card(card_a2)
	if res_a2:
		print("Second Active card play in same turn succeeded unexpectedly.")
		return false

	# 1st Passive place should succeed
	var card_p1: CardResource = CardDatabase.get_card("PASSIVE_03")
	var card_p2: CardResource = CardDatabase.get_card("PASSIVE_04")
	tm.white_engine.hand.append(card_p1)
	tm.white_engine.hand.append(card_p2)

	var res_p1: bool = tm.place_passive_card(card_p1)
	if not res_p1:
		print("First Passive placement failed.")
		return false

	# 2nd Passive place in same turn should fail
	var res_p2: bool = tm.place_passive_card(card_p2)
	if res_p2:
		print("Second Passive placement in same turn succeeded unexpectedly.")
		return false

	# Test max 4 passive slots across simulated turns
	tm.white_engine.reset_turn_limits()
	var res_p2_turn2: bool = tm.place_passive_card(card_p2)
	if not res_p2_turn2:
		print("Second passive placement in turn 2 failed.")
		return false

	tm.white_engine.reset_turn_limits()
	var card_p3: CardResource = CardDatabase.get_card("PASSIVE_05")
	tm.white_engine.hand.append(card_p3)
	tm.place_passive_card(card_p3)

	tm.white_engine.reset_turn_limits()
	var card_p4: CardResource = CardDatabase.get_card("PASSIVE_06")
	tm.white_engine.hand.append(card_p4)
	tm.place_passive_card(card_p4)

	if tm.passive_manager.get_slots(PieceData.Team.WHITE).size() != 4:
		print("Failed to fill 4 passive slots.")
		return false

	# 5th passive should fail due to slot limit
	tm.white_engine.reset_turn_limits()
	var card_p5: CardResource = CardDatabase.get_card("PASSIVE_07")
	tm.white_engine.hand.append(card_p5)
	var res_p5: bool = tm.place_passive_card(card_p5)
	if res_p5:
		print("5th Passive placed successfully beyond 4-slot limit.")
		return false

	return true

# 4. Checkmate Interception Hook: trigger ONLY 1 card (prioritize earlier placed), grant 2 moves
func test_checkmate_hook_survival() -> bool:
	var tm: TurnManager = TurnManager.new()
	var pas15: CardResource = CardDatabase.get_card("PASSIVE_15")
	var pas16: CardResource = CardDatabase.get_card("PASSIVE_16")

	# Place PASSIVE_15 first at turn 1, then PASSIVE_16 at turn 2
	tm.passive_manager.place_passive(PieceData.Team.BLACK, pas15, 1)
	tm.passive_manager.place_passive(PieceData.Team.BLACK, pas16, 2)

	var black_slots: Array[Dictionary] = tm.passive_manager.get_slots(PieceData.Team.BLACK)
	if black_slots.size() != 2:
		print("Setup of passive slots failed.")
		return false

	# Trigger checkmate hook
	var hook_res: Dictionary = tm.passive_manager.trigger_checkmate_hook(PieceData.Team.BLACK)
	if not hook_res.get("intercepted", false):
		print("Checkmate hook failed to intercept.")
		return false

	# Must trigger ONLY ONE: the earlier placed card (PASSIVE_15)
	if hook_res.get("card_id", "") != "PASSIVE_15":
		print("Checkmate hook did not trigger earlier placed card PASSIVE_15.")
		return false

	if hook_res.get("extra_moves_granted", 0) != 2:
		print("Checkmate hook did not grant 2 moves.")
		return false

	if hook_res.get("target_scope", "") != "KING":
		print("Checkmate hook target scope is not KING.")
		return false

	# The remaining slot must be PASSIVE_16
	var remaining_slots: Array[Dictionary] = tm.passive_manager.get_slots(PieceData.Team.BLACK)
	if remaining_slots.size() != 1:
		print("Slots size after interception is not 1.")
		return false

	var remaining_card: CardResource = remaining_slots[0]["card"]
	if remaining_card.id != "PASSIVE_16":
		print("Remaining card is not PASSIVE_16.")
		return false

	return true

# 5. Death Ring Stalemate Resolution: higher initial points loses on 0 points (Decision B)
func test_death_ring_stalemate_resolution() -> bool:
	var board: BoardState = BoardState.new()
	board._init_empty_grid()

	# White King at a1 (0, 0): points = 10.0
	board.set_piece(Vector2i(0, 0), PieceData.new(PieceData.PieceType.KING, PieceData.Team.WHITE))

	# Black King at c2 (2, 1) and Queen at b3 (1, 2): points = 10 + 9 = 19.0
	board.set_piece(Vector2i(2, 1), PieceData.new(PieceData.PieceType.KING, PieceData.Team.BLACK))
	board.set_piece(Vector2i(1, 2), PieceData.new(PieceData.PieceType.QUEEN, PieceData.Team.BLACK))

	# White is not in check, but has 0 legal moves -> Stalemate
	if MoveValidator.is_in_check(board, PieceData.Team.WHITE):
		print("White King is in check unexpectedly in stalemate setup.")
		return false

	if not MoveValidator.is_stalemate(board, PieceData.Team.WHITE, false):
		print("Stalemate was not detected.")
		return false

	var dr: DeathRingSystem = DeathRingSystem.new()
	dr.activate_death_ring(board)

	if not dr.is_death_ring_active:
		print("Death Ring failed to activate.")
		return false

	if dr.initial_points_white != 10.0 or dr.initial_points_black != 19.0:
		print("Initial points recording failed: W=%f, B=%f" % [dr.initial_points_white, dr.initial_points_black])
		return false

	# Burn points down to 0
	dr.burn_rate_per_turn = 5.0
	var res1: Dictionary = dr.process_turn_burn(board, PieceData.Team.WHITE)
	if res1.get("game_over", false):
		print("Game over triggered too early in death ring.")
		return false

	var res2: Dictionary = dr.process_turn_burn(board, PieceData.Team.WHITE)
	if not res2.get("game_over", false):
		print("Game over not triggered when points hit 0.")
		return false

	# Decision B: Side with HIGHER initial points (Black with 19.0 > White with 10.0) LOSES -> White WINS!
	var winner: int = res2.get("winner", -1)
	if winner != int(PieceData.Team.WHITE):
		print("Decision B check failed: Winner is not White (was %d)." % winner)
		return false

	return true

# 6. Holy War Kings Combat: 2 Kings only, can approach and capture King directly (Decision A)
func test_holy_war_kings_combat() -> bool:
	var board: BoardState = BoardState.new()
	board._init_empty_grid()

	# 2 adjacent Kings: White King at (3, 3), Black King at (3, 4)
	board.set_piece(Vector2i(3, 3), PieceData.new(PieceData.PieceType.KING, PieceData.Team.WHITE))
	board.set_piece(Vector2i(3, 4), PieceData.new(PieceData.PieceType.KING, PieceData.Team.BLACK))

	var dr: DeathRingSystem = DeathRingSystem.new()
	var activated: bool = dr.check_and_activate_holy_war(board)
	if not activated or not dr.is_holy_war_active:
		print("Holy War failed to activate with 2 Kings.")
		return false

	# Decision A: Breaking FIDE rules, White King can move directly to (3, 4) to capture Black King
	var legal: Array[Vector2i] = MoveValidator.get_legal_moves(board, Vector2i(3, 3), true)
	if not legal.has(Vector2i(3, 4)):
		print("Decision A failed: King cannot attack enemy King directly in Holy War.")
		return false

	# Execute move in TurnManager
	var tm: TurnManager = TurnManager.new(board)
	tm.death_ring_system.is_holy_war_active = true
	tm.current_phase = TurnManager.Phase.MAIN_PHASE
	tm.current_turn_team = PieceData.Team.WHITE

	var moved: bool = tm.execute_move(Vector2i(3, 3), Vector2i(3, 4))
	if not moved or not tm.is_game_over or tm.winner != int(PieceData.Team.WHITE):
		print("King direct capture execution failed in Holy War.")
		return false

	# Test King selecting other piece movement styles
	var board2: BoardState = BoardState.new()
	board2._init_empty_grid()
	board2.set_piece(Vector2i(0, 0), PieceData.new(PieceData.PieceType.KING, PieceData.Team.WHITE))
	board2.set_piece(Vector2i(7, 7), PieceData.new(PieceData.PieceType.KING, PieceData.Team.BLACK))

	var tm2: TurnManager = TurnManager.new(board2)
	tm2.death_ring_system.is_holy_war_active = true

	tm2.set_holy_war_king_move_mode(PieceData.Team.WHITE, "ROOK")
	var rook_moves: Array[Vector2i] = MoveValidator.get_legal_moves(board2, Vector2i(0, 0), true)
	if not rook_moves.has(Vector2i(0, 5)):
		print("King adopting Rook style in Holy War failed.")
		return false

	tm2.set_holy_war_king_move_mode(PieceData.Team.WHITE, "KNIGHT")
	var knight_moves: Array[Vector2i] = MoveValidator.get_legal_moves(board2, Vector2i(0, 0), true)
	if not knight_moves.has(Vector2i(1, 2)):
		print("King adopting Knight style in Holy War failed.")
		return false

	return true

# 7. Curse Countdown: Active 31 curses piece, counts down turns = points, destroys if unmoved
func test_curse_countdown() -> bool:
	var tm: TurnManager = TurnManager.new()
	tm.start_game()

	# Black has a Rook (5 points) at a8 (0, 7)
	var rook: PieceData = tm.board.get_piece(Vector2i(0, 7))
	if rook == null or rook.type != PieceData.PieceType.ROOK or rook.points != 5:
		print("Target Rook not found at (0, 7).")
		return false

	# White plays Active 31 (DEATH_CURSE) targeting the Rook
	var curse_card: CardResource = CardDatabase.get_card("ACTIVE_31")
	tm.white_engine.hand.append(curse_card)
	var cursed: bool = tm.play_active_card(curse_card, Vector2i(0, 7))
	if not cursed or not rook.is_cursed or rook.curse_turns != 5:
		print("Curse card play failed.")
		return false

	# White moves Pawn e2 to e3 to finish White's turn
	tm.execute_move(Vector2i(4, 1), Vector2i(4, 2))
	if tm.current_turn_team != PieceData.Team.BLACK or rook.curse_turns != 5:
		print("Turn did not switch to Black or curse decremented during White's turn.")
		return false

	# Black takes 5 turns moving other pieces without moving the cursed Rook
	# Move 1: Black moves a7 to a6
	tm.execute_move(Vector2i(0, 6), Vector2i(0, 5))
	if rook.curse_turns != 4 or tm.board.get_piece(Vector2i(0, 7)) == null:
		print("Curse turn 1 countdown failed: turns=%d" % rook.curse_turns)
		return false

	# Move 2
	tm.execute_move(Vector2i(4, 2), Vector2i(4, 3)) # White
	tm.execute_move(Vector2i(1, 6), Vector2i(1, 5)) # Black
	if rook.curse_turns != 3:
		print("Curse turn 2 countdown failed: turns=%d" % rook.curse_turns)
		return false

	# Move 3
	tm.execute_move(Vector2i(3, 1), Vector2i(3, 2)) # White
	tm.execute_move(Vector2i(2, 6), Vector2i(2, 5)) # Black
	if rook.curse_turns != 2:
		print("Curse turn 3 countdown failed: turns=%d" % rook.curse_turns)
		return false

	# Move 4
	tm.execute_move(Vector2i(2, 1), Vector2i(2, 2)) # White
	tm.execute_move(Vector2i(3, 6), Vector2i(3, 5)) # Black
	if rook.curse_turns != 1:
		print("Curse turn 4 countdown failed: turns=%d" % rook.curse_turns)
		return false

	# Move 5: After this move, curse_turns reaches 0 and Rook must be destroyed
	tm.execute_move(Vector2i(1, 1), Vector2i(1, 2)) # White
	tm.execute_move(Vector2i(5, 6), Vector2i(5, 5)) # Black

	if tm.board.get_piece(Vector2i(0, 7)) != null:
		print("Cursed Rook was not removed from board when curse countdown finished.")
		return false

	if not tm.board.grave_black.has(rook):
		print("Cursed Rook was not added to black graveyard.")
		return false

	return true

# 8. UI Scene Integration test
func test_ui_scene_integration() -> bool:
	var controller: GameController = null
	var scene_path: String = "res://assets/ui/game_scene.tscn"

	if ResourceLoader.exists(scene_path):
		var scene: PackedScene = load(scene_path) as PackedScene
		if scene == null:
			print("Error: Could not load scene at %s" % scene_path)
			return false
		var instance: Node = scene.instantiate()
		controller = instance as GameController
		if controller == null:
			print("Error: Root node of %s does not have GameController script" % scene_path)
			return false
	else:
		# Graceful Fallback (Rule 5)
		print("Note: %s not yet created by Ag3; validating GameController with fallback." % scene_path)
		controller = GameController.new()

	controller.setup_game()

	# Check existence of all required child nodes
	var required_nodes: Array[String] = [
		"Chessboard",
		"HandContainer",
		"DeckSlot",
		"PlayerActiveSlot",
		"OpponentActiveSlot",
		"PlayerPassiveRow",
		"OpponentPassiveRow",
		"EndTurnButton"
	]

	for node_name in required_nodes:
		var found_node: Node = controller.find_child(node_name, true, false)
		if found_node == null:
			print("Error: Missing required node '%s' in GameController scene" % node_name)
			return false

	# Simulate 1 chess move: White pawn e2 (4, 1) to e4 (4, 3)
	var from_pos: Vector2i = Vector2i(4, 1)
	var to_pos: Vector2i = Vector2i(4, 3)

	var piece_before: PieceData = controller.turn_manager.board.get_piece(from_pos)
	if piece_before == null or piece_before.type != PieceData.PieceType.PAWN:
		print("Error: Expected White pawn at e2 (4, 1)")
		return false

	# Trigger board click on e2 to select
	controller._on_tile_clicked(from_pos)
	if controller.board_view.selected_cell != from_pos:
		print("Error: Board selection failed for cell (4, 1)")
		return false

	# Trigger board click on e4 to move
	controller._on_tile_clicked(to_pos)
	if controller.board_view.selected_cell != Vector2i(-1, -1):
		print("Error: Board cell was not deselected after move")
		return false

	var piece_after: PieceData = controller.turn_manager.board.get_piece(to_pos)
	if piece_after == null or piece_after.type != PieceData.PieceType.PAWN:
		print("Error: Pawn was not moved to e4 (4, 3)")
		return false

	# Verify turn transitioned to Black
	if controller.turn_manager.current_turn_team != PieceData.Team.BLACK:
		print("Error: Turn did not advance to Black team after move")
		return false

	controller.free()
	return true

# 9. Fan Arc Hand Layout test
func test_fan_arc_hand_layout() -> bool:
	var tm: TurnManager = TurnManager.new()
	tm.start_game()

	var hand_view: CardHandView = CardHandView.new()
	hand_view.setup(tm, PieceData.Team.WHITE)

	if hand_view.cards_container == null or hand_view.cards_container is HBoxContainer:
		print("Hand view cards_container is null or still an HBoxContainer.")
		hand_view.free()
		return false

	var child_count: int = hand_view.cards_container.get_child_count()
	if child_count == 0:
		print("No card holders in hand view.")
		hand_view.free()
		return false

	var first_holder: CardHandView.DraggableCardSlot = hand_view.cards_container.get_child(0) as CardHandView.DraggableCardSlot
	var last_holder: CardHandView.DraggableCardSlot = hand_view.cards_container.get_child(child_count - 1) as CardHandView.DraggableCardSlot

	# First card should rotate negative angle, last card should rotate positive angle
	if first_holder.rotation_degrees >= 0.0 or last_holder.rotation_degrees <= 0.0:
		print("Fan arc angles invalid: first=%f, last=%f" % [first_holder.rotation_degrees, last_holder.rotation_degrees])
		hand_view.free()
		return false

	# Test hover effect: mouse_entered
	hand_view._on_card_mouse_entered(first_holder)
	if first_holder.rotation_degrees != 0.0 or first_holder.scale != CardHandView.HOVER_SCALE or first_holder.z_index != 50:
		print("Hover state failed: rot=%f, scale=%s, z=%d" % [first_holder.rotation_degrees, str(first_holder.scale), first_holder.z_index])
		hand_view.free()
		return false

	# Test mouse_exited restores base state
	hand_view._on_card_mouse_exited(first_holder)
	if first_holder.scale != Vector2.ONE or first_holder.z_index != int(first_holder.get_meta("base_z")):
		print("Exit hover state restore failed: scale=%s, z=%d" % [str(first_holder.scale), first_holder.z_index])
		hand_view.free()
		return false

	hand_view.free()
	return true

# 10. Position History and Queen Tether test
func test_piece_position_history_and_queen_tether() -> bool:
	var board: BoardState = BoardState.new()
	board.setup_initial_board()

	var white_queen: PieceData = board.get_piece(Vector2i(3, 0))
	if white_queen == null or white_queen.type != PieceData.PieceType.QUEEN:
		print("White queen not at (3, 0).")
		return false

	if white_queen.position_history.is_empty() or white_queen.position_history[0] != Vector2i(3, 0):
		print("Initial position history not recorded on queen: %s" % str(white_queen.position_history))
		return false

	# Move Queen 1: (3, 0) -> (3, 4)
	board.set_piece(Vector2i(3, 1), null)
	board.move_piece(Vector2i(3, 0), Vector2i(3, 4))
	if white_queen.position_history.size() != 2 or white_queen.position_history.back() != Vector2i(3, 4):
		print("Position history after move 1 failed: %s" % str(white_queen.position_history))
		return false

	# Move Queen 2: (3, 4) -> (7, 4)
	board.move_piece(Vector2i(3, 4), Vector2i(7, 4))
	if white_queen.position_history.size() != 3 or white_queen.position_history.back() != Vector2i(7, 4):
		print("Position history after move 2 failed: %s" % str(white_queen.position_history))
		return false

	var pos_2_moves_ago: Vector2i = white_queen.get_position_two_moves_ago()
	if pos_2_moves_ago != Vector2i(3, 0):
		print("get_position_two_moves_ago returned %s, expected (3, 0)" % str(pos_2_moves_ago))
		return false

	# Execute Queen tether (PASSIVE_06)
	var tethered: Array[Dictionary] = board.execute_queen_tether()
	if tethered.is_empty():
		print("execute_queen_tether returned empty array.")
		return false

	if board.get_piece(Vector2i(3, 0)) != white_queen or white_queen.is_locked:
		print("Queen was not returned to (3, 0) cleanly without unwanted lock.")
		return false

	return true

# 11. Passive Glow-to-Click & Triggers test
func test_passive_glow_to_click_and_triggers() -> bool:
	var tm: TurnManager = TurnManager.new()
	tm.start_game()

	var card_p06: CardResource = CardDatabase.get_card("PASSIVE_06")
	tm.white_engine.hand.append(card_p06)
	var placed: bool = tm.place_passive_card(card_p06)
	if not placed:
		print("Placing PASSIVE_06 failed.")
		return false

	var slot: Dictionary = tm.passive_manager.get_slot(PieceData.Team.WHITE, 0)
	if slot.get("is_ready_to_trigger", false) != false:
		print("Passive slot prematurely marked ready to trigger.")
		return false

	# Advance 1 turn so PASSIVE_06 satisfies turns_on_board >= 1 rule (GDD line 14)
	tm.passive_manager.on_turn_end(PieceData.Team.WHITE)

	# Simulate Boss moves Queen
	var b_queen: PieceData = tm.board.get_piece(Vector2i(3, 7))
	var triggered: Array[Dictionary] = tm.passive_manager.evaluate_triggers("queen_moved", {
		"active_team": PieceData.Team.BLACK,
		"moved_piece": b_queen,
		"from": Vector2i(3, 7),
		"to": Vector2i(3, 5),
		"board": tm.board
	})

	if triggered.is_empty():
		print("evaluate_triggers did not trigger PASSIVE_06 on enemy queen move.")
		return false

	var updated_slot: Dictionary = tm.passive_manager.get_slot(PieceData.Team.WHITE, 0)
	if not updated_slot.get("is_ready_to_trigger", false):
		print("Slot is_ready_to_trigger not set to true.")
		return false

	# Execute trigger (simulating click on glowing slot)
	var exec_res: Dictionary = tm.execute_passive_trigger(PieceData.Team.WHITE, 0)
	if not exec_res.get("success", false):
		print("execute_passive_trigger failed.")
		return false

	# Verify slot was consumed
	if not tm.passive_manager.get_slots(PieceData.Team.WHITE).is_empty():
		print("Triggered passive slot was not consumed.")
		return false

	return true

# 12. Active 1/Turn Warning & Slot Render test
func test_active_one_per_turn_warning_and_slot_render() -> bool:
	var scene_path: String = "res://assets/ui/game_scene.tscn"
	var controller: GameController = null
	if ResourceLoader.exists(scene_path):
		var scene: PackedScene = load(scene_path) as PackedScene
		controller = scene.instantiate() as GameController
	else:
		controller = GameController.new()

	controller.setup_game()

	var card_act1: CardResource = CardDatabase.get_card("ACTIVE_04") # Khiên Vua
	var card_act2: CardResource = CardDatabase.get_card("ACTIVE_18") # Sông

	controller.turn_manager.white_engine.hand.append(card_act1)
	controller.turn_manager.white_engine.hand.append(card_act2)

	# Play 1st active card
	controller._try_cast_active_card(card_act1)
	if controller.turn_manager.white_engine.actives_used_this_turn != 1:
		print("Actives used this turn count not incremented to 1.")
		controller.free()
		return false

	# Check active slot rendering
	var slot_container: Control = controller.player_active_slot.find_child("CardContainer", true, false) as Control
	if slot_container == null or slot_container.get_child_count() == 0:
		print("Active slot CardContainer was not populated with card UI.")
		controller.free()
		return false

	# Attempt to play 2nd active card in the same turn
	controller._try_cast_active_card(card_act2)

	if controller.message_banner.text != "MỖI LƯỢT CHỈ ĐƯỢC DÙNG 1 LÁ ACTIVE!":
		print("Banner message mismatch for 2nd active limit: '%s'" % controller.message_banner.text)
		controller.free()
		return false

	if controller.turn_manager.white_engine.actives_used_this_turn != 1:
		print("2nd active card was played despite 1/turn limit.")
		controller.free()
		return false

	controller.free()
	return true

# 13. Multi-Target Sequencing test
func test_multi_target_sequencing() -> bool:
	var tm: TurnManager = TurnManager.new()
	tm.start_game()

	# Test ACTIVE_03 (Hoán Đổi 2 quân đồng minh): Rook at (0, 0) and Knight at (1, 0)
	var card_swap: CardResource = CardDatabase.get_card("ACTIVE_03")
	tm.white_engine.hand.append(card_swap)

	var p_rook: PieceData = tm.board.get_piece(Vector2i(0, 0))
	var p_knight: PieceData = tm.board.get_piece(Vector2i(1, 0))

	var swapped: bool = tm.play_active_card(card_swap, Vector2i(-1, -1), Vector2i(-1, -1), [Vector2i(0, 0), Vector2i(1, 0)])
	if not swapped:
		print("Playing ACTIVE_03 with 2 targets failed.")
		return false

	if tm.board.get_piece(Vector2i(0, 0)) != p_knight or tm.board.get_piece(Vector2i(1, 0)) != p_rook:
		print("Pieces at (0, 0) and (1, 0) were not swapped.")
		return false

	# Test ACTIVE_05 (5 Ô Cấm):
	var tm2: TurnManager = TurnManager.new()
	tm2.start_game()
	var card_ban5: CardResource = CardDatabase.get_card("ACTIVE_05")
	tm2.white_engine.hand.append(card_ban5)

	var five_cells: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3)]
	var banned: bool = tm2.play_active_card(card_ban5, Vector2i(-1, -1), Vector2i(-1, -1), five_cells)
	if not banned:
		print("Playing ACTIVE_05 with 5 targets failed.")
		return false

	for c in five_cells:
		if not tm2.board.is_cell_forbidden(c):
			print("Cell %s was not marked forbidden by ACTIVE_05." % str(c))
			return false

	return true

# 14. Card Icons (51 SVGs) & VFXManager Integration test
func test_card_icons_and_vfx_integration() -> bool:
	var all_cards: Dictionary = CardDatabase.get_all_cards()
	if all_cards.size() != 51:
		print("Expected 51 cards in CardDatabase, got %d." % all_cards.size())
		return false

	for id_key in all_cards.keys():
		var card: CardResource = all_cards[id_key] as CardResource
		var expected_path: String = "res://assets/sprites/cards/art/" + String(id_key).to_lower() + ".png"
		if card == null or card.icon_path != expected_path:
			print("Card %s has invalid icon_path: '%s' (expected '%s')" % [str(id_key), card.icon_path if card != null else "null", expected_path])
			return false

	var vfx: VFXManager = VFXManager.new()
	var bv: BoardView = BoardView.new()
	vfx.setup(bv)

	var vfx_types: Array[String] = ["ripple", "explosion_cross", "vortex", "lock_chains", "fusion_beam", "dissolve"]
	for vt in vfx_types:
		vfx.play_tile_vfx(Vector2i(3, 3), vt)

	vfx.trigger_board_shake(8.0, 0.25)
	vfx.play_card_cast_vfx(CardDatabase.get_card("ACTIVE_25"), bv)

	if VFXManager.get_vfx_type_for_card(CardDatabase.get_card("ACTIVE_25")) != "explosion_cross":
		print("VFXManager card mapping failed for ACTIVE_25.")
		vfx.free()
		bv.free()
		return false

	if VFXManager.get_vfx_type_for_card(CardDatabase.get_card("ACTIVE_30")) != "vortex":
		print("VFXManager card mapping failed for ACTIVE_30.")
		vfx.free()
		bv.free()
		return false

	vfx.free()
	bv.free()
	return true

# 15. Manual Draw Mode & StatusTooltip (Piece effects + Passive slots + Fog of War)
func test_manual_draw_and_status_tooltip() -> bool:
	# Part A: Manual Draw Mode in CardEngine
	var engine: CardEngine = CardEngine.new(PieceData.Team.WHITE)
	engine.setup_default_deck()
	engine.manual_draw_mode = true
	engine.draw_initial_hand() # 6 cards, 21 left in deck

	if engine.has_pending_draw() or engine.pending_draws != 0:
		print("Manual draw should start with 0 pending draws.")
		return false

	# Move 1 -> still 0 pending draws
	var m1: bool = engine.on_move_completed()
	if m1 or engine.pending_draws != 0 or engine.hand.size() != 6:
		print("Move 1 unexpectedly triggered manual draw.")
		return false

	# Move 2 -> pending_draws == 1, hand size remains 6 (no auto-draw!)
	var m2: bool = engine.on_move_completed()
	if not m2 or engine.pending_draws != 1 or not engine.has_pending_draw() or engine.hand.size() != 6:
		print("Move 2 failed to queue pending draw in manual_draw_mode.")
		return false

	# Claim pending draw -> draws 1 card, pending_draws returns to 0
	var claimed: CardResource = engine.claim_pending_draw()
	if claimed == null or engine.hand.size() != 7 or engine.pending_draws != 0 or engine.has_pending_draw():
		print("claim_pending_draw failed to draw 1 card and decrement pending_draws.")
		return false

	# Test skip_pending_draw
	engine.on_move_completed()
	engine.on_move_completed()
	if engine.pending_draws != 1:
		print("Expected pending_draws == 1 before skip.")
		return false
	engine.skip_pending_draw()
	if engine.pending_draws != 0 or engine.hand.size() != 7:
		print("skip_pending_draw failed.")
		return false

	# Part B: StatusTooltip formatting for pieces & Fog of War
	var board: BoardState = BoardState.new()
	board.setup_initial_board()

	var white_queen: PieceData = board.get_piece(Vector2i(3, 0))
	white_queen.is_locked = true
	white_queen.locked_turns = 2
	white_queen.is_cursed = true
	white_queen.curse_turns = 3
	white_queen.is_immortal = true
	white_queen.immortal_turns = 1

	var piece_tip: Dictionary = StatusTooltip.build_piece_tooltip_data(board, Vector2i(3, 0), PieceData.Team.WHITE)
	if not bool(piece_tip.get("should_show", false)):
		print("StatusTooltip did not activate for debuffed/buffed piece.")
		return false

	var tip_body: String = "\n".join(piece_tip.get("lines", []))
	if not tip_body.contains("còn 2 lượt") or not tip_body.contains("còn 3 lượt") or not tip_body.contains("còn 1 lượt"):
		print("StatusTooltip piece lines missing turn counts: %s" % tip_body)
		return false

	# Fog of War: Enemy stealthed piece must NOT reveal tooltip
	var black_rook: PieceData = board.get_piece(Vector2i(0, 7))
	black_rook.is_stealth = true
	black_rook.stealth_turns = 2
	var stealth_tip: Dictionary = StatusTooltip.build_piece_tooltip_data(board, Vector2i(0, 7), PieceData.Team.WHITE)
	if bool(stealth_tip.get("should_show", false)):
		print("Fog of War violated: enemy stealthed piece showed tooltip.")
		return false

	# Part C: StatusTooltip formatting for Passive slots (own vs opponent)
	var pm: PassiveManager = PassiveManager.new()
	var p_card: CardResource = CardDatabase.get_card("PASSIVE_06")
	pm.place_passive(PieceData.Team.WHITE, p_card, 1)
	pm.place_passive(PieceData.Team.BLACK, p_card, 1)

	var own_slot: Dictionary = pm.get_slot(PieceData.Team.WHITE, 0)
	own_slot["is_ready_to_trigger"] = true
	var own_tip: Dictionary = StatusTooltip.build_passive_tooltip_data(own_slot, PieceData.Team.WHITE, 3, pm, PieceData.Team.WHITE)
	if not bool(own_tip.get("should_show", false)) or not String(own_tip.get("title", "")).contains(p_card.title):
		print("Own passive tooltip missing card title.")
		return false
	var own_body: String = "\n".join(own_tip.get("lines", []))
	if not own_body.contains("2 vòng") or not own_body.contains("SẴN SÀNG KÍCH HOẠT"):
		print("Own passive tooltip missing round count or ready status: %s" % own_body)
		return false

	var opp_slot: Dictionary = pm.get_slot(PieceData.Team.BLACK, 0)
	var opp_tip: Dictionary = StatusTooltip.build_passive_tooltip_data(opp_slot, PieceData.Team.BLACK, 3, pm, PieceData.Team.WHITE)
	if not bool(opp_tip.get("should_show", false)) or String(opp_tip.get("title", "")) != "Bài Bẫy Úp (Đối Thủ)":
		print("Opponent passive tooltip violated Fog of War: %s" % str(opp_tip))
		return false

	# Instantiate StatusTooltip node & verify clamp
	var tooltip_node: StatusTooltip = StatusTooltip.new()
	var tip_lines: Array[String] = []
	for l in piece_tip.get("lines", []):
		tip_lines.append(String(l))
	tooltip_node.show_tooltip(String(piece_tip.get("title", "")), tip_lines, Rect2(Vector2(1850, 1000), Vector2(60, 60)))
	if not tooltip_node.visible or tooltip_node.global_position.x + tooltip_node.size.x > 1920.0:
		print("StatusTooltip failed to clamp within 1920x1080 bounds.")
		tooltip_node.free()
		return false
	tooltip_node.free()

	return true

# 16. ACTIVE_01 (Song Trùng): Queen moves exactly 2 consecutive times in 1 turn before switching to Black
func test_active_01_double_move_queen() -> bool:
	var tm: TurnManager = TurnManager.new()
	tm.start_game()
	# Clear pawn in front of White Queen at d2 (3, 1)
	tm.board.remove_piece(Vector2i(3, 1))

	var card_a01: CardResource = CardDatabase.get_card("ACTIVE_01")
	tm.white_engine.hand.append(card_a01)
	if not tm.play_active_card(card_a01, Vector2i(3, 0)):
		print("Failed to play ACTIVE_01 on White Queen.")
		return false

	# Move 1: Queen d1 (3, 0) -> d4 (3, 3)
	if not tm.execute_move(Vector2i(3, 0), Vector2i(3, 3)):
		print("Queen 1st move failed.")
		return false

	# Must still be White's turn with double_move_piece_pos == (3, 3)
	if tm.current_turn_team != PieceData.Team.WHITE or tm.double_move_piece_pos != Vector2i(3, 3):
		print("Turn switched prematurely or double_move_piece_pos invalid: team=%d, pos=%s" % [tm.current_turn_team, str(tm.double_move_piece_pos)])
		return false

	# Another White piece (pawn e2 -> e3) MUST be rejected during 2nd move
	if tm.execute_move(Vector2i(4, 1), Vector2i(4, 2)):
		print("Another piece was allowed to move during ACTIVE_01 2nd move window.")
		return false

	# Move 2: Queen d4 (3, 3) -> f4 (5, 3)
	if not tm.execute_move(Vector2i(3, 3), Vector2i(5, 3)):
		print("Queen 2nd move failed.")
		return false

	# Now turn must switch to Black and double_move_piece_pos reset
	if tm.current_turn_team != PieceData.Team.BLACK or tm.double_move_piece_pos != Vector2i(-1, -1):
		print("Turn did not switch to Black after 2nd move.")
		return false

	if tm.board.get_piece(Vector2i(5, 3)) == null or tm.board.get_piece(Vector2i(5, 3)).type != PieceData.PieceType.QUEEN:
		print("White Queen not found at final destination (5, 3).")
		return false

	return true

# 17. PASSIVE_20 (Truy Hồn Trục Xuất): Black piece captures White -> banned for EXACTLY 2 Black turns, unbanned on 3rd
func test_passive_20_ban_exact_two_turns() -> bool:
	var tm: TurnManager = TurnManager.new()
	tm.start_game()

	# Place PASSIVE_20 for White on turn 1
	var card_p20: CardResource = CardDatabase.get_card("PASSIVE_20")
	tm.white_engine.hand.append(card_p20)
	if not tm.place_passive_card(card_p20):
		print("Failed to place PASSIVE_20.")
		return false

	# Place a Black Knight at d5 (3, 4) and a White Pawn at e3 (4, 2) -> Knight can capture e3
	var b_knight: PieceData = PieceData.new(PieceData.PieceType.KNIGHT, PieceData.Team.BLACK)
	tm.board.set_piece(Vector2i(3, 4), b_knight)
	# White moves e2 (4, 1) -> e3 (4, 2) -> ends White turn 1 (PASSIVE_20 turns_on_board becomes 1)
	if not tm.execute_move(Vector2i(4, 1), Vector2i(4, 2)):
		print("White setup move failed.")
		return false

	# Black captures White pawn at (4, 2) with Knight from (3, 4)
	if not tm.execute_move(Vector2i(3, 4), Vector2i(4, 2)):
		print("Black capture move failed.")
		return false

	# Verify PASSIVE_20 became ready to trigger
	var slot: Dictionary = tm.passive_manager.get_slot(PieceData.Team.WHITE, 0)
	if not bool(slot.get("is_ready_to_trigger", false)):
		print("PASSIVE_20 did not trigger on enemy capture.")
		return false

	# White triggers PASSIVE_20 (now it is White's turn)
	var trig_res: Dictionary = tm.execute_passive_trigger(PieceData.Team.WHITE, 0)
	if not bool(trig_res.get("success", false)) or not b_knight.is_banned or b_knight.banned_turns != 2:
		print("PASSIVE_20 failed to ban Black Knight for 2 turns.")
		return false

	# White finishes turn
	tm.execute_move(Vector2i(0, 1), Vector2i(0, 2))

	# Black Turn 1: Knight at (4, 2) MUST be banned (cannot move)
	if not b_knight.is_banned or not MoveValidator.get_legal_moves(tm.board, Vector2i(4, 2), false).is_empty():
		print("Black Knight was not banned on Black Turn 1.")
		return false
	# Black moves another piece (a7 -> a6)
	tm.execute_move(Vector2i(0, 6), Vector2i(0, 5))
	if not b_knight.is_banned or b_knight.banned_turns != 1:
		print("After Black Turn 1, expected banned_turns == 1, got %d (banned=%s)." % [b_knight.banned_turns, str(b_knight.is_banned)])
		return false

	# White finishes turn
	tm.execute_move(Vector2i(1, 1), Vector2i(1, 2))

	# Black Turn 2: Knight MUST STILL be banned
	if not b_knight.is_banned or not MoveValidator.get_legal_moves(tm.board, Vector2i(4, 2), false).is_empty():
		print("Black Knight was unbanned too early on Black Turn 2.")
		return false
	# Black moves another piece (b7 -> b6) -> end of Black Turn 2 should unban Knight!
	tm.execute_move(Vector2i(1, 6), Vector2i(1, 5))
	if b_knight.is_banned or b_knight.banned_turns != 0:
		print("Black Knight stayed permanently banned after 2 turns! banned=%s, turns=%d" % [str(b_knight.is_banned), b_knight.banned_turns])
		return false

	# White finishes turn
	tm.execute_move(Vector2i(2, 1), Vector2i(2, 2))

	# Black Turn 3: Knight MUST be able to move normally again!
	var knight_moves_t3: Array[Vector2i] = MoveValidator.get_legal_moves(tm.board, Vector2i(4, 2), false)
	if knight_moves_t3.is_empty():
		print("Black Knight has no legal moves on Black Turn 3 after unban.")
		return false

	return true

# 18. Passive next-turn rule (turns_on_board >= 1), PASSIVE_05 burn 0.5/turn x2, PASSIVE_06 no lock
func test_passive_next_turn_rule_and_burn_zone() -> bool:
	var tm: TurnManager = TurnManager.new()
	tm.start_game()

	# Part A: Passive placed in turn 1 CANNOT trigger in turn 1
	var p03: CardResource = CardDatabase.get_card("PASSIVE_03")
	tm.white_engine.hand.append(p03)
	tm.place_passive_card(p03)
	var early_trig: Array[Dictionary] = tm.passive_manager.evaluate_triggers("main_phase_started", {"board": tm.board})
	if not early_trig.is_empty():
		print("Passive triggered on the same turn it was placed (turns_on_board == 0).")
		return false

	# After 1 turn end, turns_on_board == 1 -> now it CAN trigger
	tm.passive_manager.on_turn_end(PieceData.Team.WHITE)
	var valid_trig: Array[Dictionary] = tm.passive_manager.evaluate_triggers("main_phase_started", {"board": tm.board})
	if valid_trig.is_empty():
		print("Passive failed to trigger on next turn (turns_on_board == 1).")
		return false

	# Part B: PASSIVE_05 burns 0.5 pts/turn for 2 turns and expires automatically
	var tm2: TurnManager = TurnManager.new()
	tm2.start_game()
	var p05: CardResource = CardDatabase.get_card("PASSIVE_05")
	tm2.white_engine.hand.append(p05)
	tm2.place_passive_card(p05)
	tm2.passive_manager.on_turn_end(PieceData.Team.WHITE)

	# Put a Black Pawn (1.0 pt) at (4, 4) and trigger PASSIVE_05 centered at (4, 3) -> (4, 4) is inside burn zone
	var victim_pawn: PieceData = PieceData.new(PieceData.PieceType.PAWN, PieceData.Team.BLACK)
	tm2.board.set_piece(Vector2i(4, 4), victim_pawn)
	tm2.execute_passive_trigger(PieceData.Team.WHITE, 0, [Vector2i(4, 3)])
	if not tm2.board.barrier_burn_zones.has(Vector2i(4, 4)):
		print("PASSIVE_05 did not create burn zone at (4, 4).")
		return false

	# End Turn 1: pawn takes -0.5 -> 0.5 remaining, still alive
	tm2.end_turn()
	if not is_equal_approx(victim_pawn.current_points, 0.5) or tm2.board.get_piece(Vector2i(4, 4)) != victim_pawn:
		print("PASSIVE_05 burn tick 1 failed: pts=%f" % victim_pawn.current_points)
		return false

	# End Turn 2: pawn takes -0.5 -> 0.0 -> destroyed to grave, burn zone expires
	tm2.end_turn()
	if tm2.board.get_piece(Vector2i(4, 4)) != null or not tm2.board.grave_black.has(victim_pawn):
		print("PASSIVE_05 burn tick 2 failed to destroy 0-point pawn.")
		return false
	if not tm2.board.barrier_burn_zones.is_empty():
		print("PASSIVE_05 burn zone did not expire after 2 turns.")
		return false

	# Part C: PASSIVE_06 pulls both Queens back 2 moves WITHOUT locking them
	var b3: BoardState = BoardState.new()
	b3.setup_initial_board()
	b3.remove_piece(Vector2i(3, 1))
	var wq: PieceData = b3.get_piece(Vector2i(3, 0))
	b3.move_piece(Vector2i(3, 0), Vector2i(3, 3))
	b3.move_piece(Vector2i(3, 3), Vector2i(5, 3))
	b3.execute_queen_tether()
	if b3.get_piece(Vector2i(3, 0)) != wq or wq.is_locked:
		print("PASSIVE_06 failed to pull Queen back cleanly without lock.")
		return false

	return true

# 19. ACTIVE_30 Gravity Vortex (pull radius 2 & ban center 3 turns), FIDE Castling, ACTIVE_14 temp summon (1 turn)
func test_gravity_vortex_and_castling_and_temp_summon() -> bool:
	# Part A: ACTIVE_30 Gravity Vortex
	var tm: TurnManager = TurnManager.new()
	tm.board._init_empty_grid()
	tm.board.set_piece(Vector2i(4, 0), PieceData.new(PieceData.PieceType.KING, PieceData.Team.WHITE))
	tm.board.set_piece(Vector2i(4, 7), PieceData.new(PieceData.PieceType.KING, PieceData.Team.BLACK))

	# Center at (4, 4) (rank 5). Piece A at (4, 3) (dist 1 -> pulled into center -> BANNED 3 turns).
	# Piece B at (2, 4) (dist 2 -> pulled 1 step to (3, 4), NOT banned).
	var p_near: PieceData = PieceData.new(PieceData.PieceType.KNIGHT, PieceData.Team.BLACK)
	var p_far: PieceData = PieceData.new(PieceData.PieceType.BISHOP, PieceData.Team.WHITE)
	tm.board.set_piece(Vector2i(4, 3), p_near)
	tm.board.set_piece(Vector2i(2, 4), p_far)
	tm.current_phase = TurnManager.Phase.MAIN_PHASE
	tm.current_turn_team = PieceData.Team.WHITE

	var card_vortex: CardResource = CardDatabase.get_card("ACTIVE_30")
	tm.white_engine.hand.append(card_vortex)
	if not tm.play_active_card(card_vortex, Vector2i(4, 4)):
		print("Failed to play ACTIVE_30.")
		return false

	if tm.board.get_piece(Vector2i(4, 4)) != p_near or not p_near.is_banned or p_near.banned_turns != 3:
		print("ACTIVE_30 failed to pull adjacent piece to center and ban for 3 turns.")
		return false
	if tm.board.get_piece(Vector2i(3, 4)) != p_far or p_far.is_banned:
		print("ACTIVE_30 failed to pull distance-2 piece 1 square inward without banning.")
		return false

	# Part B: FIDE Castling (King + Rook both move)
	var tm_c: TurnManager = TurnManager.new()
	tm_c.start_game()
	# Clear f1 (5, 0) and g1 (6, 0) for White kingside castling
	tm_c.board.remove_piece(Vector2i(5, 0))
	tm_c.board.remove_piece(Vector2i(6, 0))
	var w_king: PieceData = tm_c.board.get_piece(Vector2i(4, 0))
	var w_rook: PieceData = tm_c.board.get_piece(Vector2i(7, 0))

	if not tm_c.execute_move(Vector2i(4, 0), Vector2i(6, 0)):
		print("White kingside castling failed.")
		return false
	if tm_c.board.get_piece(Vector2i(6, 0)) != w_king or tm_c.board.get_piece(Vector2i(5, 0)) != w_rook:
		print("FIDE castling did not move both King to g1 and Rook to f1.")
		return false

	# Part C: ACTIVE_14 Temporary Summon lasts 1 turn then returns to grave
	var tm_s: TurnManager = TurnManager.new()
	tm_s.start_game()
	var dead_knight: PieceData = PieceData.new(PieceData.PieceType.KNIGHT, PieceData.Team.WHITE)
	tm_s.board.grave_white.append(dead_knight)
	var card_a14: CardResource = CardDatabase.get_card("ACTIVE_14")
	tm_s.white_engine.hand.append(card_a14)
	if not tm_s.play_active_card(card_a14, Vector2i(4, 2)):
		print("Failed to play ACTIVE_14.")
		return false
	if tm_s.board.get_piece(Vector2i(4, 2)) != dead_knight or dead_knight.temporary_summon_turns != 1:
		print("ACTIVE_14 did not summon piece with temporary_summon_turns == 1.")
		return false
	# End White's turn -> summoned piece must vanish back to grave
	tm_s.end_turn()
	if tm_s.board.get_piece(Vector2i(4, 2)) != null or not tm_s.board.grave_white.has(dead_knight):
		print("ACTIVE_14 temporary summon did not disappear after 1 turn.")
		return false

	return true

# 20. Remaining Passives: PASSIVE_11, PASSIVE_12, PASSIVE_14, PASSIVE_17, PASSIVE_18, PASSIVE_19
func test_remaining_passives_11_12_14_17_18_19() -> bool:
	# PASSIVE_11: 10 checks -> immortal for 3 turns
	var tm11: TurnManager = TurnManager.new()
	tm11.start_game()
	var w_queen: PieceData = tm11.board.get_piece(Vector2i(3, 0))
	w_queen.check_count = 10
	tm11.passive_manager.place_passive(PieceData.Team.WHITE, CardDatabase.get_card("PASSIVE_11"), 1)
	tm11.passive_manager.on_turn_end(PieceData.Team.WHITE)
	tm11.execute_passive_trigger(PieceData.Team.WHITE, 0)
	if not w_queen.is_immortal or w_queen.immortal_turns != 3:
		print("PASSIVE_11 did not grant 3-turn immortality after 10 checks.")
		return false

	# PASSIVE_12: >= 50 moves & equal points -> reset board once
	var tm12: TurnManager = TurnManager.new()
	tm12.start_game()
	tm12.board.remove_piece(Vector2i(0, 1))
	tm12.board.remove_piece(Vector2i(0, 6))
	tm12.total_moves_played = 50
	tm12.passive_manager.place_passive(PieceData.Team.WHITE, CardDatabase.get_card("PASSIVE_12"), 1)
	tm12.passive_manager.on_turn_end(PieceData.Team.WHITE)
	tm12.execute_passive_trigger(PieceData.Team.WHITE, 0)
	if not tm12.passive_12_used or tm12.board.get_piece(Vector2i(0, 1)) == null or tm12.board.get_piece(Vector2i(0, 6)) == null:
		print("PASSIVE_12 did not reset board at 50 moves with equal points.")
		return false

	# PASSIVE_14: King escape + force opponent to move King next turn
	var tm14: TurnManager = TurnManager.new()
	tm14.board._init_empty_grid()
	tm14.board.set_piece(Vector2i(6, 0), PieceData.new(PieceData.PieceType.KING, PieceData.Team.WHITE))
	tm14.board.set_piece(Vector2i(4, 7), PieceData.new(PieceData.PieceType.KING, PieceData.Team.BLACK))
	tm14.board.set_piece(Vector2i(0, 6), PieceData.new(PieceData.PieceType.PAWN, PieceData.Team.BLACK))
	tm14.current_phase = TurnManager.Phase.MAIN_PHASE
	tm14.current_turn_team = PieceData.Team.BLACK
	tm14.passive_manager.place_passive(PieceData.Team.WHITE, CardDatabase.get_card("PASSIVE_14"), 1)
	tm14.passive_manager.on_turn_end(PieceData.Team.WHITE)
	tm14.execute_passive_trigger(PieceData.Team.WHITE, 0, [Vector2i(2, 0)])
	if tm14.board.find_king(PieceData.Team.WHITE) != Vector2i(2, 0) or tm14.forced_king_move_team != int(PieceData.Team.BLACK):
		print("PASSIVE_14 did not teleport King and set forced_king_move_team.")
		return false
	# Black tries to move Pawn instead of King -> MUST be rejected!
	if tm14.execute_move(Vector2i(0, 6), Vector2i(0, 5)):
		print("PASSIVE_14 failed to force Black to move King.")
		return false
	# Black moves King -> succeeds and clears forced_king_move_team
	if not tm14.execute_move(Vector2i(4, 7), Vector2i(3, 7)) or tm14.forced_king_move_team != -1:
		print("PASSIVE_14 failed when Black moved King.")
		return false

	# PASSIVE_17: Destroy 1 of opponent's 3 diagonal pawns
	var tm17: TurnManager = TurnManager.new()
	tm17.board._init_empty_grid()
	tm17.board.set_piece(Vector2i(4, 0), PieceData.new(PieceData.PieceType.KING, PieceData.Team.WHITE))
	tm17.board.set_piece(Vector2i(4, 7), PieceData.new(PieceData.PieceType.KING, PieceData.Team.BLACK))
	tm17.board.set_piece(Vector2i(1, 5), PieceData.new(PieceData.PieceType.PAWN, PieceData.Team.BLACK))
	tm17.board.set_piece(Vector2i(2, 4), PieceData.new(PieceData.PieceType.PAWN, PieceData.Team.BLACK))
	tm17.board.set_piece(Vector2i(3, 3), PieceData.new(PieceData.PieceType.PAWN, PieceData.Team.BLACK))
	tm17.passive_manager.place_passive(PieceData.Team.WHITE, CardDatabase.get_card("PASSIVE_17"), 1)
	tm17.passive_manager.on_turn_end(PieceData.Team.WHITE)
	tm17.execute_passive_trigger(PieceData.Team.WHITE, 0, [Vector2i(2, 4)])
	if tm17.board.get_piece(Vector2i(2, 4)) != null:
		print("PASSIVE_17 failed to destroy selected diagonal enemy pawn.")
		return false

	# PASSIVE_18 + PASSIVE_19: Fire diagonal deals -1 pt on entry, PASSIVE_19 buffs +2 pts
	var tm18: TurnManager = TurnManager.new()
	tm18.board._init_empty_grid()
	tm18.board.set_piece(Vector2i(4, 0), PieceData.new(PieceData.PieceType.KING, PieceData.Team.WHITE))
	tm18.board.set_piece(Vector2i(4, 7), PieceData.new(PieceData.PieceType.KING, PieceData.Team.BLACK))
	tm18.board.set_piece(Vector2i(0, 1), PieceData.new(PieceData.PieceType.PAWN, PieceData.Team.WHITE))
	tm18.board.set_piece(Vector2i(1, 2), PieceData.new(PieceData.PieceType.PAWN, PieceData.Team.WHITE))
	tm18.board.set_piece(Vector2i(2, 3), PieceData.new(PieceData.PieceType.PAWN, PieceData.Team.WHITE))
	var b_rook: PieceData = PieceData.new(PieceData.PieceType.ROOK, PieceData.Team.BLACK) # 5 pts
	tm18.board.set_piece(Vector2i(3, 6), b_rook)
	tm18.passive_manager.place_passive(PieceData.Team.WHITE, CardDatabase.get_card("PASSIVE_18"), 1)
	tm18.passive_manager.place_passive(PieceData.Team.BLACK, CardDatabase.get_card("PASSIVE_19"), 1)
	tm18.passive_manager.on_turn_end(PieceData.Team.WHITE)
	tm18.passive_manager.on_turn_end(PieceData.Team.BLACK)
	tm18.execute_passive_trigger(PieceData.Team.WHITE, 0)
	if not tm18.board.fire_diagonals.has(Vector2i(3, 4)):
		print("PASSIVE_18 failed to populate fire_diagonals at (3, 4).")
		return false
	# Black Rook moves (3, 6) -> (3, 4) onto fire diagonal -> loses 1 pt (5 -> 4), triggers PASSIVE_19 ready
	tm18.current_turn_team = PieceData.Team.BLACK
	tm18.current_phase = TurnManager.Phase.MAIN_PHASE
	if not tm18.execute_move(Vector2i(3, 6), Vector2i(3, 4)):
		print("Black Rook move onto fire diagonal failed.")
		return false
	if not is_equal_approx(b_rook.current_points, 4.0) or not b_rook.affected_by_point_penalty:
		print("PASSIVE_18 did not deduct 1 point on fire diagonal entry: pts=%f" % b_rook.current_points)
		return false
	var p19_slot: Dictionary = tm18.passive_manager.get_slot(PieceData.Team.BLACK, 0)
	if not bool(p19_slot.get("is_ready_to_trigger", false)):
		print("PASSIVE_19 did not become ready after point penalty.")
		return false
	# Black triggers PASSIVE_19 -> Rook gets +2 pts (4 -> 6)
	tm18.execute_passive_trigger(PieceData.Team.BLACK, 0)
	if not is_equal_approx(b_rook.current_points, 6.0):
		print("PASSIVE_19 failed to buff affected piece +2 pts: pts=%f" % b_rook.current_points)
		return false

	return true
