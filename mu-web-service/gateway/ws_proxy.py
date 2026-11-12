"""Gateway WebSocket <-> TCP cho MU Online (bản chạy container).

Client Godot (web/APK) nói chuyện WebSocket nhị phân; OpenMU GameServer nói TCP. Gateway chỉ chuyển byte qua lại,
không sửa gói tin. Cấu hình bằng biến môi trường:
    WS_HOST (0.0.0.0)  WS_PORT (8080)  OPENMU_HOST (openmu)  OPENMU_PORT (45901)
    MOCK_WHEN_OFFLINE  =1 để trả lời giả khi OpenMU tắt (chỉ để thử client; production để 0)
"""
import asyncio
import logging
import os
import signal

import websockets

import presence

logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"), format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("mu-gateway")

WS_HOST = os.environ.get("WS_HOST", "0.0.0.0")
WS_PORT = int(os.environ.get("WS_PORT", "8080"))
OPENMU_HOST = os.environ.get("OPENMU_HOST", "openmu")
OPENMU_PORT = int(os.environ.get("OPENMU_PORT", "45901"))
MOCK = os.environ.get("MOCK_WHEN_OFFLINE", "0") == "1"
# Client hiện gửi gói đăng nhập tự chế (F1 01, tài khoản/mật khẩu thô) mà OpenMU không hiểu. Gateway gốc của dự án
# (E:\MuMain\gateway\ws_proxy.py) tự trả lời "đăng nhập thành công"; giữ nguyên hành vi đó. Đặt LOGIN_ACK=0 khi client đã
# nói đúng giao thức MU để OpenMU tự xác thực.
LOGIN_ACK = os.environ.get("LOGIN_ACK", "1") == "1"
CONNECT_TIMEOUT = float(os.environ.get("CONNECT_TIMEOUT", "5"))
MAX_MSG = 10 * 1024 * 1024


async def ws_to_tcp(ws, writer):
    async for msg in ws:
        if isinstance(msg, bytes):
            if LOGIN_ACK and len(msg) >= 4 and msg[2] == 0xF1 and msg[3] == 0x01:
                log.info("login '%s' -> ack cục bộ", msg[4:14].split(b"\0")[0].decode("latin1", "ignore"))
                await ws.send(bytes([0xC1, 0x05, 0xF1, 0x01, 0x01]))
                continue
            writer.write(msg)
            await writer.drain()
        else:
            await presence.handle_text(ws, msg)


async def tcp_to_ws(reader, ws):
    while True:
        data = await reader.read(8192)
        if not data:
            return
        await ws.send(data)


async def mock_session(ws):
    """Phản hồi tối thiểu khi OpenMU tắt (chỉ để thử giao diện)."""
    replies = {(0xF1, 0x01): b"\xC1\x05\xF1\x01\x01", (0xF3, 0x01): b"\xC1\x05\xF3\x01\x01",
               (0xF3, 0x02): b"\xC1\x05\xF3\x02\x01", (0xF3, 0x03): b"\xC1\x05\xF3\x03\x01"}
    async for msg in ws:
        if isinstance(msg, bytes) and len(msg) >= 4 and (msg[2], msg[3]) in replies:
            await ws.send(replies[(msg[2], msg[3])])
        elif isinstance(msg, str):
            await presence.handle_text(ws, msg)


async def handle(ws):
    peer = ws.remote_address
    try:
        reader, writer = await asyncio.wait_for(asyncio.open_connection(OPENMU_HOST, OPENMU_PORT), CONNECT_TIMEOUT)
    except Exception as e:
        log.warning("OpenMU %s:%s không kết nối được (%s)", OPENMU_HOST, OPENMU_PORT, e)
        if MOCK:
            try:
                await mock_session(ws)
            finally:
                await presence.disconnect(ws)
        else:
            await ws.close(code=1013, reason="game server unavailable")
        return
    log.info("client %s -> %s:%s", peer, OPENMU_HOST, OPENMU_PORT)
    tasks = [asyncio.create_task(ws_to_tcp(ws, writer)), asyncio.create_task(tcp_to_ws(reader, ws))]
    try:
        await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
    finally:
        for t in tasks:
            t.cancel()
        await presence.disconnect(ws)
        writer.close()
        log.info("client %s ngắt kết nối", peer)


async def main():
    stop = asyncio.get_running_loop().create_future()
    for s in (signal.SIGTERM, signal.SIGINT):
        try:
            asyncio.get_running_loop().add_signal_handler(s, lambda: stop.done() or stop.set_result(None))
        except NotImplementedError:   # Windows
            pass
    async with websockets.serve(handle, WS_HOST, WS_PORT, max_size=MAX_MSG, ping_interval=30, ping_timeout=60):
        log.info("ws://%s:%s -> tcp://%s:%s (mock=%s)", WS_HOST, WS_PORT, OPENMU_HOST, OPENMU_PORT, MOCK)
        await stop


if __name__ == "__main__":
    asyncio.run(main())
