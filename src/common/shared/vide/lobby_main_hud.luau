--!strict
--------------------------------------------------------------------------------
-- LobbyMainHUD.luau  (src/common/vide)
-- The default HUD visible in the lobby at all times.
--
-- Shows:
--   - Game title (top-center)
--   - Player name + silver balance (top-left)
--   - Navigation hint text (bottom-center, e.g. "Walk to a pad to play")
--
-- Always-on, non-reactive panel — no show/hide toggling needed.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")

local vide  = require(replicated_storage.Packages.vide)
local theme = require(replicated_storage.common.shared.vide.vide_theme)
local ui    = require(replicated_storage.common.shared.vide.ui_config)
local DepressedButton = require(replicated_storage.common.shared.vide.depressed_button)
local armoryHud = require(replicated_storage.common.shared.vide.armory)
local ProfileInventory = require(replicated_storage.common.shared.profile_db_types)
local ProfileDb = require(replicated_storage.common.shared.profile_db_types)

local create = vide.create
local source = vide.source
local effect = vide.effect
local mount  = vide.mount

export type LobbyMainHUDProps = {
    title: string,
    hintText: string,
    parentGui: Instance?,
    playerName: string?,
    onPurchaseWeapon: ((string, string) -> ())?,
    profileApi: ProfileDb.API?,
}

--- Creates the always-visible lobby HUD.
--- Returns the ScreenGui, a control table for updating reactive fields, and an
--- unmount function.
function createLobbyMainHUD(props: LobbyMainHUDProps): (Instance, {
    setSilver: (number) -> (),
    setGold: (number) -> (),
    setHint:   (string) -> (),
}, () -> ())
    local silverAmount = source(0)
    local goldAmount = source(0)
    local hintMsg      = source(props.hintText or "")
    -- UI Labs stories run without a client Player, so LocalPlayer can be nil.
    -- Keep the component renderable there while preserving the real name in-game.
    local localPlayer = Players.LocalPlayer
    local displayName = props.playerName
    if not displayName then
        displayName = "PLAYER"
        if localPlayer then
            displayName = localPlayer.Name
        end
    end

    local screenGui: Instance
    if props.parentGui then
        screenGui = props.parentGui
    else
        screenGui = create "ScreenGui" {
            Name           = "LobbyMainHud",
            ResetOnSpawn   = false,
            IgnoreGuiInset = true,
            Parent         = localPlayer and localPlayer.PlayerGui,
        }
    end

    -- Armory panel (created once, returns a toggle function)
    local toggleArmory = armoryHud.createArmoryHUD(screenGui, props.onPurchaseWeapon)
    local toggleInventory: () -> () = function() end
    local cleanupInventory: (() -> ())? = nil
    if props.profileApi then
        toggleInventory, cleanupInventory = ProfileInventory.createProfileInventoryHUD(props.profileApi, screenGui)
    end

    -- Click sound (static, not reactive)
    local _clickSound = create "Sound" {
        Name     = "ShopClick",
        Parent   = screenGui,
        SoundId  = ui.sounds.Click,
        Volume   = ui.button.clickVolume,
    }

    local function renderHUD()
        -- Game title (top-center) — static
        create "TextLabel" {
            Name                   = "Title",
            Parent                 = screenGui,
            Size                 = UDim2.new(0.5, 0, 0.1, 0),
            Position             = UDim2.new(0.25, 0, 0.02, 0),
            BackgroundTransparency = 1,
            TextColor3           = theme.TEXT_HIGHLIGHT,
            TextScaled           = true,
            Font                 = theme.FONT_BOLD,
            Text                 = props.title,
        }

        -- Player name (top-left) — static
        create "TextLabel" {
            Name                   = "PlayerName",
            Parent                 = screenGui,
            Size                 = UDim2.new(0.3, 0, 0.06, 0),
            Position             = UDim2.new(0.02, 0, 0.02, 0),
            BackgroundTransparency = 1,
            TextColor3           = theme.TEXT_PRIMARY,
            TextScaled           = true,
            Font                 = theme.FONT_BOLD,
            TextXAlignment       = Enum.TextXAlignment.Left,
            Text                 = displayName,
        }

        -- Silver balance (top-left, below player name) — reactive
        local silverLabel = create "TextLabel" {
            Name                   = "SilverLabel",
            Parent                 = screenGui,
            Size                 = UDim2.new(0.3, 0, 0.06, 0),
            Position             = UDim2.new(0.02, 0, 0.09, 0),
            BackgroundTransparency = 1,
            TextColor3           = theme.SILVER,
            TextScaled           = true,
            Font                 = theme.FONT_REGULAR,
            TextXAlignment       = Enum.TextXAlignment.Left,
            Text                 = "SILVER: 0",
        }

	effect(function()
		silverLabel.Text = "SILVER: " .. tostring(math.max(0, math.floor(silverAmount())))
	end)

	-- Gold balance — reactive
	local goldLabel = create "TextLabel" {
		Name                   = "GoldLabel",
		Parent                 = screenGui,
		Size                 = UDim2.new(0.3, 0, 0.06, 0),
		Position             = UDim2.new(0.02, 0, 0.15, 0),
		BackgroundTransparency = 1,
		TextColor3           = theme.GOLD,
		TextScaled           = true,
		Font                 = theme.FONT_REGULAR,
		TextXAlignment       = Enum.TextXAlignment.Left,
		Text                 = "GOLD: 0",
	}

	effect(function()
		goldLabel.Text = "GOLD: " .. tostring(math.max(0, math.floor(goldAmount())))
	end)

	-- Navigation hint (bottom-center) — reactive
	local hintLabel = create "TextLabel" {
		Name                   = "Hint",
		Parent                 = screenGui,
		Size                 = UDim2.new(0.5, 0, 0.06, 0),
		Position             = UDim2.new(0.25, 0, 0.90, 0),
		BackgroundTransparency = 1,
		TextColor3           = theme.TEXT_SECONDARY,
		TextScaled           = true,
		Font                 = theme.FONT_REGULAR,
		Text                 = hintMsg(),
	}

	effect(function()
		hintLabel.Text = hintMsg()
	end)

        -- Shop button (bottom-center) — reusable DepressedButton component
        DepressedButton({
            parent   = screenGui,
            position = UDim2.new(0.93, 0, 0.3, 0),
            image    = ui.images.ClassShopButton,
            size     = ui.button.normalSize,
            onActivated = function()
                -- TODO: open shop UI
            end,
        })

        -- Shop button (bottom-center) — reusable DepressedButton component
        DepressedButton({
            parent   = screenGui,
            position = UDim2.new(0.93, 0, 0.5, 0),
            image    = ui.images.ShopButton,
            size     = ui.button.normalSize,
            onActivated = toggleArmory
        })

        -- Shop button (bottom-center) — reusable DepressedButton component
        DepressedButton({
            parent   = screenGui,
            position = UDim2.new(0.93, 0, 0.7, 0),
            image    = ui.images.PlayButton,
            size     = ui.button.normalSize,
            onActivated = function()
                -- TODO: open shop UI
            end,
        })

        create "TextButton" {
            Name                   = "InventoryButton",
            Parent                 = screenGui,
            Size                   = UDim2.new(0.16, 0, 0.05, 0),
            Position               = UDim2.new(0.42, 0, 0.83, 0),
            BackgroundColor3       = theme.BACKGROUND_LIGHT,
            TextColor3             = theme.TEXT_PRIMARY,
            Text                   = "INVENTORY",
            TextScaled             = true,
            Font                   = theme.FONT_BOLD,
            BorderSizePixel        = 0,
            Visible                = props.profileApi ~= nil,
            Activated              = toggleInventory,
        }


    end

    local unmount = mount(renderHUD, screenGui)
    local function cleanup()
        unmount()
        if cleanupInventory then
            cleanupInventory()
        end
    end

    local controls = {
        setSilver = function(amount: number) silverAmount(amount) end,
        setGold = function(amount: number) goldAmount(amount) end,
        setHint   = function(msg: string) hintMsg(msg) end,
    }

    return screenGui, controls, cleanup
end

return {
    createLobbyMainHUD = createLobbyMainHUD,
}
