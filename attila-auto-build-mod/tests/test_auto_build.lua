-- Sahte (mock) oyun arayuzu ile auto_build testleri. Lua 5.1 uyumlu.

local failures, passed = 0, 0

local function check(cond, msg)
	if cond then
		passed = passed + 1
	else
		failures = failures + 1
		print("BASARISIZ: " .. msg)
	end
end

-- --- Sahte oyun nesneleri ---------------------------------------------------

local function List(items)
	return {
		num_items = function(self) return #items end,
		item_at = function(self, i) return items[i + 1] end,
	}
end

local function Slot(key, building_key)
	local slot = { _key = key, _building = building_key }
	function slot:name() return self._key end
	function slot:has_building() return self._building ~= nil end
	function slot:building()
		local b = self._building
		return { name = function() return b end }
	end
	return slot
end

local function Region(name, public_order, slots)
	local r = {}
	function r:name() return name end
	function r:public_order() return public_order end
	function r:settlement() return { slot_list = function() return List(slots) end } end
	return r
end

local function Faction(name, human, treasury, regions)
	local f = { _treasury = treasury }
	function f:name() return name end
	function f:is_human() return human end
	function f:treasury() return self._treasury end
	function f:region_list() return List(regions) end
	function f:has_food_shortage() return false end
	return f
end

-- Sadece instantly_upgrade_building_in_region destekleyen sahte motor
local function Game(all_slots, factions)
	local gi = { calls = {} }
	function gi:instantly_upgrade_building_in_region(slot_key, building_key)
		for _, s in ipairs(all_slots) do
			if s._key == slot_key then s._building = building_key end
		end
		self.calls[#self.calls + 1] = slot_key .. "=" .. building_key
	end
	function gi:treasury_mod(faction_key, amount)
		local f = factions[faction_key]
		f._treasury = f._treasury + amount
	end
	return gi
end

-- --- Kurulum ----------------------------------------------------------------

package.loaded["auto_build_config"] = nil
local AB = require("auto_build")

AB.config.log_file = nil
AB.upgrades = {
	bld_city_1   = { next = "bld_city_2", level = 1, cost = 1000 },
	bld_city_2   = { next = "bld_city_3", level = 2, cost = 2500 },
	bld_city_3   = { level = 3, cost = 5000 },
	bld_temple_1 = { next = "bld_temple_2", level = 1, cost = 600 },
	bld_temple_2 = { level = 2, cost = 1500 },
	bld_farm_1   = { next = "bld_farm_2", level = 1, cost = 500 },
	bld_farm_2   = { level = 2, cost = 1200 },
	bld_ruin_1   = { next = "bld_ruin_2", level = 1, cost = 10 },
	bld_ruin_2   = { level = 2, cost = 20 },
}

-- --- Test 1: ihtiyac + butce + bolge siniri -----------------------------------

local s_city  = Slot("r1:0", "bld_city_1")
local s_temp  = Slot("r1:1", "bld_temple_1")
local s_farm  = Slot("r2:0", "bld_farm_1")
local s_ruin  = Slot("r2:1", "bld_ruin_1")
local s_empty = Slot("r2:2", nil)
local all = { s_city, s_temp, s_farm, s_ruin, s_empty }

local r1 = Region("region_unrest", -50, { s_city, s_temp })
local r2 = Region("region_calm", 40, { s_farm, s_ruin, s_empty })
local player = Faction("fac_player", true, 6000, { r1, r2 })
local gi = Game(all, { fac_player = player })
AB.set_game_interface(gi)

AB.config.treasury_reserve = 3000
AB.config.max_spend_ratio = 1.0
AB.config.max_builds_per_turn = 5
AB.config.max_builds_per_region = 1
AB.config.charge_cost = true

local built = AB.run_for_faction(player)

check(#built == 2, "iki bina insa edilmeli (her bolgeden bir), olan: " .. #built)
check(s_temp._building == "bld_temple_2", "isyanli bolgede tapinak onceliklenmeli, olan: " .. tostring(s_temp._building))
check(s_city._building == "bld_city_1", "ayni bolgede ikinci insaat yapilmamali")
check(s_farm._building == "bld_farm_2", "sakin bolgede ciftlik yukseltilmeli")
check(s_ruin._building == "bld_ruin_1", "kara listedeki bina yukseltilmemeli")
check(s_empty._building == nil, "bos slota dokunulmamali")
check(player._treasury == 6000 - 1500 - 1200, "hedef seviyenin maliyeti kasadan dusulmeli, kasa: " .. player._treasury)
check(AB.working_method and AB.working_method.name == "instantly_upgrade_building_in_region",
	"calisan komut hatirlanmali")

-- --- Test 2: rezerv altina inilmez ----------------------------------------

local poor = Faction("fac_poor", true, 3200, { Region("r_poor", 0, { Slot("p:0", "bld_city_1") }) })
AB.set_game_interface(Game({}, { fac_poor = poor }))
built = AB.run_for_faction(poor)
check(#built == 0, "butce (200) yetmezse insaat yapilmamali")
check(poor._treasury == 3200, "kasa degismemeli")

-- --- Test 3: yapay zeka (human_only) ---------------------------------------

local ai_slot = Slot("ai:0", "bld_farm_1")
local ai = Faction("fac_ai", false, 99999, { Region("r_ai", 0, { ai_slot }) })
AB.set_game_interface(Game({ ai_slot }, { fac_ai = ai }))
built = AB.run_for_faction(ai)
check(#built == 0 and ai_slot._building == "bld_farm_1", "human_only iken AI'ya dokunulmamali")

AB.config.human_only = false
built = AB.run_for_faction(ai)
check(#built == 1 and ai_slot._building == "bld_farm_2", "human_only=false iken AI da insa etmeli")
AB.config.human_only = true

-- --- Test 4: komut sessizce basarisiz olursa para alinmaz -----------------

AB.working_method = nil
local broken_slot = Slot("b:0", "bld_farm_1")
local broken = Faction("fac_b", true, 9000, { Region("r_b", 0, { broken_slot }) })
local broken_gi = Game({}, { fac_b = broken })
function broken_gi:instantly_upgrade_building_in_region() end -- hicbir sey yapmaz
AB.set_game_interface(broken_gi)
built = AB.run_for_faction(broken)
check(#built == 0, "dogrulanamayan insaat sayilmamali")
check(broken._treasury == 9000, "dogrulanamayan insaat icin para alinmamali")

-- --- Test 5: max_level ve olay kaydi ---------------------------------------

AB.working_method = nil
AB.config.max_level = 2
local lvl_slot = Slot("l:0", "bld_city_2")
local lvl = Faction("fac_l", true, 99999, { Region("r_l", 0, { lvl_slot }) })
AB.set_game_interface(Game({ lvl_slot }, { fac_l = lvl }))
built = AB.run_for_faction(lvl)
check(#built == 0, "max_level asilmamali")
AB.config.max_level = 5

_G.events = {}
check(AB.init() == true, "init events tablosuna kaydolmali")
check(#events.FactionTurnStart == 1, "FactionTurnStart dinleyicisi eklenmeli")
events.FactionTurnStart[1]({ faction = function() return lvl end })
check(lvl_slot._building == "bld_city_3", "olay tetiklenince insaat yapilmali")

-- Hatali context oyunu cokertmemeli
events.FactionTurnStart[1]({})
check(true, "hatali context hata firlatmamali")

print(string.format("%d test gecti, %d basarisiz", passed, failures))
return failures
