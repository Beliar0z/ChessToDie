# BẢN KIỂM TOÁN THIẾT KẾ CHI TIẾT (GDD AUDIT REPORT)
**Dự án:** Chess to Die  
**Tài liệu nguồn:** `design/GameplayCore.md`  
**Người thực hiện:** AG1 (Tech Lead & Producer)  
**Ngày thực hiện:** 19/11/2026  

---

## I. TỔNG QUAN TẬP THẺ BÀI & CƠ CHẾ CỐT LÕI

### 1. Thống kê bài (Card Census)
- **Kế hoạch GDD:** 60 lá bài.
- **Bộ bài người chơi khi vào trận:** 27 lá bài.
- **Hiện trạng tài liệu:** Tổng cộng **51 lá bài** đã được đặc tả:
  - **Active Cards:** 31 lá.
  - **Passive Cards:** 20 lá.
- **Chênh lệch:** Thiếu **9 lá bài** so với mục tiêu 60 lá ban đầu.

---

## II. KIỂM TOÁN HỆ THỐNG LUẬT & TOÁN HỌC

### 1. Hệ thống điểm quân cờ & Hợp thể (Point & Super-piece System)
- **Quân cờ chuẩn:** Tốt (1đ), Mã (3đ), Tượng (3đ), Xe (5đ), Hậu (9đ), Vua (10đ). Tổng điểm chuẩn bên trắng/đen = 39 điểm (không tính Vua) hoặc 49 điểm (tính cả Vua).
- **Siêu quân cờ:**
  - Siêu Tốt: 3đ (Gốc 3 Tốt = 3đ).
  - Siêu Mã: 7đ (Gốc 2 Mã = 6đ $\rightarrow$ Tăng +1đ giá trị).
  - Siêu Tượng: 7đ (Gốc 2 Tượng = 6đ $\rightarrow$ Tăng +1đ giá trị).
  - Siêu Xe: 11đ (Gốc 2 Xe = 10đ $\rightarrow$ Tăng +1đ giá trị).
  - Siêu Hậu: 20đ (Gốc 2 Hậu = 18đ $\rightarrow$ Tăng +2đ giá trị).
- **Quy tắc Hiến tế (Sacrifice):**
  - Hiến tế 8đ $\rightarrow$ tạo Xe (5đ) [Lỗ 3đ giá trị].
  - Hiến tế 7đ $\rightarrow$ hồi sinh Mã/Tượng (3đ) [Lỗ 4đ giá trị].
  - Hiến tế 17đ $\rightarrow$ hồi sinh Hậu (9đ) [Lỗ 8đ giá trị].
  *Đánh giá:* Logic toán học cân bằng rủi ro/lợi nhuận rất tốt, ngăn chặn lạm phát quân mạnh trên bàn cờ.

### 2. Luồng Turn (Turn Flow Engine)
- **Khởi đầu:** Rút 6 lá bài.
- **Chu kỳ rút bài:** Cứ 2 nước đi của bản thân thì rút 1 lá.
- **Giới hạn trên tay:** Tối đa 10 lá. Đầy tay phải hủy hoặc skip lượt rút.
- **Giới hạn sân:** Tối đa 4 ô úp bài Passive.
- **Giới hạn dùng bài:** 1 Active + 1 Passive mỗi turn.
- **Lỗ hổng cần chuẩn hóa:**
  - Phân định rõ giữa hành động **Úp bài (Set)** trong Main Phase và **Kích hoạt phản đòn (Trigger)** trong turn đối thủ.
  - Khi bẫy Passive tự kích hoạt trong turn đối thủ, có tính vào giới hạn 1 Passive của turn mình kế tiếp hay không?

---

## III. KIỂM TOÁN CÁC TRƯỜNG HỢP NGOẠI LỆ & HOOK ĐẶC BIỆT

### 1. Vòng lửa sinh tử (Death Ring) & Thánh chiến (Holy War)
- **Điều kiện kích hoạt:** Hòa cờ (Stalemate - 1 trong 2 bên không còn nước đi hợp lệ).
- **Cơ chế Vòng lửa:**
  - Dịch chuyển các quân còn sống về vị trí ban đầu.
  - Thiêu đốt điểm các quân cờ qua từng lượt.
  - Xuất hiện điểm hồi phục ngẫu nhiên, tăng tầm đi thêm 1 ô cho mọi quân cờ.
- **Nghịch lý GDD cần giải quyết:** GDD ghi: *"nếu điểm về 0 mà chưa chiếu hết bên nào có số điểm ban đầu lớn hơn thì sẽ thua"*.
  - Điều này trái ngược trực giác thi đấu (người có ưu thế quân ban đầu lại bị xử thua). Cần chốt lại điều kiện phân định thắng bại.
- **Thánh chiến:**
  - Kích hoạt khi chỉ còn 2 Vua.
  - Hai Vua được chọn bước đi của bất kỳ quân nào (Xe, Mã, Tượng, Hậu) và bị trừ điểm theo lượt. Cần khóa chỉ số HP và cơ chế va chạm giữa 2 Vua.

### 2. Checkmate Hooks (Bài cứu thua khi bị chiếu hết)
- **Lá Passive 15:** Khi bị chiếu hết, Vua được đi 2 nước (kể cả ăn Vua đối thủ).
- **Lá Passive 16:** Khi bị chiếu hết, toàn bộ quân được đi 2 nước (trừ ăn Vua đối thủ).
- **Xung đột kỹ thuật:**
  - Trong engine cờ vua tiêu chuẩn, khi Checkmate xuất hiện, game loop lập tức dừng và chuyển sang trạng thái Game Over.
  - Hệ thống cần một Event Hook trung gian `OnCheckmateTriggered`, tạm dừng tiến trình kết thúc trận, kiểm tra xem có lá Passive này đang úp không để hoãn Game Over và cấp cho người chơi 2 nước đi đặc quyền.

### 3. Cơ chế Ban (Trục xuất) & Bù nhìn (Scarecrow) & Tàng hình (Stealth)
- **Cơ chế Ban (Lá Active 29, 30, Passive 20):** Quân cờ bị đưa vào vùng đệm (Exile Zone) trong X turn, sau đó quay lại bàn cờ. Cần quy định thứ tự ưu tiên nếu ô đáp trả bị chiếm đóng.
- **Cơ chế Bù nhìn (Lá Active 27):** Vật thể cản đường có 0 điểm, không thể di chuyển hay bị ăn trừ khi bị bao vây bởi $\ge 3$ quân.
- **Cơ chế Hợp thể Siêu Hậu (Active 13):** Bắt đầu trận chỉ có 1 Hậu, việc hợp thể 2 Hậu đòi hỏi người chơi phải phong cấp Tốt hoặc hồi sinh Hậu trước đó.

---

## IV. BẢNG DANH MỤC 6 ĐIỂM CẦN GAME DESIGNER CHỐT

1. **Tổng lượng bài Milestone 1:** 51 lá hiện có hay bổ sung đủ 60 lá ngay?
2. **Quy tắc thắng thua Vòng lửa sinh tử:** Bên ít điểm hơn thua (chuẩn) hay bên nhiều điểm hơn thua (đánh thuế kẻ mạnh)?
3. **Quy tắc Úp vs Kích hoạt Passive:** Tách riêng lượt Úp (Main Phase) và lượt Phản xạ (Trigger Phase)?
4. **Xung đột 2 lá Checkmate Hook:** Nếu người chơi úp cả 2 lá cứu thua, thứ tự ưu tiên thế nào?
5. **Turn Timer (Thời gian mỗi nước đi):** Có giới hạn thời gian mỗi turn không (ví dụ 60s) để kích hoạt hiệu ứng Lời nguyền (Active 31)?
6. **Luật va chạm 2 Vua trong Thánh chiến:** Cho phép 2 Vua áp sát nhau và tấn công nhau trực tiếp hay giữ luật cấm của FIDE?
