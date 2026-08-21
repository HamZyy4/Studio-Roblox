-- StarterPlayerScripts | LocalScript "InstantMovement"
-- Responsive Movement Controller
-- Credits: Forkt Community

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local CONFIG = {
	RotateInstant = false,

	AirControl = true,
	AirControlMult = 1.2,
	AirSpeedMult = 1.1,

	SnapStrength = 15,
	MaxExtraSpeed = 5,

	StopInAir = false,
	InputDeadzone = 0.05,
	MaxDeltaTime = 1 / 20,
}

local BLOCKED_STATES = {
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Dead] = true,
	[Enum.HumanoidStateType.Physics] = true,
}

local character
local humanoid
local rootPart
local characterVersion = 0

local function clearCharacter()
	characterVersion += 1
	character = nil
	humanoid = nil
	rootPart = nil
end

local function setupCharacter(newCharacter)
	clearCharacter()

	local currentVersion = characterVersion
	local newHumanoid = newCharacter:WaitForChild("Humanoid", 10)
	local newRootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)

	-- Mencegah karakter lama menimpa cache setelah respawn cepat.
	if currentVersion ~= characterVersion then
		return
	end

	if not newHumanoid or not newRootPart or not newCharacter.Parent then
		warn("[InstantMovement] Gagal memuat komponen karakter.")
		return
	end

	character = newCharacter
	humanoid = newHumanoid
	rootPart = newRootPart

	humanoid.AutoRotate = not CONFIG.RotateInstant

	print("[InstantMovement] Character controller aktif.")
end

local function isFlying()
	if not character or not humanoid then
		return false
	end

	return humanoid.PlatformStand
		or character:FindFirstChild("ADONIS_FLYING") ~= nil
		or character:GetAttribute("Flying") == true
end

local function updateMovement(deltaTime)
	if not character or not humanoid or not rootPart then
		return
	end

	if not character.Parent or humanoid.Health <= 0 then
		return
	end

	if rootPart.Anchored or isFlying() then
		return
	end

	local state = humanoid:GetState()

	if BLOCKED_STATES[state] then
		return
	end

	-- Mencegah lonjakan smoothing ketika terjadi lag.
	deltaTime = math.min(deltaTime, CONFIG.MaxDeltaTime)

	local moveDirection = humanoid.MoveDirection
	local hasInput = moveDirection.Magnitude > CONFIG.InputDeadzone
	local walkSpeed = math.max(humanoid.WalkSpeed, 0)

	local velocity = rootPart.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(
		velocity.X,
		0,
		velocity.Z
	)

	local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
	local isAirState =
		state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall

	-- Rotasi instan opsional.
	if CONFIG.RotateInstant and hasInput then
		local direction = Vector3.new(
			moveDirection.X,
			0,
			moveDirection.Z
		)

		if direction.Magnitude > 0.001 then
			rootPart.CFrame = CFrame.lookAt(
				rootPart.Position,
				rootPart.Position + direction.Unit,
				Vector3.yAxis
			)
		end
	end

	if not onGround and not (CONFIG.AirControl and isAirState) then
		return
	end

	local desiredVelocity = Vector3.zero

	if hasInput then
		local targetSpeed = walkSpeed

		if not onGround then
			targetSpeed *= CONFIG.AirSpeedMult
		end

		desiredVelocity = moveDirection.Unit * targetSpeed
	elseif not onGround and not CONFIG.StopInAir then
		-- Pertahankan momentum udara ketika input dilepas.
		return
	end

	local controlMultiplier = onGround and 1 or CONFIG.AirControlMult
	local smoothing = math.max(CONFIG.SnapStrength * controlMultiplier, 0)
	local alpha = 1 - math.exp(-smoothing * deltaTime)

	local newHorizontalVelocity =
		horizontalVelocity:Lerp(desiredVelocity, alpha)

	local maximumSpeed = walkSpeed + math.max(CONFIG.MaxExtraSpeed, 0)

	if maximumSpeed > 0
		and newHorizontalVelocity.Magnitude > maximumSpeed
	then
		newHorizontalVelocity =
			newHorizontalVelocity.Unit * maximumSpeed
	end

	-- Sumbu Y dipertahankan agar gravitasi dan lompatan tidak terganggu.
	rootPart.AssemblyLinearVelocity = Vector3.new(
		newHorizontalVelocity.X,
		velocity.Y,
		newHorizontalVelocity.Z
	)
end

player.CharacterAdded:Connect(setupCharacter)
player.CharacterRemoving:Connect(clearCharacter)

if player.Character then
	task.spawn(setupCharacter, player.Character)
end

RunService.PreSimulation:Connect(updateMovement)

print("----------------------------------------")
print("[InstantMovement] Berhasil dimuat")
print("[InstantMovement] Credits: Forkt Community")
print("----------------------------------------")