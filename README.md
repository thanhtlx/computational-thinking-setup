# Thiết lập thực hành môn Tư duy tính toán

Script chạy máy chủ Python trên máy sinh viên để thực hành môn Tư duy tính toán.
Mỗi hệ điều hành chỉ cần tải một file chạy tương ứng, không cần cài Python trước.

## Yêu cầu

- Windows 10/11 x64, macOS Intel/Apple Silicon hoặc Linux glibc x64/ARM64.
- Linux cần Bash, tar, curl hoặc wget, và sha256sum hoặc shasum.
- Có kết nối mạng ở lần chạy đầu để tải Python và thư viện.

## Cách chạy

| Hệ điều hành | File cần tải |
| --- | --- |
| Windows | [run.bat](https://github.com/thanhtlx/computational-thinking-setup/raw/refs/heads/main/run.bat) |
| macOS | [run.command](https://github.com/thanhtlx/computational-thinking-setup/raw/refs/heads/main/run.command) |
| Linux | [run.sh](https://github.com/thanhtlx/computational-thinking-setup/raw/refs/heads/main/run.sh) |

Nếu trình duyệt chỉ hiện nội dung, nhấp chuột phải vào liên kết, chọn **Lưu liên kết thành...**
và giữ nguyên tên file.

### Windows

Nhấp đúp vào `run.bat` và chờ chương trình tải Python cùng thư viện ở lần đầu.

### macOS

Nếu tải file vào thư mục Downloads, mở Terminal và cấp quyền chạy một lần:

```bash
chmod +x ~/Downloads/run.command
```

Sau đó nhấp đúp vào `run.command` để mở Terminal và chạy server.
Các lần sau chỉ cần nhấp đúp lại file này.

### Linux

Mở Terminal tại thư mục vừa tải file rồi chạy:

```bash
bash run.sh
```

Script hỗ trợ Linux dùng glibc như Ubuntu, Debian và Fedora; không hỗ trợ Alpine/musl.

### Kiểm tra và dừng server

Khi máy chủ đã chạy, mở <http://127.0.0.1:8001/health>. Kết quả cần thấy là:

```json
{"status":"ok"}
```

Giữ cửa sổ terminal mở trong lúc thực hành. Nhấn **Ctrl+C** để dừng máy chủ.
Những lần sau, mở lại file chạy tương ứng. Chương trình dùng lại Python và thư viện
đã tải, không cần mạng để khởi động máy chủ.

## Cài Python 3.9 trên Windows

Nếu cần dùng Python 3.9 trực tiếp trong Terminal hoặc trình soạn thảo, tải
[install_python39.bat](https://github.com/thanhtlx/computational-thinking-setup/raw/refs/heads/main/install_python39.bat)
và nhấp đúp. File tự tải bộ cài Python 3.9.13 x64, cài cho tài khoản hiện tại,
kèm pip và Python Launcher, rồi thêm Python và Scripts vào PATH người dùng.
Lần cài mới cần có mạng.

Nếu đã có Python 3.9 x64 được bộ cài chính thức đăng ký, script dùng lại bản đó
và bổ sung PATH. Các bản Python khác đang có được giữ lại.

Sau khi hoàn tất, đóng và mở lại Terminal/CMD/PowerShell rồi kiểm tra:

```text
python --version
python -m pip --version
```

Nếu máy có nhiều phiên bản Python, dùng `py -3.9` để chọn đúng dòng 3.9,
và `py -3.9 -m pip` để cài thư viện cho dòng này. Nếu bản Python 3.9 có sẵn
không kèm lệnh `py`, dùng đường dẫn `python.exe` mà script hiển thị.

Python 3.9 đã kết thúc hỗ trợ; 3.9.13 là bản cuối có bộ cài Windows chính thức.
Xem [thông tin phát hành Python 3.9.13](https://www.python.org/downloads/release/python-3913/).
Các file chạy server ở trên dùng Python 3.13 riêng cùng FastAPI/Uvicorn.

## Các file

- `run.bat`, `run.command`, `run.sh`: mỗi file chứa cả phần chuẩn bị môi trường và mã máy chủ.
- `install_python39.bat`: bộ cài tự động Python 3.9 cho Windows.
- `python_server.py`: mã nguồn máy chủ để xem hoặc chỉnh sửa.

Máy chủ chạy tại `http://127.0.0.1:8001`, cung cấp API `GET /health` và `POST /run`.
Runtime của server được lưu theo hệ điều hành:

- Windows: `%LOCALAPPDATA%\PythonRunner`.
- macOS: `~/Library/Application Support/PythonRunner`.
- Linux: `~/.local/share/PythonRunner`.

macOS/Linux dùng Python từ dự án
[python-build-standalone của Astral](https://github.com/astral-sh/python-build-standalone).
Các script server không cần quyền quản trị hoặc cài Python vào hệ thống.

## Tình trạng kiểm tra

Đã chạy setup từ đầu và khởi động lại bằng runtime đã lưu trên Mac Apple Silicon;
kiểm tra API, nhập dữ liệu, tiếng Việt, lỗi Python và giới hạn thời gian chạy.
Đã kiểm tra cú pháp Bash/PowerShell và mô phỏng các nhánh Linux/Mac Intel,
bộ cài Python 3.9 trên Windows, cập nhật PATH và xử lý lỗi tải/cài đặt.
Chưa chạy thử trên Windows, Linux hoặc Mac Intel thực tế.
