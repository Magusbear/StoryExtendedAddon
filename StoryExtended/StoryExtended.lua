StoryExtended = LibStub("AceAddon-3.0"):NewAddon("StoryExtended", "AceConsole-3.0", "AceTimer-3.0")

StoryExtendedDB = {}                                                            -- The save variable which is written into SavedVariables
CurrentID = 1                                                                   -- the current dialogue ID (the ID for which text is shown currently)
local NextID                                                                    -- The ID for the upcoming Dialogue
local HideUIOption = false
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
local playVoices = true                                                         -- Option: Can voice over be played
local showNpcPortrait = true                                                    -- Option: Show NPC Portraits
local animateNpcPortrait = true                                                 -- Option: animate the NPC Portraits
local currentSoundHandle                                                        -- holds a reference of the playing dialogue audio (New WoW only)

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
local AceTimer
-- print(CLIENT_VERSION)
if string.sub(CLIENT_VERSION, 1, 1) == "1" then
    -- Client version is 1.12 or below
else
    -- Client version is higher than 1.12
end


dialogueDataAddons =
{
    availableDataAddons = {},         -- A list of data addons that were found by the main addon
    -- availableDataAddonsOrdered = {},  -- 
    registeredDataAddons = {},        -- A list of data addons that registered themselves with the main addon after being activated
}


-- Register the data addons

function StoryExtended:Register(name, dataAddon)
    assert(not dialogueDataAddons.registeredDataAddons[name], format([[Data addon "%s" already registered]], name))     -- Check if the addon is already registered
    dialogueDataAddons.registeredDataAddons[name] = dataAddon                                                           -- Add the data addon data to the array under its name
    --dataAddonVersion = GetAddOnMetadata(name, "Version")
end



-- Load the saved variables from disk when the addon is loaded
LoadAddOn("StoryExtended")


-- Ace3 functions Begin

local defaults = {                                                                  -- the Default values for the options menu
	profile = {
		HideUIOption = false,                                                       -- Hide the UI when starting a dialogue
        lockDialogueFrames = true,                                                  -- prevent dialogue frames from being dragged
        playNpcVoiceOver = true,                                                    -- play audio voice overs
        showNpcPortraitOption = true,                                               -- show a 3D portrait of NPC
        animateNpcPortraitOption = true,                                            -- Play emotes with the 3D portrait
	},
}

-- Ace3 Options menu for New WoW
local options = {                                                                                   -- Atm everything is in the main menu page
    name = "StoryExtended",                                                                         -- there is no formatting, just a list of toggles
    handler = StoryExtended,                                                                        -- should be made prettier at some point I guess
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
        playNpcVoiceOver = {
            type = 'toggle',
            name = 'Play Voice Over',
            desc = 'Play sound voice overs for NPC.',
            set = function (info, value)
                StoryExtended.db.profile.playNpcVoiceOver = value
                playVoices = StoryExtended.db.profile.playNpcVoiceOver
            end,
            get = function (info) return StoryExtended.db.profile.playNpcVoiceOver end,
        },
        showNpcPortraitOption = {
            type = 'toggle',
            name = 'Show NPC Portrait',
            desc = 'Shows a 3D NPC Portrait during Dialogue.',
            set = function (info, value)
                StoryExtended.db.profile.showNpcPortraitOption = value
                showNpcPortrait = StoryExtended.db.profile.showNpcPortraitOption
            end,
            get = function (info) return StoryExtended.db.profile.showNpcPortraitOption end,
        },
        animateNpcPortraitOption = {
            type = 'toggle',
            name = 'Animate NPC Portrait',
            desc = 'Animates the 3D NPC Portrait with emotes.',
            set = function (info, value)
                StoryExtended.db.profile.animateNpcPortraitOption = value
                animateNpcPortrait = StoryExtended.db.profile.animateNpcPortraitOption
            end,
            get = function (info) return StoryExtended.db.profile.animateNpcPortraitOption end,
        },
    }
}
--END Ace3 Options menu for New WoW

-- Ace3 function for when Addon is initialized. Fired too early for my uses. The SavedVariables aren't loaded yet when this fires
function StoryExtended:OnInitialize()

end

-- Ace3 function for when Addon is enabled
function StoryExtended:OnEnable()
    -- New WoW code         -- I'm not sure if ace3 options menu works in WoW 1.12 or how to set it up there
    if string.sub(CLIENT_VERSION, 1, 1) ~= "1" then
        StoryExtended.db = LibStub("AceDB-3.0"):New("GlobalStoryExtendedDB", defaults, false)           -- Register the options DB
        -- Register the main options menu
        LibStub("AceConfig-3.0"):RegisterOptionsTable("StoryExtended_options", options)
        StoryExtended.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("StoryExtended_options", "StoryExtended")

        local profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(StoryExtended.db)           -- Gets optionstable DB
        -- Register the profile tab in the options menu
        LibStub("AceConfig-3.0"):RegisterOptionsTable("StoryExtended_Profiles", profile)
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions("StoryExtended_Profiles", "Profiles", "StoryExtended")

        StoryExtended:RegisterChatCommand("se", "SlashCommand")                                 -- Slash command /se
        StoryExtended:RegisterChatCommand("storyextended", "SlashCommand")                      -- Slash command /storyextended     both start a dialogue with target
        -- Getting the SavedVariables from our Options DB and setting them -> load options basically
        HideUIOption = StoryExtended.db.profile.HideUIOption
        lockDialogueFrames = StoryExtended.db.profile.lockDialogueFrames
        letMoveFrames = not lockDialogueFrames and not lockedFramesHelper
        playVoices = StoryExtended.db.profile.playNpcVoiceOver
        showNpcPortrait = StoryExtended.db.profile.showNpcPortraitOption
        animateNpcPortrait = StoryExtended.db.profile.animateNpcPortraitOption
    end
end

-- Ace3 function for when Addon is disabled. Not in use atm
function StoryExtended:OnDisable()

end  

-- Ace3 functions End

-- Check for data addons in the Interface/AddOns folder
function checkLoadDataAddons()
    for i = 1, GetNumAddOns() do                                                            -- Go through each addon in folder
        local name = GetAddOnInfo(i)                                                        -- get its addon/folder name
        if GetAddOnMetadata(i, "X-StoryExtendedData-Parent") == "StoryExtended" then        -- Does.toc specify that its a StoryExtended child?
            local dataAddon = {                                                             -- create the dataAddon table with info about data addon
                dataAddonName = name,                                                       -- name of data addon
                dataAddonVersion = GetAddOnMetadata(name, "Version"),                       -- data addon version (set by web app)
                databaseVersion = GetAddOnMetadata(name, "X-StoryExtended-Data-Version"),   -- database version (set by web app), important for compatibility if new...
                                                                                            -- variables are added later on
                webAppVersion = GetAddOnMetadata(name, "X-StoryExtended-WebApp-Version"),   -- web app version (set by web app), might be useful for compatibility
                dataAddonPriority = GetAddOnMetadata(name, "X-StoryExtended-Priority"),     -- dataAddonPriority for when the same NPC is used by more than one...
                                                                                            -- data addon. Set through web app
            }
            dialogueDataAddons.availableDataAddons[name] = dataAddon                        -- added to list of available data addons
            -- table.insert(dialogueDataAddons.availableDataAddonsOrdered, dataAddon)
            EnableAddOn(dataAddon.dataAddonName)                                            -- Enable and load every data addon...
            LoadAddOn(dataAddon.dataAddonName)                                              -- so they can self register
        end
    end
end
checkLoadDataAddons()

-- Add Characters/Events etc. to a list for faster retrieval - Dunno if I should keep this
-- for key, value in pairs(Dialogues) do
--     local currentDialogueExtractor = Dialogues[key]
--     table.insert(NamesWithDialogue, currentDialogueExtractor.Name)
-- end

-- For saving the Character names as numeric values because SavedVariables doesnt like non-numeric values as index...
-- is what I though after struggling with SavedVariables at first. I don't think that is actually the case but I'm keeping it in for now
-- Never touch a running system and all that...
local function hashString(str)
        local sum = 0
        for i = 1, string.len(str) do
            sum = sum + string.byte(str, i)
        end
        return sum
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

-- save the current profile before the addon is unloaded
function StoryExtended:OnShutdown()
    StoryExtended.db:ProfileChanged(StoryExtended.db:GetCurrentProfile())
end

-- Function that saves data into SavedVariables
local function StoryExtended_OnEvent(self, event, addonName)
    -- wow 1.12 code. 1.12 seems to save a tad bit differently into SavedVariables
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then
        if event == "ADDON_LOADED" and addonName == "StoryExtended" then
            if not StoryExtendedDB then
                StoryExtendedDB = {}
            end
        end
    -- New WoW code
    else
        if event == "ADDON_LOADED" and addonName == "StoryExtended" then            -- When the StoryExtended Addons loads:
            if not StoryExtendedDB then
                StoryExtendedDB = {}                                                -- Initialize the StoryExtendedDB table if it does not exist
            end
            if SavedStoryExtendedDB then
                StoryExtendedDB = SavedStoryExtendedDB                              -- Load saved database if it exists
            end
        elseif event == "PLAYER_LOGOUT" then                                        -- on logout
            if StoryExtendedDB then
                SavedStoryExtendedDB = StoryExtendedDB                              -- save StoryExtendedDB
            end
        end
    end
end

-- Helper Frame to make StoryExtended_OnEvent listen to events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", StoryExtended_OnEvent)



-- Workaround for storing completed Quests for wow 1.12
--      WoW 1.12 does not have functionality for checking a QuestID for its QuestComplete status
--      It also does not have a function to get a quest ID from anything
--      I borrowed the Questlist from pfQuest to use it as a lookup table for the QuestIDs
--      Depending on if Shagu wants to give out this list or not I am either going to make my own or make their Addon a dependency
--
-- Function for getting Quest ID
local function getCurrentQuestID(questName)
local foundQuestID = 0
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
if string.sub(CLIENT_VERSION, 1, 1) == "1" then
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
end
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
    -- WoW 1.12 Code
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then
        for _, dataAddon in pairs(dialogueDataAddons.registeredDataAddons) do               -- Goes through each data addon dialogue DB...
            local dialogueData = dataAddon.GetDialogue                                      -- looks for the namefield and checks if that name...
            local checkDialogues = dialogueData                                             -- is already present in the nameList
            for _, dialogData in ipairs(checkDialogues) do                                  -- if not it adds that name to the namelist
                if not string.find(table.concat(nameList, ","), dialogData.Name) then
                    table.insert(nameList, dialogData.Name)
                end
            end
        end
    -- New WoW Code
    else
        --check which data addon to use
        for name, dataAddon in pairs(dialogueDataAddons.registeredDataAddons) do            -- Functions like the 1.12 code but uses...
            local dialogueData = dataAddon.GetDialogue                                      -- "table.oncat...:find" instead of "string.find(table.concat)"
            local checkDialogues = dialogueData
            for key, value in pairs(checkDialogues) do
                if not table.concat(nameList, ","):find(checkDialogues[key].Name) then
                    table.insert(nameList, checkDialogues[key].Name)
                end
            end
        end
    end
end



-- Create a frame to hold the dialogue
--
-- Create the frame itself with graphics
local DialogueFrame                                                                 -- declared outside of if function

-- WoW 1.12 code
if string.sub(CLIENT_VERSION, 1, 1) == "1" then
    DialogueFrame = CreateFrame("Frame", "DialogueFrame", UIParent)
-- New WoW Code (only difference is the use of "BackdropTemplate" in New WoW)
else
    DialogueFrame = CreateFrame("Frame", "DialogueFrame", UIParent, "BackdropTemplate")
end

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

-- Create a text label and set its properties
local DialogueText = DialogueFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
DialogueText:SetPoint("TOPLEFT", DialogueFrame, "TOPLEFT", 16, -16)
DialogueText:SetPoint("BOTTOMRIGHT", DialogueFrame, "BOTTOMRIGHT", -16, 16)
DialogueText:SetJustifyH("LEFT")
DialogueText:SetFont(DialogueText:GetFont(), 20)


-- Create a question frame for the dialogue questions
local QuestionFrame                                                                 -- declared outside of if function
-- WoW 1.12 Code
if string.sub(CLIENT_VERSION, 1, 1) == "1" then
    QuestionFrame = CreateFrame("Frame", "QuestionFrame", UIParent)
-- New WoW Code (only difference is the use of "BackdropTemplate" in New WoW)
else
    QuestionFrame = CreateFrame("Frame", "QuestionFrame", UIParent, "BackdropTemplate")
end
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
QuestionText:SetJustifyH("CENTER")
QuestionText:SetFont(QuestionText:GetFont(), 20)

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


-- Create 4 question buttons within the Question Frame                              -- Question Button might be a bit confusing as a name
local QuestionButtons = {}                                                          -- these are the player dialogue choices
for i = 1, 4 do
    -- WoW 1.12 Code
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
    -- New WoW Code     -- Lots of repetitions but leaving it as is for now for readability
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
QuestionButtons[1]:SetPoint("TOPLEFT", QuestionFrame, "TOPLEFT", 10, -10)                           -- Anchor Dialogue Option 1 to the Dialogue Options (question) frame
for i = 2, 4 do                                                                                     -- Anchor each of the other buttons to the button above it
    QuestionButtons[i]:SetPoint("TOPLEFT", QuestionButtons[i-1], "BOTTOMLEFT", 0, -10)              -- and move it down a bit
end


-- NPC 3D Portrait frame creation
-- the following code creates the 3D portrait and drives its animations
local talkingHead                                                                           -- have to declare outside of the if statement
local model                                                                                 -- have to declare outside of the if statement
-- WoW 1.12 code
if string.sub(CLIENT_VERSION, 1, 1) == "1" then
    talkingHead = CreateFrame("Frame", "SETalkingHeadFrame", UIParent)                      -- WoW 1.12 hasnt got a "BackdropTemplate"
    model = CreateFrame("DressUpModel", "SETalkingHeadModel", talkingHead)                  -- DressUpModel is a special frame that can hold a 3D model
-- New WoW Code
else
    talkingHead = CreateFrame("Frame", "SETalkingHeadFrame", UIParent, "BackdropTemplate")  -- New WoW needs the "BackdropTemplate"
    model = CreateFrame("PlayerModel", "SETalkingHeadModel", talkingHead)                   -- DressUpModel is a special frame that can hold a 3D model
end
tinsert(UISpecialFrames, "SETalkingHeadFrame")                                              -- Close with ESC key

-- from https://github.com/mrthinger/wow-voiceover, added the animLength                    -- A lookup table for the model IDs and talk animation lengths
local modelToFileID = {                                                                     -- If anims other than "talk" are used they would have to be...
    ["Original"] = {                                                                        -- added to this list with their corresponding length
                                                                                            -- Anim [60]: Talk emote
                                                                                            -- Anim [1]: Dance emote
                                                                                            -- to add new animation use ",[animID] = lengthOfAnim," for each model
        ["interface/buttons/talktomequestion_white"]                = {id = 130737, animId = { [60] = 0, [1] = 0 },},
        ["character/bloodelf/female/bloodelffemale"]                = {id = 116921, animId = { [60] = 0, [1] = 0 },},
        ["character/bloodelf/male/bloodelfmale"]                    = {id = 117170, animId = { [60] = 0, [1] = 0 },},
        ["character/broken/female/brokenfemale"]                    = {id = 117400, animId = { [60] = 0, [1] = 0 },},
        ["character/broken/male/brokenmale"]                        = {id = 117412, animId = { [60] = 0, [1] = 0 },},
        ["character/draenei/female/draeneifemale"]                  = {id = 117437, animId = { [60] = 0, [1] = 0 },},
        ["character/draenei/male/draeneimale"]                      = {id = 117721, animId = { [60] = 0, [1] = 0 },},
        ["character/dwarf/female/dwarffemale"]                      = {id = 118135, animId = { [60] = 0, [1] = 0 },},
        ["character/dwarf/female/dwarffemale_hd"]                   = {id = 950080, animId = { [60] = 0, [1] = 0 },},
        ["character/dwarf/female/dwarffemale_npc"]                  = {id = 950080, animId = { [60] = 0, [1] = 0 },},
        ["character/dwarf/male/dwarfmale"]                          = {id = 118355, animId = { [60] = 0, [1] = 0 },},
        ["character/dwarf/male/dwarfmale_hd"]                       = {id = 878772, animId = { [60] = 0, [1] = 0 },},
        ["character/dwarf/male/dwarfmale_npc"]                      = {id = 878772, animId = { [60] = 0, [1] = 0 },},
        ["character/felorc/female/felorcfemale"]                    = {id = 118652, animId = { [60] = 0, [1] = 0 },},
        ["character/felorc/male/felorcmale"]                        = {id = 118653, animId = { [60] = 0, [1] = 0 },},
        ["character/felorc/male/felorcmaleaxe"]                     = {id = 118654, animId = { [60] = 0, [1] = 0 },},
        ["character/felorc/male/felorcmalesword"]                   = {id = 118667, animId = { [60] = 0, [1] = 0 },},
        ["character/foresttroll/male/foresttrollmale"]              = {id = 118798, animId = { [60] = 0, [1] = 0 },},
        ["character/gnome/female/gnomefemale"]                      = {id = 119063, animId = { [60] = 0, [1] = 0 },},
        ["character/gnome/female/gnomefemale_hd"]                   = {id = 940356, animId = { [60] = 0, [1] = 0 },},
        ["character/gnome/female/gnomefemale_npc"]                  = {id = 940356, animId = { [60] = 0, [1] = 0 },},
        ["character/gnome/male/gnomemale"]                          = {id = 119159, animId = { [60] = 0, [1] = 0 },},
        ["character/gnome/male/gnomemale_hd"]                       = {id = 900914, animId = { [60] = 0, [1] = 0 },},
        ["character/gnome/male/gnomemale_npc"]                      = {id = 900914, animId = { [60] = 0, [1] = 0 },},
        ["character/goblin/female/goblinfemale"]                    = {id = 119369, animId = { [60] = 0, [1] = 0 },},
        ["character/goblin/male/goblinmale"]                        = {id = 119376, animId = { [60] = 0, [1] = 0 },},
        ["character/goblinold/male/goblinoldmale"]                  = {id = 119376, animId = { [60] = 0, [1] = 0 },},
        ["character/human/female/humanfemale"]                      = {id = 119563, animId = { [60] = 0, [1] = 0 },},
        ["character/human/female/humanfemale_hd"]                   = {id = 1000764, animId = { [60] = 0, [1] = 0 },},
        ["character/human/female/humanfemale_npc"]                  = {id = 1000764, animId = { [60] = 0, [1] = 0 },},
        ["character/human/male/humanmale"]                          = {id = 119940, animId = { [60] = 0, [1] = 0 },},
        ["character/human/male/humanmale_cata"]                     = {id = 119940, animId = { [60] = 0, [1] = 0 },},
        ["character/human/male/humanmale_hd"]                       = {id = 1011653, animId = { [60] = 0, [1] = 0 },},
        ["character/human/male/humanmale_npc"]                      = {id = 1011653, animId = { [60] = 0, [1] = 0 },},
        ["character/icetroll/male/icetrollmale"]                    = {id = 232863, animId = { [60] = 0, [1] = 0 },},
        ["character/naga_/female/naga_female"]                      = {id = 120263, animId = { [60] = 0, [1] = 0 },},
        ["character/naga_/male/naga_male"]                          = {id = 120294, animId = { [60] = 0, [1] = 0 },},
        ["character/nightelf/female/nightelffemale"]                = {id = 120590, animId = { [60] = 0, [1] = 0 },},
        ["character/nightelf/female/nightelffemale_hd"]             = {id = 921844, animId = { [60] = 0, [1] = 0 },},
        ["character/nightelf/female/nightelffemale_npc"]            = {id = 921844, animId = { [60] = 0, [1] = 0 },},
        ["character/nightelf/male/nightelfmale"]                    = {id = 120791, animId = { [60] = 0, [1] = 0 },},
        ["character/nightelf/male/nightelfmale_hd"]                 = {id = 974343, animId = { [60] = 0, [1] = 0 },},
        ["character/nightelf/male/nightelfmale_npc"]                = {id = 974343, animId = { [60] = 0, [1] = 0 },},
        ["character/northrendskeleton/male/northrendskeletonmale"]  = {id = 233367, animId = { [60] = 0, [1] = 0 },},
        ["character/orc/female/orcfemale"]                          = {id = 121087, animId = { [60] = 1.900, [1] = 0 },},
        ["character/orc/female/orcfemale_npc"]                      = {id = 121087, animId = { [60] = 1.900, [1] = 0 },},
        ["character/orc/male/orcmale"]                              = {id = 121287, animId = { [60] = 1.900, [1] = 2.000 },},
        ["character/orc/male/orcmale_hd"]                           = {id = 917116, animId = { [60] = 0, [1] = 0 },},
        ["character/orc/male/orcmale_npc"]                          = {id = 917116, animId = { [60] = 0, [1] = 0 },},
        ["character/scourge/female/scourgefemale"]                  = {id = 121608, animId = { [60] = 0, [1] = 0 },},
        ["character/scourge/female/scourgefemale_hd"]               = {id = 997378, animId = { [60] = 0, [1] = 0 },},
        ["character/scourge/female/scourgefemale_npc"]              = {id = 997378, animId = { [60] = 0, [1] = 0 },},
        ["character/scourge/male/scourgemale"]                      = {id = 121768, animId = { [60] = 0, [1] = 0 },},
        ["character/scourge/male/scourgemale_hd"]                   = {id = 959310, animId = { [60] = 0, [1] = 0 },},
        ["character/scourge/male/scourgemale_npc"]                  = {id = 959310, animId = { [60] = 0, [1] = 0 },},
        ["character/skeleton/male/skeletonmale"]                    = {id = 121942, animId = { [60] = 0, [1] = 0 },},
        ["character/taunka/male/taunkamale"]                        = {id = 233878, animId = { [60] = 0, [1] = 0 },},
        ["character/tauren/female/taurenfemale"]                    = {id = 121961, animId = { [60] = 0, [1] = 0 },},
        ["character/tauren/female/taurenfemale_hd"]                 = {id = 986648, animId = { [60] = 0, [1] = 0 },},
        ["character/tauren/female/taurenfemale_npc"]                = {id = 986648, animId = { [60] = 0, [1] = 0 },},
        ["character/tauren/male/taurenmale"]                        = {id = 122055, animId = { [60] = 0, [1] = 0 },},
        ["character/tauren/male/taurenmale_hd"]                     = {id = 968705, animId = { [60] = 0, [1] = 0 },},
        ["character/tauren/male/taurenmale_npc"]                    = {id = 968705, animId = { [60] = 0, [1] = 0 },},
        ["character/troll/female/trollfemale"]                      = {id = 122414, animId = { [60] = 0, [1] = 0 },},
        ["character/troll/female/trollfemale_hd"]                   = {id = 1018060, animId = { [60] = 0, [1] = 0 },},
        ["character/troll/female/trollfemale_npc"]                  = {id = 1018060, animId = { [60] = 0, [1] = 0 },},
        ["character/troll/male/trollmale"]                          = {id = 122560, animId = { [60] = 0, [1] = 0 },},
        ["character/troll/male/trollmale_hd"]                       = {id = 1022938, animId = { [60] = 0, [1] = 0 },},
        ["character/troll/male/trollmale_npc"]                      = {id = 1022938, animId = { [60] = 0, [1] = 0 },},
        ["character/tuskarr/male/tuskarrmale"]                      = {id = 122738, animId = { [60] = 0, [1] = 0 },},
        ["character/vrykul/male/vrykulmale"]                        = {id = 122815, animId = { [60] = 0, [1] = 0 },},
    },
    ["HD"] = {
        ["character/scourge/female/scourgefemale"]                  = {id = 997378, animId = { [60] = 0, [1] = 0 },},
    },
}
local function CleanupModelName(model)                                          -- Found this workaround here: https://github.com/mrthinger/wow-voiceover
    model = string.lower(model)                                                 -- make string lowercase
    model = string.gsub(model, "\\", "/")                                       -- Replace backslashes with forward slashes
    model = string.gsub(model, "%.m2", "")                                      -- remove the literal string .m2
    model = string.gsub(model, "%.mdx", "")                                     -- remove the literal string .mdx
    return model                                                                -- return cleaned up string
end

-- WoW 1.12 code
if string.sub(CLIENT_VERSION, 1, 1) == "1" then                                 -- Found this workaround here: https://github.com/mrthinger/wow-voiceover
    function GetModelFileID()                                                   -- GetModelFileID is a native function in new wow, this replicates it somewhat
        local model = model:GetModel()                                          -- get model string path of portrait model
        if model and type(model) == "string" then                               -- if it exists and is a string
            model = CleanupModelName(model)                                     -- remove file type from path
            return modelToFileID["Original"][model].id                          -- return model ID from lookup table
        end
    end
end
-- END WoW 1.12 Code


function GetAnimLength(inputAnimId)                                             -- Using a lookup table to get the animLength for the input Animation
    -- WoW 1.12 code
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then                             -- 
        local model = model:GetModel()                                          -- WoW 1.12 has a function to get the model path...
        model = CleanupModelName(model)                                         -- ...need to remove file extensions...
        return modelToFileID["Original"][model]["animId"][inputAnimId]          -- then use model path to lookup the AnimLength for input animation
    -- END WoW 1.12 Code
    -- New WoW Code
    else
        local animLength = 0                                                    -- New WoW has removed t he GetModel function
        local modelId = model:GetModelFileID()                                  -- I could not find any way to get the model file path
        for k, v in pairs(modelToFileID["Original"]) do                         -- Which is why I'm looping through the table looking for the NPC id
            if v.id == modelId then                                             --
                animLength = v.animId[inputAnimId]                              -- Then I just read the value for animLength
            end
        end
        return animLength
    end
    -- END New WoW Code
end


local function HasModelLoaded(modelCheck)
    -- WoW 1.12 code
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then
        local model = model:GetModel()                                              -- get model string path of portrait model
        return model and type(model) == "string" and GetModelFileID() ~= 130737     -- is model not nil, is it a string, and is it not ID 130737 (the default model)
    -- END WoW 1.12 Code
    -- New WoW Code
    else                                                                            -- New WoW has a GetModelFileID, so we dont need any workarounds
        return model:GetModelFileID() and model:GetModelFileID() ~= 130737          -- is it a model and is it not the default model
    end
    -- END New WoW Code
end

function playAnimation(sequenceID, animLoops)                           -- SequenceID = Animation ID, animLoops = number of times the anim loops
                                                                        -- AnimLoops depends on the length of the npc dialogue (not the sound file if it exists)
    -- WoW 1.12 code
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then
        local sequenceDuration = GetAnimLength(sequenceID)*1000         -- Using lookup table to get AnimLength
        local animTimer = 0                                             -- helper var to count how long the anim has played already
        local animLoopCount =  0                                        -- helper var to count how many anims were played
        local function OnUpdate(frame, elapsed)                         -- Anims in WoW 1.12 are weird. Apparently you need to play each frame individually?
                                                                        -- like stop motion, only faster and thereby smooth again
                                                                        --  that's why we need an OnUpdate to Set the Sequence Time rapidly
            animTimer = animTimer + (arg1*1000)                         -- count up the animTimer using arg1 (wow 1.12 uses arg1..X to get arguments) *1000 = in ms
            model:SetSequenceTime(sequenceID, animTimer)                -- set our animation to frame/time of the animTimer
            if animTimer > sequenceDuration then                        -- the sequenceDuration is the length of the anim and we got that from a lookup table...
                                                                        -- again, no easy way to grab that data. wow 1.12 strikes again
                animLoopCount = animLoopCount + 1                       -- increment our loopcount
                if animLoopCount >= animLoops then                      -- if we reach our max Loop count
                    model:SetScript("OnUpdate", nil)                    -- break/stop OnUpdate if we have played all anim loops
                else                                                    -- WoW 1.12 will automatically go back to idle anim, which is neat
                    animTimer = 0                                       -- Reset animTimer if we havent reached our max loops yet
                end
            end
        end
        model:SetScript("OnUpdate", OnUpdate)                           -- start the OnUpdate
    -- END WoW 1.12 code    

    -- New WoW Code
    else
        local sequenceDuration = GetAnimLength(sequenceID)*1000         -- Using lookup table to get AnimLength
        local animTimer = 0                                             -- helper var to count how long the anim has played already
        local animLoopCount = 0                                         -- helper var to count how many anims were played
        local function OnUpdate(frame, elapsed)                         -- New WoW models just stop animation completely after a SetAnimation ran through
                                                                        -- so I need to time it right to loop it. The idle anim (0) however runs indefinetly
            if animLoopCount <= animLoops then                          -- as long as we havent reached our loop max count
                if (GetTime() - animTimer)*1000 >= sequenceDuration then    -- First time will always go through, after that it checks for elapsed time...
                    animTimer = GetTime()                               -- through GetTime - animTimer = elapsed time 
                    model:SetAnimation(sequenceID)                              -- set the animID/sequenceID
                    animLoopCount = animLoopCount + 1                   -- increment the loop count
                end
            else
                model:SetAnimation(0)                                   -- setting SetAnimation(0) plays the idle, this runs indefinetly...
                model:SetScript("OnUpdate", nil)                        -- so no need for further checks, OnUpdate can be stopped
            end
        end
        model:SetScript("OnUpdate", OnUpdate)                           -- start the OnUpdate
    end
    -- END New WoW Code
end



local function createTalkingHead()                                      -- The function only changes the settings of the already created frames
    -- Create the frame                                                 --
    talkingHead:SetWidth(128)                                           -- Width 
    talkingHead:SetHeight(128)                                          -- and height of the parent frame for the 3d model
    talkingHead:SetPoint("BOTTOM", UIParent, "BOTTOM", -360, 110)       -- Put it right next to the dialogue frame

    -- Set the background and border of the frame
    talkingHead:SetBackdrop({                                           -- Sets the background and border for the parent frame of the 3d model
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",          -- background file
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",            -- border file
        tile = true, tileSize = 16, edgeSize = 16,                      -- players should be able to change these
        insets = { left = 0.5, right = 0.5, top = 0.5, bottom = 0.5 }   -- would be nice to have the option
    })                                                                  -- thoughts for later
    talkingHead:SetBackdropBorderColor(1, 1, 1)                         -- border color
    talkingHead:SetBackdropColor(0, 0, 0, 0.5)                          -- background color

    -- Setup model and model window
    model:SetPoint("CENTER", talkingHead, "CENTER")             -- Center the model on the talkingHead frame (which holds our border and background)
    model:SetWidth(120)                                         -- set the model frames size to slightly smaller than the border frame...
    model:SetHeight(120)                                        -- so that it does not go over the border texture
    model:SetUnit("target")                                     -- Set the model to that of our target npc
    -- placeholder code goes here!                              -- if we don't have a target npc, we use a placeholder
    --model:SetPosition(0, 0, 0)
    -- WoW 1.12 settings
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then
        model:SetRotation(math.rad(10))                         -- Rotation seems to be the only setting working before full model initialisation
        local function OnUpdate(frame, elapsed)                 -- Need to wait for model init before we can set the other model settings
            if HasModelLoaded(model) then                       -- custom function if model ID is valid and not the default model 
                                                                -- mostly taken from https://github.com/mrthinger/wow-voiceover 
                model:SetModelScale(4)                          -- Setting size and...
                model:SetPosition(0, 0, -2.8)                   -- setting Position to get a portrait close up shot of the model
                model:SetPosition(0, 0, -5)
                talkingHead:SetScript("OnUpdate", nil)          -- after setting our desired "camera" settings stop the OnUpdate
            end
        end
        -- Set the OnUpdate script
        talkingHead:SetScript("OnUpdate", OnUpdate)
    -- END WoW 1.12 settings

    -- New WoW settings
    else
        model:SetPortraitZoom(1.0)                              -- For New WoW we can just set the Portrait Zoom level. Nice and easy
       -- model:SetPosition(0, 0, 0)
    -- END New WoW settings

    end
    -- Show the frame
    talkingHead:Show()                                          -- Lastly show the frame after setting it up
end


-- Call the createNameList Function
createNameList()

-- WoW 1.12 compat function
local function isInNameList(name)
    local nameFound = false
    -- WoW 1.12 Code
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then
        if string.find(table.concat(nameList, ","), name) then
            nameFound = true
        end
    -- New WoW Code
    else
        if table.concat(nameList, ","):find(name) then
            nameFound = true
        end
    end
    return nameFound
end

-- Add texture to name plate of NPC if they have dialogue
local DialogueMarkerIcon = nil
local targetIcon = nil
local DialogueMarkerBorder = nil
local targetIconBorder = nil
local DialogueMarkerFrame = CreateFrame("Frame", "DialogueMarkerFrame")
DialogueMarkerFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
DialogueMarkerFrame:SetScript("OnEvent", function()
-- Only do if it is a friendly target
if UnitExists("target") and UnitClassification("target") == "normal" then
    local name = UnitName("target")
    if isInNameList(name) == true then
        -- Add texture to TalkStoryButton
        local button = getglobal("TalkStoryButton")
        if not DialogueMarkerIcon then
            DialogueMarkerIcon = button:CreateTexture(nil, "OVERLAY")
            DialogueMarkerIcon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
            DialogueMarkerIcon:SetWidth(34)
            DialogueMarkerIcon:SetHeight(34)
            DialogueMarkerIcon:SetPoint("LEFT", button, "RIGHT", -10, 0)
            DialogueMarkerIcon:SetVertexColor(1, 1, 1)
            DialogueMarkerIcon:SetDrawLayer("BACKGROUND", 1)
            DialogueMarkerBorder = button:CreateTexture(nil, "BORDER")
            -- New WoW Code                                                                         -- WoW 1.12 does not have the SetMask function
            if string.sub(CLIENT_VERSION, 1, 1) ~= "1" then
                DialogueMarkerIcon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")      -- set the mask texture to make the icon round 
            end
            DialogueMarkerBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
            DialogueMarkerBorder:SetWidth(65)
            DialogueMarkerBorder:SetHeight(65)
            DialogueMarkerBorder:SetPoint("CENTER", DialogueMarkerIcon, "CENTER", 12, -15)
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
            targetIcon:SetVertexColor(1, 1, 1)
            targetIconBorder = TargetFrameTextureFrame:CreateTexture(nil, "BORDER")
            targetIconBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
            targetIconBorder:SetWidth(50)
            targetIconBorder:SetHeight(50)
            targetIconBorder:SetPoint("CENTER", targetIcon, "CENTER", 10, -11)
                        
            -- WoW 1.12 Code             -- WoW 1.12 does not have the SetMask function
            if string.sub(CLIENT_VERSION, 1, 1) == "1" then
                targetIcon:SetDrawLayer("BACKGROUND", 1)
                targetIconBorder:SetDrawLayer("BORDER", 2)
            -- New WoW Code
            else
                targetIcon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")              -- set the mask texture to make the icon round 
                targetIcon:SetDrawLayer("OVERLAY", 1)                                               -- OVERLAY Draw Layer only exists in new WoW
                targetIconBorder:SetDrawLayer("OVERLAY", 2)                                         -- OVERLAY Draw Layer only exists in new WoW
            end
            
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
end)

-- END



-- Function to start playing dialogue sound files
function PlayDialogue(CurrentDialogue, DatabaseName)
    -- WoW 1.12 Code                                                                                -- WoW 1.12 does not have sound handles, the audio can't be stopped
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then                                                 -- without workarounds, which aren't implemented yet
        local audioFile = "Interface\\Addons\\"..DatabaseName.."\\audio\\"..CurrentDialogue.Name..CurrentDialogue.id..".mp3"
        PlaySoundFile(audioFile)
    -- New WoW Code                                                                                 -- New WoW can play sound and give it a handle to stop that sound
    else
        local audioFile = "Interface\\Addons\\"..DatabaseName.."\\audio\\"..CurrentDialogue.Name..CurrentDialogue.id..".mp3"
        currentSoundHandle = select(2, PlaySoundFile(audioFile))                                    -- Plays sound and sets handle
    end
end
--END

-- Function to stop playing current dialogue sound file
function StopDialogue(CurrentDialogue)
    -- WoW 1.12 Code
    if string.sub(CLIENT_VERSION, 1, 1) == "1" then
        -- does nothing in WoW 1.12 atm
    -- New WoW Code
    else
        if currentSoundHandle then
            StopSound(currentSoundHandle)                                                           -- Stops the sound using its sound handle
        end
    end
end

-- Function to set the QuestionFrame Size depending on how many questions  the dialogue has
local function QuestionButtonHider(QuestionCounter)
    local QuestionFrameHeights = {50, 100, 150, 200}                                                    -- using hardcoded values which probably need to be dynamic
    QuestionFrameHeight = QuestionFrameHeights[QuestionCounter] * 1.10                                  -- changing this later when I find the time
    QuestionFrame:SetHeight(QuestionFrameHeight)
end

local function StartConditionCheck(targetName, conditionType, conditionValue)                           -- Checking every condition set with the web app 
    local playerName = UnitName("player")                                                               -- Setting up variables
    local playerLevel = UnitLevel("player")
    local npcID = hashString(targetName)

    if (conditionType == "level" and tonumber(playerLevel) >= tonumber(conditionValue)) then            -- Checking player level against condition
        return true

    -- New WoW Code
    elseif (string.sub(CLIENT_VERSION, 1, 1) > "1" and conditionType == "quest-id"                      -- New WoW Code:
    and C_QuestLog.IsQuestFlaggedCompleted(tonumber(conditionValue))) then                              -- Checking if Quest is finished through Quest ID directly
        return true

    -- WoW 1.12 Code
    elseif (string.sub(CLIENT_VERSION, 1, 1) == "1" and conditionType == "quest-id"                     -- WoW 1.12 Code:
    and StoryExtendedDB[99999] and StoryExtendedDB[99999][(tonumber(conditionValue))] == true) then     -- Checking the custom finished Quest table with Quest ID
        return true

    -- New WoW Code
    elseif (string.sub(CLIENT_VERSION, 1, 1) > "1" and conditionType == "doFirst") then                 -- New WoW Code:
        local npcCheck, npcIdCheck = conditionValue:match("([^,]+),([^,]+)")                            -- Checks the SavedVariables if player has already seen
        local hashedNpcCheck = hashString(npcCheck)                                                     -- this specific dialogue. If so don't show it again
        if(StoryExtendedDB[hashedNpcCheck] ~= nil and StoryExtendedDB[hashedNpcCheck][npcIdCheck] ~= nil-- Works for starting a dialogue, as well as for showing... 
        and StoryExtendedDB[hashedNpcCheck][npcIdCheck]["AlreadySeenAll"] ~= nil                        -- dialogue choices, or not.    
        and StoryExtendedDB[hashedNpcCheck][npcIdCheck]["AlreadySeenAll"] == true) then
            return true
        else
            return false
        end

    -- WoW 1.12 Code
    elseif (string.sub(CLIENT_VERSION, 1, 1) == "1" and conditionType == "doFirst") then                -- WoW 1.12 code
        local npcCheck, npcIdCheck = string.match(conditionValue, "([^,]+),([^,]+)")                    -- Same as New WoW code except for usage of string.match     
        local hashedNpcCheck = hashString(npcCheck)                                                     -- instead of shorthand match
        if(StoryExtendedDB[hashedNpcCheck] ~= nil 
        and StoryExtendedDB[hashedNpcCheck][npcIdCheck] ~= nil 
        and StoryExtendedDB[hashedNpcCheck][npcIdCheck]["AlreadySeenAll"] ~= nil 
        and StoryExtendedDB[hashedNpcCheck][npcIdCheck]["AlreadySeenAll"] == true) then
            return true
        else
            return false
        end

    elseif (conditionType == "none") then                                                               -- if conditionType "none" is used check is automatically passed
        return true
        
    else
        return false                                                                                    -- Otherwise return false
    end

    --local lastSeenDate = StoryExtendedDB.LastSeenDays         local currentDate = date("%m/%d/%y")    <-- Something to think about. For a different dialogue a 
                                                                                                        --couple real days later for more immersion and feel of a living world

end



-- Function to update the text and buttons based on the NPC information
local function UpdateFrame(CurrentDialogue, targetName, DatabaseName, NotNPC)
    local npcIndexID = CurrentDialogue.id
    local npcID = hashString(CurrentDialogue.Name)

    if CurrentDialogue == nil then                                                          -- Hide everything and return out of the function if
        DialogueFrame:Hide()                                                                -- for some reason the dialogue table cannot be found for the NPC
        talkingHead:Hide()
        for index, QuestionButton in ipairs(QuestionButtons) do
            QuestionButton:Hide()
        end
        QuestionFrame:Hide()
        ShowUI()
        return
    end

    if not StoryExtendedDB then                                                             -- Check for the table and every subtable
        StoryExtendedDB = {}                                                                -- if they exist yet and if not create them
    end
    if not StoryExtendedDB[npcID] then
        StoryExtendedDB[npcID] = {}
    end
    if not StoryExtendedDB[npcID][npcIndexID] then
        StoryExtendedDB[npcID][npcIndexID] = {}
        StoryExtendedDB[npcID][npcIndexID]["Name"] = CurrentDialogue.Name or {}
    end  

    if StoryExtendedDB[npcID] ~= nil and StoryExtendedDB[npcID][npcIndexID] ~= nil          --If the dialogue is marked DoOnce and was already done/seen once
    and StoryExtendedDB[npcID][npcIndexID].didOnce1 ~= nil then                             -- The Dialogue UI hides and the function stops
        if StoryExtendedDB[npcID][npcIndexID].didOnce1 == "true" then
            DialogueFrame:Hide()
            QuestionFrame:Hide()
            talkingHead:Hide()
            ShowUI()
            return
        end
    end
    DialogueText:SetText(CurrentDialogue.Text)                                              -- Set the dialogue text

    if animateNpcPortrait == true and NotNPC == false then                                  -- Can be toggled in the options menu
        local animToPlay = 60                                                               -- hardcoded to talk emote (60)
        local animLoops = math.ceil(string.len(CurrentDialogue.Text) / 40)                  --calculate animLoops from dialogue text length  
        playAnimation(animToPlay,animLoops)                                                 -- play the anim (only talk supported atm), second input is the loop counter
    end

    if CurrentDialogue.UseAudio == "true" and playVoices == true then                       -- Can be toggled in the options menu
        PlayDialogue(CurrentDialogue, DatabaseName)                                         -- play the current dialogue
    end

    -- Set the button labels and enable/disable them based on the button information
    local QuestionCounter = 0
    local dialogueEnds = false

    for i = 1, 4 do                                                                         -- Setup loop for the 4 dialogue choice buttons
                                                                                            -- Setting up variables
        local nameConvert = {"First", "Second", "Third", "Fourth"}                          -- Stupid workaround because I am bad at naming variables
        local ButtonName = nameConvert[i].."Answer"
        local doOnce = "DoOnce"..i
        local didOnce = "didOnce"..i
        local AlreadySeenAll = "AlreadySeenAll"
        local AlreadySeen = "AlreadySeen"..i
        local GoToID = "GoToID"..i
        local btnConditionType
        local btnConditionValue
        local conditionCheck = false
        
        if StoryExtendedDB[npcID] ~= nil and StoryExtendedDB[npcID][npcIndexID] ~= nil      -- If doOnce does not exist yet in the dialogue ID under the...
        and StoryExtendedDB[npcID][npcIndexID][doOnce] == nil then                          -- current NPC create it...
            StoryExtendedDB[npcID][npcIndexID][doOnce] = CurrentDialogue[doOnce]            -- and set its sibling value didOnce to false    
            StoryExtendedDB[npcID][npcIndexID][didOnce] = "false"
        end

        for key, value in pairs(Dialogues) do                                               -- Loop through the current dialogue database
            if (tonumber(Dialogues[key].id) == tonumber(CurrentDialogue[GoToID])) then      -- Look for the Dialogue ID that fits the GoToID...
                btnConditionType = Dialogues[key].ConditionType                             -- (so the ID of the dialogue this player choice leads to)...
                btnConditionValue = Dialogues[key].ConditionValue                           --  and take its conditionType and conditionValue
                if (btnConditionType ~= "none") then                                        -- if it has a condition then check for it...
                    conditionCheck = StartConditionCheck(CurrentDialogue.Name,              -- and set conditionCheck to either true or false
                                            btnConditionType, btnConditionValue)
                else
                    conditionCheck = true                                                   -- if conditionType is "none" set the check to true
                end
            elseif (tonumber(CurrentDialogue[GoToID]) == -1) then                           -- if this dialogue choice would end the conversation (-1)
                conditionCheck = true                                                       -- skip the conditionCheck
            end
        end
        
        if CurrentDialogue[ButtonName] ~= "" and conditionCheck == true then                -- Check if the player choice is not empty and that the condition Check
                                                                                            -- (based on the dialogue conditions) was passed
            if StoryExtendedDB[npcID][npcIndexID][didOnce] == "false" then                  -- If the StoryExtendedDB for this character exists and didOnce is set 
                                                                                            -- to false: continue (didOnce is set to true if this is a one time player 
                                                                                            -- choice and has already been clicked before)
                QuestionButtons[i]:Show()                                                   -- Reveal the question button (player choice)
                QuestionCounter = QuestionCounter + 1                                       -- To keep track of how many valid player choices we have activated
                QuestionButtons[i]:SetText(CurrentDialogue[ButtonName])                     -- Set the text of the question buttons to the text of the player choice 1-4

                if (StoryExtendedDB[npcID] ~= nil                                           -- Check if the player choice has already been seen before / clicked before...
                and StoryExtendedDB[npcID][npcIndexID] ~= nil
                and StoryExtendedDB[npcID][npcIndexID][AlreadySeen] ~= nil 
                and StoryExtendedDB[npcID][npcIndexID][AlreadySeen] == true) then
                    QuestionButtons[i]:GetFontString():SetTextColor(0.66, 0.66, 0.66)       -- if so its colored grey
                else
                    QuestionButtons[i]:GetFontString():SetTextColor(1, 1, 1)                -- otherwise colored white
                end

                QuestionButtons[i]:SetScript("OnClick", function()                          -- Activate the On Button Click functionality and set it up
                    -- model:SetSequence(60)                                                -- Recheck: Do I need this really?    
                    StoryExtendedDB[npcID][npcIndexID][AlreadySeen] = StoryExtendedDB[npcID][npcIndexID][AlreadySeen] or true       -- Set the SavedVariables dialogue ID 
                    StoryExtendedDB[npcID][npcIndexID][AlreadySeenAll] = StoryExtendedDB[npcID][npcIndexID][AlreadySeenAll] or true -- to AlreadySeen (so we can check if 
                                                                                                                                    -- it has been seen and should be seen again)
                    
                    if StoryExtendedDB[npcID][npcIndexID][doOnce] == "true" then            -- Check if DoOnce is set for this dialogue choice. If so then set the didOnce to true
                        StoryExtendedDB[npcID][npcIndexID][didOnce] = "true"
                    end
                    if tonumber(CurrentDialogue[GoToID]) == -1 then                         -- convert the string value of GoToID1-4 to int 
                        dialogueEnds = true                                                 -- and if it is -1 then set dialogueEnds to true (-1 -> dialogue ends) 
                    end
                    if CurrentDialogue.UseAudio == "true" and playVoices == true then       -- Stop the dialogue mp3 playback if there is any
                        StopDialogue(CurrentDialogue)
                    end
                    NextID = CurrentDialogue[GoToID]                                        -- The GoToID 1-4 becomes our NextID to grab our dialogue from
                    UpdateDialogue(CurrentDialogue, NextID, dialogueEnds, DatabaseName, NotNPC) -- Update Dialogue function handles grabbing the next dialogue file
                end)

                QuestionButtons[i]:Enable()                                                 -- Enable clicking the Question Buttons
            else
                QuestionButtons[i]:SetText("")                                              -- Deactivate the question buttons for empty dialogue choices
                QuestionButtons[i]:SetScript("OnClick", nil)
                QuestionButtons[i]:Disable()
                QuestionButtons[i]:Hide()
            end
        else
            QuestionButtons[i]:SetText("")                                                  -- Deactivate the question buttons for empty dialogue choices
            QuestionButtons[i]:SetScript("OnClick", nil)
            QuestionButtons[i]:Disable()
            QuestionButtons[i]:Hide()
        end
        if i == 4 then                                                                      -- The for loop goes up to 4, so on the last loop run the 
            QuestionButtonHider(QuestionCounter)                                            -- QuestionButtoNHider function (which hides frame elements for empty dialogue choices)
        end
    end
end



-- Helper Function to save the current/next dialogue into the savedVariables
function UpdateDialogue(Dialogue, NextID, dialogueEnds, DatabaseName, notNPC)
    local savedName = Dialogue.Name
    local npcID = hashString(Dialogue.Name)
    if dialogueEnds ~= true then
        CurrentID = tonumber(NextID)        
        for i, dialogue in ipairs(Dialogues) do                                             -- Iterate through each element in the table
            idCheck = tostring(CurrentID)
            if dialogue.id == idCheck then                                                  -- Check if the current element's id matches the id being looked for
                CurrentDialogue = dialogue                                                  -- If it matches, save the current element to the Dialogue variable
                break                                                                       -- Exit the loop
            end
        end
        UpdateFrame(CurrentDialogue, nil, DatabaseName, notNPC)                                     -- Update the dialogue interface with the next dialogue fragment
        NextID = nil
    else                                                                                    -- if dialogueEnds=true, stop the dialogue and hide the frames
        DialogueFrame:Hide()
        for index, QuestionButton in ipairs(QuestionButtons) do
            QuestionButton:Hide()
        end
        QuestionFrame:Hide()
        talkingHead:Hide()
        ShowUI()
        CurrentID = StoryExtendedDB[npcID][targetName]
        dialogueEnds = false
        NextID = nil
    end
end

-- Function to check if the players target is an NPC with Dialogue
local function IsNPC(targetName)
    local npcID = hashString(CurrentDialogue.Name)
    if targetName ~= nil and StoryExtendedDB[npcID][targetName] == nil then
        for keys, value in pairs(NamesWithDialogue) do
            if NamesWithDialogue[keys] == targetName then
                return true
            end
        end
    StoryExtendedDB[npcID][targetName] = CurrentID
    elseif targetName ~= nil and StoryExtendedDB[npcID][targetName] ~= nil then
        CurrentID = StoryExtendedDB[npcID][targetName]
        return true
    end
    return false, nil
end

-- Check the databases for dialogue
local function chooseDatabase(targetName)
    for name, dataAddon in pairs(dialogueDataAddons.registeredDataAddons) do                -- loop through the registered data addons
        local addonName = name                                                              -- Setup their variables
        local dialogueData = dataAddon.GetDialogue
        local checkDialogues = dialogueData
        local foundNpcDialogues = {}
        local internalConditionSuccess = false
        local conditionSuccess = false
        local count = 0
        for key, value in pairs(checkDialogues) do                                          -- Loop through the dialogue database
            -- Workaround for wow 1.12
            count = 0                                                                       -- reset iteration every loop
            for key, value in pairs(foundNpcDialogues) do                                   -- loop through all the eligible found NPC Dialogues
            count = count + 1                                                               -- count up for every found eligible NPC dialogue
            end
            if (targetName == checkDialogues[key].Name and checkDialogues[key].Greeting == "true") then     -- if the target name is in the DB and its greeting is set to true
                internalConditionSuccess = StartConditionCheck(targetName, checkDialogues[key].ConditionType, checkDialogues[key].ConditionValue)   -- do condition check
                if (internalConditionSuccess == true) then                                  -- if the condition Check is successful 
                    foundNpcDialogues[count+1] = checkDialogues[key]                        -- add them to foundNPCDialogues
                    CurrentID = tonumber(checkDialogues[key].id)                            -- set CurrentID to found NPCs ID
                    conditionSuccess = true                                                 -- set conditionSuccess to true
                end                                                                         -- Will always return the dialogue with the highest ID which condition is true
            end
        end
        if (foundNpcDialogues ~= nil and count > 0) then                                    -- if a possible dialogue was found
            return dialogueData, conditionSuccess, addonName                                -- return its data
        end
    end
    return nil, false                                                                       -- if nothing was found return nil and false
end

-- Create a button to trigger the conversation
local function TalkStoryFunc(zone_input)                                                    -- Function for starting dialogue, can also be called by events
    local targetName
    local isZone = false
    if zone_input ~= nil then                                                               -- check if the event was triggered by a zone change
        targetName = zone_input                                                             -- if so targetName becomes the zone name
        zone_input = nil
        isZone = true
    else
        targetName = UnitName("target")                                                     -- if not, targetName is the players target
    end
    local isCondition
    local DatabaseName
    Dialogues, isCondition, DatabaseName = chooseDatabase(targetName)                       -- call chooseDatabase function to look for dialogue
    if isCondition then
        for i, dialogue in ipairs(Dialogues) do                                             -- Could do this in the chooseDatabase function already, will change at some point
            idCheck = tostring(CurrentID)                                                   -- CurrentID is set in the chooseDatabase function
            if dialogue.id == idCheck then                                                  -- Check if the current element's id matches the id being looked for
                CurrentDialogue = dialogue                                                  -- If it matches, save the current element to the CurrentDialogue variable
            end
        end

        if not isZone then                                                                  -- If the target is an NPC
            local isInRange = CheckInteractDistance("target", 3)                            -- Check if they are in range
            if isInRange then                                                               -- Show dialogue UI if they are in range
                if showNpcPortrait == true then
                    createTalkingHead()                                                     -- create 3D portrait if option is activated
                end
                DialogueFrame:Show()
                QuestionFrame:Show()
                HideUI()                                                                    -- Hide all UI elements but the dialogue UI, if the option is activated
                UpdateFrame(CurrentDialogue, nil, DatabaseName, isZone)                     -- fill dialogue UI through UpdateFrame function
            else
                UIErrorsFrame:AddMessage("Not in range.", 1.0, 0.1, 0.1, 1.0, 3)            -- show warning when player is too far away to talk to the target
            end
        else                                                                                -- if this is an event dialogue the distance check is not needed
            HideUI()                                                                        -- Hide all UI elements but the dialogue UI, if the option is activated 
            DialogueFrame:Show()
            QuestionFrame:Show()
            if showNpcPortrait == true then
                createTalkingHead()                                                         -- create 3D portrait if option is activated
            end
            UpdateFrame(CurrentDialogue, targetName, DatabaseName, isZone)                  -- fill dialogue UI through UpdateFrame function
        end
    end
end

-- The button that triggers the start of conversations
local TalkStoryButton = CreateFrame("Button", "TalkStoryButton", UIParent, "UIPanelButtonTemplate")
TalkStoryButton:SetPoint("CENTER", UIParent, "CENTER", 450, -300)
TalkStoryButton:SetWidth(120)
TalkStoryButton:SetHeight(25)
TalkStoryButton:SetText("Talk")
TalkStoryButton:SetScript("OnClick", function() TalkStoryFunc(nil) end)

-- starts the start dialogue function after zone change (if there is a valid dialogue to be shown there)
local function OnZoneChanged()                                                              -- The text is delayed a bit so it does not trigger right the millisecond you enter zone
    local subzone = GetSubZoneText()                                                        -- get subzone name
    local zoneName = GetZoneText()                                                          -- get zone name
    local foundName
    if isInNameList(zoneName) then                                                          -- check if either the zone name...
        foundName = zoneName
    else if isInNameList(subzone) then                                                      -- or subzone name is in one of the lists
        foundName = subzone                                                                 -- for now subzone has priority over zone name if both are in the name list
    end                                                                                     -- I will change this later
    if foundName then
        -- WoW 1.12 Code
        if string.sub(CLIENT_VERSION, 1, 1) == "1" then
            StoryExtended:ScheduleTimer(function() TalkStoryFunc(subzone) end, 2)          -- Have to use AceTimer in classic to delay the dialogue for a bit
        -- New WoW Code
        else
            C_Timer.After(2, function() TalkStoryFunc(subzone) end)                        -- New WoW has a timer that can be used for delay
        end
    end
end

-- Register the zone change events to the OnZoneChanged script
local zoneChangeFrame = CreateFrame("FRAME")
zoneChangeFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
zoneChangeFrame:RegisterEvent("ZONE_CHANGED")
zoneChangeFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneChangeFrame:SetScript("OnEvent", OnZoneChanged)

function StoryExtended:SlashCommand(msg)                                                    -- registers /se talk and /storyextended talk to talk to an NPC
    if(msg == "talk") then                                                                  -- makes it easy to make a talk makro and set it on a keyboard button
        TalkStoryFunc()
    end
end

-- Hide all the frames on game/addon start
DialogueFrame:Hide()
QuestionFrame:Hide()
if talkingHead then
    talkingHead:Hide()
end
for index, QuestionButton in ipairs(QuestionButtons) do
    QuestionButton:Hide()
end