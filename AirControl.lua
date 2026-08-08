-- StarterPlayerScripts | Local Script "InstantMovement"
-- Super responsive movement | Optimized | By Forkt Community

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local plr = Players.LocalPlayer

-- ⚙️ KONFIGURASI
local CONFIG = {
	RotateInstant = false,
	AirControl = true,
	AirControlMult = 1.2,
	SnapStrength = 15,
	AirBoost = 1.6,
	MaxExtraSpeed = 9999,
	StopInAir = false
}

-- 🚫 State yang di-skip (tidak mengaplikasikan custom velocity)
local BLOCKED_STATES = {
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Physics] = true,
}

-- 📦 Cache Variabel (Optimasi ekstrim untuk performa loop)
local char, hum, root

local function updateCharacter(newChar)
	char = newChar
	hum = char:WaitForChild("Humanoid", 5)
	root = char:WaitForChild("HumanoidRootPart", 5)
end

if plr.Character then updateCharacter(plr.Character) end
plr.CharacterAdded:Connect(updateCharacter)

-- 🔄 Main Loop
RunService.PreSimulation:Connect(function(dt)
	-- Pastikan cache valid
	if not (char and hum and root) or hum.Health <= 0 then return end

	-- 🛡️ Anti-fly / Admin fly logic (Lebih universal)
	if hum.PlatformStanding or char:FindFirstChild("ADONIS_FLYING") then return end

	local state = hum:GetState()
	if BLOCKED_STATES[state] then return end

	local move = hum.MoveDirection
	local hasInput = move.Magnitude > 0.05
	local currentSpeed = math.max(tonumber(hum.WalkSpeed) or 16, 1)

	-- 🔄 AutoRotate Logic
	hum.AutoRotate = not CONFIG.RotateInstant

	if CONFIG.RotateInstant and hasInput then
		local lookVector = Vector3.new(move.X, 0, move.Z)
		if lookVector.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + lookVector)
		end
	end

	-- 🚀 Kalkulasi Velocity
	local vel = root.AssemblyLinearVelocity
	local flatVel = Vector3.new(vel.X, 0, vel.Z)

	local onGround = (hum.FloorMaterial ~= Enum.Material.Air)
	local isFreeAir = (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping)

	-- Skip jika di udara tapi Air Control dimatikan
	if not onGround and not (CONFIG.AirControl and isFreeAir) then return end

	local desiredFlat = Vector3.zero

	if hasInput then
		-- Jika sedang menekan tombol gerak
		desiredFlat = move.Unit * (onGround and currentSpeed or (currentSpeed * 1.1))
	else
		-- Jika tombol dilepas
		if not onGround and not CONFIG.StopInAir then
			return 
		end
	end

	local mult = onGround and 1 or CONFIG.AirControlMult
	local airBoost = (not onGround) and CONFIG.AirBoost or 1
	local alpha = 1 - math.exp(-CONFIG.SnapStrength * mult * airBoost * dt)
	local newFlat = flatVel:Lerp(desiredFlat, alpha)
	local limit = math.min(math.max(currentSpeed + 5, currentSpeed * 1.25), CONFIG.MaxExtraSpeed)
	if newFlat.Magnitude > limit then
		newFlat = newFlat.Unit * limit
	end

	-- 💥 Terapkan Velocity baru (Tanpa mengganggu sumbu Y / Gravitasi)
	root.AssemblyLinearVelocity = Vector3.new(newFlat.X, vel.Y, newFlat.Z)
end)
