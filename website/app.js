"use strict";

const $ = (s, r = document) => r.querySelector(s);
const modal = $("#modal");
const authArea = $("#authArea");
let lastFocus = null;

/* ================= Dữ liệu 7 lớp nhân vật =================
   Chỉ số khởi đầu và mô tả lấy từ game (MuAccountSession.CLASS_INFO).
   Trang bị: bộ giáp, vũ khí, cánh, thú cưỡi trong ảnh (tất cả +15 Excellent), chụp bằng tools/class_shot.gd. */
const CLASSES = [
	{
		id: 1, name: "Dark Knight", title: "Chiến Binh Bóng Đêm", type: "melee", tag: "Cận chiến", role: "Sát thương cận chiến · chịu đòn",
		desc: "Chiến binh kiên cường của vương quốc Lorencia, sở hữu sức mạnh cận chiến vô song và giáp trụ cứng cáp.",
		stats: [28, 20, 25, 10, 0], req: 1, glow: "rgba(224,90,50,.35)", g1: "#2a1410", g2: "#120907", rc: "#ff9b7a",
		gear: { "Giáp": "Dragon Knight", "Vũ khí": "Bone Blade + Crimson Glory", "Cánh": "Wing of Storm", "Thú cưỡi": "Fenrir đỏ" },
	},
	{
		id: 0, name: "Dark Wizard", title: "Phù Thủy Áo Đen", type: "magic", tag: "Phép thuật", role: "Pháp sư tấn công diện rộng",
		desc: "Hậu duệ của hội pháp thuật Arka cổ xưa, thành thạo các nguyên tố ma thuật diện rộng.",
		stats: [18, 18, 15, 30, 0], req: 1, glow: "rgba(90,130,255,.35)", g1: "#101830", g2: "#080b17", rc: "#8fb0ff",
		gear: { "Giáp": "Venom Mist", "Vũ khí": "Grand Viper Staff", "Cánh": "Wing of Eternal", "Thú cưỡi": "Fenrir xanh" },
	},
	{
		id: 2, name: "Fairy Elf", title: "Tiên Nữ Xạ Thủ", type: "ranged", tag: "Tầm xa & hỗ trợ", role: "Cung thủ · hồi phục · buff",
		desc: "Những nữ chiến binh thanh nhã từ vương quốc Noria, cung thủ bách phát bách trúng và có khả năng hồi phục sinh lực.",
		stats: [22, 25, 20, 15, 0], req: 1, glow: "rgba(90,200,120,.32)", g1: "#10261a", g2: "#07120c", rc: "#8be0a2",
		gear: { "Giáp": "Sylphid Ray", "Vũ khí": "Sylph Wind Bow", "Cánh": "Wing of Illusion", "Thú cưỡi": "Fenrir vàng" },
	},
	{
		id: 3, name: "Magic Gladiator", title: "Đấu Sĩ Ma Pháp", type: "melee", tag: "Cận chiến", role: "Kiếm thuật kết hợp ma pháp",
		desc: "Chiến binh kết hợp tuyệt đỉnh giữa kiếm thuật cận chiến tàn bạo và phép thuật hủy diệt.",
		stats: [26, 26, 26, 26, 0], req: 220, glow: "rgba(180,100,255,.33)", g1: "#1f1230", g2: "#0d0814", rc: "#caa2ff",
		gear: { "Giáp": "Volcano", "Vũ khí": "Explosion Blade", "Cánh": "Wing of Ruin", "Thú cưỡi": "Fenrir đen" },
	},
	{
		id: 4, name: "Dark Lord", title: "Chúa Tể Bóng Đêm", type: "melee", tag: "Cận chiến", role: "Chỉ huy · thú cưỡi · triệu quạ",
		desc: "Thủ lĩnh mang dòng dõi đế vương với uy quyền lãnh đạo, điều khiển chiến mã và quạ tinh bóng đêm.",
		stats: [26, 20, 20, 15, 25], req: 250, glow: "rgba(236,190,90,.35)", g1: "#2a2010", g2: "#120d07", rc: "#f3d27c",
		gear: { "Giáp": "Sunlight", "Vũ khí": "Divine Scepter of Archangel", "Cánh": "Cape of Emperor", "Thú cưỡi": "Dark Horse" },
	},
	{
		id: 5, name: "Summoner", title: "Thuật Sĩ Triệu Hồi", type: "magic", tag: "Phép thuật", role: "Triệu hồi · nguyền rủa",
		desc: "Nữ thuật sĩ với tinh thần thép và khả năng nguyền rủa, triệu hồi sức mạnh bóng tối.",
		stats: [21, 21, 18, 23, 0], req: 1, glow: "rgba(255,110,170,.32)", g1: "#2a1022", g2: "#12080f", rc: "#ff9cc6",
		gear: { "Giáp": "Eternal Wing", "Vũ khí": "Eternal Wing Stick", "Cánh": "Wing of Dimension", "Thú cưỡi": "Fenrir xanh" },
	},
	{
		id: 6, name: "Rage Fighter", title: "Thiết Binh Quyền Thần", type: "melee", tag: "Cận chiến", role: "Võ sĩ tốc độ · đòn liên hoàn",
		desc: "Chiến binh hoàng gia Karutan, chiến đấu bằng nắm đấm thép cuồng bạo và kình lực cận chiến mãnh liệt.",
		stats: [32, 27, 25, 20, 0], req: 250, glow: "rgba(70,200,210,.3)", g1: "#0f2328", g2: "#07100f", rc: "#7fe0e8",
		gear: { "Giáp": "Phoenix Soul", "Vũ khí": "Phoenix Soul Star", "Cánh": "Cape of Overrule", "Thú cưỡi": "Fenrir vàng" },
	},
];

const STAT_LABELS = ["SỨC", "NHANH", "THỂ", "NĂNG", "CHỈ HUY"];

function el(tag, cls, text) {
	const e = document.createElement(tag);
	if (cls) e.className = cls;
	if (text !== undefined) e.textContent = text;
	return e;
}

function renderClasses() {
	const box = $("#classes");
	for (const c of CLASSES) {
		const card = el("article", "cls");
		card.dataset.type = c.type;
		card.style.cssText = `--glow:${c.glow};--g1:${c.g1};--g2:${c.g2};--rc:${c.rc}`;

		const art = el("div", "cls-art");
		art.append(el("span", "tag", c.tag), el("span", "plus", "FULL +15"));
		const img = document.createElement("img");
		img.src = `assets/classes/class_${c.id}.webp`;
		img.alt = `${c.name} mặc trọn bộ trang bị +15, cánh và thú cưỡi`;
		img.width = 720; img.height = 960; img.loading = "lazy"; img.decoding = "async";
		art.append(img);

		const body = el("div", "cls-body");
		body.append(el("h3", "", c.name), el("p", "role", c.role), el("p", "desc", c.desc));

		const stats = el("div", "stats");
		stats.setAttribute("aria-label", "Chỉ số khởi đầu");
		c.stats.forEach((v, i) => {
			if (i === 4 && v === 0) return;
			const s = el("div", "stat");
			s.append(el("small", "", STAT_LABELS[i]), el("b", "", String(v)));
			stats.append(s);
		});
		stats.style.gridTemplateColumns = `repeat(${c.stats[4] ? 5 : 4}, 1fr)`;

		const gear = el("ul", "gear");
		for (const [k, v] of Object.entries(c.gear)) {
			const li = el("li");
			li.append(el("span", "", k), el("span", "", v));
			gear.append(li);
		}
		body.append(stats, gear);
		if (c.req > 1) body.append(el("p", "req", `Mở khóa khi có nhân vật cấp ${c.req}+`));

		card.append(art, body);
		box.append(card);
	}
}
renderClasses();

/* ---------- bộ lọc lớp ---------- */
$("#chips").addEventListener("click", (e) => {
	const chip = e.target.closest(".chip");
	if (!chip) return;
	for (const c of document.querySelectorAll(".chip")) {
		const on = c === chip;
		c.classList.toggle("on", on);
		c.setAttribute("aria-selected", String(on));
	}
	const f = chip.dataset.f;
	for (const card of document.querySelectorAll(".cls")) card.hidden = !(f === "all" || card.dataset.type === f);
});

/* ---------- menu di động ---------- */
$("#burger").addEventListener("click", () => {
	const open = $("#nav").classList.toggle("open");
	$("#burger").setAttribute("aria-expanded", String(open));
});
$("#nav").addEventListener("click", (e) => {
	if (e.target.tagName === "A") {
		$("#nav").classList.remove("open");
		$("#burger").setAttribute("aria-expanded", "false");
	}
});

/* ---------- hộp thoại ---------- */
function setTab(name) {
	const login = name === "login";
	$("#loginForm").hidden = !login;
	$("#registerForm").hidden = login;
	$("#tabLogin").setAttribute("aria-selected", String(login));
	$("#tabRegister").setAttribute("aria-selected", String(!login));
	$("#modalTitle").textContent = login ? "Đăng nhập" : "Tạo tài khoản";
	for (const m of document.querySelectorAll(".msg")) { m.textContent = ""; m.className = "msg"; }
	const first = (login ? $("#loginForm") : $("#registerForm")).querySelector("input");
	setTimeout(() => first.focus(), 0);
}

function openModal(tab) {
	lastFocus = document.activeElement;
	modal.hidden = false;
	document.body.style.overflow = "hidden";
	setTab(tab);
}

function closeModal() {
	modal.hidden = true;
	document.body.style.overflow = "";
	if (lastFocus) lastFocus.focus();
}

document.addEventListener("click", (e) => {
	const opener = e.target.closest("[data-open]");
	if (opener) { openModal(opener.dataset.open); return; }
	if (e.target.closest("[data-close]")) closeModal();
	const tab = e.target.closest("[data-tab]");
	if (tab) setTab(tab.dataset.tab);
});
document.addEventListener("keydown", (e) => { if (e.key === "Escape" && !modal.hidden) closeModal(); });

/* ---------- gọi API ---------- */
async function api(path, body) {
	const res = await fetch("api/" + path, {
		method: body ? "POST" : "GET",
		headers: body ? { "Content-Type": "application/json" } : undefined,
		body: body ? JSON.stringify(body) : undefined,
		credentials: "same-origin",
	});
	let data = {};
	try { data = await res.json(); } catch (_) { /* không phải JSON */ }
	if (!res.ok) throw new Error(data.error || "Không kết nối được máy chủ. Hãy thử lại sau.");
	return data;
}

function showMsg(form, text, ok = false) {
	const m = form.querySelector(".msg");
	m.textContent = text;
	m.className = ok ? "msg ok" : "msg";
}

async function submit(form, path, build) {
	const btn = form.querySelector("button[type=submit]");
	btn.disabled = true;
	try {
		const body = build(Object.fromEntries(new FormData(form)));
		if (typeof body === "string") { showMsg(form, body); return; }
		const data = await api(path, body);
		showUser(data.username);
		closeModal();
		form.reset();
	} catch (err) {
		showMsg(form, err.message);
	} finally {
		btn.disabled = false;
	}
}

$("#loginForm").addEventListener("submit", (e) => {
	e.preventDefault();
	submit(e.target, "login", (v) => {
		if (!v.username || !v.password) return "Hãy nhập tên tài khoản và mật khẩu.";
		return { username: v.username.trim(), password: v.password };
	});
});

$("#registerForm").addEventListener("submit", (e) => {
	e.preventDefault();
	submit(e.target, "register", (v) => {
		const u = (v.username || "").trim();
		if (!/^[A-Za-z0-9]{4,10}$/.test(u)) return "Tên tài khoản gồm 4–10 chữ cái hoặc số, không dấu, không khoảng trắng.";
		if ((v.password || "").length < 6) return "Mật khẩu cần ít nhất 6 ký tự.";
		if (v.password !== v.password2) return "Hai mật khẩu không giống nhau.";
		return { username: u, password: v.password };
	});
});

/* ---------- trạng thái đăng nhập ---------- */
function showUser(name) {
	authArea.replaceChildren();
	const who = el("span", "who", "Xin chào, ");
	who.append(el("b", "", name));
	const play = el("a", "btn gold", "Vào game");
	play.href = "https://mu.viettheo.site/";
	const out = el("button", "btn ghost", "Đăng xuất");
	out.addEventListener("click", async () => {
		try { await api("logout", {}); } catch (_) { /* bỏ qua */ }
		showGuest();
	});
	authArea.append(who, play, out);
	$("#heroRegister").hidden = true;
	$("#tileRegister").hidden = true;
	$("#tileLogin").hidden = true;
	$(".tiles").style.gridTemplateColumns = "repeat(2, 1fr)";
}

function showGuest() {
	authArea.replaceChildren();
	const l = el("button", "btn ghost", "Đăng nhập");
	l.dataset.open = "login";
	const r = el("button", "btn gold", "Đăng ký");
	r.dataset.open = "register";
	authArea.append(l, r);
	$("#heroRegister").hidden = false;
	$("#tileRegister").hidden = false;
	$("#tileLogin").hidden = false;
	$(".tiles").style.gridTemplateColumns = "";
}

showGuest();
api("me").then((d) => { if (d.username) showUser(d.username); }).catch(() => { /* chưa đăng nhập / mở file trực tiếp */ });

/* ---------- liên kết tải game ----------
   Điền đường dẫn thật vào đây khi bản cài đặt đã sẵn sàng (file đặt trong website/downloads/ hoặc link cửa hàng).
   Để trống thì nút hiện "Sắp ra mắt". */
const DOWNLOADS = {
	pc: "",       // ví dụ: "downloads/MU-Online-Setup.exe"
	android: "https://mu.viettheo.site/download/mu-launcher.apk",
	ios: "",      // ví dụ: link App Store / TestFlight
};
for (const a of document.querySelectorAll("a.dl")) {
	const url = DOWNLOADS[a.dataset.dl];
	if (url) {
		a.href = url;
		a.rel = "noopener";
	} else {
		a.removeAttribute("href");
		a.setAttribute("aria-disabled", "true");
		a.textContent += " · Sắp ra mắt";
		a.addEventListener("click", (e) => e.preventDefault());
	}
}

/* Trên điện thoại / máy tính bảng không chơi trên trình duyệt: đổi các nút "Chơi trên web" thành lời nhắc tải ứng dụng. */
const IS_MOBILE = /Android|iPhone|iPad|iPod|Mobile|Silk/i.test(navigator.userAgent)
	|| (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
if (IS_MOBILE) {
	for (const a of document.querySelectorAll('a[href="https://mu.viettheo.site/"]')) {
		if (a.closest(".plat")) {
			a.removeAttribute("href");
			a.setAttribute("aria-disabled", "true");
			a.classList.remove("gold");
			a.textContent = "Chỉ dành cho máy tính";
			a.addEventListener("click", (e) => e.preventDefault());
		} else {
			a.href = DOWNLOADS.android || "#tai-game";
			a.textContent = a.classList.contains("tile") ? a.textContent : "Tải APK Android";
			const b = a.querySelector("b");
			if (b) b.textContent = "Tải APK Android";
		}
	}
}
