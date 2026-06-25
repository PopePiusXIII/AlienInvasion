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
		local viewModelsFolder = ReplicatedStorage:FindFirstChild("ViewModels")
		if viewModelsFolder then
			local template = viewModelsFolder:FindFirstChild(_currentGunName) or viewModelsFolder:FindFirstChild(string.lower(_currentGunName))
			local animObj = template and (template:FindFirstChild("reloadAnimation") or template:FindFirstChild("ReloadAnimation"))
			if animObj and animObj:IsA("Animation") then
				local cam = workspace.CurrentCamera
				if cam then
					local vmInstance = cam:FindFirstChild(_currentGunName) or cam:FindFirstChild(string.lower(_currentGunName))
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
		local viewModelsFolder = ReplicatedStorage:FindFirstChild("ViewModels")
		if viewModelsFolder then
			local template = viewModelsFolder:FindFirstChild(_currentGunName) or viewModelsFolder:FindFirstChild(string.lower(_currentGunName))
			if template and template:IsA("Model") then
				local animObj = template:FindFirstChild("shootAnimation") or template:FindFirstChild("ShootAnimation")
				if animObj and animObj:IsA("Animation") then
					_cachedShootAnimObj = animObj :: Animation
				end
			end
		end
	end

	-- Resolve the camera-mounted viewmodel and obtain an Animator
	local cam = workspace.CurrentCamera
	if not cam then return false end
	local vmInstance = cam:FindFirstChild(_currentGunName) or cam:FindFirstChild(string.lower(_currentGunName))
	if not vmInstance or not vmInstance:IsA("Model") then return false end

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
		return false
	end

	_cachedAnimator = animator

	-- Load the animation track if we have both animation object and animator
	if _cachedShootAnimObj and _cachedAnimator then
		local ok, track = pcall(function()
			return _cachedAnimator:LoadAnimation(_cachedShootAnimObj)
		end)
		if ok and track then
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

	-- If we already have a cached reload track with a valid animator, reuse it
	if _cachedReloadTrack and _cachedReloadAnimator and _cachedReloadAnimator.Parent and _cachedReloadAnimator.Parent.Parent then
		_cachedReloadTrack:Play()
		-- Play reload sound alongside the animation if available
		if _cachedReloadSnd then
			_cachedReloadSnd.TimePosition = 0
			_cachedReloadSnd:Play()
		end
		return _cachedReloadTrack
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

	-- Attempt to load and cache the reload track
	local ok, track = pcall(function()
		return animator:LoadAnimation(animObj :: Animation)
	end)
	if not ok or not track then
		warn("GunFxModule.playReloadAnimation: failed to load animation track for '" .. tostring(_currentGunName) .. "'")
		return
	end

	_cachedReloadAnimator = animator
	_cachedReloadTrack = track

	track:Play()

	-- Play reload sound alongside the animation
	if _cachedReloadSnd then
		_cachedReloadSnd.TimePosition = 0
		_cachedReloadSnd:Play()
	end

	return track
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
