-- StarterPlayerScripts | LocalScript
-- Character Effect Optimizer
-- Credits: Forkt Community

local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

--==================================================
-- KONFIGURASI
--==================================================

local CONFIG = {
	Enabled = true,

	-- Pemain berjarak <= ini menggunakan efek penuh.
	FullDistance = 100,

	-- Pemain berjarak >= ini menggunakan efek ringan.
	ReducedDistance = 140,

	-- Jeda pemeriksaan jarak. Jangan terlalu kecil.
	UpdateInterval = 0.5,

	-- Kekuatan partikel pemain jauh.
	ParticleRateMultiplier = 0.2,

	-- Efek yang dimatikan ketika pemain jauh.
	DisableTrails = true,
	DisableBeams = true,
	DisableHighlights = true,

	-- Optimisasi aksesori tertentu.
	OptimizeAccessories = true,
	OptimizeAllAccessories = false,

	-- Transparansi tambahan aksesori saat jauh.
	-- 0 = terlihat, 1 = tidak terlihat.
	ReducedAccessoryTransparency = 0.85,

	-- Accessory dengan atribut OptimizeCosmetic = true
	-- juga akan otomatis dioptimalkan.
	AccessoryKeywords = {
		"Aura",
		"Wing",
		"Wings",
		"Cape",
		"Back",
		"Effect",
		"Trail",
		"Glow",
		"Pet",
	},

	DebugMode = true,
}

--==================================================
-- INTERNAL
--==================================================

local PREFIX = "[FORKT OPTIMIZER]"

local trackers = {}
local running = true

-- Weak table agar cache otomatis dibersihkan ketika instance hilang.
local originalProperties = setmetatable({}, {
	__mode = "k",
})

local function log(message, ...)
	if CONFIG.DebugMode then
		print(string.format(
			"%s %s",
			PREFIX,
			string.format(message, ...)
		))
	end
end

local function getRootPart(character)
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function findAccessory(instance)
	local current = instance

	while current do
		if current:IsA("Accessory") then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function isOptimizedAccessory(accessory)
	if not CONFIG.OptimizeAccessories or not accessory then
		return false
	end

	if CONFIG.OptimizeAllAccessories then
		return true
	end

	if accessory:GetAttribute("OptimizeCosmetic") == true then
		return true
	end

	local accessoryName = string.lower(accessory.Name)

	for _, keyword in ipairs(CONFIG.AccessoryKeywords) do
		if string.find(
			accessoryName,
			string.lower(keyword),
			1,
			true
		) then
			return true
		end
	end

	return false
end

--==================================================
-- PROPERTY CACHE
--==================================================

local function getOriginalProperties(instance)
	local cached = originalProperties[instance]

	if cached then
		return cached
	end

	if instance:IsA("ParticleEmitter") then
		cached = {
			Enabled = instance.Enabled,
			Rate = instance.Rate,
		}
	elseif instance:IsA("Trail") then
		cached = {
			Enabled = instance.Enabled,
		}
	elseif instance:IsA("Beam") then
		cached = {
			Enabled = instance.Enabled,
		}
	elseif instance:IsA("Highlight") then
		cached = {
			Enabled = instance.Enabled,
		}
	elseif instance:IsA("BasePart") then
		cached = {
			LocalTransparencyModifier =
				instance.LocalTransparencyModifier,
		}
	else
		return nil
	end

	originalProperties[instance] = cached
	return cached
end

--==================================================
-- EFFECT OPTIMIZATION
--==================================================

local function applyFullMode(instance)
	local original = originalProperties[instance]

	if not original then
		return
	end

	if instance:IsA("ParticleEmitter") then
		instance.Enabled = original.Enabled
		instance.Rate = original.Rate

	elseif instance:IsA("Trail")
		or instance:IsA("Beam")
		or instance:IsA("Highlight")
	then
		instance.Enabled = original.Enabled

	elseif instance:IsA("BasePart") then
		instance.LocalTransparencyModifier =
			original.LocalTransparencyModifier
	end
end

local function applyReducedMode(instance)
	local original = getOriginalProperties(instance)

	if not original then
		return
	end

	if instance:IsA("ParticleEmitter") then
		instance.Enabled = original.Enabled
		instance.Rate =
			original.Rate * CONFIG.ParticleRateMultiplier

	elseif instance:IsA("Trail") then
		if CONFIG.DisableTrails then
			instance.Enabled = false
		end

	elseif instance:IsA("Beam") then
		if CONFIG.DisableBeams then
			instance.Enabled = false
		end

	elseif instance:IsA("Highlight") then
		if CONFIG.DisableHighlights then
			instance.Enabled = false
		end

	elseif instance:IsA("BasePart") then
		local accessory = findAccessory(instance)

		if isOptimizedAccessory(accessory) then
			local originalTransparency =
				original.LocalTransparencyModifier

			-- Menggabungkan transparansi asli dengan transparansi tambahan.
			instance.LocalTransparencyModifier =
				1 - (
					(1 - originalTransparency)
					* (1 - CONFIG.ReducedAccessoryTransparency)
				)
		end
	end
end

local function applyToInstance(instance, mode)
	if instance:IsA("ParticleEmitter")
		or instance:IsA("Trail")
		or instance:IsA("Beam")
		or instance:IsA("Highlight")
	then
		getOriginalProperties(instance)

		if mode == "FULL" then
			applyFullMode(instance)
		else
			applyReducedMode(instance)
		end

	elseif instance:IsA("BasePart") then
		local accessory = findAccessory(instance)

		if isOptimizedAccessory(accessory) then
			getOriginalProperties(instance)

			if mode == "FULL" then
				applyFullMode(instance)
			else
				applyReducedMode(instance)
			end
		end
	end
end

local function applyMode(tracker, mode)
	if tracker.Mode == mode then
		return
	end

	local character = tracker.Character

	if not character or not character.Parent then
		return
	end

	tracker.Mode = mode

	for _, instance in ipairs(character:GetDescendants()) do
		applyToInstance(instance, mode)
	end

	log(
		"%s berubah ke mode %s",
		tracker.Player.Name,
		mode
	)
end

--==================================================
-- CHARACTER TRACKING
--==================================================

local function disconnectCharacter(tracker)
	if tracker.DescendantConnection then
		tracker.DescendantConnection:Disconnect()
		tracker.DescendantConnection = nil
	end

	tracker.Character = nil
	tracker.Mode = nil
end

local function setupCharacter(tracker, character)
	disconnectCharacter(tracker)

	tracker.Character = character
	tracker.Mode = nil

	tracker.DescendantConnection =
		character.DescendantAdded:Connect(function(instance)
			if not CONFIG.Enabled then
				return
			end

			-- Terapkan mode saat ini pada efek baru.
			if tracker.Mode then
				applyToInstance(instance, tracker.Mode)
			end

			-- Pastikan isi aksesori baru ikut diproses.
			if instance:IsA("Accessory") and tracker.Mode then
				for _, descendant in ipairs(
					instance:GetDescendants()
				) do
					applyToInstance(descendant, tracker.Mode)
				end
			end
		end)
end

local function addPlayer(player)
	if player == localPlayer or trackers[player] then
		return
	end

	local tracker = {
		Player = player,
		Character = nil,
		Mode = nil,
		Connections = {},
	}

	trackers[player] = tracker

	table.insert(
		tracker.Connections,
		player.CharacterAdded:Connect(function(character)
			setupCharacter(tracker, character)
		end)
	)

	table.insert(
		tracker.Connections,
		player.CharacterRemoving:Connect(function(character)
			if tracker.Character == character then
				disconnectCharacter(tracker)
			end
		end)
	)

	if player.Character then
		setupCharacter(tracker, player.Character)
	end
end

local function removePlayer(player)
	local tracker = trackers[player]

	if not tracker then
		return
	end

	-- Pulihkan efek sebelum tracker dibersihkan.
	if tracker.Character then
		applyMode(tracker, "FULL")
	end

	disconnectCharacter(tracker)

	for _, connection in ipairs(tracker.Connections) do
		connection:Disconnect()
	end

	table.clear(tracker.Connections)
	trackers[player] = nil
end

--==================================================
-- DISTANCE WORKER
--==================================================

local function updatePlayers()
	local localCharacter = localPlayer.Character
	local localRoot = getRootPart(localCharacter)

	if not localRoot then
		return
	end

	for player, tracker in pairs(trackers) do
		local character = tracker.Character
		local rootPart = getRootPart(character)

		if not rootPart then
			continue
		end

		local distance =
			(localRoot.Position - rootPart.Position).Magnitude

		-- Hysteresis mencegah mode berubah-ubah cepat
		-- ketika pemain berada di batas jarak.
		if tracker.Mode == "FULL" then
			if distance >= CONFIG.ReducedDistance then
				applyMode(tracker, "REDUCED")
			end

		elseif tracker.Mode == "REDUCED" then
			if distance <= CONFIG.FullDistance then
				applyMode(tracker, "FULL")
			end

		else
			if distance >= CONFIG.ReducedDistance then
				applyMode(tracker, "REDUCED")
			else
				applyMode(tracker, "FULL")
			end
		end
	end
end

--==================================================
-- BOOTSTRAP
--==================================================

for _, player in ipairs(Players:GetPlayers()) do
	addPlayer(player)
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)

task.spawn(function()
	while running do
		if CONFIG.Enabled then
			updatePlayers()
		end

		task.wait(CONFIG.UpdateInterval)
	end
end)

script.Destroying:Connect(function()
	running = false

	for player in pairs(trackers) do
		removePlayer(player)
	end
end)

log("Character Effect Optimizer aktif")
log("Credits: Forkt Community")