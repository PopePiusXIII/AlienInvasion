--!strict

local GunFxModule = {}

function GunFxModule.flashMuzzle(gun: Tool, muzzleDelay: number)
	local muzzle = gun:FindFirstChild("Muzzle", true)
	if not muzzle then return end

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
