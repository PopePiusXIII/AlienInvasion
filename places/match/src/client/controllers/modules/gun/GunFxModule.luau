--!strict

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunFxModule = {}

local muzzleFlashTemplate = ReplicatedStorage:FindFirstChild("MuzzleFlash")

-- Cached per-gun references, populated once when a gun is equipped.
local _cachedMuzzle:    BasePart?        = nil
local _cachedFlash:     PointLight?      = nil
local _cachedParticles: ParticleEmitter? = nil
local _cachedSound:     Sound?           = nil

type GunTracerStyle = {
	lifetime: number,
	thickness: number,
	color: Color3,
}

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

function GunFxModule.onGunEquipped(gun: Tool)
	_cachedMuzzle    = nil
	_cachedFlash     = nil
	_cachedParticles = nil
	_cachedSound     = nil

	local m = gun:FindFirstChild("Muzzle", true)
	if m and m:IsA("BasePart") then
		_cachedMuzzle = m :: BasePart
		local fl = m:FindFirstChild("FlashLight")
		if fl and fl:IsA("PointLight") then
			_cachedFlash = fl :: PointLight
		end
		local pe = m:FindFirstChildWhichIsA("ParticleEmitter")
		if pe then
			_cachedParticles = pe :: ParticleEmitter
		end
	end

	local snd = gun:FindFirstChild("ShootSound", true)
	if snd and snd:IsA("Sound") then
		_cachedSound = snd :: Sound
	end
end

function GunFxModule.onGunUnequipped()
	_cachedMuzzle    = nil
	_cachedFlash     = nil
	_cachedParticles = nil
	_cachedSound     = nil
end

function GunFxModule.playShootSound()
	if not _cachedSound then return end
	_cachedSound.TimePosition = 0
	_cachedSound:Play()
end

function GunFxModule.drawTracer(origin: Vector3, hitPosition: Vector3, tracerStyle: GunTracerStyle)
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
	tracer.Color = tracerStyle.color
	tracer.Size = Vector3.new(tracerStyle.thickness, tracerStyle.thickness, distance)
	tracer.CFrame = CFrame.lookAt(origin, hitPosition) * CFrame.new(0, 0, -distance * 0.5)
	tracer.Parent = workspace

	Debris:AddItem(tracer, tracerStyle.lifetime)
end

function GunFxModule.flashMuzzle(muzzleDelay: number)
	local muzzle = _cachedMuzzle
	if not muzzle then return end

	if spawnTemplateMuzzleFlash(muzzle, muzzleDelay) then
		return
	end

	local flash = _cachedFlash
	if flash then
		flash.Enabled = true
		task.delay(muzzleDelay, function()
			flash.Enabled = false
		end)
	end

	local particles = _cachedParticles
	if particles then
		particles:Emit(8)
	end
end

return GunFxModule
