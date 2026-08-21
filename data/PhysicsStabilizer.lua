-- ServerScriptService | Script "PhysicsStabilizer"
-- Safe Character Physics Stabilizer
-- Credits: Forkt Community

local Players = game:GetService("Players")

local CONFIG = {
	Enabled = true,
 DisablePhysicsStabilizer = true,
	-- Waktu pemeriksaan intensif setelah respawn.
	SpawnMonitorDuration = 8,
	CheckInterval = 0.15,
	InitialDelay = 0.1,

	-- Batas fisika tidak normal.
	MaxLinearVelocity = 180,
	MaxAngularVelocity = 80,

	-- RootPart dapat dilepas dari Anchored jika jelas abnormal.
	FixAbnormalRootAnchored = true,
	RootAnchoredGraceTime = 1.5,

	-- Tidak direkomendasikan untuk diaktifkan secara universal.
	-- Jika aktif, properti yang berubah saat periode spawn akan
	-- dikembalikan ke konfigurasi awal.
	RestorePartProperties = false,

	DebugMode = true,
}

local PREFIX = "[FORKT PHYSICS]"
local trackers = {}

local EXCLUDED_STATES = {
	[Enum.HumanoidStateType.Dead] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Climbing] = true,
}

local function log(message, ...)
	if CONFIG.DebugMode then
		print(string.format(
			"%s %s",
			PREFIX,
			string.format(message, ...)
		))
	end
end

local function isFiniteNumber(value)
	return value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function isValidVector(vector)
	return isFiniteNumber(vector.X)
		and isFiniteNumber(vector.Y)
		and isFiniteNumber(vector.Z)
end

local function getVelocityMagnitude(vector)
	if not isValidVector(vector) then
		return math.huge
	end

	return vector.Magnitude
end

local function characterAllowsStabilization(character, humanoid, rootPart)
	if not character.Parent
		or not humanoid.Parent
		or not rootPart.Parent
		or humanoid.Health <= 0
	then
		return false
	end

	if character:GetAttribute("DisablePhysicsStabilizer") == true then
		return false
	end

	if humanoid.PlatformStand then
		return false
	end

	if EXCLUDED_STATES[humanoid:GetState()] then
		return false
	end

	-- Kompatibilitas dengan beberapa sistem fly/admin.
	if character:FindFirstChild("ADONIS_FLYING") then
		return false
	end

	if character:GetAttribute("Flying") == true then
		return false
	end

	return true
end

--==================================================
-- SNAPSHOT KONFIGURASI AWAL
--==================================================

local function savePartConfiguration(tracker, part)
	if tracker.PartSnapshots[part] then
		return
	end

	tracker.PartSnapshots[part] = {
		Anchored = part.Anchored,
		CanCollide = part.CanCollide,
		Massless = part.Massless,
	}
end

local function scanCharacterParts(tracker)
	local character = tracker.Character

	if not character then
		return
	end

	for _, instance in ipairs(character:GetDescendants()) do
		if instance:IsA("BasePart") then
			savePartConfiguration(tracker, instance)
		end
	end
end

--==================================================
-- SAFE PHYSICS REPAIR
--==================================================

local function resetAssemblyVelocity(tracker, reason)
	local rootPart = tracker.RootPart

	if not rootPart or not rootPart.Parent then
		return
	end

	local currentTime = os.clock()

	-- Mencegah reset berulang pada frame yang sama.
	if currentTime - tracker.LastVelocityReset < 0.25 then
		return
	end

	tracker.LastVelocityReset = currentTime

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	log(
		"Velocity %s direset (%s).",
		tracker.Player.Name,
		reason
	)
end

local function checkAssemblyVelocity(tracker)
	local rootPart = tracker.RootPart

	if not rootPart or not rootPart.Parent then
		return
	end

	local linearVelocity = rootPart.AssemblyLinearVelocity
	local angularVelocity = rootPart.AssemblyAngularVelocity

	local linearMagnitude = getVelocityMagnitude(linearVelocity)
	local angularMagnitude = getVelocityMagnitude(angularVelocity)

	if linearMagnitude > CONFIG.MaxLinearVelocity then
		resetAssemblyVelocity(
			tracker,
			string.format(
				"linear abnormal: %.1f",
				linearMagnitude
			)
		)

		return
	end

	if angularMagnitude > CONFIG.MaxAngularVelocity then
		resetAssemblyVelocity(
			tracker,
			string.format(
				"angular abnormal: %.1f",
				angularMagnitude
			)
		)
	end
end

local function checkRootPart(tracker)
	local rootPart = tracker.RootPart
	local humanoid = tracker.Humanoid

	if not rootPart or not humanoid then
		return
	end

	local rootSnapshot = tracker.PartSnapshots[rootPart]

	if not rootSnapshot then
		savePartConfiguration(tracker, rootPart)
		rootSnapshot = tracker.PartSnapshots[rootPart]
	end

	-- Hanya perbaiki jika root awalnya memang tidak Anchored.
	if CONFIG.FixAbnormalRootAnchored
		and rootPart.Anchored
		and not rootSnapshot.Anchored
		and os.clock() - tracker.SpawnTime
			>= CONFIG.RootAnchoredGraceTime
	then
		rootPart.Anchored = false
		resetAssemblyVelocity(tracker, "RootPart Anchored abnormal")

		log(
			"RootPart %s berhasil dilepas dari Anchored.",
			tracker.Player.Name
		)
	end
end

local function checkPartProperties(tracker)
	for part, snapshot in pairs(tracker.PartSnapshots) do
		if not part.Parent then
			tracker.PartSnapshots[part] = nil
			continue
		end

		-- Selalu diperiksa, tetapi tidak diubah secara membabi buta.
		local anchoredChanged = part.Anchored ~= snapshot.Anchored
		local collisionChanged = part.CanCollide ~= snapshot.CanCollide
		local masslessChanged = part.Massless ~= snapshot.Massless

		if CONFIG.RestorePartProperties
			and part ~= tracker.RootPart
		then
			if anchoredChanged then
				part.Anchored = snapshot.Anchored
			end

			if collisionChanged then
				part.CanCollide = snapshot.CanCollide
			end

			if masslessChanged then
				part.Massless = snapshot.Massless
			end
		end
	end
end

local function stabilizeCharacter(tracker)
	local character = tracker.Character
	local humanoid = tracker.Humanoid
	local rootPart = tracker.RootPart

	if not characterAllowsStabilization(
		character,
		humanoid,
		rootPart
	) then
		return
	end

	checkRootPart(tracker)
	checkAssemblyVelocity(tracker)
	checkPartProperties(tracker)
end

--==================================================
-- CHARACTER MANAGEMENT
--==================================================

local function disconnectTracker(player)
	local tracker = trackers[player]

	if not tracker then
		return
	end

	tracker.Active = false

	for _, connection in ipairs(tracker.Connections) do
		connection:Disconnect()
	end

	table.clear(tracker.Connections)
	table.clear(tracker.PartSnapshots)

	trackers[player] = nil
end

local function setupCharacter(player, character)
	disconnectTracker(player)

	local humanoid = character:WaitForChild("Humanoid", 10)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)

	if not humanoid or not rootPart or not character.Parent then
		warn(PREFIX, "Komponen karakter tidak lengkap:", player.Name)
		return
	end

	local tracker = {
		Player = player,
		Character = character,
		Humanoid = humanoid,
		RootPart = rootPart,

		SpawnTime = os.clock(),
		LastVelocityReset = 0,
		PartSnapshots = {},
		Connections = {},
		Active = true,
	}

	trackers[player] = tracker
	scanCharacterParts(tracker)

	table.insert(
		tracker.Connections,
		character.DescendantAdded:Connect(function(instance)
			if instance:IsA("BasePart") then
				-- Simpan konfigurasi asli part baru tanpa mengubahnya.
				savePartConfiguration(tracker, instance)
			end
		end)
	)

	table.insert(
		tracker.Connections,
		humanoid.Died:Connect(function()
			tracker.Active = false
		end)
	)

	task.spawn(function()
		task.wait(CONFIG.InitialDelay)

		while tracker.Active
			and character.Parent
			and os.clock() - tracker.SpawnTime
				<= CONFIG.SpawnMonitorDuration
		do
			stabilizeCharacter(tracker)
			task.wait(CONFIG.CheckInterval)
		end

		if tracker.Active then
			log(
				"Monitoring spawn %s selesai.",
				player.Name
			)
		end
	end)

	log("Physics Stabilizer aktif untuk %s.", player.Name)
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)

	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end
end

--==================================================
-- BOOTSTRAP
--==================================================

if CONFIG.Enabled then
	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(disconnectTracker)

	print("------------------------------------------")
	print("[FORKT PHYSICS] Physics Stabilizer Online")
	print("[FORKT PHYSICS] Credits: Forkt Community")
	print("------------------------------------------")
end