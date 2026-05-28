--!strict

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunFxModule = {}

local muzzleFlashTemplate = ReplicatedStorage:FindFirstChild("MuzzleFlash")
local TRACER_LIFETIME = 0.06
local TRACER_THICKNESS = 0.08
local TRACER_COLOR = Color3.fromRGB(255, 235, 170)

local function spawnTemplateMuzzleFlash(muzzle: BasePart, muzzleDelay: number): boolean
	if not muzzleFlashTemplate then return false end
	if not muzzleFlashTemplate:IsA("BasePart") then return false end

	local flashClone = (muzzleFlashTemplate :: BasePart):Clone()
	flashClone.CFrame = muzzle.CFrame
	flashClone.CanCollide = false
	flashClone.CanTouch = false
	flashClone.CanQuery = false
	flashClone.Massless = true
	flashClone.Anchored = false
	flashClone.Parent = workspace

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = flashClone
	weld.Part1 = muzzle
	weld.Parent = flashClone

	task.delay(muzzleDelay, function()
		if flashClone.Parent then
			flashClone:Destroy()
		end
	end)

	return true
end

function GunFxModule.playShootSound(gun: Tool)
	local shootSound = gun:FindFirstChild("ShootSound", true)
	if not shootSound or not shootSound:IsA("Sound") then return end

	local sound = shootSound :: Sound
	sound.TimePosition = 0
	sound:Play()
end

function GunFxModule.drawTracer(origin: Vector3, hitPosition: Vector3)
	local direction = hitPosition - origin
	local distance = direction.Magnitude
	if distance < 0.01 then return end

	local tracer = Instance.new("Part")
	tracer.Name = "BulletTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = TRACER_COLOR
	tracer.Size = Vector3.new(TRACER_THICKNESS, TRACER_THICKNESS, distance)
	tracer.CFrame = CFrame.lookAt(origin, hitPosition) * CFrame.new(0, 0, -distance * 0.5)
	tracer.Parent = workspace

	Debris:AddItem(tracer, TRACER_LIFETIME)
end

function GunFxModule.flashMuzzle(gun: Tool, muzzleDelay: number)
	local muzzle = gun:FindFirstChild("Muzzle", true)
	if not muzzle or not muzzle:IsA("BasePart") then return end

	if spawnTemplateMuzzleFlash(muzzle :: BasePart, muzzleDelay) then
		return
	end

	local flash = muzzle:FindFirstChild("FlashLight")
	if flash and flash:IsA("PointLight") then
		(flash :: PointLight).Enabled = true
		task.delay(muzzleDelay, function()
			(flash :: PointLight).Enabled = false
		end)
	end

	local particles = muzzle:FindFirstChildWhichIsA("ParticleEmitter")
	if particles then
		(particles :: ParticleEmitter):Emit(8)
	end
end

return GunFxModule
