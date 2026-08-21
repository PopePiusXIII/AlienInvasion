--!strict

local replicated_storage = game:GetService("ReplicatedStorage")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)

local TempEndGameGUI = {}

local TAG = "TempEndGameGUI"

local _levelContinueVoteRemote: RemoteEvent
local _overlay: Frame
local _status: TextLabel
local _continueButton: TextButton
local _returnButton: TextButton
local _hasSubmittedVote = false

local function setVoteButtonsEnabled(enabled: boolean)
	_continueButton.Active = enabled
	_continueButton.AutoButtonColor = enabled
	_returnButton.Active = enabled
	_returnButton.AutoButtonColor = enabled
end

local function onContinueActivated()
	if _hasSubmittedVote then
		return
	end
	_hasSubmittedVote = true
	setVoteButtonsEnabled(false)
	_status.Text = "Waiting for the squad..."
	_levelContinueVoteRemote:FireServer(true)
end

local function onReturnActivated()
	if _hasSubmittedVote then
		return
	end
	_hasSubmittedVote = true
	setVoteButtonsEnabled(false)
	_status.Text = "Returning to lobby..."
	_levelContinueVoteRemote:FireServer(false)
end

local function onLevelContinuePrompt(nextLevelId: any, voteDuration: any)
	assert(type(nextLevelId) == "string" and nextLevelId ~= "", "Temporary level prompt received an invalid level id.")
	assert(type(voteDuration) == "number" and voteDuration > 0, "Temporary level prompt received an invalid vote duration.")
	_hasSubmittedVote = false
	setVoteButtonsEnabled(true)
	_status.Text = string.format("Advance to %s? The squad has %d seconds to agree.", nextLevelId, math.ceil(voteDuration))
	_overlay.Visible = true
end

local function onLevelContinuePromptClosed()
	_overlay.Visible = false
end

function TempEndGameGUI.temporary(parent: Instance)
	assert(_overlay == nil, "[TempEndGameGUI] Temporary end-game GUI has already been created.")
	local overlay = Instance.new("Frame")
	overlay.Name = "TemporaryLevelContinuePrompt"
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.ZIndex = 20

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(24, 31, 43)
	panel.BorderSizePixel = 0
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 230)
	panel.ZIndex = 21
	panel.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	title.Position = UDim2.fromOffset(24, 24)
	title.Size = UDim2.fromOffset(372, 35)
	title.Text = "LEVEL CLEAR"
	title.TextColor3 = Color3.fromRGB(246, 214, 105)
	title.TextScaled = true
	title.ZIndex = 22
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
	status.Position = UDim2.fromOffset(24, 75)
	status.Size = UDim2.fromOffset(372, 42)
	status.TextColor3 = Color3.fromRGB(232, 237, 244)
	status.TextScaled = true
	status.TextWrapped = true
	status.ZIndex = 22
	status.Parent = panel

	local continueButton = Instance.new("TextButton")
	continueButton.Name = "Continue"
	continueButton.BackgroundColor3 = Color3.fromRGB(62, 136, 84)
	continueButton.BorderSizePixel = 0
	continueButton.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	continueButton.Position = UDim2.fromOffset(24, 151)
	continueButton.Size = UDim2.fromOffset(180, 52)
	continueButton.Text = "CONTINUE"
	continueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	continueButton.TextScaled = true
	continueButton.ZIndex = 22
	continueButton.Parent = panel

	local returnButton = Instance.new("TextButton")
	returnButton.Name = "Return"
	returnButton.BackgroundColor3 = Color3.fromRGB(157, 65, 65)
	returnButton.BorderSizePixel = 0
	returnButton.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	returnButton.Position = UDim2.fromOffset(216, 151)
	returnButton.Size = UDim2.fromOffset(180, 52)
	returnButton.Text = "RETURN"
	returnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	returnButton.TextScaled = true
	returnButton.ZIndex = 22
	returnButton.Parent = panel

	_continueButton = continueButton
	_returnButton = returnButton
	_status = status
	_overlay = overlay
	overlay.Parent = parent

	local levelContinuePromptRemote = Framework.GetRemote("LevelContinuePrompt")
	local levelContinuePromptClosedRemote = Framework.GetRemote("LevelContinuePromptClosed")
	_levelContinueVoteRemote = Framework.GetRemote("LevelContinueVote")
	continueButton.Activated:Connect(onContinueActivated)
	returnButton.Activated:Connect(onReturnActivated)
	Logger.onClientEvent(levelContinuePromptRemote, TAG, onLevelContinuePrompt)
	Logger.onClientEvent(levelContinuePromptClosedRemote, TAG, onLevelContinuePromptClosed)
end

return TempEndGameGUI