-- Pretty much all functionality lies within this module. The other modules are used as crude database.
-- Dialogue.lua holds all NPCs that are interactable and points to the NPC_X.lua which exist for every interactable NPC.
-- With the amount of text and different dialogue options that exist for each NPC it makes more sense to have a single .lua for every single one.

-- Declare variables
StoryExtended = LibStub("AceAddon-3.0"):NewAddon("StoryExtended", "AceConsole-3.0")

StoryExtendedDB = {}          -- The save variable which is written into SavedVariables
CurrentID = 1                 -- the current dialogue ID (the ID for which text is shown currently)
local NextID                        -- The ID for the upcoming Dialogue
local HideUIOption = false       -- Will add this to a proper options menu later
local lockDialogueFrames = true
local lockedFramesHelper = false
local letMoveFrames = not lockDialogueFrames and not lockedFramesHelper
local HiddenUIParts = {}
local NamesWithDialogue = {}
local CurrentDialogue
local currentDataAddon = nil
local nameList = {}
local CURRENT_DATA_ADDON_VERSION = 1;
local currentQuestList = {}

-- Helper Functions shamelefully "borrowed" from AI_VoiceOver by MrThinger, will ask for permission and forgiveness later!
if not print then
    function print(...)
        local text = ""
        for i = 1, arg.n do
            text = text .. (i > 1 and " " or "") .. tostring(arg[i])
        end
        DEFAULT_CHAT_FRAME:AddMessage(text)
    end
end

if not select then
    function select(index, ...)
        if index == "#" then
            return arg.n
        else
            local result = {}
            for i = index, arg.n do
                table.insert(result, arg[i])
            end
            return unpack(result)
        end
    end
end
-- ^^^ Helper Functions shamelefully "borrowed" from AI_VoiceOver by MrThinger, will ask for permission and forgiveness later!

local CLIENT_VERSION, BUILD = GetBuildInfo()
-- print(CLIENT_VERSION)
if CLIENT_VERSION == "1.16.5" then
    -- Client version is 1.12 or below
else
    -- Client version is higher than 1.12
end


dialogueDataAddons =
{
    availableDataAddons = {},         -- To store the list of modules present in Interface\AddOns folder, whether they're loaded or not
    availableDataAddonsOrdered = {},  -- To store the list of modules present in Interface\AddOns folder, whether they're loaded or not
    registeredDataAddons = {},        -- To keep track of which module names were already registered
    registeredDataAddonsOrdered = {}, -- To have a consistent ordering of modules (which key-value hashmaps don't provide) to avoid bugs that can only be reproduced randomly
}


-- Register the data addons

function StoryExtended:Register(name, dataAddon)
    --print("Register addon...")
    assert(not dialogueDataAddons.registeredDataAddons[name], format([[Data addon "%s" already registered]], name))

    local metadata = assert(dialogueDataAddons.availableDataAddons[name],
        format([[A data addon "%s" attempted to register but could not be properly loaded. Check if .toc file was generated correctly.]], name))
    -- local dataVersion = assert(tonumber(GetAddOnMetadata(name, "StoryExtended-Data-Version")),
    --     format([[Data Addon "%s" is missing data version]], name))

    -- Ideally if module format would ever change - there should be fallbacks in place to handle outdated formats
 --   assert(dataVersion == CURRENT_DATA_ADDON_VERSION,
 --       format([[The data addon "%s" is outdated. To use it with the current version of the core addon please import it into the web app, refresh it and download it again (Data Addon version %d, current version %d)]], name, dataVersion,
  --      CURRENT_DATA_ADDON_VERSION))

    --    dataAddon.METADATA = metadata

    dialogueDataAddons.registeredDataAddons[name] = dataAddon
    -- table.insert(registeredDataAddonsOrdered, dataAddon)
    --currentDataAddon = dialogueDataAddons.registeredDataAddons[1]
    dataAddonVersion = GetAddOnMetadata(name, "Version")
    --LoadAddOn(name)
end



-- Load the saved variables from disk when the addon is loaded
LoadAddOn("StoryExtended")


-- Ace3 functions Begin

local defaults = {
	profile = {
		HideUIOption = false,
        lockDialogueFrames = true
	},
}


local options = {
    name = "StoryExtended",
    handler = StoryExtended,
    type = 'group',
    args = {
        HideUIOption = {
            type = 'toggle',
            name = 'Hide UI',
            desc = 'Hide the Interface when starting a Dialogue.',
            set = function (info, value)
                StoryExtended.db.profile.HideUIOption = value
                HideUIOption = StoryExtended.db.profile.HideUIOption
            end,
            get = function (info) return StoryExtended.db.profile.HideUIOption end,
        },
        LockDialogueFrames = {
            type = 'toggle',
            name = 'Lock Frames',
            desc = 'Lock the dialogue frames.',
            set = function (info, value)
                StoryExtended.db.profile.lockDialogueFrames = value
                lockDialogueFrames = StoryExtended.db.profile.lockDialogueFrames
                letMoveFrames = not lockDialogueFrames and not lockedFramesHelper
                DialogueFrame:SetMovable(letMoveFrames)
                QuestionFrame:SetMovable(letMoveFrames)
                DialogueFrame:EnableMouse(letMoveFrames)
                QuestionFrame:EnableMouse(letMoveFrames)
            end,
            get = function (info) return StoryExtended.db.profile.lockDialogueFrames end,
        },
    }
}

function StoryExtended:OnInitialize()

end

function StoryExtended:OnEnable()
    if string.sub(CLIENT_VERSION, 1, 1) ~= "1" then
        StoryExtended.db = LibStub("AceDB-3.0"):New("GlobalStoryExtendedDB", defaults, false)
        LibStub("AceConfig-3.0"):RegisterOptionsTable("StoryExtended_options", options)
        StoryExtended.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("StoryExtended_options", "StoryExtended")
    --  LibStub("AceConfig-3.0"):RegisterOptionsTable("StoryExtended_general", general)
    --	StoryExtended.generalframe = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("StoryExtended_general", "General", "StoryExtended")

        local profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(StoryExtended.db)
        LibStub("AceConfig-3.0"):RegisterOptionsTable("StoryExtended_Profiles", profile)
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions("StoryExtended_Profiles", "Profiles", "StoryExtended")

        StoryExtended:RegisterChatCommand("se", "SlashCommand")
        StoryExtended:RegisterChatCommand("storyextended", "SlashCommand")
        HideUIOption = StoryExtended.db.profile.HideUIOption
        lockDialogueFrames = StoryExtended.db.profile.lockDialogueFrames
        letMoveFrames = not lockDialogueFrames and not lockedFramesHelper
        --HideUIOption = StoryExtended.db.profile.HideUIOption
        -- Called when the addon is enabled
    end
end

function StoryExtended:OnDisable()
    -- Called when the addon is disabled
end  

-- Ace3 functions End


function checkLoadDataAddons()
    local playerName = UnitName("player")
    for i = 1, GetNumAddOns() do
        local name = GetAddOnInfo(i)
        if GetAddOnMetadata(i, "X-StoryExtendedData-Parent") == "StoryExtended" then
            local dataAddon = {
                dataAddonName = name,
                dataAddonVersion = GetAddOnMetadata(name, "Version"),
                databaseVersion = GetAddOnMetadata(name, "X-StoryExtended-Data-Version"),
                webAppVersion = GetAddOnMetadata(name, "X-StoryExtended-WebApp-Version"),
                dataAddonTitle = GetAddOnMetadata(name, "Title") or name,
                dataAddonPriority = GetAddOnMetadata(name, "X-StoryExtended-Priority"),
            }
            dialogueDataAddons.availableDataAddons[name] = dataAddon
            table.insert(dialogueDataAddons.availableDataAddonsOrdered, dataAddon)
            EnableAddOn(dataAddon.dataAddonName)
            LoadAddOn(dataAddon.dataAddonName)
            -- local dial = GetDialogueData()
            -- print(dial[1].Name)
        end
    end
end

checkLoadDataAddons()

-- Add Characters/Events etc. to a list for faster retrieval - Dunno if I should keep this
-- for key, value in pairs(Dialogues) do
--     local currentDialogueExtractor = Dialogues[key]
--     table.insert(NamesWithDialogue, currentDialogueExtractor.Name)
-- end

-- For saving the Character names as numeric values because SavedVariables doesnt like non-numeric values as index
local function hashString(str)
    -- if CLIENT_VERSION == "1.16.5" then
    --     local sum = 0
    --     for i = 1, len(str) do
    --         sum = sum + string.byte(str, i)
    --     end
    --     return sum
    -- else
    --     print(CLIENT_VERSION)
        local sum = 0
        for i = 1, string.len(str) do
            sum = sum + string.byte(str, i)
        end
        return sum
    -- end
end

-- Hide the UI (if the option is set)
local function HideUI()
    TalkStoryButton:Hide()
    if HideUIOption == true then
        MinimapCluster:Hide()
        PlayerFrame:Hide()
        TargetFrame:Hide()
        MainMenuBarArtFrame:Hide()
        MainMenuExpBar:Hide()
        MultiCastActionBarFrame:Hide()
        ChatFrame1:Hide()
        TotemFrame:Hide()
        VerticalMultiBarsContainer:Hide()
        MultiBarLeft:Hide()
        ChatFrameMenuButton:Hide()
        ChatFrameChannelButton:Hide()
        WatchFrame:Hide()
        StanceBarFrame:Hide()
    end
end
-- function to show the UI again after having hidden it (if the option is set)
local function ShowUI()
    TalkStoryButton:Show()
    if HideUIOption == true then
        MinimapCluster:Show()
        PlayerFrame:Show()
        if UnitName("target") ~= nil then
            TargetFrame:Show()
        end
        MainMenuBarArtFrame:Show()
        MainMenuExpBar:Show()
        MultiCastActionBarFrame:Show()
        ChatFrame1:Show()
        TotemFrame:Show()
        VerticalMultiBarsContainer:Show()
        MultiBarLeft:Show()
        ChatFrameMenuButton:Show()
        ChatFrameChannelButton:Show()
        WatchFrame:Show()
        StanceBarFrame:Show()
    end
end

function StoryExtended:OnShutdown()
    -- save the current profile before the addon is unloaded
    StoryExtended.db:ProfileChanged(StoryExtended.db:GetCurrentProfile())
end

-- Function that saves data into SavedVariables
local function StoryExtended_OnEvent(self, event, addonName)
    -- wow 1.12 saves a tad bit differently into SavedVariables
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then
        if event == "ADDON_LOADED" and addonName == "StoryExtended" then
            if not StoryExtendedDB then
                StoryExtendedDB = {}
            end
        end
    else
        if event == "ADDON_LOADED" and addonName == "StoryExtended" then
            -- Initialize the StoryExtendedDB table with defaults
            if not StoryExtendedDB then
                StoryExtendedDB = {}
            end
            -- Load saved database if it exists
            if SavedStoryExtendedDB then
                StoryExtendedDB = SavedStoryExtendedDB
            end
        elseif event == "PLAYER_LOGOUT" then
            if StoryExtendedDB then
                SavedStoryExtendedDB = StoryExtendedDB
            end
        end
    end
end
--END


-- Workaround for storing completed Quests for wow 1.12
--      WoW 1.12 does not have functionality for checking a QuestID for its QuestComplete status
--      It also does not have a function to get a quest ID from anything
--      I borrowed the Questlist from pfQuest to use it as a lookup table for the QuestIDs
--      Depending on if Shagu wants to give out this list or not I am either going to make my own or make his Addon a dependency
--
-- Function for getting Quest ID
local function getCurrentQuestID(questName)
local foundQuestID
for id, loc in pairs(pfDB["quests"]["enUS"]) do                                     -- Searching the pfDB for the completed quest name
    locText = loc["T"]                                                              -- "T" is the Title of the quest which I check against the input quest name
    if locText == questName then
        foundQuestID = id                                                           -- the keys of this table are the id's
    end
end
return foundQuestID
end

-- Mark the quest as finished in the SavedVariables
function markQuestFinished(questId)
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then
        if not StoryExtendedDB[99999] then                                          -- The table keys are numericals so I chose a high number for the QuestList
            StoryExtendedDB[99999] = {}                                             -- Create the table if it doesn't exist
        end
        StoryExtendedDB[99999][questId] = true                                      -- Write the questID and set it to true
    end
end

-- Save the original QuestRewardCompleteButton function into a variable for later use
local originalQuestRewardCompleteButton_OnClick
originalQuestRewardCompleteButton_OnClick = QuestRewardCompleteButton_OnClick

-- Overwritten Complete Quest btn function
function customQuestRewardCompleteButton_OnClick() 
	local rewardTitle = GetTitleText();                                             -- Get Quest Text from Title
    local finishedQuestId = getCurrentQuestID(rewardTitle)                          -- Call function to get Quest ID
    markQuestFinished(finishedQuestId)                                              -- Mark Quest ID as finished in SavedVariables
    originalQuestRewardCompleteButton_OnClick()                                     -- Call original Quest Complete function
end
-- Overwrite Complete Quest button 
QuestRewardCompleteButton_OnClick = customQuestRewardCompleteButton_OnClick

-- If players want or have to set a quest to finished manually
local function ManualQuestFinish(questID)
    if not StoryExtendedDB[99999] then
        StoryExtendedDB[99999] = {}
    end
    StoryExtendedDB[99999][questID] = true
end
ManualQuestFinish(4641)

-- End of storing completed Quests for wow 1.12 workaround

-- Create a list of all NPC with dialgue
local function createNameList()
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then
        for _, dataAddon in pairs(dialogueDataAddons.registeredDataAddons) do
            local dialogueData = dataAddon.GetDialogue
            local checkDialogues = dialogueData
            for _, dialogData in ipairs(checkDialogues) do
                if not string.find(table.concat(nameList, ","), dialogData.Name) then
                    table.insert(nameList, dialogData.Name)
                end
            end
        end
    else
        --check which data addon to use
        for name, dataAddon in pairs(dialogueDataAddons.registeredDataAddons) do
            local dialogueData = dataAddon.GetDialogue
            local checkDialogues = dialogueData
            for key, value in pairs(checkDialogues) do
                if not table.concat(nameList, ","):find(checkDialogues[key].Name) then
                    table.insert(nameList, checkDialogues[key].Name)
                end
            end
        end
    end
end

-- Helper Frame to make StoryExtended_OnEvent listen to events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", StoryExtended_OnEvent)
--END

-- Create a frame to hold the dialogue
--
-- Create the frame itself with graphics
if string.sub(CLIENT_VERSION, 1, 1) == "1" then
    local DialogueFrame = CreateFrame("Frame", "DialogueFrame", UIParent)
    DialogueFrame:SetWidth(600)
    DialogueFrame:SetHeight(150)
    DialogueFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 100)
    if HideUIOption == true then
        DialogueFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 50)
    end
    DialogueFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    DialogueFrame:SetBackdropColor(0, 0, 0, 1)
    DialogueFrame:SetMovable(letMoveFrames)
    DialogueFrame:EnableMouse(letMoveFrames)
    DialogueFrame:RegisterForDrag("LeftButton")
    DialogueFrame:SetScript("OnDragStart", DialogueFrame.StartMoving)
    DialogueFrame:SetScript("OnDragStop", DialogueFrame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "DialogueFrame")                                   -- Close with ESC key
    DialogueFrame:SetScript("OnHide", function(self)                            -- Show TalkStoryBtn again (only needed when closing with ESC key)
        TalkStoryButton:Show()
    end)
else
    local DialogueFrame = CreateFrame("Frame", "DialogueFrame", UIParent, "BackdropTemplate")
    DialogueFrame:SetWidth(600)
    DialogueFrame:SetHeight(150)
    DialogueFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 100)
    if HideUIOption == true then
        DialogueFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 50)
    end
    DialogueFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    DialogueFrame:SetBackdropColor(0, 0, 0, 1)
    DialogueFrame:SetMovable(letMoveFrames)
    DialogueFrame:EnableMouse(letMoveFrames)
    DialogueFrame:RegisterForDrag("LeftButton")
    DialogueFrame:SetScript("OnDragStart", DialogueFrame.StartMoving)
    DialogueFrame:SetScript("OnDragStop", DialogueFrame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "DialogueFrame")                                   -- Close with ESC key
    DialogueFrame:SetScript("OnHide", function(self)                            -- Show TalkStoryBtn again (only needed when closing with ESC key)
        TalkStoryButton:Show()
    end)
end

-- Create a text label and set its properties
local DialogueText = DialogueFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
DialogueText:SetPoint("TOPLEFT", DialogueFrame, "TOPLEFT", 16, -16)
DialogueText:SetPoint("BOTTOMRIGHT", DialogueFrame, "BOTTOMRIGHT", -16, 16)
DialogueText:SetJustifyH("LEFT")
DialogueText:SetFont(DialogueText:GetFont(), 20)

-- Have to omit "BackdropTemplate" for wow 1.12
if string.sub(CLIENT_VERSION, 1, 1) == "1" then
    -- WOW 1.12
    -- Create a question frame for the dialogue questions
    local QuestionFrame = CreateFrame("Frame", "QuestionFrame", UIParent)
    QuestionFrame:SetWidth(300)
    QuestionFrame:SetHeight(200)
    QuestionFrame:SetPoint("RIGHT", UIParent, "RIGHT", -100, -100)
    QuestionFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    QuestionFrame:SetBackdropColor(0, 0, 0, 1)
    QuestionFrame:SetMovable(letMoveFrames)
    QuestionFrame:EnableMouse(letMoveFrames)
    QuestionFrame:RegisterForDrag("LeftButton")
    QuestionFrame:SetScript("OnDragStart", QuestionFrame.StartMoving)
    QuestionFrame:SetScript("OnDragStop", QuestionFrame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "QuestionFrame")
    -- Create a text label and set its properties
    local QuestionText = QuestionFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal", "BackdropTemplate")
    QuestionText:SetPoint("CENTER", QuestionFrame, "CENTER", 0, 0)
   -- QuestionText:SetPoint("BOTTOMRIGHT", QuestionFrame, "BOTTOMRIGHT", -16, 16)
    QuestionText:SetJustifyH("CENTER")
    QuestionText:SetFont(QuestionText:GetFont(), 20)
else
    -- NEW WoW
    -- Create a question frame for the dialogue questions
    local QuestionFrame = CreateFrame("Frame", "QuestionFrame", UIParent, "BackdropTemplate")
    QuestionFrame:SetWidth(300)
    QuestionFrame:SetHeight(200)
    QuestionFrame:SetPoint("RIGHT", UIParent, "RIGHT", -100, -100)
    QuestionFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    QuestionFrame:SetBackdropColor(0, 0, 0, 1)
    QuestionFrame:SetMovable(letMoveFrames)
    QuestionFrame:EnableMouse(letMoveFrames)
    QuestionFrame:RegisterForDrag("LeftButton")
    QuestionFrame:SetScript("OnDragStart", QuestionFrame.StartMoving)
    QuestionFrame:SetScript("OnDragStop", QuestionFrame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "QuestionFrame")
    -- Create a text label and set its properties
    local QuestionText = QuestionFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal", "BackdropTemplate")
    QuestionText:SetPoint("TOPLEFT", DialogueFrame, "TOPLEFT", 16, -16)
    QuestionText:SetPoint("BOTTOMRIGHT", DialogueFrame, "BOTTOMRIGHT", -16, 16)
    QuestionText:SetJustifyH("LEFT")
    QuestionText:SetFont(QuestionText:GetFont(), 20)
end

-- Create 4 question buttons within the Question Frame
local QuestionButtons = {}
for i = 1, 4 do
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then
        local QuestionButton = CreateFrame("Button", "QuestionButton"..i, UIParent)
        QuestionButton:SetWidth(QuestionFrame:GetWidth() * 0.93)
        QuestionButton:SetHeight(QuestionFrame:GetHeight() * 0.75 / 4)
        QuestionButton:SetText(" ")
        QuestionButton:SetFrameStrata("HIGH")
        QuestionButton:SetFont("Fonts\\FRIZQT__.TTF", 14)
        QuestionButton:SetHighlightFontObject("GameFontHighlightLarge")
        QuestionButton:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        QuestionButton:SetBackdropColor(0, 0, 0, 1)
        QuestionButton:SetBackdropBorderColor(1, 1, 1, 1)
        local text = QuestionButton:GetFontString()
        text:SetPoint("CENTER", QuestionButton, "CENTER")
        text:SetTextColor(1, 1, 1)
        QuestionButtons[i] = QuestionButton
        tinsert(UISpecialFrames, "QuestionButton"..i)
    else
        local QuestionButton = CreateFrame("Button", "QuestionButton"..i, UIParent, "BackdropTemplate")
        QuestionButton:SetSize(QuestionFrame:GetWidth() * 0.93, QuestionFrame:GetHeight() * 0.75 / 4)
        QuestionButton:SetText(" ")
        QuestionButton:SetFrameStrata("HIGH")
        QuestionButton:SetNormalFontObject("GameFontNormalLarge")
        QuestionButton:SetHighlightFontObject("GameFontHighlightLarge")
        QuestionButton:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        QuestionButton:SetBackdropColor(0, 0, 0, 1)
        QuestionButton:SetBackdropBorderColor(1, 1, 1, 1)
        local text = QuestionButton:GetFontString()
        text:SetPoint("CENTER")
        text:SetTextColor(1, 1, 1)
        QuestionButtons[i] = QuestionButton
        tinsert(UISpecialFrames, "QuestionButton"..i)
    end
end
QuestionButtons[1]:SetPoint("TOPLEFT", QuestionFrame, "TOPLEFT", 10, -10)
for i = 2, 4 do
    QuestionButtons[i]:SetPoint("TOPLEFT", QuestionButtons[i-1], "BOTTOMLEFT", 0, -10)
end

createNameList()
-- Add texture to name plate of NPC if they have dialogue

local DialogueMarkerIcon = nil
local targetIcon = nil
local DialogueMarkerBorder = nil
local targetIconBorder = nil
local DialogueMarkerFrame = CreateFrame("Frame", "DialogueMarkerFrame")
DialogueMarkerFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
DialogueMarkerFrame:SetScript("OnEvent", function()
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then
        if UnitExists("target") and UnitClassification("target") == "normal" then
            local name = UnitName("target")
            if string.find(table.concat(nameList, ","), name) then
                -- Add texture to TalkStoryButton
                local button = getglobal("TalkStoryButton")
                if not DialogueMarkerIcon then
                    DialogueMarkerIcon = button:CreateTexture(nil, "OVERLAY")
                    DialogueMarkerIcon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
                    DialogueMarkerIcon:SetWidth(34)
                    DialogueMarkerIcon:SetHeight(34)
                    DialogueMarkerIcon:SetPoint("LEFT", button, "RIGHT", -10, 0)
                    DialogueMarkerIcon:SetVertexColor(1, 1, 1) -- reset any tint or color changes
                    DialogueMarkerIcon:SetDrawLayer("BACKGROUND", 1) -- adjust the draw layer as needed
                    -- SetMask does not exist yet in wow 1.12
                    -- DialogueMarkerIcon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") -- set the mask texture to make the icon round
                    DialogueMarkerBorder = button:CreateTexture(nil, "BORDER")
                    DialogueMarkerBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder") -- replace with the path to your border image
                    DialogueMarkerBorder:SetWidth(65) -- adjust the width and height to match the border image size
                    DialogueMarkerBorder:SetHeight(65)
                    DialogueMarkerBorder:SetPoint("CENTER", DialogueMarkerIcon, "CENTER", 12, -15) -- set the position to match the icon
                    DialogueMarkerBorder:SetDrawLayer("BORDER")
                else
                    DialogueMarkerIcon:Show()
                    DialogueMarkerBorder:Show()
                end

                -- -- Add texture to target DialogueMarkerFrame
                if not targetIcon then
                    targetIcon = TargetFrameTextureFrame:CreateTexture(nil, "OVERLAY")
                    targetIcon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
                    targetIcon:SetWidth(26)
                    targetIcon:SetHeight(26)
                    targetIcon:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", 170, -10)
                    targetIcon:SetVertexColor(1, 1, 1) -- reset any tint or color changes
                    targetIcon:SetDrawLayer("BACKGROUND", 1) -- adjust the draw layer as needed
                    -- SetMask does not exist yet in wow 1.12
                    -- targetIcon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") -- set the mask texture to make the icon round
                    targetIconBorder = TargetFrameTextureFrame:CreateTexture(nil, "BORDER")
                    targetIconBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder") -- replace with the path to your border image
                    targetIconBorder:SetWidth(50) -- adjust the width and height to match the border image size
                    targetIconBorder:SetHeight(50)
                    targetIconBorder:SetPoint("CENTER", targetIcon, "CENTER", 10, -11) -- set the position to match the icon
                    targetIconBorder:SetDrawLayer("BORDER", 2) -- adjust the draw layer as needed
                else
                    targetIcon:Show()
                    targetIconBorder:Show()
                end
            else
                if DialogueMarkerIcon ~= nil then
                    DialogueMarkerIcon:Hide()
                    DialogueMarkerBorder:Hide()
                end
                if targetIcon ~= nil then
                    targetIcon:Hide()
                    targetIconBorder:Hide()
                end
            end
        else
            if DialogueMarkerIcon ~= nil then
                DialogueMarkerIcon:Hide()
                DialogueMarkerBorder:Hide()
            end
            if targetIcon ~= nil then
                targetIcon:Hide()
                targetIconBorder:Hide()
            end
        end
    else
        if UnitExists("target") and UnitClassification("target") == "normal" then
            local name = UnitName("target")
            if table.concat(nameList, ","):find(name) then
                -- Add texture to TalkStoryButton
                local button = getglobal("TalkStoryButton")
                if not DialogueMarkerIcon then
                    DialogueMarkerIcon = button:CreateTexture(nil, "OVERLAY")
                    DialogueMarkerIcon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
                    DialogueMarkerIcon:SetWidth(34)
                    DialogueMarkerIcon:SetHeight(34)
                    DialogueMarkerIcon:SetPoint("LEFT", button, "RIGHT", -10, 0)
                    DialogueMarkerIcon:SetVertexColor(1, 1, 1) -- reset any tint or color changes
                    DialogueMarkerIcon:SetDrawLayer("BACKGROUND", 1) -- adjust the draw layer as needed
                    DialogueMarkerIcon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") -- set the mask texture to make the icon round
                    DialogueMarkerBorder = button:CreateTexture(nil, "BORDER")
                    DialogueMarkerBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder") -- replace with the path to your border image
                    DialogueMarkerBorder:SetWidth(65) -- adjust the width and height to match the border image size
                    DialogueMarkerBorder:SetHeight(65)
                    DialogueMarkerBorder:SetPoint("CENTER", DialogueMarkerIcon, "CENTER", 12, -15) -- set the position to match the icon
                    DialogueMarkerBorder:SetDrawLayer("BORDER")
                else
                    DialogueMarkerIcon:Show()
                    DialogueMarkerBorder:Show()
                end

                -- -- Add texture to target DialogueMarkerFrame
                if not targetIcon then
                    targetIcon = TargetFrameTextureFrame:CreateTexture(nil, "OVERLAY")
                    targetIcon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
                    targetIcon:SetWidth(26)
                    targetIcon:SetHeight(26)
                    targetIcon:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", 170, -10)
                    targetIcon:SetVertexColor(1, 1, 1) -- reset any tint or color changes
                    targetIcon:SetDrawLayer("OVERLAY", 1) -- adjust the draw layer as needed
                    targetIcon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") -- set the mask texture to make the icon round
                    targetIconBorder = TargetFrameTextureFrame:CreateTexture(nil, "BORDER")
                    targetIconBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder") -- replace with the path to your border image
                    targetIconBorder:SetWidth(50) -- adjust the width and height to match the border image size
                    targetIconBorder:SetHeight(50)
                    targetIconBorder:SetPoint("CENTER", targetIcon, "CENTER", 10, -11) -- set the position to match the icon
                    targetIconBorder:SetDrawLayer("OVERLAY", 2) -- adjust the draw layer as needed
                else
                    targetIcon:Show()
                    targetIconBorder:Show()
                end
            else
                if DialogueMarkerIcon ~= nil then
                    DialogueMarkerIcon:Hide()
                    DialogueMarkerBorder:Hide()
                end
                if targetIcon ~= nil then
                    targetIcon:Hide()
                    targetIconBorder:Hide()
                end
            end
        else
            if DialogueMarkerIcon ~= nil then
                DialogueMarkerIcon:Hide()
                DialogueMarkerBorder:Hide()
            end
            if targetIcon ~= nil then
                targetIcon:Hide()
                targetIconBorder:Hide()
            end
        end
    end
end)

-- END

-- Couple of functions ahead

local currentSoundHandle
-- Function to start playing dialogue sound files
function PlayDialogue(CurrentDialogue, DatabaseName)
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then
        local audioFile = "Interface\\Addons\\"..DatabaseName.."\\audio\\"..CurrentDialogue.Name..CurrentDialogue.id..".mp3"
        --DEFAULT_CHAT_FRAME:AddMessage(audioFile)
        PlaySoundFile(audioFile)
    else
        local audioFile = "Interface\\Addons\\"..DatabaseName.."\\audio\\"..CurrentDialogue.Name..CurrentDialogue.id..".mp3"
        currentSoundHandle = select(2, PlaySoundFile(audioFile))
    end
end
--END

-- Function to stop playing current dialogue sound file
function StopDialogue(CurrentDialogue)
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then

    else
        if currentSoundHandle then
            StopSound(currentSoundHandle)
        end
    end
   -- currentSoundHandle = nil
end

-- local function IsQuestCompleted(questId)
--     local completedQuests = C_QuestLog.GetCompletedQuests()
--     for i, completedQuestId in ipairs(completedQuests) do
--         if completedQuestId == questId then
--             return true
--         end
--     end
--     return false
-- end

-- Function to set the QuestionFrame Size depending on how many questions  the dialogue has
local function QuestionButtonHider(QuestionCounter)
    local QuestionFrameHeights = {50, 100, 150, 200}
    QuestionFrameHeight = QuestionFrameHeights[QuestionCounter] * 1.10
    QuestionFrame:SetHeight(QuestionFrameHeight)
end

local function StartConditionCheck(targetName, conditionType, conditionValue)
    local playerName = UnitName("player")
    local playerLevel = UnitLevel("player")
    local npcID = hashString(targetName)
    if (conditionType == "level" and tonumber(playerLevel) >= tonumber(conditionValue)) then
        return true
    -- If the CLient version is higher than 1 (need to recheck if new classic wow is in this range) use C_QuestLog check
    elseif (string.sub(CLIENT_VERSION, 1, 1) > "1" and conditionType == "quest-id" and C_QuestLog.IsQuestFlaggedCompleted(tonumber(conditionValue))) then
        return true
    -- If the client version is 1.12 or something similar dont use C_QuestLog
    elseif (string.sub(CLIENT_VERSION, 1, 1) == "1" and conditionType == "quest-id" and StoryExtendedDB[99999][(tonumber(conditionValue))] == true) then
        return true
    -- For new WoW
    elseif (string.sub(CLIENT_VERSION, 1, 1) > "1" and conditionType == "doFirst") then
        local npcCheck, npcIdCheck = conditionValue:match("([^,]+),([^,]+)")
        local hashedNpcCheck = hashString(npcCheck)       
        if(StoryExtendedDB[hashedNpcCheck] ~= nil and StoryExtendedDB[hashedNpcCheck][npcIdCheck] ~= nil and StoryExtendedDB[hashedNpcCheck][npcIdCheck]["AlreadySeenAll"] ~= nil and StoryExtendedDB[hashedNpcCheck][npcIdCheck]["AlreadySeenAll"] == true) then
            return true
        else
            return false
        end
    -- Workaround for wow 1.12
    elseif (string.sub(CLIENT_VERSION, 1, 1) == "1" and conditionType == "doFirst") then
        local npcCheck, npcIdCheck = string.match(conditionValue, "([^,]+),([^,]+)")
        local hashedNpcCheck = hashString(npcCheck)       
        if(StoryExtendedDB[hashedNpcCheck] ~= nil and StoryExtendedDB[hashedNpcCheck][npcIdCheck] ~= nil and StoryExtendedDB[hashedNpcCheck][npcIdCheck]["AlreadySeenAll"] ~= nil and StoryExtendedDB[hashedNpcCheck][npcIdCheck]["AlreadySeenAll"] == true) then
            return true
        else
            return false
        end
    elseif (conditionType == "none") then
        return true
    else
        return false
    end

    --local lastSeenDate = StoryExtendedDB.LastSeenDays         local currentDate = date("%m/%d/%y")    <-- Something to think about. For a different dialogue a 
                                                                                                        --couple real days later for more immersion and feel of a living world

end



-- Function to update the text and buttons based on the NPC information
local function UpdateFrame(CurrentDialogue, targetName, DatabaseName)
    local npcIndexID = CurrentDialogue.id
    -- Do we have a valid NPC loaded? If not, then stop the function and hide the dialogue interface
    if CurrentDialogue == nil then
        DialogueFrame:Hide()
        for index, QuestionButton in ipairs(QuestionButtons) do
            QuestionButton:Hide()
        end
        QuestionFrame:Hide()
        ShowUI()
        return
    end
    local npcID = hashString(CurrentDialogue.Name)    
    -- if the npcID subtable does not exist yet, create it
    if not StoryExtendedDB[npcID] then
        StoryExtendedDB[npcID] = {}
    end
    if not StoryExtendedDB[npcID][npcIndexID] then
        StoryExtendedDB[npcID][npcIndexID] = {}
        StoryExtendedDB[npcID][npcIndexID]["Name"] = CurrentDialogue.Name or {}


        --testing
        for npcID, subTable in pairs(StoryExtendedDB) do
            for npcIndexID, nestedTable in pairs(subTable) do
                if type(nestedTable) == "table" then
                    for key, value in pairs(nestedTable) do
                        if key == "Name" then
                            DEFAULT_CHAT_FRAME:AddMessage("npcID: " .. npcID .. ", npcIndexID: " .. npcIndexID .. ", " .. key .. ": " .. value)
                        end
                    end
                end
            end
        end





    end  

    if StoryExtendedDB[npcID] ~= nil and StoryExtendedDB[npcID][npcIndexID] ~= nil and StoryExtendedDB[npcID][npcIndexID].didOnce1 ~= nil then            --This is only important for zone changed triggered one time narration
        if StoryExtendedDB[npcID][npcIndexID].didOnce1 == "true" then
            DialogueFrame:Hide()
            QuestionFrame:Hide()
            ShowUI()
            return
        end
    end
    DialogueText:SetText(CurrentDialogue.Text)        
    if CurrentDialogue.UseAudio == "true" then
        PlayDialogue(CurrentDialogue, DatabaseName)
    end
    -- Set the button labels and enable/disable them based on the button information
    local QuestionCounter = 0
    local dialogueEnds = false
    -- Setup loop for the 4 dialogue choice buttons
    for i = 1, 4 do
        -- Setting up variables
        local nameConvert = {"First", "Second", "Third", "Fourth"}          -- Stupid workaround because I am bad at naming variables
        local ButtonName = nameConvert[i].."Answer"
        local doOnce = "DoOnce"..i
        local didOnce = "didOnce"..i
        local AlreadySeenAll = "AlreadySeenAll"
        local AlreadySeen = "AlreadySeen"..i
        local GoToID = "GoToID"..i
        local btnConditionType
        local btnConditionValue
        local conditionCheck = false
        -- Variables End
        -- If doOnce does not exist yet in the dialogue ID under the current NPC we have to create it and set its sibling value didOnce to false
        if StoryExtendedDB[npcID] ~= nil and StoryExtendedDB[npcID][npcIndexID] ~= nil and StoryExtendedDB[npcID][npcIndexID][doOnce] == nil then
            StoryExtendedDB[npcID][npcIndexID][doOnce] = CurrentDialogue[doOnce]
            StoryExtendedDB[npcID][npcIndexID][didOnce] = "false"
        end
        -- Loop through our current dialogue database
        for key, value in pairs(Dialogues) do
            -- Look for the Dialogue ID that fits our GoToID (so the ID of the dialogue this player choice leads to) and take its conditionType and conditionValue
            if (tonumber(Dialogues[key].id) == tonumber(CurrentDialogue[GoToID])) then
                btnConditionType = Dialogues[key].ConditionType
                btnConditionValue = Dialogues[key].ConditionValue
                -- if it has a condition we check for it and set conditionCheck to either true or false
                if (btnConditionType ~= "none") then
                    conditionCheck = StartConditionCheck(CurrentDialogue.Name, btnConditionType, btnConditionValue)
                else
                    conditionCheck = true
                end
            -- if this dialogue choice would end the conversation (-1) skip the conditionCheck
            elseif (tonumber(CurrentDialogue[GoToID]) == -1) then
                conditionCheck = true
            end
        end
        -- Check if the player choice is not empty and that the condition Check (based on the dialogue conditions) was passed
        if CurrentDialogue[ButtonName] ~= "" and conditionCheck == true then
            -- If the StoryExtendedDB for this character exists and didOnce is set to false: continue (didOnce is set to true if this is a one time player choice and has already been clicked before)
        --    if StoryExtendedDB[npcID] ~= nil and StoryExtendedDB[npcID][CurrentID] ~= nil and StoryExtendedDB[npcID][CurrentID][didOnce] ~= nil and StoryExtendedDB[npcID][CurrentID][didOnce] == "false" then
            if StoryExtendedDB[npcID][npcIndexID][didOnce] == "false" then
                -- Reveal the question button (player choice)
                QuestionButtons[i]:Show()
                -- To keep track of how many valid player choices we have activated
                QuestionCounter = QuestionCounter + 1
                -- Set the text of the question buttons to the text of the player choice 1-4
                QuestionButtons[i]:SetText(CurrentDialogue[ButtonName])
                -- Check if the player choice has already been seen before / clicked before. If so its colored grey
                if (StoryExtendedDB[npcID] ~= nil and StoryExtendedDB[npcID][npcIndexID] ~= nil and StoryExtendedDB[npcID][npcIndexID][AlreadySeen] ~= nil and StoryExtendedDB[npcID][npcIndexID][AlreadySeen] == true) then
                    QuestionButtons[i]:GetFontString():SetTextColor(0.66, 0.66, 0.66)
                else
                    QuestionButtons[i]:GetFontString():SetTextColor(1, 1, 1)
                end

                -- Activate the On Button Click functionality and set it up
                QuestionButtons[i]:SetScript("OnClick", function()
                    -- Set the SavedVariables dialogue ID to AlreadySeen (so we can check if it has been seen and should be seen again)
                    StoryExtendedDB[npcID][npcIndexID][AlreadySeen] = StoryExtendedDB[npcID][npcIndexID][AlreadySeen] or true
                    StoryExtendedDB[npcID][npcIndexID][AlreadySeenAll] = StoryExtendedDB[npcID][npcIndexID][AlreadySeenAll] or true
                    -- Check if DoOnce is set for this dialogue choice. If so then set the didOnce to true
                    if StoryExtendedDB[npcID][npcIndexID][doOnce] == "true" then
                        StoryExtendedDB[npcID][npcIndexID][didOnce] = "true"
                    end
                    -- convert the string value of GoToID1-4 to int and if it is -1 then set dialogueEnds to true (-1 -> dialogue ends) 
                    if tonumber(CurrentDialogue[GoToID]) == -1 then
                        dialogueEnds = true
                    end
                    -- Stop the dialogue mp3 playback if there is any
                    StopDialogue(CurrentDialogue)
                    -- The GoToID1-4 becomes our NextID to grab our dialogue from
                    NextID = CurrentDialogue[GoToID]
                    -- Update Dialogue function handles grabbing the next dialogue file
                    UpdateDialogue(CurrentDialogue, NextID, dialogueEnds, DatabaseName)
                end)
                -- Enable clicking the Question Buttons
                QuestionButtons[i]:Enable()
            else
                -- Whole block is for deactivating the question buttons for empty dialogue choices
                QuestionButtons[i]:SetText("")
                QuestionButtons[i]:SetScript("OnClick", nil)
                QuestionButtons[i]:Disable()
                QuestionButtons[i]:Hide()
            end
        else
            -- Whole block is for deactivating the question buttons for empty dialogue choices
            QuestionButtons[i]:SetText("")
            QuestionButtons[i]:SetScript("OnClick", nil)
            QuestionButtons[i]:Disable()
            QuestionButtons[i]:Hide()
        end
        -- Our for loop goes up to 4, so on the last loop we run the QuestionButtoNHider function (which hides frame elements for empty dialogue choices)
        if i == 4 then
            QuestionButtonHider(QuestionCounter)
        end
    end
end
--END


-- Helper Function to save the current/next dialogue into the savedVariables
function UpdateDialogue(Dialogue, NextID, dialogueEnds, DatabaseName)
    local savedName = Dialogue.Name
    local npcID = hashString(Dialogue.Name)
    if dialogueEnds ~= true then
        CurrentID = tonumber(NextID)
        -- Iterate through each element in the table
        
        for i, dialogue in ipairs(Dialogues) do
            idCheck = tostring(CurrentID)
            -- Check if the current element's id matches the id we are looking for
            if dialogue.id == idCheck then
                -- If it matches, save the current element to the Dialogue variable
                CurrentDialogue = dialogue
                -- Exit the loop since we have found the element we are looking for
                break
            end
        end


        -- CurrentDialogue = Dialogues[CurrentID]

        UpdateFrame(CurrentDialogue, nil, DatabaseName)
        NextID = nil
    else
        DialogueFrame:Hide()
        for index, QuestionButton in ipairs(QuestionButtons) do
            QuestionButton:Hide()
        end
        QuestionFrame:Hide()
        ShowUI()
        CurrentID = StoryExtendedDB[npcID][targetName]
        dialogueEnds = false
        NextID = nil
    end
end
--END

-- Function to check if the players target is an NPC with Dialogue
local function IsNPC(targetName)
    local npcID = hashString(CurrentDialogue.Name)
    if targetName ~= nil and StoryExtendedDB[npcID][targetName] == nil then
        for keys, value in pairs(NamesWithDialogue) do
            if NamesWithDialogue[keys] == targetName then
                return true
            end
        end
    -- for key, value in pairs(Dialogues) do
    --     if Dialogues[key].Name == targetName and Dialogues[key].Greeting == true then
    --         CurrentID = Dialogues[key]
    --     end
    -- end
    StoryExtendedDB[npcID][targetName] = CurrentID
    elseif targetName ~= nil and StoryExtendedDB[npcID][targetName] ~= nil then
        CurrentID = StoryExtendedDB[npcID][targetName]
        return true
    end
    return false, nil
end
--END



local function chooseDatabase(targetName)
    --check which data addon to use
    for name, dataAddon in pairs(dialogueDataAddons.registeredDataAddons) do
        local addonName = name
        local dialogueData = dataAddon.GetDialogue
        local checkDialogues = dialogueData
        local foundNpcDialogues = {}
        local internalConditionSuccess = false
        local conditionSuccess = false
        local count = 0
        for key, value in pairs(checkDialogues) do

            -- Workaround for wow 1.12
            count = 0
            for key, value in pairs(foundNpcDialogues) do
            count = count + 1
            end
            --workaround for wow 1.12

            if (targetName == checkDialogues[key].Name and checkDialogues[key].Greeting == "true") then
                internalConditionSuccess = StartConditionCheck(targetName, checkDialogues[key].ConditionType, checkDialogues[key].ConditionValue)
                -- If we have a condition success we have to check if any dialogues further down the line are also eligable
                -- if (conditionSuccess == false) then
                --     return nil
                -- end
                if (internalConditionSuccess == true) then
                    foundNpcDialogues[count+1] = checkDialogues[key]
                    CurrentID = tonumber(checkDialogues[key].id)
                    conditionSuccess = true
                end
            end
        end
        if (foundNpcDialogues ~= nil and count > 0) then
            return dialogueData, conditionSuccess, addonName
        end
    end
    return nil, false
end

-- Create a button to trigger the conversation
local function TalkStoryFunc(zone_input)
    getCurrentQuests()
    local targetName
    local isZone = false
    if zone_input ~= nil then
        targetName = zone_input
        zone_input = nil
        isZone = true
    else
        targetName = UnitName("target")
    end
    --local isNPC = IsNPC(targetName)
    local isCondition
    local DatabaseName
    Dialogues, isCondition, DatabaseName = chooseDatabase(targetName)
    if isCondition then
        -- If the target NPC is already in the Saved Variables then we take its last Dialogue ID

        -- Iterate through each element in the table
        for i, dialogue in ipairs(Dialogues) do
            idCheck = tostring(CurrentID)
            -- Check if the current element's id matches the id we are looking for
            if dialogue.id == idCheck then
                -- If it matches, save the current element to the CurrentDialogue variable
                CurrentDialogue = dialogue
                -- Exit the loop since we have found the element we are looking for
            end
        end

        if not isZone then
            local isInRange = CheckInteractDistance("target", 3)
            if isInRange then
                DialogueFrame:Show()
                QuestionFrame:Show()
                -- Hide all UI elements but the dialogue UI, if the option is activated
                HideUI()
                -- The player is close enough to talk to the target
                UpdateFrame(CurrentDialogue, nil, DatabaseName)

            else
                -- The player is too far away to talk to the target
                UIErrorsFrame:AddMessage("Not in range.", 1.0, 0.1, 0.1, 1.0, 3)
            end
        else
            -- The player is close enough to talk to the target
            -- Hide all UI elements but the dialogue UI, if the option is activated 
            HideUI()
            DialogueFrame:Show()
            QuestionFrame:Show()
            UpdateFrame(CurrentDialogue, targetName, DatabaseName)

        end
        --CurrentDialogue = Dialogues[CurrentID]
    end
end

-- The button that triggers the start of conversations - want to add a slash command as well
local TalkStoryButton = CreateFrame("Button", "TalkStoryButton", UIParent, "UIPanelButtonTemplate")
TalkStoryButton:SetPoint("CENTER", UIParent, "CENTER", 450, -300)
TalkStoryButton:SetWidth(120)
TalkStoryButton:SetHeight(25)
TalkStoryButton:SetText("Talk Story")
TalkStoryButton:SetScript("OnClick", function() TalkStoryFunc(nil) end)
-- END

-- starts the start dialogue function after zone change (if there is a valid dialogue to be shown there)
local function OnZoneChanged()
    local subzone = GetSubZoneText()
    -- For now we do the database lookup for the subzone everytime you enter a subzone. Will change this later
    local ZoneInDatabase
    local ZoneInDatabase2
    ZoneInDatabase, ZoneInDatabase2 = chooseDatabase(subzone)
    if (ZoneInDatabase ~= nil) then
        C_Timer.After(2, function() TalkStoryFunc(subzone) end)
    end
end

-- Register the zone change events to our OnZoneChanged script
local zoneChangeFrame = CreateFrame("FRAME")
zoneChangeFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
zoneChangeFrame:RegisterEvent("ZONE_CHANGED")
zoneChangeFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneChangeFrame:SetScript("OnEvent", OnZoneChanged)

function StoryExtended:SlashCommand(msg)
    if(msg == "talk") then
        TalkStoryFunc()
    end
end

-- Hide the frame when the player clicks outside of it
--DialogueFrame:SetScript("OnMouseDown", function() DialogueFrame:StopMovingOrSizing() end)
DialogueFrame:Hide()
QuestionFrame:Hide()
for index, QuestionButton in ipairs(QuestionButtons) do
    QuestionButton:Hide()
end


--END