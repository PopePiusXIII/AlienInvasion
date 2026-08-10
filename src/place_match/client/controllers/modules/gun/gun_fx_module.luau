--!strict

local Debris = game:GetService("Debris")
local replicated_storage = game:GetService("ReplicatedStorage")

local GunFxModule = {}

local muzzleFlashTemplate = replicated_storage:FindFirstChild("MuzzleFlash")

-- Cached per-gun references, populated once when a gun is equipped.
local _cachedMuzzle:    BasePart?        = nil
local _cachedFlash:     PointLight?      = nil
local _cachedParticles: ParticleEmitter? = nil
local _cachedSound:     Sound?           = nil
local _cachedReloadSnd: Sound?           = nil
local _currentGunName:  string?          = nil
local _cachedShootAnimObj: Animation?     = nil
local _cachedAnimator:    Animator?       = nil
local _cachedShootTrack:  AnimationTrack? = nil
local _cachedReloadAnimObj: Animation?     = nil
local _cachedReloadAnimator: Animator?     = nil
local _cachedReloadTrack:  AnimationTrack? = nil

type GunTracerStyle = {
	lifetime: number,
	thickness: number,
	color: Color3,
}

-- Helper: find the camera-mounted viewmodel instance for the currently cached gun name.
local function findViewModelInstance(): Model?
	if not _currentGunName then return nil end
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local vm = cam:FindFirstChild(_currentGunName)
	return (vm and vm:IsA("Model")) and vm :: Model or nil
end

local function removePrefix(inventoryName: string): string
	return inventoryName:match("^[^_]+_(.+)$") or inventoryName
end

-- Helper: obtain or create an Animator for a viewmodel instance.
local function getAnimatorForVm(vmInstance: Model): Animator?
	if not vmInstance then return nil end
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
	end
	return animator
end

-- Helper: attempt to load an Animation into an animator and return the track.
local function tryLoadAnimationTrack(animator: Animator, animObj: Animation): AnimationTrack?
	if not animator or not animObj then return nil end
	local ok, track = pcall(function()
		return animator:LoadAnimation(animObj)
	end)
	if ok and track then
		return track :: AnimationTrack
	end
	return nil
end

local function hasValidCachedReloadTrack(): boolean
	if not _cachedReloadTrack or not _cachedReloadAnimator then
		return false
	end

	local animatorParent = _cachedReloadAnimator.Parent
	return animatorParent ~= nil and animatorParent.Parent ~= nil
end

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

	_currentGunName = removePrefix(gun.Name)

	-- clear cached animator/track for the newly equipped gun (will be lazily initialized)
	_cachedShootAnimObj = nil
	_cachedAnimator = nil
	_cachedShootTrack = nil

	_cachedReloadAnimObj = nil
	_cachedReloadAnimator = nil
	_cachedReloadTrack = nil

	-- Attempt to preload the reload animation track into the viewmodel animator so
	-- the track.Length is available immediately when first played.
	do
		local viewModelsFolder = replicated_storage:FindFirstChild("ViewModels")
		if viewModelsFolder then
			local template = viewModelsFolder:FindFirstChild(_currentGunName)
			local animObj = template and (template:FindFirstChild("reloadAnimation") or template:FindFirstChild("ReloadAnimation"))
			if animObj and animObj:IsA("Animation") then
				local cam = workspace.CurrentCamera
				if cam then
					local vmInstance = cam:FindFirstChild(_currentGunName)
					if vmInstance and vmInstance:IsA("Model") then
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
						end
						if animator then
							local ok, track = pcall(function()
								return animator:LoadAnimation(animObj :: Animation)
							end)
							if ok and track then
								_cachedReloadAnimator = animator
								_cachedReloadTrack = track
							end
						end
					end
				end
			end
		end
	end
end

function GunFxModule.onGunUnequipped()
	_cachedMuzzle    = nil
	_cachedFlash     = nil
	_cachedParticles = nil
	_cachedSound     = nil
	_currentGunName = nil

	_cachedShootAnimObj = nil
	_cachedAnimator = nil
	_cachedShootTrack = nil

	_cachedReloadAnimObj = nil
	_cachedReloadAnimator = nil
	_cachedReloadTrack = nil
end

local function ensureShootAnimationReady(): boolean
	if not _currentGunName then return false end

	-- If we already have a track and its animator still exists, reuse it
	if _cachedShootTrack and _cachedAnimator and _cachedAnimator.Parent and _cachedAnimator.Parent.Parent then
		return true
	end

	-- Lazy-resolve the animation object from the template if not cached
	if not _cachedShootAnimObj then
		local viewModelsFolder = replicated_storage:FindFirstChild("ViewModels")
		if viewModelsFolder then
			local template = viewModelsFolder:FindFirstChild(_currentGunName)
			if template and template:IsA("Model") then
				local animObj = template:FindFirstChild("shootAnimation") or template:FindFirstChild("ShootAnimation")
				if animObj and animObj:IsA("Animation") then
					_cachedShootAnimObj = animObj :: Animation
				end
			end
		end
	end

	-- Resolve the viewmodel instance and animator using shared helpers
	local vmInstance = findViewModelInstance()
	if not vmInstance then return false end
	local animator = getAnimatorForVm(vmInstance)
	if not animator then return false end

	_cachedAnimator = animator

	-- Load and cache the shoot track if possible
	if _cachedShootAnimObj and _cachedAnimator then
		local track = tryLoadAnimationTrack(_cachedAnimator, _cachedShootAnimObj)
		if track then
			_cachedShootTrack = track
			return true
		end
	end

	return false
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
		return
	end

	if not ensureShootAnimationReady() then
		return
	end

	if _cachedShootTrack then
		_cachedShootTrack:Play()
	end
end

function GunFxModule.playReloadAnimation(targetDuration: number): AnimationTrack
	assert(targetDuration > 0, string.format("Reload duration must be positive, got %f", targetDuration))

	local gunName = assert(_currentGunName, "Cannot play reload animation without an equipped gun")
	local viewModelsFolder = assert(
		replicated_storage:FindFirstChild("ViewModels"),
		"Missing replicated_storage.ViewModels required for reload animation"
	)
	local template = assert(
		viewModelsFolder:FindFirstChild(gunName),
		string.format("Missing ViewModel template for gun '%s'", gunName)
	)
	assert(template:IsA("Model"), string.format("ViewModel template for gun '%s' must be a Model", gunName))

	local animation = template:FindFirstChild("reloadAnimation") or template:FindFirstChild("ReloadAnimation")
	assert(
		animation and animation:IsA("Animation"),
		string.format("ViewModel template for gun '%s' is missing a reload Animation", gunName)
	)

	local track: AnimationTrack
	if hasValidCachedReloadTrack() then
		track = assert(_cachedReloadTrack, "Validated reload track unexpectedly missing")
	else
		local cam = assert(workspace.CurrentCamera, "Missing workspace.CurrentCamera for reload animation")
		local vmInstance = assert(
			cam:FindFirstChild(gunName),
			string.format("Missing camera-mounted ViewModel instance for gun '%s'", gunName)
		)
		assert(vmInstance:IsA("Model"), string.format("Camera ViewModel for gun '%s' must be a Model", gunName))
		local animator = assert(
			getAnimatorForVm(vmInstance),
			string.format("Missing Animator for ViewModel '%s'", vmInstance.Name)
		)
		track = animator:LoadAnimation(animation :: Animation)
		_cachedReloadAnimator = animator
		_cachedReloadTrack = track
	end

	assert(track.Length > 0, string.format("Reload animation for gun '%s' has no duration", gunName))
	track:Stop(0)
	track.TimePosition = 0
	track:AdjustSpeed(track.Length / targetDuration)
	track:Play()

	if _cachedReloadSnd then
		_cachedReloadSnd.TimePosition = 0
		_cachedReloadSnd:Play()
	end

	return track
end

function GunFxModule.stopReloadAnimation()
	if _cachedReloadTrack then
		_cachedReloadTrack:Stop(0)
		_cachedReloadTrack.TimePosition = 0
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
