-- ============================================================================
-- Otomatik Sehir Insaati (Auto Build) - Total War: ATTILA
--
-- Her tur basinda fraksiyonun tum yerlesimlerindeki binalari tarar, kasa ve
-- bolge ihtiyaclarina (kamu duzeni, yemek, sanitasyon) gore en mantikli
-- yukseltmeleri secer ve otomatik olarak insa eder.
--
-- Kurulum icin README.md dosyasina bakin.
-- ============================================================================

local AB = {}

AB.VERSION = "1.0.0"

-- ---------------------------------------------------------------------------
-- Yardimcilar
-- ---------------------------------------------------------------------------

local function load_optional(module_name, fallback)
	local ok, result = pcall(require, module_name)
	if ok and type(result) == "table" then
		return result
	end
	return fallback
end

AB.config = load_optional("auto_build_config", { enabled = true })
-- auto_build_data.lua: tools/generate_building_data.py ile uretilir.
-- Format: [bina_anahtari] = { next = "sonraki_anahtar", level = n, cost = altin }
AB.upgrades = load_optional("auto_build_data", {})

-- Bir nesne uzerinde metodu guvenli cagirir: safe(obj, "name") -> obj:name()
local function safe(obj, method, ...)
	if obj == nil then return nil end
	local ok, fn = pcall(function() return obj[method] end)
	if not ok or type(fn) ~= "function" then return nil end
	local ok2, result = pcall(fn, obj, ...)
	if ok2 then return result end
	return nil
end

-- Oyunun liste arayuzlerini (num_items/item_at) Lua tablosuna cevirir
local function list_to_table(list)
	local out = {}
	local count = safe(list, "num_items") or 0
	for i = 0, count - 1 do
		local item = safe(list, "item_at", i)
		if item ~= nil then
			out[#out + 1] = item
		end
	end
	return out
end

local function contains_any(text, patterns)
	if not text or not patterns then return false end
	text = string.lower(text)
	for _, p in ipairs(patterns) do
		if string.find(text, string.lower(p), 1, true) then
			return true
		end
	end
	return false
end

function AB.log(msg)
	local file_name = AB.config.log_file
	if not file_name or not io or not io.open then return end
	pcall(function()
		local f = io.open(file_name, "a")
		if f then
			f:write("[AutoBuild] " .. tostring(msg) .. "\n")
			f:close()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Oyun arayuzu
-- ---------------------------------------------------------------------------

local game_interface_override = nil

-- Testler icin sahte arayuz enjekte etmeyi saglar
function AB.set_game_interface(gi)
	game_interface_override = gi
end

function AB.game()
	if game_interface_override then return game_interface_override end
	local s = rawget(_G, "scripting")
	if s == nil then
		local ok, mod = pcall(require, "lua_scripts.EpisodicScripting")
		if ok then s = mod end
	end
	if s and s.game_interface then return s.game_interface end
	return nil
end

-- ---------------------------------------------------------------------------
-- Bina verisi
-- ---------------------------------------------------------------------------

-- Anahtarin sonundaki seviye numarasi: "att_bld_x_farm_3" -> 3
local function trailing_level(key)
	local n = string.match(key or "", "_(%d+)$")
	return n and tonumber(n) or nil
end

-- Bir binanin sonraki seviyesini ve bilgilerini dondurur (yoksa nil)
function AB.next_level_info(building_key)
	local entry = AB.upgrades[building_key]
	if entry and entry.next then
		local next_entry = AB.upgrades[entry.next]
		local level = (next_entry and next_entry.level) or ((entry.level or 0) + 1)
		local cost = (next_entry and next_entry.cost) or entry.next_cost
		return { key = entry.next, level = level, cost = cost }
	end
	if entry == nil and AB.config.guess_next_level then
		local lvl = trailing_level(building_key)
		if lvl then
			local next_key = string.gsub(building_key, "_%d+$", "_" .. (lvl + 1))
			return { key = next_key, level = lvl + 1 }
		end
	end
	return nil
end

function AB.estimate_cost(info)
	if info.cost then return info.cost end
	return (AB.config.default_cost_per_level or 600) * (info.level or 1)
end

function AB.category_of(building_key)
	for _, cat in ipairs(AB.config.categories or {}) do
		if contains_any(building_key, cat.patterns) then
			return cat
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Bolge ihtiyaclari
-- ---------------------------------------------------------------------------

function AB.region_needs(region, faction)
	local cfg = AB.config
	local needs = {}

	local po = safe(region, "public_order")
	if po ~= nil and po < (cfg.public_order_threshold or 0) then
		needs.public_order = true
	end

	local sanitation = safe(region, "sanitation")
	if sanitation ~= nil and sanitation < (cfg.sanitation_threshold or 1) then
		needs.sanitation = true
	end

	if safe(faction, "has_food_shortage") == true then
		needs.food = true
	end

	return needs
end

-- ---------------------------------------------------------------------------
-- Puanlama
-- ---------------------------------------------------------------------------

function AB.score(building_key, info, needs, budget)
	local cfg = AB.config
	local cat = AB.category_of(building_key)
	local score = cat and cat.weight or (cfg.default_weight or 15)

	if cat and cat.need and needs[cat.need] then
		score = score + (cfg.need_bonus or 60)
	end

	-- Ucuz/dusuk seviyeli binalar once
	local bonus = (cfg.low_level_bonus or 8) * math.max(0, 6 - (info.level or 1))
	score = score + bonus

	-- Butceye gore pahali binalar biraz geri plana duser
	local cost = AB.estimate_cost(info)
	if budget and budget > 0 then
		score = score - (cost / budget) * 20
	end

	return score
end

-- ---------------------------------------------------------------------------
-- Aday toplama
-- ---------------------------------------------------------------------------

function AB.collect_candidates(faction, budget)
	local cfg = AB.config
	local candidates = {}

	for _, region in ipairs(list_to_table(safe(faction, "region_list"))) do
		local region_key = safe(region, "name") or "?"
		local needs = AB.region_needs(region, faction)
		local settlement = safe(region, "settlement")
		local slots = list_to_table(safe(settlement, "slot_list"))

		for slot_index, slot in ipairs(slots) do
			if safe(slot, "has_building") then
				local building = safe(slot, "building")
				local key = safe(building, "name")
				if key and not contains_any(key, cfg.blacklist_patterns) then
					local info = AB.next_level_info(key)
					if info and (info.level or 1) <= (cfg.max_level or 99) then
						candidates[#candidates + 1] = {
							region = region,
							region_key = region_key,
							slot = slot,
							slot_index = slot_index,
							from = key,
							to = info.key,
							level = info.level,
							cost = AB.estimate_cost(info),
							score = AB.score(key, info, needs, budget),
						}
					end
				end
			end
		end
	end

	table.sort(candidates, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		if a.cost ~= b.cost then return a.cost < b.cost end
		-- Siralamanin her zaman ayni olmasi icin
		if a.region_key ~= b.region_key then return a.region_key < b.region_key end
		return a.slot_index < b.slot_index
	end)

	return candidates
end

-- ---------------------------------------------------------------------------
-- Insaat (oyun motoruna komut)
-- ---------------------------------------------------------------------------

-- Slotun motor icindeki anahtari
local function slot_key(slot)
	return safe(slot, "name") or safe(slot, "key") or safe(slot, "slot_key")
end

-- Slottaki binayi yeniden okuyarak yukseltmenin gercekten olup olmadigini dogrular
local function current_building_in_slot(region, slot_index, slot)
	local settlement = safe(region, "settlement")
	local fresh = list_to_table(safe(settlement, "slot_list"))[slot_index] or slot
	return safe(safe(fresh, "building"), "name")
end

-- Farkli Total War surumlerinde ayni isi yapan komutlar farkli isimlere sahip.
-- Hepsini sirayla dener; ise yarayani hatirlar.
AB.upgrade_methods = {
	{ name = "region_slot_instantly_upgrade_building", call = function(gi, c)
		return gi:region_slot_instantly_upgrade_building(c.slot, c.to)
	end },
	{ name = "instantly_upgrade_building_in_region", call = function(gi, c)
		return gi:instantly_upgrade_building_in_region(slot_key(c.slot), c.to)
	end },
	{ name = "instantly_upgrade_building", call = function(gi, c)
		return gi:instantly_upgrade_building(slot_key(c.slot), c.to)
	end },
	{ name = "instant_upgrade_building", call = function(gi, c)
		return gi:instant_upgrade_building(slot_key(c.slot), c.to)
	end },
}

AB.working_method = nil

function AB.upgrade(candidate)
	local gi = AB.game()
	if gi == nil then return false end

	local methods = AB.upgrade_methods
	if AB.working_method then
		methods = { AB.working_method }
	end

	for _, m in ipairs(methods) do
		local has_fn = pcall(function() assert(type(gi[m.name]) == "function") end)
		if has_fn then
			local ok, err = pcall(m.call, gi, candidate)
			if ok then
				local now = current_building_in_slot(candidate.region, candidate.slot_index, candidate.slot)
				if now == candidate.to then
					if AB.working_method == nil then
						AB.working_method = m
						AB.log("Calisan insaat komutu: " .. m.name)
					end
					return true
				end
				AB.log(m.name .. " hata vermedi ama bina degismedi (" .. tostring(now) .. ")")
			else
				AB.log(m.name .. " basarisiz: " .. tostring(err))
			end
		end
	end
	return false
end

function AB.charge(faction, amount)
	if not AB.config.charge_cost or amount <= 0 then return end
	local gi = AB.game()
	local faction_key = safe(faction, "name")
	if gi and faction_key then
		local ok, err = pcall(function() gi:treasury_mod(faction_key, -amount) end)
		if not ok then AB.log("treasury_mod basarisiz: " .. tostring(err)) end
	end
end

-- ---------------------------------------------------------------------------
-- Ana dongu
-- ---------------------------------------------------------------------------

function AB.run_for_faction(faction)
	local cfg = AB.config
	if not cfg.enabled or faction == nil then return {} end
	if cfg.human_only and not safe(faction, "is_human") then return {} end

	local treasury = safe(faction, "treasury") or 0
	local spendable = treasury - (cfg.treasury_reserve or 0)
	local budget = spendable * (cfg.max_spend_ratio or 1)
	if not cfg.charge_cost then
		budget = math.huge
	end
	if budget <= 0 then
		AB.log(tostring(safe(faction, "name")) .. ": butce yok (kasa " .. treasury .. ")")
		return {}
	end

	local built = {}
	local per_region = {}
	local spent = 0
	local max_total = cfg.max_builds_per_turn or 1
	local max_region = cfg.max_builds_per_region or 1

	for _, c in ipairs(AB.collect_candidates(faction, budget < math.huge and budget or nil)) do
		if #built >= max_total then break end
		local region_count = per_region[c.region_key] or 0
		local affordable = (not cfg.charge_cost) or (spent + c.cost <= budget)
		if region_count < max_region and affordable then
			if AB.upgrade(c) then
				if cfg.charge_cost then
					AB.charge(faction, c.cost)
					spent = spent + c.cost
				end
				per_region[c.region_key] = region_count + 1
				built[#built + 1] = c
				AB.log(string.format("%s: %s -> %s (%d altin, puan %.1f)",
					c.region_key, c.from, c.to, c.cost, c.score))
			end
		end
	end

	return built
end

-- ---------------------------------------------------------------------------
-- Olay kaydi
-- ---------------------------------------------------------------------------

local function on_faction_turn_start(context)
	local ok, err = pcall(function()
		AB.run_for_faction(safe(context, "faction"))
	end)
	if not ok then AB.log("Hata: " .. tostring(err)) end
end

function AB.init()
	local ev = rawget(_G, "events")
	if ev == nil and type(rawget(_G, "get_events")) == "function" then
		ev = get_events()
	end

	if type(ev) == "table" then
		ev.FactionTurnStart = ev.FactionTurnStart or {}
		table.insert(ev.FactionTurnStart, on_faction_turn_start)
		AB.log("v" .. AB.VERSION .. " yuklendi (events tablosu)")
		return true
	end

	local s = rawget(_G, "scripting")
	if s and type(s.AddEventCallBack) == "function" then
		s.AddEventCallBack("FactionTurnStart", on_faction_turn_start)
		AB.log("v" .. AB.VERSION .. " yuklendi (AddEventCallBack)")
		return true
	end

	AB.log("UYARI: Olay sistemi bulunamadi, mod calismayacak")
	return false
end

AB.on_faction_turn_start = on_faction_turn_start

return AB
