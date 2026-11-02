# Dòng Nước Xanh

Game mô phỏng dọn dẹp môi trường góc nhìn thứ nhất, kết hợp quản lý và tự động hóa nhẹ.
Bản chơi thử gồm màn 1 **Đoạn sông Tô Lịch** (30–45 phút) theo tài liệu thiết kế v1.0.

Chạy trên trình duyệt PC (chuột + bàn phím), dựng bằng [Three.js](https://threejs.org) và [Vite](https://vite.dev).
Không dùng tệp hình ảnh hay âm thanh ngoài: mô hình, họa tiết và âm thanh đều được tạo bằng code.

## Chạy

```bash
npm install
npm run dev      # mở http://localhost:5173
npm run build    # bản tĩnh trong dist/, đưa lên bất kỳ máy chủ web nào
```

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
→ mua vợt, băng chuyền → dọn cửa xả và kéo vật cản bằng móc → lắp máy vớt và công trình xử lý nước thải
→ nghiệm thu khi đủ điều kiện → xem ảnh trước–sau, mở Hồ thành phố trên bản đồ chiến dịch.

Điều kiện nghiệm thu: thu gom ≥ 90% khối lượng rác, xử lý vật cản, không còn rác chờ ở giỏ/thùng/bàn/dây chuyền,
công trình xử lý đang chạy và hoàn thành nhiệm vụ chính.

## Cấu trúc

```
index.html            khung trang và HUD
src/
  main.js             khởi động, nối các hệ thống, vòng lặp chính, nghiệm thu, chế độ phát triển
  data.js             toàn bộ nội dung và thông số cân bằng (rác, giá, bố trí màn, chiến dịch, phím)
  style.css           giao diện
  core/
    state.js          trạng thái ván, cài đặt, lưu/tải, giao dịch kinh tế
    input.js          bàn phím, chuột, khóa con trỏ, gán phím
    audio.js          âm thanh tổng hợp WebAudio
  world/
    level.js          địa hình, nước, cảnh quan, va chạm, hiệu ứng phục hồi
    trash.js          rác (InstancedMesh), chọn bằng tia ngắm, rác trôi, đồ sưu tầm
    machines.js       bàn phân loại, băng chuyền, máy vớt, công trình xử lý, vật cản
  game/
    player.js         di chuyển góc nhìn thứ nhất, dụng cụ, tương tác, đặt máy
    quests.js         nhiệm vụ, chỉ dẫn lần đầu, chỉ đường, điều kiện nghiệm thu
  ui/
    hud.js            HUD trong lúc chơi
    panels.js         menu, Tab, bàn phân loại, bảng máy, bản đồ chiến dịch, kết quả, chế độ phát triển
```

Muốn chỉnh cân bằng (giá, sức chứa, tốc độ máy, số rác từng khu) chỉ cần sửa `src/data.js`.

## Ghi chú kỹ thuật

- Rác vẽ bằng một `InstancedMesh` cho mỗi loại (14 lần vẽ cho 280 món); chọn rác bằng phép thử tia–cầu, không dùng raycast lưới.
- Mỗi món rác có mã cố định; trạng thái lưu theo mã nên không thể thu tiền hay tính tiến độ hai lần.
- Mỗi giao dịch xử lý trừ đầu vào và cấp thưởng trong cùng một bước rồi mới lưu.
- Tự lưu sau mua bán, hoàn thành nhiệm vụ, nghiệm thu, định kỳ 30 giây và khi rời trang.
- Khe lưu tách biệt: `main` (chiến dịch), `replay` (chơi lại, không cộng thưởng), `dev` (dữ liệu thử).
