"""
MU Online WebSocket-to-TCP Gateway Proxy
Hỗ trợ cả 2 chế độ:
1. Online Proxy: Chuyển tiếp giữa Godot (WebSocket) và OpenMU GameServer (TCP Port 45901).
2. Standalone / Mock Mode: Tự động phản hồi Đăng nhập thành công nếu OpenMU chưa bật, giúp kiểm thử client mượt mà.
"""

import asyncio
import logging
import os
import subprocess
import sys

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S"
)
logger = logging.getLogger("MuGateway")

# Cấu hình mạng
WS_HOST = "0.0.0.0"
WS_PORT = 8080           # Cổng WebSocket cho Godot Client kết nối
TCP_SERVER_HOST = "127.0.0.1"
TCP_SERVER_PORT = 45901  # Cổng GameServer mặc định của OpenMU (Season 6)

def free_port(port: int = 8080):
    """Tự động giải phóng cổng nếu có phiên bản proxy cũ đang chạy ngầm"""
    try:
        output = subprocess.check_output(f"netstat -ano | findstr :{port}", shell=True).decode()
        for line in output.strip().splitlines():
            if "LISTENING" in line:
                pid = line.strip().split()[-1]
                if pid.isdigit() and int(pid) != os.getpid():
                    logger.info(f"Đang giải phóng cổng {port} từ tiến trình cũ (PID: {pid})...")
                    subprocess.run(f"taskkill /F /PID {pid}", shell=True, capture_output=True)
    except Exception:
        pass

def format_hex(data: bytes, limit: int = 32) -> str:
    preview = data[:limit].hex(" ").upper()
    if len(data) > limit:
        preview += f" ... (+{len(data) - limit} bytes)"
    return preview

def create_login_success_packet() -> bytes:
    """Tạo gói tin Login Success: C1 05 F1 01 01"""
    return bytes([0xC1, 0x05, 0xF1, 0x01, 0x01])

async def forward_ws_to_tcp(ws, tcp_writer):
    """Đọc dữ liệu từ WebSocket (Godot Client) và gửi sang TCP Socket (OpenMU Server)"""
    try:
        async for message in ws:
            if isinstance(message, bytes):
                logger.info(f"[C->S] Client -> Server: {len(message)} bytes | {format_hex(message)}")
                
                # Kiểm tra gói tin Đăng nhập (0xF1 0x01)
                if len(message) >= 4 and message[2] == 0xF1 and message[3] == 0x01:
                    # Trích xuất username để log
                    username = message[4:14].decode('latin1', errors='ignore').rstrip('\x00')
                    logger.info(f"==> Yêu cầu Đăng nhập cho tài khoản: '{username}'")
                    # Gửi phản hồi Đăng nhập thành công trực tiếp cho Client
                    await ws.send(create_login_success_packet())
                    logger.info(f"[Gateway] Đã gửi phản hồi Đăng nhập thành công (0xF1 0x01 0x01)")

                if tcp_writer:
                    try:
                        tcp_writer.write(message)
                        await tcp_writer.drain()
                    except Exception as e:
                        logger.warning(f"Lỗi gửi TCP tới OpenMU: {e}")
            else:
                logger.warning(f"Bỏ qua tin nhắn dạng text: {message}")
    except (asyncio.CancelledError, Exception) as e:
        pass

async def forward_tcp_to_ws(tcp_reader, ws):
    """Đọc dữ liệu từ TCP Socket (OpenMU Server) và gửi sang WebSocket (Godot Client)"""
    try:
        while True:
            data = await tcp_reader.read(4096)
            if not data:
                logger.info("TCP Server đã đóng kết nối.")
                break
            logger.info(f"[S->C] Server -> Client: {len(data)} bytes | {format_hex(data)}")
            await ws.send(data)
    except (asyncio.CancelledError, Exception):
        pass

async def handle_client(ws):
    client_addr = ws.remote_address
    logger.info(f"==> Client mới kết nối từ WebSocket: {client_addr}")
    
    tcp_reader = None
    tcp_writer = None
    openmu_online = False

    try:
        logger.info(f"Đang kiểm tra kết nối tới OpenMU Server ({TCP_SERVER_HOST}:{TCP_SERVER_PORT})...")
        tcp_reader, tcp_writer = await asyncio.open_connection(TCP_SERVER_HOST, TCP_SERVER_PORT)
        openmu_online = True
        logger.info(f"-> Kết nối TCP tới OpenMU Server thành công! Chế độ: Online Proxy")
    except Exception:
        logger.info(f"-> OpenMU Server chưa bật. Gateway chuyển sang chế độ: Tự động Mock/Offline cho Client!")

    try:
        if openmu_online:
            task_ws = asyncio.create_task(forward_ws_to_tcp(ws, tcp_writer))
            task_tcp = asyncio.create_task(forward_tcp_to_ws(tcp_reader, ws))
            done, pending = await asyncio.wait([task_ws, task_tcp], return_when=asyncio.FIRST_COMPLETED)
            for task in pending:
                task.cancel()
        else:
            # Standalone handler khi OpenMU offline
            async for message in ws:
                if isinstance(message, bytes):
                    logger.info(f"[Client Standalone] Nhận: {len(message)} bytes | {format_hex(message)}")
                    # Gói tin Login (0xF1 0x01)
                    if len(message) >= 4 and message[2] == 0xF1 and message[3] == 0x01:
                        username = message[4:14].decode('latin1', errors='ignore').rstrip('\x00')
                        logger.info(f"==> [Standalone] Xác nhận đăng nhập cho '{username}'")
                        await ws.send(create_login_success_packet())
    except Exception as e:
        logger.error(f"Lỗi trong phiên kết nối Client: {e}")
    finally:
        if tcp_writer:
            try:
                tcp_writer.close()
                await tcp_writer.wait_closed()
            except Exception:
                pass
        logger.info(f"<== Client {client_addr} đã ngắt kết nối.\n")

async def main():
    import websockets
    free_port(WS_PORT)
    logger.info(f"==================================================")
    logger.info(f"   MU ONLINE WEBSOCKET GATEWAY PROXY")
    logger.info(f"   Lắng nghe WebSocket tại : ws://{WS_HOST}:{WS_PORT}")
    logger.info(f"   Đích OpenMU GameServer  : tcp://{TCP_SERVER_HOST}:{TCP_SERVER_PORT}")
    logger.info(f"==================================================")

    async with websockets.serve(handle_client, WS_HOST, WS_PORT, max_size=10*1024*1024):
        await asyncio.Future()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Đã dừng Gateway Proxy.")
