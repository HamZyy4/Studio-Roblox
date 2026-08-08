-- SSS ( ServerScriptService )
-- BISMILLAH INSYALLAH GA NGELEG
-- Developer By : Forkt Community

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ContentProvider = game:GetService("ContentProvider")

-- ==========================================
-- ⚙️ CONFIGURATION (MAXIMAL EDITION)
-- ==========================================
local Config = {
    -- 📦 Aggressive Preload Settings
    PreloadAssets = true,
    PreloadSounds = true,      
    PreloadMeshes = true,
    PreloadTextures = true,    
    PreloadAnimations = true,  
    PreloadBatchSize = 50,     
    
    -- 🛡️ Network Security Optimization
    OptimizeNetwork = true,    
    
    -- 📊 Performance & Security
    MonitoringEnabled = true,
    MonitorRateLimit = 2,
    
    -- 🐛 Debugging
    DebugMode = true,
}

-- ==========================================
-- 📦 1. SERVER ASSET PRELOADER
-- ==========================================
local AssetPreloader = {}
AssetPreloader.AssetsToPreload = {}

function AssetPreloader:Initialize()
    if not Config.PreloadAssets then return end
    if Config.DebugMode then print("[FORKT] Memulai scanning aset...") end
    
    task.spawn(function()
        local assets = Workspace:GetDescendants()
        local startTime = os.clock()
        
        for _, obj in ipairs(assets) do
            -- Smart yield
            if os.clock() - startTime >= 0.015 then
                task.wait()
                startTime = os.clock()
            end
            
            if Config.PreloadSounds and obj:IsA("Sound") and obj.SoundId ~= "" then
                table.insert(self.AssetsToPreload, obj.SoundId)
            elseif Config.PreloadMeshes and obj:IsA("MeshPart") and obj.MeshId ~= "" then
                table.insert(self.AssetsToPreload, obj.MeshId)
            elseif Config.PreloadTextures and (obj:IsA("Decal") or obj:IsA("Texture")) and obj.Texture ~= "" then
                table.insert(self.AssetsToPreload, obj.Texture)
            elseif Config.PreloadAnimations and obj:IsA("Animation") and obj.AnimationId ~= "" then
                table.insert(self.AssetsToPreload, obj.AnimationId)
            end
        end
        
        if #self.AssetsToPreload > 0 then
            self:StartPreloading()
        end
    end)
end

function AssetPreloader:StartPreloading()
    local startTime = tick()
    local batchSize = Config.PreloadBatchSize
    
    for i = 1, #self.AssetsToPreload, batchSize do
        local batch = {}
        for j = i, math.min(i + batchSize - 1, #self.AssetsToPreload) do
            table.insert(batch, self.AssetsToPreload[j])
        end
        
        pcall(function() ContentProvider:PreloadAsync(batch) end)
        task.wait(0.1) 
    end
    
    if Config.DebugMode then 
        print(string.format("[FORKT] ✅ Load %d aset selesai (%.2f detik)", #self.AssetsToPreload, tick() - startTime)) 
    end
end

-- ==========================================
-- 🛡️ 2. NETWORK SECURITY (ANTI-FLING)
-- ==========================================
local NetworkOptimizer = {}

function NetworkOptimizer:Initialize()
    if not Config.OptimizeNetwork then return end
    
    task.spawn(function()
        Workspace.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("BasePart") and not descendant.Anchored then
                pcall(function()
                    if descendant:CanSetNetworkOwnership() then
                        descendant:SetNetworkOwner(nil)
                    end
                end)
            end
        end)
    end)
    
    if Config.DebugMode then print("[FORKT] 🛡️ Anti-Fling Aktif") end
end

-- ==========================================
-- 📊 3. PERFORMANCE MONITORING
-- ==========================================
local PerformanceStats = {}
PerformanceStats.PlayerStats = {}
PerformanceStats.RateLimits = {} 

function PerformanceStats:Initialize()
    if not Config.MonitoringEnabled then return end
    
    local folder = ReplicatedStorage:FindFirstChild("ForktPerformance") or Instance.new("Folder")
    folder.Name = "ForktPerformance"
    folder.Parent = ReplicatedStorage
    
    local statsRemote = folder:FindFirstChild("SendStats") or Instance.new("RemoteEvent")
    statsRemote.Name = "SendStats"
    statsRemote.Parent = folder
    
    statsRemote.OnServerEvent:Connect(function(player, stats)
        local lastUpdate = self.RateLimits[player.UserId] or 0
        if tick() - lastUpdate < Config.MonitorRateLimit then return end
        self.RateLimits[player.UserId] = tick()
        
        if type(stats) == "table" then
            local fps = tonumber(stats.FPS)
            local ping = tonumber(stats.Ping)
            
            if fps and ping then
                self.PlayerStats[player.UserId] = {
                    FPS = math.clamp(fps, 0, 1000),
                    Ping = math.clamp(ping, 0, 9999),
                    Timestamp = os.time()
                }
            end
        end
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self.PlayerStats[player.UserId] = nil
        self.RateLimits[player.UserId] = nil
    end)
    
    if Config.DebugMode then print("[FORKT] 📊 Telemetri Standby") end
end

-- ==========================================
-- 🚀 BOOTSTRAPPER (AUTO-RUN)
-- ==========================================
task.spawn(function()
    AssetPreloader:Initialize()
    NetworkOptimizer:Initialize()
    task.wait(0.1)
    PerformanceStats:Initialize()
    print("[FORKT] 🚀 ENGINE ONLINE (Max Performance)")
end)
