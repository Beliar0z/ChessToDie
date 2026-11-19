Đọc design/GDD_Core.md (bản mới nhất), tasks/STATE.md và toàn bộ code hiện tại trong src/ cùng assets/ui/. Hãy dùng Auto-Dispatch (Ag2 & Ag3) triển khai đồng bộ 2 phần sau:

PHẦN A — NÂNG CẤP GIAO DIỆN & TRẢI NGHIỆM (UI/UX):
1. Xòe bài hình quạt (Fan Arc) cho bài trên tay người chơi (`src/scenes/card_hand_view.gd`):
   - Bỏ HBoxContainer phẳng; xếp các lá bài theo đường cung hình quạt (xoay nhẹ từ -14° đến +14°, nhô cao ở giữa).
   - Khi rê chuột vào lá nào (`mouse_entered`): lá đó dựng thẳng về 0°, phóng to 1.28x, nhô cao hẳn lên trên (`z_index = 50`) để đọc rõ toàn bộ khung và chữ; rời chuột thì trả về vị trí cũ.
2. Hiển thị tay bài đối thủ xòe hình quạt:
   - Thêm cụm bài úp (`card_back.svg`) xòe hình quạt ngược ở phía trên khu vực đối thủ, hiển thị đúng số lượng lá bài hiện có trên tay AI Boss kèm nhãn đếm.
3. Hiện mặt bài Passive của người chơi khi đã úp & Hiệu ứng Viền Sáng:
   - Trên 4 ô Passive của Trắng (`PlayerPassiveRow`), khi úp bài phải hiển thị đầy đủ giao diện `card_ui.tscn` (tên bài, nhãn [PASSIVE], mô tả) kèm nhãn nhỏ "ĐÃ ÚP" ở góc để người chơi tự xem lại bẫy của mình. 4 ô Passive của Đen vẫn úp mặt lưng `card_back.svg`.
   - Khi lá Passive đủ điều kiện kích hoạt (`is_ready_to_trigger == true`): bật viền phát sáng nổi bật (vàng kim / tím sáng nhấp nháy) quanh ô Passive đó cho cả phe Trắng lẫn phe Đen (khi Boss đủ điều kiện cũng phát sáng viền ở ô úp của Boss). Khi chưa đủ điều kiện thì tắt viền sáng và không cho kích hoạt.
4. Giữ nguyên khung & mô tả lá bài trong Active Slot:
   - Khi kích hoạt hoặc kéo lá `[ACTIVE]` vào `PlayerActiveSlot` / `OpponentActiveSlot`, render trực tiếp `card_ui.tscn` đầy đủ khung, tên và chức năng vào `CardContainer` của ô đó (ẩn chữ placeholder thô đi).
5. Cảnh báo giới hạn 1 Active/turn:
   - Nếu người chơi cố kéo hoặc bấm dùng lá `[ACTIVE]` thứ 2 trong cùng 1 lượt, chặn lại và hiện thông báo rõ ràng trên `MessageBanner`: "MỖI LƯỢT CHỈ ĐƯỢC DÙNG 1 LÁ ACTIVE!".

PHẦN B — CƠ CHẾ VIỀN SÁNG PASSIVE (GLOW-TO-CLICK) & CHỌN NHIỀU MỤC TIÊU:
1. Hệ thống nhận diện điều kiện & Viền sáng chủ động (`PassiveManager` + `GameController`):
   - Tuyệt đối KHÔNG dùng popup hỏi Có/Không.
   - Sau mỗi hành động (đi quân, ăn quân, dùng bài Active, chuyển phase), `PassiveManager` tự quét tất cả bài Passive đã úp từ các lượt trước:
     + Lá nào thỏa điều kiện -> bật `is_ready_to_trigger = true` (phát sáng viền). Nếu điều kiện mang tính thời điểm (ví dụ: "Hủy lá active vừa tung ra", "Ngay khi con hậu vừa di chuyển") mà người sở hữu không bấm trước khi kết thúc lượt/cửa sổ phản ứng -> tự tắt viền sáng (`false`) và giữ nguyên bài úp cho lần sau.
     + Khi người chơi click vào ô Passive đang phát sáng: tiêu hao lá bẫy và thực thi hiệu ứng ngay (nếu hiệu ứng cần chọn mục tiêu như tiêu diệt quân <3đ, hồi sinh quân <5đ, chọn ô tẩu thoát Vua... thì chuyển sang `targeting_steps` cho người chơi click chọn trên bàn cờ).
     + Đối với Boss (AI): Khi ô Passive của Boss phát sáng đủ điều kiện, AI Boss đánh giá tình huống và chủ động bấm kích hoạt tương tự người chơi.
     + Cửa sổ phản ứng trong lượt Boss: Khi Boss vừa thực hiện hành động làm bài Passive của người chơi bật viền sáng (như vừa dùng bài Active hoặc vừa di chuyển Hậu), tạm giữ nhịp 2.0 giây kèm thông báo trên banner ("BẪY ĐỦ ĐIỀU KIỆN — BẤM VÀO LÁ BÀI PHÁT SÁNG ĐỂ KÍCH HOẠT!") để người chơi kịp bấm trước khi Boss kết thúc lượt.
2. Lưu lịch sử tọa độ quân cờ (`position_history`) cho hiệu ứng kéo Hậu:
   - Mỗi quân cờ (`PieceData`) lưu danh sách các ô đã đứng qua từng nước đi. Lá Passive kéo Hậu sẽ đưa cả 2 con Hậu đang có trên sân quay về đúng ô đứng cách đó 2 nước đi của từng con (nếu ô cũ đang bị quân khác chiếm thì đặt vào ô trống gần nhất xung quanh).
3. Hệ thống chọn nhiều mục tiêu (`targeting_steps`) cho toàn bộ lá bài Active & Passive:
   - Chọn 1 mục tiêu: Nguyền rủa, Khóa 1 quân, Bất tử, Bù nhìn, Đi 2 nước, Đổi kiểu di chuyển Mã/Xe/Tượng, Hút tâm hàng 4-5.
   - Chọn nhiều mục tiêu tuần tự: Hoán đổi (2 quân đồng minh), Tạo tối đa 5 ô cấm, Hợp thể 3 Tốt -> chọn ô spawn trong 4 hàng sân nhà, Hợp thể 2 Mã/Xe/Tượng/Hậu -> chọn ô spawn, Khóa 3 quân bất kỳ (trừ Vua), Hiến tế đủ 7đ/8đ/17đ -> triệu hồi tại A1/H1 (Trắng) hoặc A8/H8 (Đen) (nếu 2 ô góc đang kẹt thì đưa vào hàng đợi chờ trống), Tàng hình tối đa 2 quân (trừ Hậu) trong 2 turn, Phân thân (Tốt 5 bóng, Mã/Tượng 2 bóng, Vua 3 bóng -> cho chọn số ô trống tương ứng trong 4 hàng sân nhà).
   - Trong lúc chọn mục tiêu: tô sáng các ô hợp lệ, hiện tiến độ trên `MessageBanner` (ví dụ "CHỌN MỤC TIÊU 2/3 - Chuột phải hoặc ESC để hủy").
4. Cập nhật đủ toàn bộ 60 lá bài theo đúng `design/GDD_Core.md`.

Chạy Godot Headless Test sau khi hoàn thành để đảm bảo 0 lỗi parse/runtime rồi báo cáo kết quả.