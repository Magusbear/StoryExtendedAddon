-- Pretty much all functionality lies within this module. The other modules are used as crude database.
-- Dialogue.lua holds all NPCs that are interactable and points to the NPC_X.lua which exist for every interactable NPC.
-- With the amount of text and different dialogue options that exist for each NPC it makes more sense to have a single .lua for every single one.

-- Declare variables
StoryExtended = LibStub("AceAddon-3.0"):NewAddon("StoryExtended", "AceConsole-3.0")

StoryExtendedDB = {}          -- The save variable which is written into SavedVariables
CurrentID = 1                 -- the current dialogue ID (the ID for which text is shown currently)
local NextID                        -- The ID for the upcoming Dialogue
local HideUIOption = true       -- Will add this to a proper options menu later
local HiddenUIParts = {}
local NamesWithDialogue = {}
local CurrentDialogue


-- Load the saved variables from disk when the addon is loaded
LoadAddOn("StoryExtended")


-- Ace3 functions Begin
function StoryExtended:OnInitialize()
    -- Code that you want to run when the addon is first loaded goes here.
    StoryExtended:Print("Hello, world!")
    StoryExtended:SetMyMessage(info, input)
    StoryExtended:GetMyMessage(info)
  end

function StoryExtended:OnEnable()
    -- Called when the addon is enabled
end

function StoryExtended:OnDisable()
    -- Called when the addon is disabled
end  

--StoryExtended:RegisterChatCommand("talkstory", "TalkStoryFunc")

local options = {
    name = "StoryExtended",
    handler = StoryExtended,
    type = 'group',
    args = {
        msg = {
            type = 'input',
            name = 'My Message',
            desc = 'The message for my addon',
            set = 'SetMyMessage',
            get = 'GetMyMessage',
        },
    },
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("StoryExtended", options, "testslash")

function StoryExtended:GetMyMessage(info)
    return myMessageVar
end

function StoryExtended:SetMyMessage(info, input)
    myMessageVar = input
end

-- Ace3 functions End

-- Add Characters/Events etc. to a list for faster retrieval - Dunno if I should keep this
for key, value in pairs(Dialogues) do
    local currentDialogueExtractor = Dialogues[key]
    table.insert(NamesWithDialogue, currentDialogueExtractor.Name)
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
    end
end


-- Function that saves data into SavedVariables
local function StoryExtended_OnEvent(self, event, addonName)
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
        -- Save the StoryExtendedDB table to the SavedVariables file
        if StoryExtendedDB then
            SavedStoryExtendedDB = StoryExtendedDB
        end
    end
end
--END

-- Helper Frame to make StoryExtended_OnEvent listen to events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", StoryExtended_OnEvent)
--END

-- Create a frame to hold the dialogue
--
-- Create the frame itself with graphics
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
DialogueFrame:SetMovable(true)
DialogueFrame:EnableMouse(true)
DialogueFrame:RegisterForDrag("LeftButton")
DialogueFrame:SetScript("OnDragStart", DialogueFrame.StartMoving)
DialogueFrame:SetScript("OnDragStop", DialogueFrame.StopMovingOrSizing)

-- Create a text label and set its properties
local DialogueText = DialogueFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
DialogueText:SetPoint("TOPLEFT", DialogueFrame, "TOPLEFT", 16, -16)
DialogueText:SetPoint("BOTTOMRIGHT", DialogueFrame, "BOTTOMRIGHT", -16, 16)
DialogueText:SetJustifyH("LEFT")
DialogueText:SetFont(DialogueText:GetFont(), 20)


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
QuestionFrame:SetMovable(true)
QuestionFrame:EnableMouse(true)
QuestionFrame:RegisterForDrag("LeftButton")
QuestionFrame:SetScript("OnDragStart", QuestionFrame.StartMoving)
QuestionFrame:SetScript("OnDragStop", QuestionFrame.StopMovingOrSizing)
-- Create a text label and set its properties
local QuestionText = QuestionFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal", "BackdropTemplate")
QuestionText:SetPoint("TOPLEFT", DialogueFrame, "TOPLEFT", 16, -16)
QuestionText:SetPoint("BOTTOMRIGHT", DialogueFrame, "BOTTOMRIGHT", -16, 16)
QuestionText:SetJustifyH("LEFT")
QuestionText:SetFont(QuestionText:GetFont(), 20)


-- Create 4 question buttons within the Question Frame
local QuestionButtons = {}
for i = 1, 4 do
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
end
QuestionButtons[1]:SetPoint("TOPLEFT", QuestionFrame, "TOPLEFT", 10, -10)
for i = 2, 4 do
    QuestionButtons[i]:SetPoint("TOPLEFT", QuestionButtons[i-1], "BOTTOMLEFT", 0, -10)
end

-- Add texture to name plate of NPC if they have dialogue
local icon = nil
local targetIcon = nil
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:SetScript("OnEvent", function()
    if UnitExists("target") and UnitClassification("target") == "normal" then
        local name = UnitName("target")
        if name == "Gornek" then
            -- Add texture to TalkStoryButton
            local button = getglobal("TalkStoryButton")
            if not icon then
                icon = button:CreateTexture(nil, "OVERLAY")
                icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                icon:SetWidth(32)
                icon:SetHeight(32)
                icon:SetPoint("LEFT", button, "RIGHT", 5, 0)
                icon:SetTexCoord(0, 1, 0, 1)
            else
                icon:Show()
            end

            -- Add texture to target frame
            if not targetIcon then
                targetIcon = TargetFrameTextureFrame:CreateTexture(nil, "OVERLAY")
                targetIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                targetIcon:SetWidth(32)
                targetIcon:SetHeight(32)
                targetIcon:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", 65, -28)
                targetIcon:SetTexCoord(0, 1, 0, 1)
            else
                targetIcon:Show()
            end
        else
            if icon then
                icon:Hide()
            end
            if targetIcon then
                targetIcon:Hide()
            end
        end
    else
        if icon then
            icon:Hide()
        end
        if targetIcon then
            targetIcon:Hide()
        end
    end
end)
-- END

-- Couple of functions ahead

local currentSoundHandle
-- Function to start playing dialogue sound files
function PlayDialogue(CurrentDialogue)
    local audioFile = "Interface\\Addons\\StoryExtended\\audio\\Dialogue\\"..CurrentDialogue.Name.."\\"..CurrentDialogue.Name..CurrentDialogue.id..".mp3"
    currentSoundHandle = select(2, PlaySoundFile(audioFile))
end
--END

-- Function to stop playing current dialogue sound file
function StopDialogue(CurrentDialogue)
    if currentSoundHandle then
        StopSound(currentSoundHandle)
    end
    currentSoundHandle = nil
end

-- Function to set the QuestionFrame Size depending on how many questions  the dialogue has
local function QuestionButtonHider(QuestionCounter)
    local QuestionFrameHeights = {50, 100, 150, 200}
    QuestionFrameHeight = QuestionFrameHeights[QuestionCounter] * 1.10
    QuestionFrame:SetHeight(QuestionFrameHeight)
end

-- Function to update the text and buttons based on the NPC information
local function UpdateFrame(CurrentDialogue)
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
    DialogueText:SetText(CurrentDialogue.Text)
    if not StoryExtendedDB[CurrentID] then
        StoryExtendedDB[CurrentID] = StoryExtendedDB[CurrentID] or {}
        StoryExtendedDB[CurrentID]["Name"] = CurrentDialogue.Name
    end    
    
    if CurrentDialogue.UseAudio == "true" then
        PlayDialogue(CurrentDialogue)
    end
    -- Set the button labels and enable/disable them based on the button information
    local QuestionCounter = 0
    local dialogueEnds = false
    for i = 1, 4 do
        local nameConvert = {"First", "Second", "Third", "Fourth"}
        local ButtonName = nameConvert[i].."Answer"
        local doOnce = "DoOnce"..i
        local didOnce = "didOnce"..i
        if not StoryExtendedDB[CurrentID][doOnce] then
            print(CurrentDialogue.Name)
            print(CurrentDialogue.DoOnce1)
            print(doOnce)
            StoryExtendedDB[CurrentID][doOnce] = CurrentDialogue[doOnce]
            StoryExtendedDB[CurrentID][didOnce] = "false"
        end
        local GoToID = "GoToID"..i
        if CurrentDialogue[ButtonName] ~= "" and StoryExtendedDB[CurrentID][didOnce] == "false" then
            QuestionButtons[i]:Show()
            QuestionCounter = QuestionCounter + 1
            QuestionButtons[i]:SetText(CurrentDialogue[ButtonName])
            QuestionButtons[i]:SetScript("OnClick", function()
                if StoryExtendedDB[CurrentID][doOnce] == "true" then
                    StoryExtendedDB[CurrentID][didOnce] = "true"
                end
                if tonumber(CurrentDialogue[GoToID]) == -1 then
                    dialogueEnds = true
                end
                StopDialogue(CurrentDialogue)
                NextID = CurrentDialogue[GoToID]
                UpdateDialogue(CurrentDialogue, NextID, dialogueEnds, Dialogues)
            end)
            QuestionButtons[i]:Enable()
        else
            QuestionButtons[i]:SetText("")
            QuestionButtons[i]:SetScript("OnClick", nil)
            QuestionButtons[i]:Disable()
            QuestionButtons[i]:Hide()
        end
        if i == 4 then
            QuestionButtonHider(QuestionCounter)
        end
    end
end
--END


-- Helper Function to save the current/next dialogue into the savedVariables
function UpdateDialogue(CurrentDialogue, NextID, dialogueEnds, Dialogues)
    local savedName = CurrentDialogue.name
    if dialogueEnds ~= true then
        CurrentID = tonumber(NextID)


        -- Iterate through each element in the table
        for i, dialogue in ipairs(Dialogues) do
            idCheck = tostring(CurrentID)
            -- Check if the current element's id matches the id we are looking for
            if dialogue.id == idCheck then
                -- If it matches, save the current element to the CurrentDialogue variable
                CurrentDialogue = dialogue
                -- Exit the loop since we have found the element we are looking for
                break
            end
        end


        -- CurrentDialogue = Dialogues[CurrentID]


        UpdateFrame(CurrentDialogue)
        NextID = nil
    else
        DialogueFrame:Hide()
        for index, QuestionButton in ipairs(QuestionButtons) do
            QuestionButton:Hide()
        end
        QuestionFrame:Hide()
        ShowUI()
        CurrentID = StoryExtendedDB[targetName]
        dialogueEnds = false
        NextID = nil
    end
end
--END

-- Function to check if the players target is an NPC with Dialogue
local function IsNPC(targetName)
    if targetName ~= nil and StoryExtendedDB[targetName] == nil then
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
    StoryExtendedDB[targetName] = CurrentID
    elseif targetName ~= nil and StoryExtendedDB[targetName] ~= nil then
        CurrentID = StoryExtendedDB[targetName]
        return true
    end
    return false, nil
end
--END

-- Checks which conditions are true and chooses the dialogue id
local function ConditionCheck(targetName)
    local ConditionCheckFailed = false
    for key, value in pairs(Dialogues) do
        if StoryExtendedDB and StoryExtendedDB[targetName] and tonumber(StoryExtendedDB[targetName]) < key then

        else
            if tostring(Dialogues[key].Name) == tostring(targetName) and Dialogues[key].Greeting == "true" and Dialogues[key].ConditionType == 'none' then
                CurrentID = tonumber(Dialogues[key].id)
                ConditionCheckFailed = false
                return true
            else
                ConditionCheckFailed = true
                CurrentID = tonumber(StoryExtendedDB[targetName])
            end
        end
    end
    if ConditionCheckFailed == true then
        ConditionCheckFailed = false
        return false, nil
    end
end

-- Create a button to trigger the conversation
local function TalkStoryFunc(zone_input)
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

    local isCondition = ConditionCheck(targetName)
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
                -- The player is close enough to talk to the target
                UpdateFrame(CurrentDialogue)
                DialogueFrame:Show()
                QuestionFrame:Show()
                -- Hide all UI elements but the dialogue UI, if the option is activated
                HideUI()
            else
                -- The player is too far away to talk to the target
                UIErrorsFrame:AddMessage("Not in range.", 1.0, 0.1, 0.1, 1.0, 3)
            end
        else
            -- The player is close enough to talk to the target
            UpdateFrame(CurrentDialogue)
            DialogueFrame:Show()
            QuestionFrame:Show()
            -- Hide all UI elements but the dialogue UI, if the option is activated
            HideUI()
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
    C_Timer.After(2, function() TalkStoryFunc(subzone) end)
end

-- Register the zone change events to our OnZoneChanged script
local zoneChangeFrame = CreateFrame("FRAME")
zoneChangeFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
zoneChangeFrame:RegisterEvent("ZONE_CHANGED")
zoneChangeFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneChangeFrame:SetScript("OnEvent", OnZoneChanged)

-- Hide the frame when the player clicks outside of it
DialogueFrame:SetScript("OnMouseDown", function() DialogueFrame:StopMovingOrSizing() end)
DialogueFrame:Hide()
QuestionFrame:Hide()
for index, QuestionButton in ipairs(QuestionButtons) do
    QuestionButton:Hide()
end

--END
