-- ============================================================================
-- Otomatik Sehir Insaati (Auto Build) - AYARLAR
-- Bu dosyayi istediginiz gibi duzenleyebilirsiniz.
-- ============================================================================

return {
	-- Mod tamamen acik/kapali
	enabled = true,

	-- Sadece oyuncunun fraksiyonu mu? (false yapilirsa yapay zeka da kullanir)
	human_only = true,

	-- Kasada her zaman kalacak minimum altin. Bunun altina inilmez.
	treasury_reserve = 3000,

	-- Bir turda harcanabilecek en fazla kasa orani (0.0 - 1.0).
	-- 0.5 = (kasa - rezerv) miktarinin en fazla yarisi harcanir.
	max_spend_ratio = 0.6,

	-- Bir turda en fazla kac bina yukseltilecek (tum imparatorluk icin)
	max_builds_per_turn = 2,

	-- Bir bolgede (region) turda en fazla kac bina yukseltilecek
	max_builds_per_region = 1,

	-- Bina bu seviyeye ulastiysa daha fazla yukseltilmez (1 = ilk seviye)
	max_level = 5,

	-- Insaat bedeli kasadan dusulsun mu? (false = bedava insaat / hile modu)
	charge_cost = true,

	-- Veri dosyasinda maliyeti bulunmayan binalar icin tahmini maliyet:
	-- tahmini_maliyet = default_cost_per_level * hedef_seviye
	default_cost_per_level = 600,

	-- Veri dosyasinda bulunmayan binalar icin anahtarin sonundaki sayiyi
	-- bir arttirarak (ornek: ..._2 -> ..._3) sonraki seviyeyi tahmin et.
	-- Riskli: yanlis anahtar uretebilir. Sadece test icin acin.
	guess_next_level = false,

	-- Bu kelimeleri iceren binalara asla dokunulmaz
	blacklist_patterns = { "ruin", "_wonder", "unique" },

	-- Kamu duzeni bu degerin altindaysa tapinak/din binalari onceliklenir
	public_order_threshold = 0,

	-- Sanitasyon bu degerin altindaysa su/kanalizasyon binalari onceliklenir
	sanitation_threshold = 1,

	-- Kategoriler: bina anahtarinda (key) gecen kelimelere gore siniflandirma.
	-- weight = temel oncelik, need = hangi ihtiyac durumunda ekstra puan alir
	categories = {
		{ name = "ana_bina",   weight = 50, patterns = { "city", "town", "capital", "settlement", "_major", "_minor" } },
		{ name = "kamu_duzeni", weight = 25, need = "public_order", patterns = { "temple", "church", "relig", "shrine", "monast", "cathedral", "pagan", "christ", "zoroast", "worship" } },
		{ name = "yemek",      weight = 30, need = "food", patterns = { "farm", "agri", "granary", "fish", "pasture", "cattle", "herd", "grain", "orchard" } },
		{ name = "sanitasyon", weight = 20, need = "sanitation", patterns = { "sewer", "aqueduct", "bath", "water", "well", "cistern", "latrine" } },
		{ name = "ekonomi",    weight = 35, patterns = { "market", "trade", "port", "workshop", "industr", "mine", "wood", "wine", "salt", "silk", "spice", "craft", "merchant" } },
		{ name = "askeri",     weight = 10, patterns = { "barrack", "military", "garrison", "stable", "range", "archer", "smith", "armour", "armor", "siege", "wall", "fort" } },
	},

	-- Hicbir kategoriye uymayan binalarin temel onceligi
	default_weight = 15,

	-- Ihtiyac durumunda eklenen puan
	need_bonus = 60,

	-- Dusuk seviyeli binalara verilen ek puan (seviye basina azalir)
	low_level_bonus = 8,

	-- Log dosyasi (oyunun ana klasorune yazilir). nil yapilirsa log tutulmaz.
	log_file = "auto_build_log.txt",
}
