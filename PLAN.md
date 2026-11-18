# KẾ HOẠCH PHÁT TRIỂN DỰ ÁN (PROJECT PLAN) - CHESS TO DIE
**Tech Lead & Producer:** AG1  
**Đội ngũ thực thi:** Ag2 (Game Developer), Ag3 (Graphic Designer & Tech Artist)  
**Tài liệu tham chiếu:** `design/GDD_Core.md`, `Gemini.md`  

---

## TỔNG QUAN TIẾN ĐỘ THEO MILESTONE

- [x] **Milestone 0: Khởi tạo Kiến trúc & Kiểm toán Thiết kế (GDD Audit)**
  - [x] Thiết lập cấu trúc thư mục phân tách độc lập (`src/`, `assets/`, `tasks/`, `design/`).
  - [x] Tạo `project.godot` Forward+, độ phân giải 1920x1080.
  - [x] Rà soát toàn bộ luật và 51 lá bài, chốt 6 quyết định thiết kế then chốt với Game Designer.
  - [x] Tạo bản phân tích kỹ thuật `tasks/gdd_audit.md`.

- [~] **Milestone 1: Khóa Hợp đồng Kỹ thuật & Phát triển Core Song song (Parallel Sprint 1)**
  - [x] Bóc tách và khóa hợp đồng kỹ thuật: `tasks/code_spec.md` và `tasks/art_spec.md`.
  - [ ] **Ag2 (Coder):** Xây dựng Core Logic cờ vua FIDE + Biến thể 51 lá bài (Headless GDScript):
    - [ ] Hệ thống bàn cờ $8 \times 8$, nước đi chuẩn và hệ thống điểm/HP quân cờ.
    - [ ] Cấu trúc dữ liệu thẻ bài `CardResource` (`res://src/resources/cards/`).
    - [ ] Bộ máy Turn Machine 4 Phase (`DrawPhase`, `MainPhase`, `MovePhase`, `EndPhase`).
    - [ ] Bộ xử lý 31 Active Cards và 20 Passive Cards.
    - [ ] Checkmate Interception Hook (cứu thua khi bị chiếu hết).
    - [ ] Bộ xử lý Vòng lửa sinh tử & Thánh chiến (Holy War giữa 2 Vua).
    - [ ] Bộ chạy Unit Test Headless `res://src/core/test_runner.gd`.
  - [ ] **Ag3 (Graphic Designer):** Dựng UI 2D tối giản Chess.com & Hệ thống Asset Vector/Shader:
    - [ ] Khung giao diện bàn cờ 2D và Theme `res://assets/ui/main_theme.tres`.
    - [ ] Bộ Icon 24 quân cờ chuẩn và siêu quân cờ (SVG sắc nét).
    - [ ] Khung thẻ bài Active, Passive và Mặt sau bài úp.
    - [ ] Bộ Shader ma thuật: Vòng lửa sinh tử, Dòng sông ranh giới, Kết giới đốt điểm, Tàng hình.
    - [ ] Xuất `assets/manifest.json` đăng ký 100% asset.

- [ ] **Milestone 2: Tích hợp Giao diện Bàn cờ 2D & Đấu Boss Roguelike (Cánh cửa 3D)**
  - [ ] Nối mạch Core Logic vào UI Scene (`chessboard.tscn`, `hand_bar.tscn`, `passive_slot.tscn`).
  - [ ] Xây dựng AI Boss với trạng thái Fog of War (không đọc lén bài úp).
  - [ ] Tích hợp giao diện chọn 10 cánh cửa Roguelike 3D (Forward+).

- [ ] **Milestone 3: Kiểm thử Chéo (QA), Đóng gói & Nghiệm thu (Delivery)**
  - [ ] Chạy tự động `godot --headless -s res://src/core/test_runner.gd` kiểm tra 100% ca kiểm thử.
  - [ ] Đối chiếu 1:1 giữa Asset gọi trong `src/` và Asset thực tế trong `assets/`.
  - [ ] Xuất báo cáo nghiệm thu hoàn chỉnh trình Game Designer.
