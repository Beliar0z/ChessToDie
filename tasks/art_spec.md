# ĐẶC TẢ THIẾT KẾ ĐỒ HỌA CHO AG3 (ART SPECIFICATION) - NÂNG CẤP THEO FIX.MD
**Dự án:** Chess to Die  
**Giai đoạn:** Milestone 2 - Hoàn thiện Scene UI, Viền Sáng Passive & Cụm Bài Đối Thủ  
**Độ phân giải chuẩn:** $1920 \times 1080$ (Godot 4.7+, CanvasItem / Control 2D)  
**Người giao:** AG1 (Tech Lead & Producer)  
**Người thực hiện:** Ag3 (Graphic Designer & Technical Artist)  
**Nguồn tham chiếu:** `design/Fix.md`, `design/Pasted image 20261119234837.png`, `design/Pasted image 20261119234915.png`  

---

## 1. MỤC TIÊU TRIỂN KHAI
Nâng cấp và tinh chỉnh các Scene UI theo đúng yêu cầu `design/Fix.md` và hình ảnh tham chiếu:
1. **`assets/ui/passive_slot.tscn`**:
   - Thêm node `GlowBorder`: ReferenceRect hoặc ColorRect phát sáng viền vàng kim `#FFD700` hoặc tím neon `#BD00FF` (độ dày viền 3px, có thể nhấp nháy hoặc modulate sáng, mặc định `visible = false`) để biểu thị bẫy đã sẵn sàng kích hoạt (`is_ready_to_trigger`).
   - Thêm node `CardContainer` (Control): Kích thước tương thích để chứa `card_ui.tscn` khi người chơi úp bài (để hiển thị rõ tên, mô tả bài bẫy của phe mình).
   - Thêm node `StatusTag` (Label): Ở góc trên bên phải, chữ "ĐÃ ÚP" màu vàng cổ/xám đậm tinh tế.
   - Giữ lại `CardBackTexture` (`card_back.svg`) cho trường hợp đối thủ úp bài.

2. **`assets/ui/active_slot.tscn`**:
   - Đảm bảo có `CardContainer` (Control, $132 \times 196$) bên trong để chứa `card_ui.tscn` khi lá Active được kích hoạt hoặc kéo thả vào.
   - Thêm `GlowBorder` viền sáng ma thuật vàng kim/đỏ khi ô đang giữ lá bài Active.

3. **`assets/ui/game_scene.tscn`**:
   - Tại `RightArea/TopPlayerZone` (khu vực đối thủ):
     - Thêm `OpponentHandArea` (Control): Nằm phía trên hàng Passive của đối thủ.
     - `OpponentHandContainer` (Control): Vùng render cụm bài úp xòe quạt ngược (Yu-Gi-Oh! style theo `Pasted image 20261119234837.png`).
     - `OpponentHandLabel` (Label): Nhãn đếm hiển thị số lượng bài trên tay đối thủ (ví dụ: "TAY BÀI ĐỐI THỦ: 6 LÁ").

4. **Cập nhật `assets/manifest.json`**:
   - Kê khai cập nhật đầy đủ các scene UI đã nâng cấp.
