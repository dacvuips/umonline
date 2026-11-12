"""Kênh "người chơi cùng thế giới" cho Gateway MU.

Tài khoản / nhân vật của client lưu cục bộ (không có trong OpenMU) nên các client không thể thấy nhau qua OpenMU.
Gateway thay vào đó chuyển tiếp các khung văn bản JSON giữa những client đang ở CÙNG MAP:

Client -> Gateway:  join, move, map, chat, whisper, eq, atk, hp
Gateway -> Client:  spawn, move, despawn, chat, whisper, eq, atk, hp, sys

Khung nhị phân (gói MU) không đi qua module này.
"""
import json
import logging

log = logging.getLogger("presence")

# ws -> thông tin người chơi
PEERS: dict = {}

_PUBLIC = ("name", "cls", "lvl", "tier", "guild", "eq", "map", "x", "y", "hp", "mhp")
_MAX_CHAT = 120


def _clip(v, n):
    return str(v)[:n]


def _public(info: dict) -> dict:
    return {k: info.get(k) for k in _PUBLIC}


async def _send(ws, obj: dict):
    try:
        await ws.send(json.dumps(obj, separators=(",", ":")))
    except Exception:
        pass


async def _broadcast_map(src, map_id, obj: dict):
    """Gửi cho mọi người cùng map, trừ src."""
    for ws, info in list(PEERS.items()):
        if ws is src or info.get("map") != map_id:
            continue
        await _send(ws, obj)


async def _enter_map(ws, info: dict):
    """Báo cho người cùng map biết có người mới, và gửi danh sách người đang có cho người mới."""
    await _broadcast_map(ws, info["map"], {"t": "spawn", "p": _public(info)})
    for other, oi in list(PEERS.items()):
        if other is not ws and oi.get("map") == info["map"]:
            await _send(ws, {"t": "spawn", "p": _public(oi)})


async def _leave_map(ws, info: dict):
    await _broadcast_map(ws, info["map"], {"t": "despawn", "n": info["name"]})


async def handle_text(ws, text: str):
    try:
        msg = json.loads(text)
    except Exception:
        return
    if not isinstance(msg, dict):
        return
    t = msg.get("t")
    me = PEERS.get(ws)

    if t == "join":
        name = _clip(msg.get("name", ""), 10).strip()
        if not name:
            return
        # Cùng tên đang online ở kết nối khác -> đá kết nối cũ (đăng nhập lại / F5)
        for other, oi in list(PEERS.items()):
            if other is not ws and oi["name"] == name:
                PEERS.pop(other, None)
                await _leave_map(other, oi)
                try:
                    await other.close(code=4000, reason="duplicate login")
                except Exception:
                    pass
        if me:
            await _leave_map(ws, me)
        info = {
            "name": name,
            "cls": int(msg.get("cls", 1)),
            "lvl": int(msg.get("lvl", 1)),
            "tier": int(msg.get("tier", 1)),
            "guild": _clip(msg.get("guild", ""), 8),
            "eq": msg.get("eq") if isinstance(msg.get("eq"), dict) else {},
            "map": int(msg.get("map", 1)),
            "x": int(msg.get("x", 130)),
            "y": int(msg.get("y", 125)),
            "hp": int(msg.get("hp", 100)),
            "mhp": int(msg.get("mhp", 100)),
        }
        PEERS[ws] = info
        log.info("join '%s' map=%s (%d online)", name, info["map"], len(PEERS))
        await _enter_map(ws, info)
        return

    if me is None:
        return   # chưa join

    if t == "move":
        me["x"], me["y"] = int(msg.get("x", me["x"])), int(msg.get("y", me["y"]))
        await _broadcast_map(ws, me["map"], {"t": "move", "n": me["name"], "x": me["x"], "y": me["y"],
                                             "run": bool(msg.get("run", False))})
    elif t == "map":
        await _leave_map(ws, me)
        me["map"] = int(msg.get("map", me["map"]))
        me["x"], me["y"] = int(msg.get("x", me["x"])), int(msg.get("y", me["y"]))
        await _enter_map(ws, me)
    elif t == "chat":
        text = _clip(msg.get("msg", ""), _MAX_CHAT)
        if text:
            await _broadcast_map(ws, me["map"], {"t": "chat", "n": me["name"], "msg": text})
    elif t == "whisper":
        to, text = _clip(msg.get("to", ""), 10), _clip(msg.get("msg", ""), _MAX_CHAT)
        for other, oi in PEERS.items():
            if oi["name"] == to:
                await _send(other, {"t": "whisper", "n": me["name"], "msg": text})
                return
        await _send(ws, {"t": "sys", "msg": "%s không online." % to})
    elif t == "eq":
        if isinstance(msg.get("eq"), dict):
            me["eq"] = msg["eq"]
            me["lvl"] = int(msg.get("lvl", me["lvl"]))
            me["cls"] = int(msg.get("cls", me["cls"]))
            me["tier"] = int(msg.get("tier", me["tier"]))
            await _broadcast_map(ws, me["map"], {"t": "eq", "n": me["name"], "eq": me["eq"], "lvl": me["lvl"],
                                                 "cls": me["cls"], "tier": me["tier"]})
    elif t == "atk":
        await _broadcast_map(ws, me["map"], {"t": "atk", "n": me["name"], "x": int(msg.get("x", me["x"])),
                                             "y": int(msg.get("y", me["y"]))})
    elif t == "hp":
        me["hp"], me["mhp"] = int(msg.get("hp", me["hp"])), int(msg.get("mhp", me["mhp"]))
        await _broadcast_map(ws, me["map"], {"t": "hp", "n": me["name"], "hp": me["hp"], "mhp": me["mhp"]})


async def disconnect(ws):
    me = PEERS.pop(ws, None)
    if me:
        log.info("leave '%s' (%d online)", me["name"], len(PEERS))
        await _leave_map(ws, me)
