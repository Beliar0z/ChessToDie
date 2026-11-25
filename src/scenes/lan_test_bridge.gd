# res://src/scenes/lan_test_bridge.gd
# GDScript / lan_test_bridge.gd / Godot 4.7 / Temporary 2-Machine LAN PvP Test Bridge
class_name LanTestBridge
extends PanelContainer

const DEFAULT_PORT: int = 7777

var controller: GameController
var is_lan_active: bool = false
var is_host: bool = false
var local_team: PieceData.Team = PieceData.Team.WHITE
var peer: ENetMultiplayerPeer = null

var _host_btn: Button
var _join_btn: Button
var _disconnect_btn: Button
var _ip_input: LineEdit
var _status_lbl: Label

func setup(p_controller: GameController) -> void:
	controller = p_controller
	name = "LanTestBridge"
	z_index = 150
	_build_ui()

func _build_ui() -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.94)
	sb.border_color = Color("#F4A236")
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_right = 8.0
	sb.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", sb)

	# Đặt gọn ở góc trên-phải của RightArea (trên đầu OpponentDeckSlot, không đè UI nào)
	set_anchors_preset(PRESET_TOP_RIGHT)
	offset_left = -560.0
	offset_top = 6.0
	offset_right = -24.0
	offset_bottom = 42.0

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)

	_host_btn = Button.new()
	_host_btn.text = "HOST TRẮNG"
	_host_btn.add_theme_font_size_override("font_size", 11)
	_host_btn.pressed.connect(_on_host_pressed)
	hbox.add_child(_host_btn)

	_ip_input = LineEdit.new()
	_ip_input.text = "127.0.0.1"
	_ip_input.placeholder_text = "IP Host"
	_ip_input.custom_minimum_size = Vector2(115.0, 24.0)
	_ip_input.add_theme_font_size_override("font_size", 11)
	hbox.add_child(_ip_input)

	_join_btn = Button.new()
	_join_btn.text = "JOIN ĐEN"
	_join_btn.add_theme_font_size_override("font_size", 11)
	_join_btn.pressed.connect(_on_join_pressed)
	hbox.add_child(_join_btn)

	_disconnect_btn = Button.new()
	_disconnect_btn.text = "NGẮT"
	_disconnect_btn.visible = false
	_disconnect_btn.add_theme_font_size_override("font_size", 11)
	_disconnect_btn.pressed.connect(_on_disconnect_pressed)
	hbox.add_child(_disconnect_btn)

	_status_lbl = Label.new()
	_status_lbl.text = "TEST: OFFLINE"
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.add_theme_color_override("font_color", Color("#FFF0C2"))
	hbox.add_child(_status_lbl)

func _connect_mp_signals() -> void:
	if multiplayer == null:
		return
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)

func _on_host_pressed() -> void:
	_disconnect_peer()
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(DEFAULT_PORT, 1)
	if err != OK:
		_status_lbl.text = "LỖI PORT %d" % DEFAULT_PORT
		return
	multiplayer.multiplayer_peer = peer
	_connect_mp_signals()
	is_host = true
	is_lan_active = true
	local_team = PieceData.Team.WHITE
	_set_connected_ui(true)
	_status_lbl.text = "HOST TRẮNG (:%d) - CHỜ ĐEN" % DEFAULT_PORT
	if controller != null:
		controller.on_lan_mode_changed(true, local_team)

func _on_join_pressed() -> void:
	_disconnect_peer()
	var ip: String = _ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, DEFAULT_PORT)
	if err != OK:
		_status_lbl.text = "KHÔNG KẾT NỐI ĐƯỢC"
		return
	multiplayer.multiplayer_peer = peer
	_connect_mp_signals()
	is_host = false
	is_lan_active = true
	local_team = PieceData.Team.BLACK
	_set_connected_ui(true)
	_status_lbl.text = "ĐANG KẾT NỐI %s..." % ip

func _on_disconnect_pressed() -> void:
	_disconnect_peer()
	_status_lbl.text = "TEST: OFFLINE"
	if controller != null:
		controller.on_lan_mode_changed(false, PieceData.Team.WHITE)

func _disconnect_peer() -> void:
	if peer != null:
		peer.close()
		peer = null
	if multiplayer != null:
		multiplayer.multiplayer_peer = null
	is_lan_active = false
	is_host = false
	local_team = PieceData.Team.WHITE
	_set_connected_ui(false)

func _set_connected_ui(connected: bool) -> void:
	if _host_btn != null:
		_host_btn.visible = not connected
	if _join_btn != null:
		_join_btn.visible = not connected
	if _ip_input != null:
		_ip_input.editable = not connected
	if _disconnect_btn != null:
		_disconnect_btn.visible = connected

func _on_peer_connected(peer_id: int) -> void:
	if is_host and controller != null:
		_status_lbl.text = "LAN: BẠN LÀ TRẮNG (2/2)"
		# Host tạo 2 bộ bài chuẩn rồi gửi sang Client để 2 máy đồng bộ 100%
		var w_deck_ids: Array[String] = _build_shuffled_deck_ids()
		var b_deck_ids: Array[String] = _build_shuffled_deck_ids()
		_apply_synced_start(w_deck_ids, b_deck_ids)
		rpc_id(peer_id, "rpc_start_lan_match", w_deck_ids, b_deck_ids)

func _on_connected_to_server() -> void:
	_status_lbl.text = "LAN: BẠN LÀ ĐEN (2/2)"

func _on_connection_failed() -> void:
	_disconnect_peer()
	_status_lbl.text = "KẾT NỐI THẤT BẠI"
	if controller != null:
		controller.on_lan_mode_changed(false, PieceData.Team.WHITE)

func _on_peer_disconnected(_peer_id: int) -> void:
	_status_lbl.text = "ĐỐI THỦ ĐÃ THOÁT"
	if controller != null:
		controller.show_message("ĐỐI THỦ ĐÃ NGẮT KẾT NỐI LAN!")

func _build_shuffled_deck_ids() -> Array[String]:
	var tmp: CardEngine = CardEngine.new(PieceData.Team.WHITE)
	tmp.setup_default_deck()
	var ids: Array[String] = []
	for c in tmp.deck:
		ids.append(c.id)
	return ids

func _apply_synced_start(white_deck_ids: Array, black_deck_ids: Array) -> void:
	if controller == null:
		return
	var w_cards: Array[CardResource] = []
	for cid in white_deck_ids:
		var c: CardResource = CardDatabase.get_card(String(cid))
		if c != null:
			w_cards.append(c)
	var b_cards: Array[CardResource] = []
	for cid in black_deck_ids:
		var c: CardResource = CardDatabase.get_card(String(cid))
		if c != null:
			b_cards.append(c)

	controller.start_synced_lan_game(w_cards, b_cards, local_team)

# --- Outgoing Sync Helpers ---
func send_move(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if is_lan_active and multiplayer != null and multiplayer.has_multiplayer_peer():
		rpc("rpc_sync_move", from_pos, to_pos)

func send_play_active(card_id: String, targets: Array) -> void:
	if is_lan_active and multiplayer != null and multiplayer.has_multiplayer_peer():
		rpc("rpc_sync_play_active", card_id, targets)

func send_place_passive(card_id: String) -> void:
	if is_lan_active and multiplayer != null and multiplayer.has_multiplayer_peer():
		rpc("rpc_sync_place_passive", card_id)

func send_trigger_passive(team: PieceData.Team, slot_index: int, targets: Array) -> void:
	if is_lan_active and multiplayer != null and multiplayer.has_multiplayer_peer():
		rpc("rpc_sync_trigger_passive", int(team), slot_index, targets)

func send_claim_draw(team: PieceData.Team) -> void:
	if is_lan_active and multiplayer != null and multiplayer.has_multiplayer_peer():
		rpc("rpc_sync_claim_draw", int(team))

func send_end_turn() -> void:
	if is_lan_active and multiplayer != null and multiplayer.has_multiplayer_peer():
		rpc("rpc_sync_end_turn")

# --- Incoming RPC Handlers ---
@rpc("any_peer", "reliable")
func rpc_start_lan_match(white_deck_ids: Array, black_deck_ids: Array) -> void:
	_apply_synced_start(white_deck_ids, black_deck_ids)

@rpc("any_peer", "reliable")
func rpc_sync_move(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if controller != null:
		controller.apply_remote_move(from_pos, to_pos)

@rpc("any_peer", "reliable")
func rpc_sync_play_active(card_id: String, targets: Array) -> void:
	if controller != null:
		controller.apply_remote_play_active(card_id, targets)

@rpc("any_peer", "reliable")
func rpc_sync_place_passive(card_id: String) -> void:
	if controller != null:
		controller.apply_remote_place_passive(card_id)

@rpc("any_peer", "reliable")
func rpc_sync_trigger_passive(team_int: int, slot_index: int, targets: Array) -> void:
	if controller != null:
		controller.apply_remote_trigger_passive(team_int as PieceData.Team, slot_index, targets)

@rpc("any_peer", "reliable")
func rpc_sync_claim_draw(team_int: int) -> void:
	if controller != null:
		controller.apply_remote_claim_draw(team_int as PieceData.Team)

@rpc("any_peer", "reliable")
func rpc_sync_end_turn() -> void:
	if controller != null:
		controller.apply_remote_end_turn()
