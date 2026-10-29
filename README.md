# Thiết lập thực hành môn Tư duy tính toán

Script chạy máy chủ Python trên máy sinh viên để thực hành môn Tư duy tính toán.
Chỉ cần tải một file `run.bat`, không cần cài Python trước.

## Yêu cầu

- Windows 10 hoặc Windows 11, bản 64-bit x64.
- Có kết nối mạng ở lần chạy đầu để tải Python và thư viện.

## Cách chạy

1. [Tải file run.bat](https://github.com/thanhtlx/computational-thinking-setup/raw/refs/heads/main/run.bat).
   Nếu trình duyệt chỉ hiện nội dung, nhấp chuột phải vào liên kết, chọn **Lưu liên kết thành...** và lưu với tên `run.bat`.
2. Nhấp đúp vào `run.bat`. Lần đầu, chờ chương trình tải Python và các thư viện cần thiết.
3. Khi máy chủ đã chạy, mở <http://127.0.0.1:8001/health> để kiểm tra. Kết quả cần thấy là:

   ```json
   {"status":"ok"}
   ```

4. Giữ cửa sổ terminal mở trong lúc thực hành. Nhấn **Ctrl+C** để dừng máy chủ.

Những lần sau, mở lại `run.bat`. Chương trình dùng lại Python và thư viện đã tải,
không cần mạng để khởi động máy chủ.

## Các file

- `run.bat`: chứa cả phần chuẩn bị môi trường và mã máy chủ; sinh viên chỉ cần file này.
- `python_server.py`: mã nguồn máy chủ để xem hoặc chỉnh sửa.

Máy chủ chạy tại `http://127.0.0.1:8001`, cung cấp API `GET /health` và `POST /run`.
Python và thư viện được lưu trong `%LOCALAPPDATA%\PythonRunner`, không cần quyền quản trị
hoặc cài Python vào hệ thống.

## Tình trạng kiểm tra

Đã kiểm tra API, nhập dữ liệu, tiếng Việt, lỗi Python và giới hạn thời gian chạy trên macOS.
Đã kiểm tra cú pháp PowerShell và mô phỏng việc chuẩn bị môi trường, chạy lại không dùng mạng,
xử lý lỗi tải. Chưa chạy thử toàn bộ file BAT trên Windows 10/11 thực tế.
