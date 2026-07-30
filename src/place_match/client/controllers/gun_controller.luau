--!strict
--------------------------------------------------------------------------------
-- GunController.luau  (src/client/controllers)
-- Manages gun equip, fire, and reload on the client.
-- Reports confirmed hits to the server via the ShootGun RemoteEvent.
-- Visual effects (muzzle flash, particles) play locally; damage is server-auth.
--
-- Single Responsibility: gun input handling and local visual feedback.
-- Ammo display is delegated to HudController — no direct UI here.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local replicated_storage = game:GetService("ReplicatedStorage")

local Framework     = require(replicated_storage.common.shared.framework)
local Logger        = require(replicated_storage.common.shared.logger)
local RemoteNames   = require(replicated_storage.match.shared.remote_names)
local RenderScheduler = require(replicated_storage.match.shared.render_scheduler)
local HudController = require(replicated_storage.match.client.controllers.hud_controller)
local InventoryController = require(replicated_storage.match.client.controllers.inventory_controller)
local GunModule = require(replicated_storage.common.shared.gun_core)
local GunFxModule = require(replicated_storage.match.client.controllers.modules.gun.gun_fx_module)
local GunViewModelModule = require(replicated_storage.match.client.controllers.modules.gun.gun_view_model_module)
local GunHitScanModule = require(replicated_storage.match.client.controllers.modules.gun.gun_hit_scan_module)

type SyncedGun = InventoryController.SyncedGun

local TAG = "GunController"

local GunController = {}
GunController.Name = TAG

local _localPlayer  = Players.LocalPlayer
local _mouse        = _localPlayer:GetMouse()
local _shootRemote:      RemoteEvent
local _hitSoundRemote:   RemoteEvent

-- Gun state — all mutable locals are module-private.
local _isReloading:      boolean              = false
local _isOnFireCooldown: boolean              = false
local _isTriggerHeld:    boolean              = false
local _isAutoFiring:     boolean              = false
local _equippedGun:      Tool?                = nil
local _activatedConn:    RBXScriptConnection? = nil
local _deactivatedConn:  RBXScriptConnection? = nil
local _aimPitchTaskId: string? = nil
local _cameraModeConn:   RBXScriptConnection? = nil
local _cameraCFrameConn: RBXScriptConnection? = nil
local _ammoByGun:        { [string]: number } = {}
local _baseGunGrip:      CFrame?              = nil
local _cachedMuzzle:     BasePart?            = nil
local _cachedHrp:        BasePart?            = nil
local _camera = workspace.CurrentCamera

local _reserveAmmoByGun: { [string]: number } = {}

local MAX_VERTICAL_AIM_RADIANS = math.rad(35)

local function getGunStats(gunName: string?): GunModule.Gun
    if not gunName then
        return {} :: GunModule.Gun
    end
	local guns = InventoryController.getGuns()
	for _, g in ipairs(guns) do
		if g.name == gunName then
			return g.stats
		end
	end
	return {} :: GunModule.Gun
end

local function getReserveAmmo(gunName: string?): number
	if not gunName then return 0 end
	if _reserveAmmoByGun[gunName] == nil then
		local stats = getGunStats(gunName)
		_reserveAmmoByGun[gunName] = stats.max_ammo
	end
	return _reserveAmmoByGun[gunName]
end

local function setReserveAmmo(gunName: string?, value: number)
	if not gunName then return end
	_reserveAmmoByGun[gunName] = math.max(0, math.floor(value or 0))
end

local function getCurrentAmmo(): number
	if not _equippedGun then return 0 end
	local gunName = _equippedGun.Name
	local stats = getGunStats(gunName)
	if _ammoByGun[gunName] == nil then
		_ammoByGun[gunName] = stats.magSize
	end
	return _ammoByGun[gunName]
end

local function setCurrentAmmo(value: number)
	if not _equippedGun then return end
	_ammoByGun[_equippedGun.Name] = value
end

-- ── Private helpers ───────────────────────────────────────────────────────────

local function refreshAmmoDisplay()
	local ammo = getCurrentAmmo()
	if not _equippedGun then
		HudController.setAmmoText("", Color3.new(1, 1, 1))
		HudController.setActiveWeaponAmmo(0, 0)
		return
	end

	local reserve = getReserveAmmo(_equippedGun.Name)
	HudController.setActiveWeaponAmmo(ammo, reserve)

	if _isReloading then
		HudController.setAmmoText("RELOADING...", Color3.new(1, 0.6, 0))
		return
	end
	local color = ammo > 0 and Color3.new(1, 1, 1) or Color3.new(1, 0.2, 0.2)
	HudController.setAmmoText(string.format("%d / %d", ammo, math.max(0, math.floor(reserve))), color)
end

local function reload()
	if not _equippedGun then return end
	local reloadingGun = _equippedGun
	local stats = getGunStats(reloadingGun.Name)
	if _isReloading or getCurrentAmmo() == stats.magSize then return end
	-- Nothing to reload from reserve for this gun
	local reserve = getReserveAmmo(reloadingGun.Name)
	if reserve <= 0 then return end
	_isReloading = true
	refreshAmmoDisplay()

	if stats.isShotgun then
		-- Shotgun: play reload animation once per shell needed to fill the mag.
		local shellsNeeded = stats.magSize - getCurrentAmmo()
		local timePerShell = stats.reloadTime / stats.magSize
		for _i = 1, shellsNeeded do
			local reserveNow = getReserveAmmo(reloadingGun.Name)
			if reserveNow <= 0 then break end
			local track = GunFxModule.playReloadAnimation()
			-- consume one shell from reserve
			local loadAmount = math.min(1, reserveNow)
			setCurrentAmmo(getCurrentAmmo() + loadAmount)
			setReserveAmmo(reloadingGun.Name, reserveNow - loadAmount)
			refreshAmmoDisplay()
			local waitTime
			if track and track.Length and track.Length > 0 then
				waitTime = track.Length
			else
				waitTime = timePerShell
			end
			task.wait(waitTime)
		end
	else
		-- Standard gun: single reload animation for the whole mag.
		local missing = stats.magSize - getCurrentAmmo()
		local reserveNow = getReserveAmmo(reloadingGun.Name)
		local amountToLoad = math.min(missing, math.max(0, math.floor(reserveNow)))
		if amountToLoad <= 0 then
			_isReloading = false
			refreshAmmoDisplay()
			return
		end
		local track = GunFxModule.playReloadAnimation()
		local waitTime = stats.reloadTime
		if track and track.Length and track.Length > 0 then
			waitTime = track.Length
		end
		task.wait(waitTime)
		-- apply loaded ammo after animation
		setCurrentAmmo(getCurrentAmmo() + amountToLoad)
		setReserveAmmo(reloadingGun.Name, reserveNow - amountToLoad)
		refreshAmmoDisplay()
	end

	_isReloading = false
	refreshAmmoDisplay()
end

local function castShot(origin: Vector3)
	local stats = getGunStats(_equippedGun and _equippedGun.Name or nil)
	return GunHitScanModule.castShot(_mouse, _localPlayer.Character, origin, stats.range)
end

local function fire(): boolean
	local stats = getGunStats(_equippedGun and _equippedGun.Name or nil)
	local character = _localPlayer.Character
	if _isOnFireCooldown or _isReloading or not _equippedGun or not character then return false end

	local hrp = _cachedHrp
	if not hrp then return false end

	local ammo = getCurrentAmmo()
	if ammo <= 0 then
		task.spawn(reload)
		return false
	end

	_isOnFireCooldown = true
	setCurrentAmmo(ammo - 1)
	refreshAmmoDisplay()

	local origin: Vector3 = _cachedMuzzle and _cachedMuzzle.Position or (hrp :: BasePart).Position
	local result = castShot(origin)
	local hitPosition = result.hitPosition
	local hitZombie = result.hitZombie
	local isHeadshot = result.isHeadshot

	GunFxModule.playShootSound()
	GunFxModule.playShootAnimation()
	GunFxModule.drawTracer(origin, hitPosition, stats.tracer)

	local muzzleDelay = 0.05
	GunFxModule.flashMuzzle(muzzleDelay)

	-- Logger.fireServer provides the net trace hook when DEBUG_NETWORKING = true.
	if hitZombie then
		Logger.fireServer(_shootRemote, hitZombie, isHeadshot, hitPosition)
	end

	task.wait(stats.fireCooldown)
	_isOnFireCooldown = false
	return true
end

local function startAutoFire(gun: Tool)
	if _isAutoFiring then return end
	_isAutoFiring = true

	task.spawn(function()
		while _isAutoFiring and _isTriggerHeld and _equippedGun == gun do
			if not fire() then
				task.wait(0.05)
			end
		end
		_isAutoFiring = false
	end)
end

local function stopTriggerFiring()
	_isTriggerHeld = false
	_isAutoFiring = false
end

local function onGunActivated(gun: Tool)
	if _equippedGun ~= gun then return end

	local stats = getGunStats(gun.Name)
	_isTriggerHeld = true

	if stats.isAutomatic then
		startAutoFire(gun)
		return
	end

	fire()
end

local function stopAimPitchTracking()
	if _aimPitchTaskId then
		RenderScheduler.unregister(_aimPitchTaskId)
		_aimPitchTaskId = nil
	end

	if _equippedGun and _baseGunGrip then
		_equippedGun.Grip = _baseGunGrip
	end

	_baseGunGrip = nil
end

local function startAimPitchTracking(gun: Tool)
	stopAimPitchTracking()
	_baseGunGrip = gun.Grip

	_aimPitchTaskId = RenderScheduler.register("aimPitch_" .. gun.Name, function(dt)
		if _equippedGun ~= gun then return end
		local hrp = _cachedHrp
		if not hrp then return end

		local toMouse = _mouse.Hit.Position - hrp.Position
		local horizontal = Vector3.new(toMouse.X, 0, toMouse.Z)
		if horizontal.Magnitude < 0.001 then return end

		local pitch = math.atan2(toMouse.Y, horizontal.Magnitude)
		pitch = math.clamp(pitch, -MAX_VERTICAL_AIM_RADIANS, MAX_VERTICAL_AIM_RADIANS)

		gun.Grip = (_baseGunGrip :: CFrame) * CFrame.Angles(-pitch, 0, 0)
	end, { enabled = true })
end

local function onCharacterAdded(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	_cachedHrp = (hrp and hrp:IsA("BasePart")) and hrp :: BasePart or nil
end

local function isFirstPerson(): boolean
	if not _localPlayer or not _localPlayer.Character or not _camera then return false end
	local root = _localPlayer.Character:FindFirstChild("Head") or _localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return false end
	local dist = (_camera.CFrame.Position - root.Position).Magnitude
	return dist < 2
end

local function updateCachedMuzzleForView()
	if not _equippedGun then return end
	if isFirstPerson() then
		-- In first-person, strictly use the active camera-mounted viewmodel muzzle.
		local vmMuzzle = GunViewModelModule.getActiveMuzzleForTool()
		_cachedMuzzle = (vmMuzzle and vmMuzzle:IsA("BasePart")) and vmMuzzle :: BasePart or nil
		GunFxModule.setCachedMuzzle(_cachedMuzzle)
		return
	end

	-- Third-person: use the tool's muzzle (if present)
	local m = _equippedGun:FindFirstChild("Muzzle", true)
	_cachedMuzzle = (m and m:IsA("BasePart")) and m :: BasePart or nil
	GunFxModule.setCachedMuzzle(_cachedMuzzle)
end

local function startViewModeTracking()
	if _cameraModeConn then
		_cameraModeConn:Disconnect()
		_cameraModeConn = nil
	end
	if _cameraCFrameConn then
		_cameraCFrameConn:Disconnect()
		_cameraCFrameConn = nil
	end
	if _localPlayer then
		_cameraModeConn = _localPlayer:GetPropertyChangedSignal("CameraMode"):Connect(function()
			Logger.info(TAG, "startViewModeTracking: CameraMode changed: " .. tostring(_localPlayer.CameraMode))
			updateCachedMuzzleForView()
		end)
		Logger.info(TAG, "startViewModeTracking: listening to CameraMode changes")
	end
	-- Ensure we have the current camera (may be nil at module load time)
	_camera = workspace.CurrentCamera
	if _camera then
		_cameraCFrameConn = _camera:GetPropertyChangedSignal("CFrame"):Connect(function()
			updateCachedMuzzleForView()
		end)
		Logger.info(TAG, "startViewModeTracking: listening to Camera.CFrame changes")
	end
end

local function stopViewModeTracking()
	if _cameraModeConn then
		_cameraModeConn:Disconnect()
		_cameraModeConn = nil
	end
	if _cameraCFrameConn then
		_cameraCFrameConn:Disconnect()
		_cameraCFrameConn = nil
	end
	Logger.info(TAG, "stopViewModeTracking: stopped camera/view tracking")
end

local function onCharacterRemoving()
	_cachedHrp = nil
end

local function onGunEquipped(gun: Tool)
	_equippedGun      = gun
	local stats = getGunStats(gun.Name)
	if _ammoByGun[gun.Name] == nil then
		_ammoByGun[gun.Name] = stats.magSize
	end
	_isReloading      = false
	_isOnFireCooldown = false
	stopTriggerFiring()
	_activatedConn    = gun.Activated:Connect(function()
		onGunActivated(gun)
	end)
	_deactivatedConn  = gun.Deactivated:Connect(stopTriggerFiring)
	local m = gun:FindFirstChild("Muzzle", true)
	_cachedMuzzle = (m and m:IsA("BasePart")) and m :: BasePart or nil
	-- Track camera/view changes and update cached muzzle to viewmodel muzzle when in first-person
	startViewModeTracking()
	GunViewModelModule.onGunEquipped(gun)
	updateCachedMuzzleForView()
	GunFxModule.onGunEquipped(gun)
	-- Ensure FX module uses the controller's cached muzzle (viewmodel muzzle when appropriate)
	GunFxModule.setCachedMuzzle(_cachedMuzzle)
	startAimPitchTracking(gun)
	refreshAmmoDisplay()
end

local function onGunUnequipped()
	if _activatedConn then
		_activatedConn:Disconnect()
		_activatedConn = nil
	end
	if _deactivatedConn then
		_deactivatedConn:Disconnect()
		_deactivatedConn = nil
	end
	stopTriggerFiring()
	stopAimPitchTracking()
	stopViewModeTracking()
	_cachedMuzzle = nil
	GunViewModelModule.onGunUnequipped()
	GunFxModule.onGunUnequipped()
	_equippedGun = nil
	refreshAmmoDisplay()
end

--- Watch a character model for the gun being equipped (moved into character by server)
--- or unequipped (removed). Uses ChildAdded/ChildRemoved on the character.
local function watchCharacter(character: Model)
	-- Check if gun is already equipped (e.g. character respawned mid-session).
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			onGunEquipped(child :: Tool)
		end
	end

	character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") then
			onGunEquipped(child :: Tool)
		end
	end)

	character.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Tool") then
			onGunUnequipped()
		end
	end)
end

local function onInventoryChanged(guns: { SyncedGun }, equippedSlot: number?)
    -- Determine target equipped name from inventory
	
	if not equippedSlot then
		Logger.info(TAG, "onInventoryChanged: player is currently not using slot 1 or 2no equipped slot")
		return
	end

	if not guns[equippedSlot] then
		Logger.info(TAG, "onInventoryChanged: no gunin the equipped slot given to gun controller from inventory")
		return
	end

	local newGun = guns[equippedSlot]
	local targetName = newGun.name
	
	if _equippedGun and _equippedGun.Name == targetName then
		return
	end

	-- Try to find the Tool instance on the character and equip it
	local character = _localPlayer and _localPlayer.Character
	if character then
		local tool = character:FindFirstChild(targetName)
		if tool and tool:IsA("Tool") then
			onGunEquipped(tool :: Tool)
			return
		end
	end
end
-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function GunController:Init()
	Logger.info(TAG, "Initialized.")
end

function GunController:Start()
	-- GetRemote yields until the server's WaveService:Init() has created the remote.
	_shootRemote = Framework.GetRemote(RemoteNames.SHOOT_GUN)

	-- Top-up ammo remote for RNG hits where player rolled an already-equipped weapon
	local _rngTopupRemote: RemoteEvent = Framework.GetRemote(RemoteNames.RNG_TOPUP_AMMO)
	_rngTopupRemote.OnClientEvent:Connect(function(weaponName: string, magSize: number?, maxAmmo: number?)
		if type(weaponName) ~= "string" then return end
		local stats = getGunStats(weaponName)
		local mag = magSize or (stats and stats.magSize) or 0
		local reserve = maxAmmo or (stats and stats.max_ammo) or getReserveAmmo(weaponName)
		setReserveAmmo(weaponName, reserve)
		if _equippedGun and _equippedGun.Name == weaponName then
			setCurrentAmmo(mag)
			refreshAmmoDisplay()
		end
		Logger.info(TAG, "RNG top-up: weapon=%s mag=%d reserve=%d", weaponName, mag, reserve)
	end)

	InventoryController.onInventoryChanged(onInventoryChanged)

	_localPlayer.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(character)
		watchCharacter(character)
	end)

	_localPlayer.CharacterRemoving:Connect(onCharacterRemoving)
	if _localPlayer.Character then
		onCharacterAdded(_localPlayer.Character)
		watchCharacter(_localPlayer.Character)
	end
	
	-- Handle number key input for weapon switching
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		
		-- R key manual reload
		if input.KeyCode == Enum.KeyCode.R then
			task.spawn(reload)
			return
		end
	end)

	-- Play hit sound (body or headshot) when server confirms a hit.
	_hitSoundRemote = Framework.GetRemote(RemoteNames.ZOMBIE_HIT_SOUND)
	local soundsFolder = replicated_storage:FindFirstChild("Sounds") :: Folder?
	_hitSoundRemote.OnClientEvent:Connect(function(hitPosition: Vector3, isHeadshot: boolean)
		local templateName = isHeadshot and "ZombieHeadshotHit" or "ZombieBodyHit"
		local template = soundsFolder and soundsFolder:FindFirstChild(templateName) :: Sound?
		if not template then return end

		local sound = (template :: Sound):Clone()
		sound.Parent = _localPlayer.Character or workspace
		sound:Play()
		sound.Ended:Connect(function() sound:Destroy() end)
	end)

	Logger.info(TAG, "ShootGun remote acquired; gun watchers connected.")
end

Framework.CreateController(GunController)
return GunController
