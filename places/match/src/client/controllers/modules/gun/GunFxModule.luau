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
local _cachedReloadSnd: Sound?           = nil
local _currentGunName:  string?          = nil

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

	local reloadSnd = gun:FindFirstChild("ReloadSound", true)
	if reloadSnd and reloadSnd:IsA("Sound") then
		_cachedReloadSnd = reloadSnd :: Sound
	end

	-- remember current gun name for viewmodel animation lookup
	_currentGunName = gun and gun.Name or nil
end

function GunFxModule.onGunUnequipped()
	_cachedMuzzle    = nil
	_cachedFlash     = nil
	_cachedParticles = nil
	_cachedSound     = nil
	_currentGunName = nil
end

function GunFxModule.setCachedMuzzle(muzzle: BasePart?)
	_cachedMuzzle = muzzle
	_cachedFlash = nil
	_cachedParticles = nil
	-- Prefer sounds/flash/particles found on the muzzle part when present
	if muzzle then
		local fl = muzzle:FindFirstChild("FlashLight")
		if fl and fl:IsA("PointLight") then
			_cachedFlash = fl :: PointLight
		end
		local pe = muzzle:FindFirstChildWhichIsA("ParticleEmitter")
		if pe then
			_cachedParticles = pe :: ParticleEmitter
		end
		local snd = muzzle:FindFirstChild("ShootSound", true)
		if snd and snd:IsA("Sound") then
			_cachedSound = snd :: Sound
		end
	end
end

function GunFxModule.playShootSound()
	if not _cachedSound then return end
	_cachedSound.TimePosition = 0
	_cachedSound:Play()
end

function GunFxModule.playShootAnimation()
	if not _currentGunName then
		warn("GunFxModule.playShootAnimation: no current gun name set")
		return
	end

	local viewModelsFolder = ReplicatedStorage:FindFirstChild("ViewModels")
	if not viewModelsFolder then
		warn("GunFxModule.playShootAnimation: ReplicatedStorage.ViewModels not found")
		return
	end

	local template = viewModelsFolder:FindFirstChild(_currentGunName) or viewModelsFolder:FindFirstChild(string.lower(_currentGunName))
	if not template or not template:IsA("Model") then
		warn("GunFxModule.playShootAnimation: no ViewModel template for gun '" .. tostring(_currentGunName) .. "' in ReplicatedStorage.ViewModels")
		return
	end

	local animObj = template:FindFirstChild("shootAnimation") or template:FindFirstChild("ShootAnimation")
	if not animObj or not animObj:IsA("Animation") then
		warn("GunFxModule.playShootAnimation: ViewModel template for '" .. tostring(_currentGunName) .. "' has no Animation named 'shootAnimation' or 'ShootAnimation'")
		return
	end

	-- Play the animation on the camera-mounted viewmodel instance (if present)
	local cam = workspace.CurrentCamera
	if not cam then
		warn("GunFxModule.playShootAnimation: workspace.CurrentCamera is nil")
		return
	end

	local vmInstance = cam:FindFirstChild(_currentGunName) or cam:FindFirstChild(string.lower(_currentGunName))
	if not vmInstance or not vmInstance:IsA("Model") then
		warn("GunFxModule.playShootAnimation: no viewmodel instance named '" .. tostring(_currentGunName) .. "' parented to Camera")
		return
	end

	-- Prefer an AnimationController, fall back to a Humanoid if present.
	local animationController = vmInstance:FindFirstChildOfClass("AnimationController")
	local humanoid = vmInstance:FindFirstChildWhichIsA("Humanoid")

	local animator: Animator? = nil
	if animationController then
		animator = animationController:FindFirstChildWhichIsA("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = animationController
		end
	elseif humanoid then
		animator = humanoid:FindFirstChildWhichIsA("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
	else
		warn("GunFxModule.playShootAnimation: viewmodel instance '" .. tostring(vmInstance.Name) .. "' has neither AnimationController nor Humanoid")
		return
	end

	if not animator then
		warn("GunFxModule.playShootAnimation: failed to obtain Animator for viewmodel '" .. tostring(vmInstance.Name) .. "'")
		return
	end

	local ok, track = pcall(function()
		return animator:LoadAnimation(animObj :: Animation)
	end)
	if not ok or not track then
		warn("GunFxModule.playShootAnimation: failed to load animation track for '" .. tostring(_currentGunName) .. "'")
		return
	end

	track:Play()
end

function GunFxModule.playReloadAnimation()
	if not _currentGunName then
		warn("GunFxModule.playReloadAnimation: no current gun name set")
		return
	end

	local viewModelsFolder = ReplicatedStorage:FindFirstChild("ViewModels")
	if not viewModelsFolder then
		warn("GunFxModule.playReloadAnimation: ReplicatedStorage.ViewModels not found")
		return
	end

	local template = viewModelsFolder:FindFirstChild(_currentGunName) or viewModelsFolder:FindFirstChild(string.lower(_currentGunName))
	if not template or not template:IsA("Model") then
		warn("GunFxModule.playReloadAnimation: no ViewModel template for gun '" .. tostring(_currentGunName) .. "' in ReplicatedStorage.ViewModels")
		return
	end

	local animObj = template:FindFirstChild("reloadAnimation") or template:FindFirstChild("ReloadAnimation")
	if not animObj or not animObj:IsA("Animation") then
		warn("GunFxModule.playReloadAnimation: ViewModel template for '" .. tostring(_currentGunName) .. "' has no Animation named 'reloadAnimation' or 'ReloadAnimation'")
		return
	end

	-- Play the animation on the camera-mounted viewmodel instance (if present)
	local cam = workspace.CurrentCamera
	if not cam then
		warn("GunFxModule.playReloadAnimation: workspace.CurrentCamera is nil")
		return
	end

	local vmInstance = cam:FindFirstChild(_currentGunName) or cam:FindFirstChild(string.lower(_currentGunName))
	if not vmInstance or not vmInstance:IsA("Model") then
		warn("GunFxModule.playReloadAnimation: no viewmodel instance named '" .. tostring(_currentGunName) .. "' parented to Camera")
		return
	end

	local animationController = vmInstance:FindFirstChildOfClass("AnimationController")
	local humanoid = vmInstance:FindFirstChildWhichIsA("Humanoid")

	local animator: Animator? = nil
	if animationController then
		animator = animationController:FindFirstChildWhichIsA("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = animationController
		end
	elseif humanoid then
		animator = humanoid:FindFirstChildWhichIsA("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
	else
		warn("GunFxModule.playReloadAnimation: viewmodel instance '" .. tostring(vmInstance.Name) .. "' has neither AnimationController nor Humanoid")
		return
	end

	if not animator then
		warn("GunFxModule.playReloadAnimation: failed to obtain Animator for viewmodel '" .. tostring(vmInstance.Name) .. "'")
		return
	end

	local ok, track = pcall(function()
		return animator:LoadAnimation(animObj :: Animation)
	end)
	if not ok or not track then
		warn("GunFxModule.playReloadAnimation: failed to load animation track for '" .. tostring(_currentGunName) .. "'")
		return
	end

	track:Play()

	-- Play reload sound alongside the animation
	if _cachedReloadSnd then
		_cachedReloadSnd.TimePosition = 0
		_cachedReloadSnd:Play()
	end
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
