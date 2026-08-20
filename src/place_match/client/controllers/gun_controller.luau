--!strict
--------------------------------------------------------------------------------
-- GunController.luau  (src/client/controllers)
-- Manages gun equip, fire, and reload on the client.
-- Reports confirmed hits to the server via the ReportZombieHit RemoteEvent.
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
local _reportZombieHitRemote: RemoteEvent
local _zombieHitConfirmedRemote: RemoteEvent
local _requestGunReloadRemote: RemoteEvent
local _cancelGunReloadRemote: RemoteEvent

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
local _activeReloadId: string? = nil
local _pendingReloadCancel: boolean = false
local _baseGunGrip:      CFrame?              = nil
local _cachedMuzzle:     BasePart?            = nil
local _cachedHrp:        BasePart?            = nil
local _camera = workspace.CurrentCamera

local _reserveAmmoByGun: { [string]: number } = {}

local MAX_VERTICAL_AIM_RADIANS = math.rad(35)

local function getGunStats(gunName: string): GunModule.Gun
	local guns = InventoryController.getGuns()
	for _, g in ipairs(guns) do
		if g.name == gunName then
			return g.stats
		end
	end

	error(string.format("Missing synchronized stats for gun '%s'", gunName))
end

local function getReserveAmmo(gunName: string): number
	if _reserveAmmoByGun[gunName] == nil then
		local stats = getGunStats(gunName)
		_reserveAmmoByGun[gunName] = stats.max_ammo
	end
	return _reserveAmmoByGun[gunName]
end

local function setReserveAmmo(gunName: string, value: number)
	_reserveAmmoByGun[gunName] = math.max(0, math.floor(value))
end

local function getCurrentAmmo(gunName: string): number
	local stats = getGunStats(gunName)
	if _ammoByGun[gunName] == nil then
		_ammoByGun[gunName] = stats.magSize
	end
	return _ammoByGun[gunName]
end

local function setCurrentAmmo(gunName: string, value: number)
	_ammoByGun[gunName] = value
end

-- ── Private helpers ───────────────────────────────────────────────────────────

local function refreshGunAmmoDisplay(gunName: string)
	local ammo = getCurrentAmmo(gunName)
	local reserve = getReserveAmmo(gunName)
	local color = ammo > 0 and Color3.new(1, 1, 1) or Color3.new(1, 0.2, 0.2)
	HudController.setActiveWeaponAmmo(gunName, ammo, reserve)
	HudController.setAmmoText(gunName, string.format("%d / %d", ammo, math.max(0, math.floor(reserve))), color)
end

local function refreshAmmoDisplay()
	if not _equippedGun then
		return
	end

	local gunName = _equippedGun.Name

	if _isReloading then
		local ammo = getCurrentAmmo(gunName)
		local reserve = getReserveAmmo(gunName)
		HudController.setActiveWeaponAmmo(gunName, ammo, reserve)
		HudController.setAmmoText(gunName, "RELOADING...", Color3.new(1, 0.6, 0))
		return
	end
	refreshGunAmmoDisplay(gunName)
end

local function playReloadAnimation(duration: number)
	local startedAt = os.clock()
	local track = GunFxModule.playReloadAnimation(duration)
	track.Stopped:Wait()
	Logger.info(TAG, "Reload animation stopped: target=%.3f elapsed=%.3f trackLength=%.3f", duration, os.clock() - startedAt, track.Length)
end

local function reload()
	if not _equippedGun then return end
	local gunName = _equippedGun.Name
	local stats = getGunStats(gunName)
	if _isReloading or getCurrentAmmo(gunName) == stats.magSize or getReserveAmmo(gunName) <= 0 then return end
	_pendingReloadCancel = false
	_isReloading = true
	refreshAmmoDisplay()
	Logger.fireServer(_requestGunReloadRemote)
end

local function cancelReload()
	if not _isReloading then
		return
	end

	GunFxModule.stopReloadAnimation()
	_isReloading = false
	refreshAmmoDisplay()

	if not _activeReloadId then
		_pendingReloadCancel = true
		return
	end

	Logger.fireServer(_cancelGunReloadRemote, _activeReloadId)
	_activeReloadId = nil
end

local function castShot(origin: Vector3, gunName: string)
	local stats = getGunStats(gunName)
	return GunHitScanModule.castShot(_mouse, _localPlayer.Character, origin, stats.range)
end

local function fire(): boolean
	local character = _localPlayer.Character
	if _isReloading then
		cancelReload()
		return false
	end
	if _isOnFireCooldown or not _equippedGun or not character then return false end

	local hrp = _cachedHrp
	if not hrp then return false end

	local gunName = _equippedGun.Name
	local stats = getGunStats(gunName)
	local ammo = getCurrentAmmo(gunName)
	if ammo <= 0 then
		task.spawn(reload)
		return false
	end

	_isOnFireCooldown = true
	setCurrentAmmo(gunName, ammo - 1)
	refreshAmmoDisplay()

	local muzzle = assert(_cachedMuzzle, string.format("Missing muzzle for gun '%s'", gunName))
	local origin = muzzle.Position
	local result = castShot(origin, gunName)
	local hitPosition = result.hitPosition
	local hitZombie = result.hitZombie
	local isHeadshot = result.isHeadshot

	GunFxModule.playShootSound()
	GunFxModule.playShootAnimation()
	GunFxModule.drawTracer(origin, hitPosition, stats.tracer)

	local muzzleDelay = 0.05
	GunFxModule.flashMuzzle(muzzleDelay)

	-- Logger.fireServer provides the net trace hook when DEBUG_NETWORKING = true.
	Logger.fireServer(_reportZombieHitRemote, hitZombie, isHeadshot, hitPosition)

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
	GunFxModule.onGunEquipped(gun)
	-- Track camera/view changes and update cached muzzle to viewmodel muzzle when in first-person
	startViewModeTracking()
	GunViewModelModule.onGunEquipped(gun)
	updateCachedMuzzleForView()
	-- Ensure FX module uses the controller's cached muzzle (viewmodel muzzle when appropriate)
	GunFxModule.setCachedMuzzle(_cachedMuzzle)
	startAimPitchTracking(gun)
	refreshAmmoDisplay()
	if getCurrentAmmo(gun.Name) == 0 then
		task.spawn(reload)
	end
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
	cancelReload()
	GunFxModule.stopReloadAnimation()
	GunViewModelModule.onGunUnequipped()
	GunFxModule.onGunUnequipped()
	_equippedGun = nil
	_activeReloadId = nil
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

local function onZombieHit(hitPosition: Vector3, isHeadshot: boolean)
		local soundsFolder = replicated_storage:FindFirstChild("Sounds") :: Folder?
		local templateName = isHeadshot and "ZombieHeadshotHit" or "ZombieBodyHit"
		local template = soundsFolder and soundsFolder:FindFirstChild(templateName) :: Sound?
		if not template then return end

		local sound = (template :: Sound):Clone()
		sound.Parent = _localPlayer.Character or workspace
		sound:Play()
		sound.Ended:Connect(function() sound:Destroy() end)
	end

local function completePredictedReload(weaponName: string, reloadId: string)
	if _activeReloadId ~= reloadId then
		return
	end

	local stats = getGunStats(weaponName)
	local magazine = getCurrentAmmo(weaponName)
	local reserve = getReserveAmmo(weaponName)
	local amountToLoad = math.min(stats.magSize - magazine, reserve)
	setCurrentAmmo(weaponName, magazine + amountToLoad)
	setReserveAmmo(weaponName, reserve - amountToLoad)
	_isReloading = false
	refreshAmmoDisplay()
	Logger.info(TAG, "Reload predicted complete: gun=%s", weaponName)
end

local function onAmmoStateUpdated(weaponName: string, magazine: number, reserve: number, reloading: boolean, reloadId: string?, reloadEndsAt: number?)
	setCurrentAmmo(weaponName, magazine)
	setReserveAmmo(weaponName, reserve)
	if _equippedGun and _equippedGun.Name == weaponName then
		if reloading then
			assert(type(reloadId) == "string", "Reload state requires an event ID")
			assert(type(reloadEndsAt) == "number", "Reload state requires an end time")
			if _pendingReloadCancel then
				_pendingReloadCancel = false
				Logger.fireServer(_cancelGunReloadRemote, reloadId)
				return
			end
			if _activeReloadId == reloadId then
				return
			end

			_activeReloadId = reloadId
			local remainingDuration = math.max(0.01, reloadEndsAt - workspace:GetServerTimeNow())
			Logger.info(TAG, "Reload acknowledged: gun=%s remaining=%.3f", weaponName, remainingDuration)
			task.spawn(playReloadAnimation, remainingDuration)
			task.delay(remainingDuration, completePredictedReload, weaponName, reloadId)
		else
			GunFxModule.stopReloadAnimation()
			_activeReloadId = nil
			_pendingReloadCancel = false
		end
		_isReloading = reloading
		refreshAmmoDisplay()
	end
end
-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function GunController:Init()
	Logger.info(TAG, "Initialized.")
end

function GunController:Start()
	-- GetRemote yields until the server's WaveService:Init() has created the remote.
	_reportZombieHitRemote = Framework.GetRemote("ReportZombieHit")
	_requestGunReloadRemote = Framework.GetRemote("RequestGunReload")
	_cancelGunReloadRemote = Framework.GetRemote("CancelGunReload")

	local ammoStateUpdatedRemote: RemoteEvent = Framework.GetRemote("AmmoStateUpdated")
	ammoStateUpdatedRemote.OnClientEvent:Connect(onAmmoStateUpdated)

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
	_zombieHitConfirmedRemote = Framework.GetRemote("ZombieHitConfirmed")
	_zombieHitConfirmedRemote.OnClientEvent:Connect(onZombieHit)

	Logger.info(TAG, "ReportZombieHit remote acquired; gun watchers connected.")
end

Framework.CreateController(GunController)
return GunController
