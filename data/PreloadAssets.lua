-- ReplicatedFirst | LocalScript "UniversalPreloader"
-- Universal Automatic Asset Preloader
-- Developed by Forkt Community

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local StarterPack = game:GetService("StarterPack")
local StarterPlayer = game:GetService("StarterPlayer")

local player = Players.LocalPlayer

--==================================================
-- KONFIGURASI
--==================================================

local CONFIG = {
	Enabled = true,

	-- Jumlah aset per proses preload.
	BatchSize = 30,

	-- Jeda antarbatch agar loading tidak terlalu berat.
	BatchDelay = 0.03,

	-- Yield ketika melakukan scanning.
	ScanYieldEvery = 300,

	-- Batas keamanan jumlah instance aset.
	MaxAssets = 5000,

	-- Otomatis preload aset yang muncul setelah game berjalan.
	PreloadNewAssets = true,
	DynamicPreloadDelay = 0.5,

	DebugMode = true,
}

--==================================================
-- JENIS INSTANCE YANG MEMILIKI ASET
--==================================================

local ASSET_CLASSES = {
	Animation = true,
	Sound = true,

	Decal = true,
	Texture = true,

	ImageLabel = true,
	ImageButton = true,

	TextLabel = true,
	TextButton = true,
	TextBox = true,

	MeshPart = true,
	SpecialMesh = true,
	SurfaceAppearance = true,
	MaterialVariant = true,

	ParticleEmitter = true,
	Beam = true,
	Trail = true,

	VideoFrame = true,
	Sky = true,

	Shirt = true,
	Pants = true,
	ShirtGraphic = true,
	CharacterMesh = true,

	Tool = true,
	WrapLayer = true,
	WrapTarget = true,
	HumanoidDescription = true,
}

--==================================================
-- INTERNAL
--==================================================

local PREFIX = "[FORKT PRELOADER]"

local scannedInstances = setmetatable({}, {
	__mode = "k",
})

local dynamicQueue = {}
local dynamicQueueLookup = setmetatable({}, {
	__mode = "k",
})

local connections = {}
local totalDiscovered = 0
local totalBatches = 0
local isDestroyed = false

local function log(message, ...)
	if not CONFIG.DebugMode then
		return
	end

	print(string.format(
		"%s %s",
		PREFIX,
		string.format(message, ...)
	))
end

local function warning(message, ...)
	warn(string.format(
		"%s %s",
		PREFIX,
		string.format(message, ...)
	))
end

local function isAssetInstance(instance)
	return instance
		and ASSET_CLASSES[instance.ClassName] == true
end

local function registerAsset(instance, destination)
	if not isAssetInstance(instance) then
		return false
	end

	if scannedInstances[instance] then
		return false
	end

	if totalDiscovered >= CONFIG.MaxAssets then
		return false
	end

	scannedInstances[instance] = true
	totalDiscovered += 1
	table.insert(destination, instance)

	return true
end

--==================================================
-- PRELOAD BATCH
--==================================================

local function preloadBatch(batch)
	if #batch == 0 or isDestroyed then
		return
	end

	totalBatches += 1

	local failedContent = {}
	local failedLookup = {}

	local success, errorMessage = pcall(function()
		ContentProvider:PreloadAsync(
			batch,
			function(contentId, status)
				if status ~= Enum.AssetFetchStatus.Success
					and not failedLookup[contentId]
				then
					failedLookup[contentId] = true
					table.insert(failedContent, contentId)
				end
			end
		)
	end)

	if not success then
		warning(
			"Batch #%d gagal diproses: %s",
			totalBatches,
			tostring(errorMessage)
		)

		return
	end

	if CONFIG.DebugMode and #failedContent > 0 then
		warning(
			"Batch #%d memiliki %d konten gagal/tidak diizinkan.",
			totalBatches,
			#failedContent
		)
	end
end

local function preloadList(assetList)
	if #assetList == 0 then
		return
	end

	for index = 1, #assetList, CONFIG.BatchSize do
		if isDestroyed then
			return
		end

		local batch = {}
		local finalIndex = math.min(
			index + CONFIG.BatchSize - 1,
			#assetList
		)

		for assetIndex = index, finalIndex do
			local asset = assetList[assetIndex]

			if asset and asset.Parent then
				table.insert(batch, asset)
			end
		end

		preloadBatch(batch)

		if finalIndex < #assetList then
			task.wait(CONFIG.BatchDelay)
		end
	end
end

--==================================================
-- AUTOMATIC SCANNER
--==================================================

local function scanRoot(root, destination)
	if not root or isDestroyed then
		return
	end

	registerAsset(root, destination)

	local descendants = root:GetDescendants()

	for index, instance in ipairs(descendants) do
		if totalDiscovered >= CONFIG.MaxAssets then
			break
		end

		registerAsset(instance, destination)

		if index % CONFIG.ScanYieldEvery == 0 then
			task.wait()
		end
	end
end

local function getScanRoots()
	local roots = {
		ReplicatedFirst,
		ReplicatedStorage,
		Workspace,
		Lighting,
		SoundService,
		StarterGui,
		StarterPack,
		StarterPlayer,
	}

	local playerGui = player:FindFirstChildOfClass("PlayerGui")

	if playerGui then
		table.insert(roots, playerGui)
	end

	local backpack = player:FindFirstChildOfClass("Backpack")

	if backpack then
		table.insert(roots, backpack)
	end

	return roots
end

--==================================================
-- ASET BARU/DINAMIS
--==================================================

local function queueDynamicAsset(instance)
	if not CONFIG.PreloadNewAssets then
		return
	end

	if not isAssetInstance(instance) then
		return
	end

	if scannedInstances[instance] or dynamicQueueLookup[instance] then
		return
	end

	if totalDiscovered >= CONFIG.MaxAssets then
		return
	end

	scannedInstances[instance] = true
	dynamicQueueLookup[instance] = true
	totalDiscovered += 1

	table.insert(dynamicQueue, instance)
end

local function connectDynamicScanner(root)
	if not root then
		return
	end

	local connection = root.DescendantAdded:Connect(queueDynamicAsset)
	table.insert(connections, connection)
end

local function startDynamicWorker()
	task.spawn(function()
		while not isDestroyed do
			task.wait(CONFIG.DynamicPreloadDelay)

			if #dynamicQueue == 0 then
				continue
			end

			local pendingAssets = dynamicQueue
			dynamicQueue = {}

			for _, instance in ipairs(pendingAssets) do
				dynamicQueueLookup[instance] = nil
			end

			preloadList(pendingAssets)

			log(
				"%d aset dinamis selesai diproses.",
				#pendingAssets
			)
		end
	end)
end

--==================================================
-- CLEANUP
--==================================================

script.Destroying:Connect(function()
	isDestroyed = true

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end

	table.clear(connections)
	table.clear(dynamicQueue)
end)

--==================================================
-- BOOTSTRAP
--==================================================

local function initialize()
	if not CONFIG.Enabled then
		return
	end

	local startTime = os.clock()

	log("Memulai Universal Asset Preloader...")
	log("Credits: Forkt Community")

	local roots = getScanRoots()

	-- Hubungkan pendeteksi terlebih dahulu agar aset baru tidak terlewat.
	if CONFIG.PreloadNewAssets then
		for _, root in ipairs(roots) do
			connectDynamicScanner(root)
		end

		-- PlayerGui/Backpack mungkin dibuat setelah script berjalan.
		table.insert(connections, player.ChildAdded:Connect(function(child)
			if child:IsA("PlayerGui") or child:IsA("Backpack") then
				connectDynamicScanner(child)

				local assets = {}
				scanRoot(child, assets)
				preloadList(assets)
			end
		end))
	end

	local initialAssets = {}

	for _, root in ipairs(roots) do
		if totalDiscovered >= CONFIG.MaxAssets then
			break
		end

		scanRoot(root, initialAssets)
	end

	log("%d instance aset ditemukan.", #initialAssets)

	preloadList(initialAssets)

	log(
		"✅ Preload awal selesai dalam %.2f detik.",
		os.clock() - startTime
	)

	if totalDiscovered >= CONFIG.MaxAssets then
		warning(
			"Batas maksimum %d aset tercapai.",
			CONFIG.MaxAssets
		)
	end

	if CONFIG.PreloadNewAssets then
		startDynamicWorker()
		log("Pemantauan aset dinamis aktif.")
	end

	log("🚀 ENGINE ONLINE — Forkt Community")
end

task.spawn(initialize)