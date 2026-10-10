-- ORNEK VERI DOSYASI
-- Bu dosyayi tools/generate_building_data.py ile oyunun gercek
-- building_levels tablosundan uretilen dosyayla DEGISTIRIN.
-- Asagidaki anahtarlar sadece formati gostermek icindir.
--
-- [bina] = { next = sonraki seviye, level = seviye, cost = altin, chain = zincir }
return {
	["ornek_bld_farm_1"] = { next = "ornek_bld_farm_2", level = 1, cost = 500, chain = "ornek_farm" },
	["ornek_bld_farm_2"] = { next = "ornek_bld_farm_3", level = 2, cost = 1000, chain = "ornek_farm" },
	["ornek_bld_farm_3"] = { level = 3, cost = 2000, chain = "ornek_farm" },
}
