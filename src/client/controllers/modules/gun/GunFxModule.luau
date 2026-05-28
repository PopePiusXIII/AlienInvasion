--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunFxModule = {}

local muzzleFlashTemplate = ReplicatedStorage:FindFirstChild("MuzzleFlash")

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
