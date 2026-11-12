extends Control
class_name ChaosRecipeDialog

## Cửa sổ Popup Cẩm Nang Toàn Bộ Công Thức Ép Máy Hỗn Nguyên (Chaos Goblin Machine)
## Chuẩn thông số từ file mix.bmd Webzen & OpenMU Season 6
## Hỗ trợ kéo thả (Draggable), lọc theo Danh mục, tìm kiếm nhanh và đóng bằng ESC / nút X.

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")

const S := 1.2
const W := 430.0
const H := 490.0

var user_has_dragged: bool = false
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_start_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 5.0

var _search_input: LineEdit
var _active_category: String = "all"
var _category_buttons: Dictionary = {}
var _scroll: ScrollContainer
var _card_container: VBoxContainer

const CATEGORIES := [
	{"id": "all", "label": "Tất Cả"},
	{"id": "upgrade", "label": "⚔️ Nâng Cấp +10..+15"},
	{"id": "wings", "label": "🪽 Cánh & Áo"},
	{"id": "pet", "label": "🐺 Sói & Thú"},
	{"id": "ticket", "label": "📜 Vé Sự Kiện"},
	{"id": "other", "label": "🧪 Bình & Khác"},
]

const RECIPES := [
	# -------------------- NÂNG CẤP TRANG BỊ +10 ĐẾN +15 --------------------
	{
		"cat": "upgrade",
		"title": "Nâng Cấp Đồ +10",
		"badge": "+10 Upgrade",
		"req": "• 1 Trang bị bất kỳ cấp +9\n• 1 Ngọc Hỗn Nguyên (Jewel of Chaos)\n• 1 Ngọc Ước Nguyện (Bless) + 1 Ngọc Tâm Linh (Soul)",
		"success": "Đồ thường: 60% (Có Luck: 85% Max)\nĐồ Exc / Thần / 380: 50% (Có Luck: 75% Max)\nĐồ Socket: 40% (Có Luck: 65% Max)",
		"fail": "15% – 40% (Đồ thường) • 25% – 50% (Đồ Exc/Thần) • 35% – 60% (Socket)",
		"penalty": "⚠️ Xịt: Món đồ chính và toàn bộ ngọc biến mất hoàn toàn!",
		"cost": "2,000,000 Zen",
		"tip": "Trang bị có dòng May Mắn (Luck) được cộng thẳng +25% tỉ lệ thành công."
	},
	{
		"cat": "upgrade",
		"title": "Nâng Cấp Đồ +11",
		"badge": "+11 Upgrade",
		"req": "• 1 Trang bị bất kỳ cấp +10\n• 1 Ngọc Chaos\n• 2 Ngọc Bless + 2 Ngọc Soul",
		"success": "Đồ thường: 60% (Có Luck: 85% Max)\nĐồ Exc / Thần / 380: 50% (Có Luck: 75% Max)\nĐồ Socket: 40% (Có Luck: 65% Max)",
		"fail": "15% – 40% (Đồ thường) • 25% – 50% (Đồ Exc/Thần) • 35% – 60% (Socket)",
		"penalty": "⚠️ Xịt: Món đồ chính và toàn bộ ngọc biến mất hoàn toàn!",
		"cost": "4,000,000 Zen",
		"tip": "Nếu có Bùa kết hợp Chaos, khi xịt đồ sẽ không bị mất."
	},
	{
		"cat": "upgrade",
		"title": "Nâng Cấp Đồ +12",
		"badge": "+12 Upgrade",
		"req": "• 1 Trang bị bất kỳ cấp +11\n• 1 Ngọc Chaos\n• 3 Ngọc Bless + 3 Ngọc Soul",
		"success": "Đồ thường: 55% (Có Luck: 80% Max)\nĐồ Exc / Thần / 380: 45% (Có Luck: 70% Max)\nĐồ Socket: 35% (Có Luck: 60% Max)",
		"fail": "20% – 45% (Đồ thường) • 30% – 55% (Đồ Exc/Thần) • 40% – 65% (Socket)",
		"penalty": "⚠️ Xịt: Món đồ chính và toàn bộ ngọc biến mất hoàn toàn!",
		"cost": "6,000,000 Zen",
		"tip": "Tỉ lệ trần giảm 5% so với cấp +11."
	},
	{
		"cat": "upgrade",
		"title": "Nâng Cấp Đồ +13",
		"badge": "+13 Upgrade",
		"req": "• 1 Trang bị bất kỳ cấp +12\n• 1 Ngọc Chaos\n• 4 Ngọc Bless + 4 Ngọc Soul",
		"success": "Đồ thường: 55% (Có Luck: 80% Max)\nĐồ Exc / Thần / 380: 45% (Có Luck: 70% Max)\nĐồ Socket: 35% (Có Luck: 60% Max)",
		"fail": "20% – 45% (Đồ thường) • 30% – 55% (Đồ Exc/Thần) • 40% – 65% (Socket)",
		"penalty": "⚠️ Xịt: Món đồ chính và toàn bộ ngọc biến mất hoàn toàn!",
		"cost": "8,000,000 Zen",
		"tip": "Đồ +13 phát ra ánh hào quang chói lọi đặc trưng của MU Online."
	},
	{
		"cat": "upgrade",
		"title": "Nâng Cấp Đồ +14",
		"badge": "+14 Upgrade",
		"req": "• 1 Trang bị bất kỳ cấp +13\n• 1 Ngọc Chaos\n• 5 Ngọc Bless + 5 Ngọc Soul",
		"success": "Đồ thường: 50% (Có Luck: 75% Max)\nĐồ Exc / Thần / 380: 40% (Có Luck: 65% Max)\nĐồ Socket: 30% (Có Luck: 55% Max)",
		"fail": "25% – 50% (Đồ thường) • 35% – 60% (Đồ Exc/Thần) • 45% – 70% (Socket)",
		"penalty": "⚠️ Xịt: Món đồ chính và toàn bộ ngọc biến mất hoàn toàn!",
		"cost": "10,000,000 Zen",
		"tip": "Rủi ro thất bại rất lớn, hãy chuẩn bị bùa bảo vệ."
	},
	{
		"cat": "upgrade",
		"title": "Nâng Cấp Đồ +15",
		"badge": "+15 Upgrade",
		"req": "• 1 Trang bị bất kỳ cấp +14\n• 1 Ngọc Chaos\n• 6 Ngọc Bless + 6 Ngọc Soul",
		"success": "Đồ thường: 50% (Có Luck: 75% Max)\nĐồ Exc / Thần / 380: 40% (Có Luck: 65% Max)\nĐồ Socket: 30% (Có Luck: 55% Max)",
		"fail": "25% – 50% (Đồ thường) • 35% – 60% (Đồ Exc/Thần) • 45% – 70% (Socket)",
		"penalty": "⚠️ Xịt: Món đồ chính và toàn bộ ngọc biến mất hoàn toàn!",
		"cost": "12,000,000 Zen",
		"tip": "Cấp cường hóa tối đa đỉnh cao trong Season 6."
	},

	# -------------------- CÁNH & ÁO CHOÀNG --------------------
	{
		"cat": "wings",
		"title": "Vũ Khí Hỗn Nguyên (Chaos Weapon)",
		"badge": "Chaos Weapon",
		"req": "• 1 hoặc nhiều trang bị bất kỳ +4 trở lên có Option (Jewel of Life)\n• 1 Ngọc Hỗn Nguyên (Jewel of Chaos)\n• (Tuỳ chọn) Bless, Soul hoặc đồ +4 opt khác để nâng tỉ lệ",
		"success": "Tối đa 100% (Mỗi 20,000 Zen giá trị đồ = 1% tỉ lệ)",
		"fail": "Tùy thuộc vào tổng giá trị đồ đưa vào (100% - Tỉ lệ thành công)",
		"penalty": "⚠️ Xịt: Đồ chính bị giảm cấp hoặc mất dòng Option; các đồ phụ và ngọc biến mất.",
		"cost": "Tỉ lệ % × 10,000 Zen",
		"tip": "Nguyên liệu chế tạo ra: Rìu Hỗn Nguyên, Cung Hỗn Nguyên, Gậy Hỗn Nguyên (cần cho ép Cánh cấp 1)."
	},
	{
		"cat": "wings",
		"title": "Cánh Cấp 1 (First Wings)",
		"badge": "Wing 1",
		"req": "• 1 Vũ Khí Chaos +4 trở lên có Option\n• 1 Ngọc Hỗn Nguyên\n• (Tuỳ chọn) Trang bị +4 có Option, Bless, Soul để tăng tỉ lệ",
		"success": "Tối đa 100% (Tính theo giá trị Zen của vật phẩm đưa vào)",
		"fail": "Tùy thuộc vào đồ đưa vào (100% - Tỉ lệ thành công)",
		"penalty": "⚠️ Xịt: Vũ khí Chaos bị giảm cấp ngẫu nhiên hoặc mất dòng Option; ngọc và đồ phụ biến mất.",
		"cost": "Tỉ lệ % × 10,000 Zen",
		"tip": "Tạo ra ngẫu nhiên: Cánh Tiên Nữ, Cánh Thiên Sứ, Cánh Ác Quỷ, Cánh Đau Khổ (20% ra dòng Luck)."
	},
	{
		"cat": "wings",
		"title": "Cánh Cấp 2 (Second Wings)",
		"badge": "Wing 2",
		"req": "• 1 Cánh cấp 1 bất kỳ\n• 1 Lông Vũ Loch (Loch's Feather)\n• 1 Ngọc Hỗn Nguyên\n• (Tuỳ chọn) Trang bị Hoàn Hảo (Exc) +4 trở lên để tăng tỉ lệ",
		"success": "Tối đa 90% (Cánh 1: giá/4M + Đồ Exc: giá/40k)",
		"fail": "Tối thiểu 10% (10% – 100% nếu thiếu đồ Exc)",
		"penalty": "⚠️ Xịt: Toàn bộ Cánh 1, Lông Vũ và trang bị trong máy biến mất hoàn toàn!",
		"cost": "5,000,000 Zen (cố định)",
		"tip": "Tạo ngẫu nhiên: Cánh Rồng, Linh Hồn, Tinh Thần, Ma Thuật, Tuyệt Vọng (20% Luck, 20% dòng Exc)."
	},
	{
		"cat": "wings",
		"title": "Áo Choàng Chúa Tể / Đấu Sĩ",
		"badge": "Capes",
		"req": "• 1 Cánh cấp 1 bất kỳ\n• 1 Huy Hiệu Hoàng Tộc (Crest of Monarch)\n• 1 Ngọc Hỗn Nguyên\n• (Tuỳ chọn) Đồ Exc +4 trở lên để tăng tỉ lệ",
		"success": "Tối đa 90% (Tính theo giá trị Cánh 1 và Đồ Exc)",
		"fail": "Tối thiểu 10% THẤT BẠI!",
		"penalty": "⚠️ Xịt: Mất sạch toàn bộ cánh và nguyên liệu trong máy!",
		"cost": "5,000,000 Zen (cố định)",
		"tip": "Chế tạo Áo Choàng Chúa Tể (Dark Lord) hoặc Áo Choàng Đấu Sĩ (Rage Fighter)."
	},
	{
		"cat": "wings",
		"title": "Cánh Cấp 3 Bước 1: Lông Vũ Condor",
		"badge": "Wing 3 - Step 1",
		"req": "• 1 Cánh cấp 2 +9 trở lên có Option 4+\n• 1 Trang bị Thần (Ancient) +7 trở lên có Option 4+\n• 1 Ngọc Chaos + 1 Ngọc Sáng Tạo (Creation)\n• 1 Cụm 10 Ngọc Tâm Linh (Soul 10)",
		"success": "Tối đa 60% (Công thức: 1% + Giá Đồ Thần / 300,000)",
		"fail": "Tối thiểu 40% THẤT BẠI!",
		"penalty": "⚠️ Xịt: Cánh 2 và Đồ thần bị giảm 2–3 cấp, mất dòng Option; toàn bộ ngọc biến mất.",
		"cost": "Tỉ lệ % × 200,000 Zen (Tối đa 12,000,000 Zen)",
		"tip": "Đồ Thần cấp càng cao và nhiều option thì tỉ lệ thành công càng tiến gần mốc 60%."
	},
	{
		"cat": "wings",
		"title": "Cánh Cấp 3 Bước 2: Cánh Cấp 3",
		"badge": "Wing 3 - Step 2",
		"req": "• 1 Lông Vũ Condor (Condor Feather)\n• 1 Ngọn Lửa Condor (Flame of Condor)\n• 1 Trang bị Hoàn Hảo (Exc) +9 trở lên có Option 4+\n• 1 Ngọc Chaos + 1 Ngọc Creation\n• 1 Cụm 10 Soul + 1 Cụm 10 Bless",
		"success": "Tối đa 40% (Công thức: 1% + Giá Đồ Exc / 3,000,000)",
		"fail": "Tối thiểu 60% THẤT BẠI!",
		"penalty": "⚠️ Xịt: Đồ Exc bị giảm 2–3 cấp và mất option; Lông Vũ, Lửa Condor và ngọc mất sạch!",
		"cost": "Tỉ lệ % × 200,000 Zen (Tối đa 8,000,000 Zen)",
		"tip": "Tạo Cánh cấp 3: Cánh Huyền Thoại, Bão Tố, Ảo Ảnh, Phục Hận, Vô Cực, Đế Vương, Bá Vương."
	},

	# -------------------- SÓI TINH & THÚ CƯỠI --------------------
	{
		"cat": "pet",
		"title": "Sói Tinh Bước 1: Mảnh Sừng",
		"badge": "Fenrir Step 1",
		"req": "• 20 Mảnh Giáp (Splinter of Armor)\n• 20 Lời Chúc Bảo Hộ (Bless of Guardian)\n• 1 Ngọc Hỗn Nguyên",
		"success": "70% thành công",
		"fail": "30% THẤT BẠI",
		"penalty": "⚠️ Xịt: Mất toàn bộ 41 vật phẩm trong máy!",
		"cost": "0 Zen",
		"tip": "Thu thập mảnh giáp và lời chúc từ quái vật tại vùng đất Crywolf."
	},
	{
		"cat": "pet",
		"title": "Sói Tinh Bước 2: Sừng Gãy",
		"badge": "Fenrir Step 2",
		"req": "• 5 Mảnh Sừng (Fragment of Horn)\n• 10 Móng Vuốt Quái Thú (Claw of Beast)\n• 1 Ngọc Hỗn Nguyên",
		"success": "50% thành công",
		"fail": "50% THẤT BẠI",
		"penalty": "⚠️ Xịt: Mất toàn bộ vật phẩm trong máy!",
		"cost": "0 Zen",
		"tip": "Móng vuốt quái thú thu thập từ quái vật cấp cao tại Crywolf."
	},
	{
		"cat": "pet",
		"title": "Sói Tinh Bước 3: Sừng Sói Tinh Đỏ",
		"badge": "Horn of Fenrir",
		"req": "• 1 Sừng Gãy (Broken Horn)\n• 3 Ngọc Sinh Mệnh (Jewel of Life)\n• 1 Ngọc Hỗn Nguyên",
		"success": "30% thành công",
		"fail": "70% THẤT BẠI",
		"penalty": "⚠️ Xịt: Mất Sừng Gãy và toàn bộ ngọc!",
		"cost": "10,000,000 Zen",
		"tip": "Tạo ra Sói Tinh màu đỏ (Horn of Fenrir) có sẵn kỹ năng Phóng Sét Tấn Công."
	},
	{
		"cat": "pet",
		"title": "Nâng Cấp Sói Tinh Đen (Công) / Xanh (Thủ)",
		"badge": "Fenrir Upgrade",
		"req": "• 1 Sừng Sói Tinh Đỏ + 5 Jewel of Life + 1 Ngọc Chaos\n• Sói Đen (Destruction): Thêm 1 Vũ Khí Exc +4 Option trở lên\n• Sói Xanh (Protection): Thêm 1 Trang Phục Exc +4 Option trở lên",
		"success": "Tối đa 79% (Tính theo giá trị trang bị Exc đưa vào)",
		"fail": "Tối thiểu 21% THẤT BẠI!",
		"penalty": "⚠️ Xịt: Sói Tinh và toàn bộ nguyên liệu biến mất hoàn toàn!",
		"cost": "10,000,000 Zen",
		"tip": "Sói Đen tăng sát thương tuyệt đối, Sói Xanh giảm sát thương nhận vào."
	},
	{
		"cat": "pet",
		"title": "Sừng Dinorant",
		"badge": "Dinorant",
		"req": "• 10 Sừng Kỳ Lân Uniria (Độ bền 255/255 đầy máu)\n• 1 Ngọc Hỗn Nguyên",
		"success": "70% thành công",
		"fail": "30% THẤT BẠI",
		"penalty": "⚠️ Xịt: Mất toàn bộ 10 sừng Uniria và ngọc Chaos!",
		"cost": "500,000 Zen",
		"tip": "Dinorant giúp nhân vật bay vào bản đồ Icarus và bơi trong Atlans, có kỹ năng Quét Đuôi."
	},

	# -------------------- VÉ SỰ KIỆN --------------------
	{
		"cat": "ticket",
		"title": "Thiệp Mời Quỷ (Devil Square 1-7)",
		"badge": "Devil Square",
		"req": "• 1 Mắt Quỷ (Devil's Eye) + 1 Chìa Khóa Quỷ (Devil's Key) cùng cấp\n• 1 Ngọc Hỗn Nguyên",
		"success": "Cấp 1: 60%  •  Cấp 2 – 4: 80%  •  Cấp 5 – 7: 70%",
		"fail": "Cấp 1: 40%  •  Cấp 2 – 4: 20%  •  Cấp 5 – 7: 30%",
		"penalty": "⚠️ Xịt: Mất toàn bộ nguyên liệu ép vé!",
		"cost": "DS1: 100k • DS2: 100k • DS3: 200k • DS4: 400k • DS5: 700k • DS6: 1.1M • DS7: 1.6M..2M Zen",
		"tip": "Dùng vào Quảng Trường Quỷ để luyện cấp và săn quái số lượng lớn."
	},
	{
		"cat": "ticket",
		"title": "Áo Choàng Tàng Hình (Blood Castle 1-8)",
		"badge": "Blood Castle",
		"req": "• 1 Cuộn Giấy Thiên Sứ (Archangel Scroll)\n• 1 Huyết Xương (Blood Bone) cùng cấp\n• 1 Ngọc Hỗn Nguyên",
		"success": "80% thành công (Tất cả cấp 1 đến 8)",
		"fail": "20% THẤT BẠI",
		"penalty": "⚠️ Xịt: Mất toàn bộ nguyên liệu!",
		"cost": "BC1: 50k • BC2: 80k • BC3: 150k • BC4: 250k • BC5: 400k • BC6: 600k • BC7: 850k • BC8: 1.05M Zen",
		"tip": "Dùng tham gia sự kiện Lâu Đài Máu phá cổng cứu Tổng Lãnh Thiên Sứ."
	},
	{
		"cat": "ticket",
		"title": "Vé Đền Ảo Ảnh (Illusion Temple 1-6)",
		"badge": "Illusion Temple",
		"req": "• 1 Cuộn Cổ (Old Scroll) + 1 Huyết Ấn (Scroll of Blood)\n• 1 Giao Ước Ảo Thuật (Illusion Covenant) cùng cấp\n• 1 Ngọc Hỗn Nguyên",
		"success": "70% thành công (Tất cả cấp 1 đến 6)",
		"fail": "30% THẤT BẠI",
		"penalty": "⚠️ Xịt: Mất toàn bộ vật phẩm ghép vé!",
		"cost": "IT1: 3M • IT2: 5M • IT3: 7M • IT4: 9M • IT5: 11M • IT6: 13M Zen",
		"tip": "Chiến trường PvP tranh đoạt Quả Cầu Thiêng tại Đền Ảo Ảnh."
	},

	# -------------------- BÌNH & KHÁC --------------------
	{
		"cat": "other",
		"title": "Trái Cây Tăng Điểm Chỉ Số (Fruits)",
		"badge": "Fruit Creation",
		"req": "• 1 Ngọc Hỗn Nguyên (Jewel of Chaos)\n• 1 Ngọc Sáng Tạo (Jewel of Creation)",
		"success": "90% thành công",
		"fail": "10% THẤT BẠI",
		"penalty": "⚠️ Xịt: Mất cả 2 viên ngọc!",
		"cost": "3,000,000 Zen",
		"tip": "Tạo ra ngẫu nhiên Trái Cây: Sức Mạnh, Nhanh Nhẹn, Thể Lực, Năng Lượng hoặc Mệnh Lệnh."
	},
	{
		"cat": "other",
		"title": "Bình Hồi Phục Khiên SD (SD Potions)",
		"badge": "SD Potions",
		"req": "• SD Nhỏ: 3 Bình Máu Lớn (Large Healing Potion) — Phí: 100k\n• SD Vừa: 3 Bình Tím Nhỏ (Small Complex Potion) — Phí: 500k\n• SD Lớn: 3 Bình Tím Vừa (Medium Complex Potion) — Phí: 1,000,000 Zen",
		"success": "SD Nhỏ: 50%  •  SD Vừa: 30%  •  SD Lớn: 30%",
		"fail": "SD Nhỏ: 50%  •  SD Vừa: 70%  •  SD Lớn: 70%",
		"penalty": "⚠️ Xịt: Mất toàn bộ bình thuốc đưa vào!",
		"cost": "100,000 – 1,000,000 Zen (không cần Chaos)",
		"tip": "Bình SD hồi phục điểm giáp phòng thủ (SD) cực kỳ quan trọng trong PvP / PK."
	},
	{
		"cat": "other",
		"title": "Bình Ước Nguyện / Tâm Linh (Siege Potions)",
		"badge": "Siege Potions",
		"req": "• Bình Ước Nguyện: Đặt các viên Ngọc Bless vào máy (1 Bless = 10 bình)\n• Bình Tâm Linh: Đặt các viên Ngọc Soul vào máy (1 Soul = 10 bình)",
		"success": "100% thành công (Không bao giờ xịt)",
		"fail": "0% Thất bại",
		"penalty": "Không có",
		"cost": "100,000 Zen / Bless • 50,000 Zen / Soul (không cần Chaos)",
		"tip": "Dùng trong Công Thành Chiến: Tăng tốc độ đánh và hồi phục đặc biệt."
	},
	{
		"cat": "other",
		"title": "Đá Sinh Mệnh (Life Stone)",
		"badge": "Castle Siege",
		"req": "• 1 Ngọc Hộ Mệnh (Jewel of Guardian)\n• 5 Ngọc Ước Nguyện (Bless) + 5 Ngọc Tâm Linh (Soul)\n• 1 Ngọc Hỗn Nguyên",
		"success": "100% thành công",
		"fail": "0% Thất bại",
		"penalty": "Không có",
		"cost": "5,000,000 Zen",
		"tip": "Đá Sinh Mệnh dùng làm điểm hồi sinh chiến lược cho bang hội trong Công Thành Chiến."
	},
]

func _ready() -> void:
	visible = false
	add_to_group("MuChaosRecipeDialog")
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(W, H) * S
	size = Vector2(W, H) * S

	# 1. Khung nền chính chuẩn phong cách MU
	MuUiSkinRes.build_frame(self, "Cẩm Nang Công Thức Ép Hỗn Nguyên", W, H, "newui_item_back01")

	# 2. Thanh kéo thả cửa sổ
	_setup_drag_header()

	# 3. Nút đóng X ở góc trên
	MuUiSkinRes.close_button(self, W, close, true)

	# 4. Thanh tìm kiếm nhanh
	_setup_search_bar()

	# 5. Thanh danh mục tabs
	_setup_category_bar()

	# 6. Danh sách cuộn chứa thẻ công thức
	_setup_recipe_scroll()

	_place()
	get_viewport().size_changed.connect(_place)

func _setup_drag_header() -> void:
	var drag_bar := Control.new()
	drag_bar.name = "DragHeader"
	drag_bar.position = Vector2.ZERO
	drag_bar.size = Vector2(W - 30.0, 38.0) * S
	drag_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_bar.gui_input.connect(_on_drag_header_input)
	add_child(drag_bar)
	move_child(drag_bar, 0)

func _on_drag_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			user_has_dragged = false
			_place()
			return
		_is_dragging = event.pressed
		_drag_start_pos = get_global_mouse_position()
		_drag_offset = get_global_mouse_position() - global_position
		if event.pressed:
			move_to_front()
	elif event is InputEventMouseMotion and _is_dragging:
		if not user_has_dragged:
			if (get_global_mouse_position() - _drag_start_pos).length() < DRAG_THRESHOLD:
				return
			user_has_dragged = true
		var vs := get_viewport_rect().size
		var np = get_global_mouse_position() - _drag_offset
		global_position = Vector2(clampf(np.x, 0.0, vs.x - size.x), clampf(np.y, 0.0, vs.y - size.y))

func _setup_search_bar() -> void:
	var search_box := HBoxContainer.new()
	search_box.position = Vector2(16, 42) * S
	search_box.size = Vector2(W - 32, 24) * S

	var lbl := Label.new()
	lbl.text = "🔍 Tìm kiếm:"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	search_box.add_child(lbl)

	_search_input = LineEdit.new()
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.placeholder_text = "Nhập tên đồ, cánh, sói, +15, vé..."
	_search_input.add_theme_font_size_override("font_size", 11)
	_search_input.text_changed.connect(_on_search_changed)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.95)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.5, 0.42, 0.28, 0.8)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	_search_input.add_theme_stylebox_override("normal", sb)
	_search_input.add_theme_stylebox_override("focus", sb)
	search_box.add_child(_search_input)

	add_child(search_box)

func _setup_category_bar() -> void:
	var cat_box := HFlowContainer.new()
	cat_box.position = Vector2(16, 72) * S
	cat_box.size = Vector2(W - 32, 48) * S
	cat_box.add_theme_constant_override("h_separation", 4)
	cat_box.add_theme_constant_override("v_separation", 4)

	for cat in CATEGORIES:
		var btn := Button.new()
		btn.text = cat["label"]
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(func(): _select_category(cat["id"]))
		cat_box.add_child(btn)
		_category_buttons[cat["id"]] = btn

	add_child(cat_box)
	_update_category_button_styles()

func _update_category_button_styles() -> void:
	for cat_id in _category_buttons:
		var btn: Button = _category_buttons[cat_id]
		var is_active: bool = (cat_id == _active_category)

		var sb := StyleBoxFlat.new()
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.corner_radius_top_left = 2
		sb.corner_radius_top_right = 2
		sb.corner_radius_bottom_left = 2
		sb.corner_radius_bottom_right = 2
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2

		if is_active:
			sb.bg_color = Color(0.35, 0.25, 0.1, 0.95)
			sb.border_color = Color(1.0, 0.85, 0.35)
			btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
		else:
			sb.bg_color = Color(0.12, 0.1, 0.08, 0.85)
			sb.border_color = Color(0.4, 0.33, 0.22, 0.8)
			btn.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))

		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)

func _select_category(cat_id: String) -> void:
	_active_category = cat_id
	_update_category_button_styles()
	_render_cards()

func _setup_recipe_scroll() -> void:
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(14, 126) * S
	_scroll.size = Vector2(W - 28, H - 138) * S
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	_card_container = VBoxContainer.new()
	_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_container.add_theme_constant_override("separation", 8)
	_scroll.add_child(_card_container)

	add_child(_scroll)
	_render_cards()

func _render_cards() -> void:
	for child in _card_container.get_children():
		child.queue_free()

	var query := _search_input.text.strip_edges().to_lower() if _search_input else ""

	var count := 0
	for data in RECIPES:
		if _active_category != "all" and data["cat"] != _active_category:
			continue

		if query != "":
			var matches := false
			for field in ["title", "badge", "req", "tip"]:
				if str(data.get(field, "")).to_lower().contains(query):
					matches = true
					break
			if not matches:
				continue

		var card := _create_recipe_card(data)
		_card_container.add_child(card)
		count += 1

	if count == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "Không tìm thấy công thức phù hợp!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.8, 0.45, 0.4))
		_card_container.add_child(empty_lbl)

func _create_recipe_card(data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.07, 0.95)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.48, 0.38, 0.22, 0.85)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 8
	sb.content_margin_top = 6
	sb.content_margin_right = 8
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	panel.add_child(vb)

	# --- Hàng 1: Tiêu đề + Huy hiệu
	var top_row := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "✨ " + data["title"]
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_lbl)

	var badge := Label.new()
	badge.text = "[ %s ]" % data["badge"]
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	top_row.add_child(badge)
	vb.add_child(top_row)

	# --- Vạch ngăn mỏng
	var sep := HSeparator.new()
	var sep_sb := StyleBoxLine.new()
	sep_sb.color = Color(0.35, 0.28, 0.18, 0.8)
	sep_sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_sb)
	vb.add_child(sep)

	# --- Hàng 2: Nguyên liệu
	var req_lbl := Label.new()
	req_lbl.text = "📦 Nguyên Liệu:\n" + data["req"]
	req_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	req_lbl.add_theme_font_size_override("font_size", 10)
	req_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.75))
	vb.add_child(req_lbl)

	# --- Hàng 3: Tỉ lệ thành công & thất bại
	var rate_row := HBoxContainer.new()

	var succ_lbl := Label.new()
	succ_lbl.text = "✅ Thành Công:\n" + data["success"]
	succ_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	succ_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	succ_lbl.add_theme_font_size_override("font_size", 10)
	succ_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	rate_row.add_child(succ_lbl)

	var fail_lbl := Label.new()
	fail_lbl.text = "❌ Thất Bại:\n" + data["fail"]
	fail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fail_lbl.add_theme_font_size_override("font_size", 10)
	fail_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	rate_row.add_child(fail_lbl)
	vb.add_child(rate_row)

	# --- Hàng 4: Chi phí & Hậu quả khi xịt
	var cost_pen := Label.new()
	cost_pen.text = "💰 Phí Trộn: %s\n%s" % [data["cost"], data["penalty"]]
	cost_pen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost_pen.add_theme_font_size_override("font_size", 10)
	cost_pen.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	vb.add_child(cost_pen)

	# --- Hàng 5: Mẹo nhỏ
	if data.has("tip") and str(data["tip"]) != "":
		var tip_lbl := Label.new()
		tip_lbl.text = "💡 Mẹo: " + data["tip"]
		tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_lbl.add_theme_font_size_override("font_size", 9)
		tip_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		vb.add_child(tip_lbl)

	return panel

func _on_search_changed(_new_text: String) -> void:
	_render_cards()

func _place() -> void:
	if user_has_dragged:
		return
	var vs := get_viewport_rect().size
	# Đặt chếch về bên trái cửa sổ máy Chaos hoặc giữa màn hình
	position = Vector2(floorf((vs.x - size.x) * 0.4), floorf((vs.y - size.y) * 0.5))

func open_dialog() -> void:
	_place()
	visible = true
	move_to_front()
	if _search_input:
		_search_input.text = ""
	_select_category("all")
	if MuAudioManager:
		MuAudioManager.play_ui_window()

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if visible and k and k.pressed and k.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
