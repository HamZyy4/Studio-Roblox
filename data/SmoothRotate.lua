-- LocalScript di StarterCharacterScripts
-- By Forkt Community 
local RunService = game:GetService("RunService")

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")

local ROTATION_SPEED = 14
local MIN_MOVEMENT = 0.05

humanoid.AutoRotate = false

local connection
connection = RunService.RenderStepped:Connect(function(dt)
	if not character.Parent or humanoid.Health <= 0 then
		connection:Disconnect()
		return
	end

	if humanoid.Sit then
		return
	end

	local moveDirection = humanoid.MoveDirection
	local flatDirection = Vector3.new(
		moveDirection.X,
		0,
		moveDirection.Z
	)

	if flatDirection.Magnitude <= MIN_MOVEMENT then
		return
	end

	local targetCFrame = CFrame.lookAt(
		root.Position,
		root.Position + flatDirection.Unit,
		Vector3.yAxis
	)

	local alpha = 1 - math.exp(-ROTATION_SPEED * dt)
	root.CFrame = root.CFrame:Lerp(targetCFrame, alpha)
end)

script.Destroying:Connect(function()
	if connection then
		connection:Disconnect()
	end
end)