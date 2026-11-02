# Dòng Nước Xanh

Game mô phỏng dọn dẹp môi trường góc nhìn thứ nhất, kết hợp quản lý và tự động hóa nhẹ.
Bản chơi thử gồm màn 1 **Đoạn sông Tô Lịch** (30–45 phút) theo tài liệu thiết kế v1.0.

Dựng bằng **[Godot 4.4](https://godotengine.org)** (GDScript, trình kết xuất Forward+).
Mô hình 3D, vân bề mặt PBR và bầu trời HDRI lấy từ [Poly Haven](https://polyhaven.com) theo giấy phép CC0,
xem [CREDITS.md](CREDITS.md). Âm thanh được tổng hợp bằng code.

## Chạy

1. Tải [Godot 4.4](https://godotengine.org/download) (bản thường, không cần bản .NET).
2. Mở Godot → **Import** → chọn `project.godot` trong thư mục này. Lần mở đầu Godot nhập asset khoảng một phút.
3. Bấm **Run** (F5).

Xuất bản chơi: **Project → Export**, thêm mẫu Windows/Linux/macOS rồi xuất.
Máy yếu có thể đổi trình kết xuất sang *Compatibility* trong **Project Settings → Rendering → Renderer**.

## Điều khiển

| Phím | Tác dụng |
| --- | --- |
| W A S D, Shift | Đi, chạy nhanh |
| Chuột | Nhìn |
| Chuột trái | Nhặt / dùng dụng cụ (giữ để vớt liên tục bằng vợt) |
| E | Tương tác (bàn phân loại, băng chuyền, máy vớt…) |
| 1 2 3, con lăn | Đổi dụng cụ: Tay, Vợt, Móc kéo |
| Tab | Nhiệm vụ, cửa hàng, nghiệm thu, cài đặt |
| B | Chế độ đặt máy |
| Esc | Tạm dừng |
| \` | Chế độ phát triển (lưu ở khe dữ liệu thử riêng) |

Mọi phím đều gán lại được trong **Cài đặt**.

## Vòng chơi

Nhặt rác → đổ giỏ ở bàn phân loại → chia vào ba thùng (nhựa, kim loại, rác còn lại) → nhận tiền và vật liệu
→ mua vợt, băng chuyền → dọn cửa xả và kéo lốp xe tải cũ bằng móc → lắp máy vớt và công trình xử lý nước thải
→ nghiệm thu khi đủ điều kiện → xem ảnh trước–sau, mở Hồ thành phố trên bản đồ chiến dịch.

Điều kiện nghiệm thu: thu gom ≥ 90% khối lượng rác, xử lý vật cản, không còn rác chờ ở giỏ/thùng/bàn/dây chuyền,
công trình xử lý đang chạy và hoàn thành nhiệm vụ chính.

## Hiệu ứng

- Nước dùng shader riêng: sóng, phản chiếu bầu trời, bọt ở mép bờ theo độ sâu, váng bẩn tan dần khi công trình xử lý chạy.
- Bờ sông chuyển từ bùn sang cỏ theo tỉ lệ rác đã gom; sương mù và độ bão hòa màu đổi theo độ sạch của nước.
- Bụi khi nhặt trên cạn, bọt nước khi vớt, ruồi bay trên đống rác cửa xả, tia lửa ở nam châm băng chuyền, bọt khí ở cửa xả.
- Sau nghiệm thu: cây, hoa, ghế đá mọc lên, vịt bơi trên sông, bướm bay.
- Ánh sáng: bầu trời HDRI, tonemap filmic, SSAO, SSR, glow, bóng đổ.

## Cấu trúc

```
project.godot           cấu hình project, autoload Game và Sfx
scenes/main.tscn        cảnh chính (chỉ gắn scripts/main.gd)
scripts/
  main.gd               khởi động, nối các hệ thống, vòng lặp chính, nghiệm thu, ảnh trước–sau, chế độ phát triển
  core/
    data.gd             toàn bộ nội dung và thông số cân bằng (rác, giá, bố trí màn, chiến dịch, phím)
    game.gd             autoload: trạng thái ván, cài đặt, lưu/tải, gán phím, giao dịch kinh tế
    sfx.gd              autoload: âm thanh tổng hợp
    assets.gd           nạp mô hình Poly Haven, gộp lưới cho MultiMesh, vật liệu PBR
  world/
    level.gd            địa hình, nước, phố, cảnh quan, va chạm, hiệu ứng phục hồi
    trash.gd            rác (MultiMesh), chọn bằng tia ngắm, rác trôi, đồ sưu tầm, hạt hiệu ứng
    machines.gd         bàn phân loại, băng chuyền, máy vớt, công trình xử lý, vật cản
  game/
    player.gd           di chuyển góc nhìn thứ nhất, dụng cụ, tương tác, đặt máy
    quests.gd           nhiệm vụ, chỉ dẫn lần đầu, cột sáng chỉ đường, điều kiện nghiệm thu
  ui/
    style.gd            theme giao diện dùng chung
    hud.gd              HUD trong lúc chơi
    panels.gd           menu, Tab, bàn phân loại, bảng máy, bản đồ chiến dịch, kết quả, chế độ phát triển
shaders/
  water.gdshader        mặt nước
  bank.gdshader         bờ sông bùn → cỏ
assets/
  models/<tên>/         mô hình glTF (Poly Haven, CC0)
  textures/<tên>/       vân bề mặt diff/nor/arm (Poly Haven, CC0)
  sky/                  bầu trời HDRI (Poly Haven, CC0)
```

Muốn chỉnh cân bằng (giá, sức chứa, tốc độ máy, số rác từng khu) chỉ cần sửa `scripts/core/data.gd`.

## Ghi chú kỹ thuật

- Rác vẽ bằng một `MultiMesh` cho mỗi loại (14 lần vẽ cho 280 món); chọn rác bằng phép thử tia–cầu, không cần vật lý.
- Mỗi món rác có mã cố định; trạng thái lưu theo mã nên không thể thu tiền hay tính tiến độ hai lần.
- Mỗi giao dịch xử lý trừ đầu vào và cấp thưởng trong cùng một bước rồi mới lưu.
- Tự lưu sau mua bán, hoàn thành nhiệm vụ, nghiệm thu, định kỳ 30 giây và khi thoát hoặc chuyển cửa sổ.
- Khe lưu tách biệt trong `user://`: `main` (chiến dịch), `replay` (chơi lại, không cộng thưởng), `dev` (dữ liệu thử).
  Cài đặt lưu riêng ở `user://settings.cfg`.
