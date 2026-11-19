# res://src/core/test_runner.gd
# GDScript / test_runner.gd / Godot 4.7 / Headless Test Runner
extends SceneTree

func _init() -> void:
	print("==================================================")
	print("CHESS TO DIE - AUTOMATED HEADLESS TEST SUITE")
	print("==================================================")

	var tests_passed: int = 0
	var total_tests: int = 7

	if test_standard_fide_moves():
		tests_passed += 1
		print("[PASS] 1/7: test_standard_fide_moves")
	else:
		print("[FAIL] 1/7: test_standard_fide_moves")
		quit(1)
		return

	if test_card_draw_engine():
		tests_passed += 1
		print("[PASS] 2/7: test_card_draw_engine")
	else:
		print("[FAIL] 2/7: test_card_draw_engine")
		quit(1)
		return

	if test_turn_restrictions():
		tests_passed += 1
		print("[PASS] 3/7: test_turn_restrictions")
	else:
		print("[FAIL] 3/7: test_turn_restrictions")
		quit(1)
		return

	if test_checkmate_hook_survival():
		tests_passed += 1
		print("[PASS] 4/7: test_checkmate_hook_survival")
	else:
		print("[FAIL] 4/7: test_checkmate_hook_survival")
		quit(1)
		return

	if test_death_ring_stalemate_resolution():
		tests_passed += 1
		print("[PASS] 5/7: test_death_ring_stalemate_resolution")
	else:
		print("[FAIL] 5/7: test_death_ring_stalemate_resolution")
		quit(1)
		return

	if test_holy_war_kings_combat():
		tests_passed += 1
		print("[PASS] 6/7: test_holy_war_kings_combat")
	else:
		print("[FAIL] 6/7: test_holy_war_kings_combat")
		quit(1)
		return

	if test_curse_countdown():
		tests_passed += 1
		print("[PASS] 7/7: test_curse_countdown")
	else:
		print("[FAIL] 7/7: test_curse_countdown")
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
