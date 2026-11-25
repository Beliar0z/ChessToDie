# CHESS TO DIE — ART BIBLE (GOLDEN STANDARD)
**Phiên bản:** 1.1 (Cập nhật theo tham chiếu `tasks/thamkhao.jpg` & `tasks/samplecard.jfif`)  
**Phê duyệt bởi:** Game Designer  
**Áp dụng cho:** Ag3 (Godot UI/VFX), Ag4 (Blender 3D-to-Pixel), Ag5 (SD Forge + Pillow Art Pipeline)

---

## 1. TRIẾT LÝ MỸ THUẬT CHỦ ĐẠO
- **Phong cách:** **Pixel Art sắc nét, tương phản cao, bảng màu giới hạn kiểu Balatro** pha trộn không khí Dark Fantasy / Tarot quái dị.
- **Quy tắc hiển thị trong Godot (BẮT BUỘC):**
  - Mọi Sprite/TextureRect của quân cờ, thẻ bài, khung bài và icon pixel đều **BẮT BUỘC** dùng `texture_filter = TEXTURE_FILTER_NEAREST` (`default_texture_filter = 0`).
  - **CẤM TUYỆT ĐỐI** làm mờ (linear filtering), anti-aliasing mềm viền, hoặc gradient trơn không theo lưới pixel.
- **Nguyên tắc đọc rõ (Readability First):**
  - Quân cờ tách nền rõ ràng trên cả ô sáng và ô tối bằng **viền đen ngoài (silhouette outline)** và **đổ bóng khối (cel/block shadow)**.
  - Chữ trên thẻ bài luôn nằm trên nền sáng giấy cổ `#F5EFE6` với chữ tối `#1A1A1D`.

---

## 2. BẢNG MÀU KHÓA CỨNG (COLOR PALETTE)

### 2.1. Hệ màu Active — Tarot "The Sun" (Tông nóng)
| Vai trò | Mã Hex | Ghi chú |
| :--- | :--- | :--- |
| Nền tối / Đỏ thẫm | `#2E0F15` | Bóng sâu, nền mặt lưng, viền nhấn Active |
| Vàng cam chủ đạo | `#F4A236` | Mặt Trời, tia nắng, huy hiệu góc & họa tiết Active |
| Kem sáng nổi bật | `#FFF0C2` | Điểm sáng (highlight), nụ cười, sao & viền sáng |
| Đen mực viền | `#121014` | Viền ngoài dày bo góc, nét khắc Tarot |

### 2.2. Hệ màu Passive — Tarot "The Moon" (Tông xanh biển)
| Vai trò | Mã Hex | Ghi chú |
| :--- | :--- | :--- |
| Xanh biển sâu | `#0B3D91` | Nền mặt lưng, bóng sâu & viền nhấn Passive |
| Xanh sáng chủ đạo | `#64B5F6` | Mặt Trăng, mây/sương cuộn, huy hiệu góc Passive |
| Trắng băng nổi bật | `#E3F2FD` | Điểm sáng (highlight), nụ cười, sao & viền sáng |
| Đen mực viền | `#081121` | Viền ngoài dày bo góc, nét khắc Tarot |

### 2.3. Hệ màu Mặt Trước Thẻ Bài (Đọc không mỏi mắt)
| Vai trò | Mã Hex | Ghi chú |
| :--- | :--- | :--- |
| Viền ngoài đen dày bo góc | `#121014` | Bao trọn lá bài, phong cách TCG cao cấp |
| Nền giấy cổ (Tiêu đề & Mô tả) | `#F5EFE6` | Dải tiêu đề trên và khung mô tả dưới |
| Sắc bóng giấy cổ | `#D9CEBE` | Tạo chiều sâu nhẹ cho cuộn mây/họa tiết giấy |
| Chữ tối độ tương phản cao | `#1A1A1D` | Chữ tên bài và chữ mô tả hiệu ứng |

### 2.4. Hệ màu Quân Cờ 3D-to-Pixel
- **Quân Trắng:** `#F5EFE6` (sáng), `#D8C9B4` (trung), `#9B8A76` (tối), viền Freestyle `#0A080C`.
- **Quân Đen:** `#5E667D` (rim sáng), `#2E2A3A` (trung), `#14111C` (tối), viền Freestyle `#0A080C`.

---

## 3. ĐẶC TẢ MẶT SAU LÁ BÀI (TAROT CƯỜI QUÁI DỊ — BIẾN TẤU GỐC, KHÔNG BÊ NGUYÊN `tasks/thamkhao.jpg`)
- **Kích thước chuẩn:** `148x206` px (dựng lưới pixel gốc `74x103` phóng `2x NEAREST`).
- **Nguyên tắc sáng tạo:** Chỉ lấy **tinh thần & khí chất Tarot cười quái dị** từ `tasks/thamkhao.jpg`, **TUYỆT ĐỐI KHÔNG sao chép nguyên xi** biểu cảm/nét vẽ; biến tấu nguyên bản cho Chess to Die + thêm nhiều chi tiết thiên văn xung quanh cho thật oách.
- **Lá Active (`the_sun_back.png`) — `• THE SUN •`:**
  - **Biểu cảm biến tấu:** Mặt Trời **cười híp mắt nhe răng cực rõ & ma mị** (hai mắt híp cong hẹp sắc lạnh, miệng cười kéo rộng nhe rõ từng chiếc răng kem sáng `#FFF0C2` tách kẽ đen `#121014` sắc nét, KHÔNG vẽ hình người).
  - **Chi tiết bao quanh cho oách:** vòng hào quang thiên văn, tia nắng gai nhọn & vòng lửa bùng cháy, các ngôi sao 4–8 cánh sắc nét, mây lửa cuộn góc, khung viền Tarot cổ điển + thanh tên `• THE SUN •` ở đáy.
  - Khóa bảng màu tông nóng: `#2E0F15`, `#F4A236`, `#FFF0C2`, `#121014`.
- **Lá Passive (`the_moon_back.png`) — `• THE MOON •`:**
  - **Biểu cảm biến tấu:** Mặt Trăng lưỡi liềm **MỞ MẮT MA MỊ + CƯỜI HÁ MỒM TO RĂNG ĐỀU** (mắt mở to trợn sắc lạnh có đồng tử nhỏ/vầng tối hốc mắt đầy ám ảnh, miệng cười há rộng tối sâu với 2 hàm răng trắng băng `#E3F2FD` xếp đều tăm tắp tách kẽ đen `#081121`, KHÔNG vẽ hình người).
  - **Chi tiết bao quanh cho oách:** mây cuộn ma mị ôm phần đáy và góc trên, các ngôi sao 4–8 cánh lấp lánh, tia trăng / hoa văn thiên văn cổ, khung viền Tarot cổ điển + thanh tên `• THE MOON •` ở đáy.
  - Khóa bảng màu tông xanh biển: `#0B3D91`, `#64B5F6`, `#E3F2FD`, `#081121`.

---

## 4. ĐẶC TẢ MẶT TRƯỚC LÁ BÀI (THAM CHIẾU `tasks/samplecard.jfif`)
- **Kích thước chuẩn:** `148x206` px (vẽ lưới gốc `74x103` phóng `2x NEAREST`).
- **Bố cục lấy cảm hứng từ `tasks/samplecard.jfif` (điều chỉnh thành Pixel Art sắc nét):**
  1. **Viền ngoài đen dày bo góc** (`#121014`) bao quanh toàn bộ thẻ.
  2. **Thanh tiêu đề phía trên:** Nền giấy cổ `#F5EFE6` (chữ `#1A1A1D`), có **huy hiệu tròn/khiên loại bài ở góc trên-trái** (biểu tượng Mặt Trời/lửa cho Active, Mặt Trăng/mắt cho Passive) và **họa tiết mây/xoáy trang trí ở góc trên-phải** tràn nhẹ xuống mép tranh.
  3. **Cửa sổ tranh minh họa lớn ở giữa:** **TRONG SUỐT HOÀN TOÀN (`alpha = 0`)** chiếm khoảng 50–55% chiều cao thẻ để tranh minh họa nổi bật tối đa.
  4. **Đường ngăn cách nghệ thuật (Swirling Mist / Ornamental Scrollwork):** Thay vì đường kẻ thẳng cứng nhắc, viền trên của khung mô tả tạo hình **làn mây/khói/hoa văn cuộn pixel** (tông vàng-đỏ cho Active, xanh băng cho Passive) ôm nhẹ lên cạnh dưới vùng tranh minh họa.
  5. **Khung mô tả bên dưới:** Nền giấy cổ `#F5EFE6` dễ đọc (chữ `#1A1A1D`), **huy hiệu nhỏ ở góc dưới-trái**, **xoáy hoa văn đen/màu ở góc dưới-phải**, và thanh viền màu loại bài mỏng ở cạnh đáy.

---

## 5. ĐẶC TẢ QUÂN CỜ 3D-TO-PIXEL (BLENDER — AG4)
- **Độ phân giải:** `64x64` px PNG RGBA, nền trong suốt, tắt anti-aliasing, bật viền đen Freestyle, Cel shading 3 bậc + bóng đổ khối, alpha nhị phân tuyệt đối (`0` hoặc `255`).

---

## 6. ĐẶC TẢ PIPELINE TRANH THẺ BÀI (SD FORGE + PILLOW — AG5)
- **Checkpoint:** `DreamshaperPixelart.safetensors` (`http://127.0.0.1:7860`).
- **Hậu kỳ bắt buộc:** Ép lưới pixel (`NEAREST`) + lượng tử hóa giới hạn bảng màu kiểu Balatro (12–20 màu sắc nét, không nhòe).
