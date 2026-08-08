--[[
    =========================================
    FORKT COMMUNITY - AUTO-DETECT ANIMATED DECAL
    Developer: @SukitooV1 (FORKT)
    Description: Automatically detects and animates all Decals inside the Part.
    =========================================
]]

local TweenService = game:GetService("TweenService")
local Part = script.Parent

-- [ CONFIGURATION ] --
local CONFIG = {
    DisplayTime = 2.5,
    FadeTime = 0.5,
    Loop = true,
    DebugMode = false,
    EasingStyle = Enum.EasingStyle.Sine,
    EasingDirection = Enum.EasingDirection.InOut
}

-- [ AUTO-DETECT DECALS ] --
local Decals = {}
local FadeInTweens = {}
local FadeOutTweens = {}

local FadeInfo = TweenInfo.new(
    CONFIG.FadeTime,
    CONFIG.EasingStyle,
    CONFIG.EasingDirection
)

-- Mencari semua objek Decal di dalam Part
for _, child in ipairs(Part:GetChildren()) do
    if child:IsA("Decal") then
        child.Transparency = 1 -- Sembunyikan semua decal saat awal mulai
        table.insert(Decals, child)
        
        -- Optimasi: Buat dan simpan cache Tween untuk masing-masing Decal
        FadeInTweens[child] = TweenService:Create(child, FadeInfo, {Transparency = 0})
        FadeOutTweens[child] = TweenService:Create(child, FadeInfo, {Transparency = 1})
    end
end

-- Pengecekan apakah ada Decal yang ditemukan
if #Decals == 0 then
    warn("[FORKT COMMUNITY] Error: Tidak ada Decal yang ditemukan di dalam " .. Part:GetFullName())
    return
end

local function PlayTween(tween)
    tween:Play()
    tween.Completed:Wait()
end

-- [ MAIN LOOP ] --
local function StartAnimation()
    local Index = 1
    local TotalDecals = #Decals
    
    print("[FORKT COMMUNITY] Memulai animasi untuk " .. TotalDecals .. " Decal di: " .. Part:GetFullName())
    
    while Part and Part.Parent do
        local CurrentDecal = Decals[Index]
        
        if CONFIG.DebugMode then
            print("[FORKT DEBUG] Menampilkan Decal: " .. CurrentDecal.Name .. " (" .. Index .. "/" .. TotalDecals .. ")")
        end
        
        -- Proses Animasi menggunakan cache Tween
        PlayTween(FadeInTweens[CurrentDecal])
        task.wait(CONFIG.DisplayTime)
        PlayTween(FadeOutTweens[CurrentDecal])
        
        -- Lanjut ke decal berikutnya
        Index += 1
        
        -- Reset index jika melebihi batas (Looping)
        if Index > TotalDecals then
            if CONFIG.Loop then
                Index = 1
            else
                if CONFIG.DebugMode then
                    print("[FORKT DEBUG] Animasi selesai.")
                end
                break
            end
        end
    end
end

-- Menjalankan animasi secara asinkron
task.spawn(StartAnimation)
