local ADDON_NAME = ...
local ADDON_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\"

local RAID_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"
local SECTOR_COUNT = 8
local SECTOR_ANGLE = math.pi / 4
local FIRST_BOUNDARY_ANGLE = -math.pi / 2 + math.pi / 8 - math.rad(12)
local MARKER_RADIUS = 0.38
local BOARD_RADIUS = 0.45
local MIN_MARKER_SIZE = 16
local MAX_MARKER_SIZE = 32
local MARKER_SIZE_STEP = 2
local DEFAULT_MARKER_SIZE = 24
local MIN_MINIMAP_ICON_SCALE = 1.0
local MAX_MINIMAP_ICON_SCALE = 3.0
local MINIMAP_ICON_SCALE_STEP = 0.2
local DEFAULT_MINIMAP_ICON_SCALE = 1.0
local DEFAULT_PROFILE_NAME = "기본 배치"
local ENTRANCE_BORDER_COLOR = { 1.0, 0.66, 0.12, 1.0 }
local PANEL_WIDTH = 950
local RIGHT_COLUMN_X = 580
local RIGHT_COLUMN_WIDTH = 345
local RIGHT_CONTENT_X = RIGHT_COLUMN_X + 10
local PANEL_TOP_PADDING = 48
local PANEL_BOTTOM_PADDING = 12
local SECTION_GAP = 2
local SECTION_TITLE_TO_CONTENT_GAP = 30
local SECTION_BOTTOM_PADDING = 12
local ADDON_CONTENT_HEIGHT = 24
local MARKER_BUTTON_WIDTH = 156
local MARKER_BUTTON_HEIGHT = 36
local MARKER_BUTTON_ROW_GAP = 8
local MARKER_BUTTON_COLUMN_GAP = 9
local MARKER_ACTION_GAP = 20
local MARKER_ACTION_HEIGHT = 28
local MARKER_GRID_HEIGHT = MARKER_BUTTON_HEIGHT * 4 + MARKER_BUTTON_ROW_GAP * 3
local MARKER_CONTENT_HEIGHT = MARKER_GRID_HEIGHT + MARKER_ACTION_GAP + MARKER_ACTION_HEIGHT
local SLIDER_LABEL_TO_SLIDER_OFFSET = 24
local SETTINGS_SECOND_LABEL_OFFSET = 74
local SETTINGS_GROUND_CHECKBOX_OFFSET = 140
local SETTINGS_CONTENT_HEIGHT = SETTINGS_GROUND_CHECKBOX_OFFSET + 24
local PROFILE_ROW_HEIGHT = 24
local PROFILE_ROW_GAP = 12
local PROFILE_ACTION_HEIGHT = 26
local PROFILE_CONTENT_HEIGHT = PROFILE_ROW_HEIGHT + PROFILE_ROW_GAP + PROFILE_ACTION_HEIGHT
local function optionSectionHeight(contentHeight)
    return SECTION_TITLE_TO_CONTENT_GAP + contentHeight + SECTION_BOTTOM_PADDING
end
local PANEL_HEIGHT = PANEL_TOP_PADDING
    + optionSectionHeight(ADDON_CONTENT_HEIGHT)
    + optionSectionHeight(MARKER_CONTENT_HEIGHT)
    + optionSectionHeight(SETTINGS_CONTENT_HEIGHT)
    + optionSectionHeight(PROFILE_CONTENT_HEIGHT)
    + SECTION_GAP * 3
    + PANEL_BOTTOM_PADDING
local atan2 = math.atan2 or function(y, x)
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif y > 0 then
        return math.pi / 2
    elseif y < 0 then
        return -math.pi / 2
    end
    return 0
end
local MARKER_NAMES = {
    [1] = "Star",
    [2] = "Circle",
    [3] = "Diamond",
    [4] = "Triangle",
    [5] = "Moon",
    [6] = "Square",
    [7] = "Cross",
    [8] = "Skull",
}

local panel
local board
local selectedMarker
local boardMarkers = {}
local minimapMarkers = {}
local paletteButtons = {}
local minimapOverlay
local boardLines = {}
local refreshAll

local function isValidMarker(markerID)
    return type(markerID) == "number" and markerID >= 1 and markerID <= 8 and markerID == math.floor(markerID)
end

local function isValidSector(sector)
    return type(sector) == "number" and sector >= 1 and sector <= SECTOR_COUNT and sector == math.floor(sector)
end

local function copyMarkers(markers)
    local copiedMarkers = {}
    if type(markers) ~= "table" then
        return copiedMarkers
    end

    for markerID, sector in pairs(markers) do
        if isValidMarker(markerID) and isValidSector(sector) then
            copiedMarkers[markerID] = sector
        end
    end
    return copiedMarkers
end

local function sectorFromAngle(angle)
    local normalizedAngle = (angle - FIRST_BOUNDARY_ANGLE) % (math.pi * 2)
    return math.floor(normalizedAngle / SECTOR_ANGLE) + 1
end

local function sectorFromPosition(x, y)
    if type(x) ~= "number" or type(y) ~= "number" or x < 0 or x > 1 or y < 0 or y > 1 then
        return nil
    end
    return sectorFromAngle(atan2(0.5 - y, x - 0.5))
end

local function sectorPosition(sector)
    if not isValidSector(sector) then
        return nil
    end
    local angle = FIRST_BOUNDARY_ANGLE + (sector - 0.5) * SECTOR_ANGLE
    return 0.5 + math.cos(angle) * MARKER_RADIUS, 0.5 - math.sin(angle) * MARKER_RADIUS
end

local function initializeDatabase()
    if type(MinimapMarkerHelperDB) ~= "table" then
        MinimapMarkerHelperDB = {}
    end

    MinimapMarkerHelperDB.enabled = nil
    if type(MinimapMarkerHelperDB.addonEnabled) ~= "boolean" then
        MinimapMarkerHelperDB.addonEnabled = true
    end
    MinimapMarkerHelperDB.largePlayerArrow = nil
    if type(MinimapMarkerHelperDB.hideGroundTextures) ~= "boolean" then
        MinimapMarkerHelperDB.hideGroundTextures = false
    end
    local markerSize = tonumber(MinimapMarkerHelperDB.markerSize)
    if markerSize then
        markerSize = math.floor(markerSize / MARKER_SIZE_STEP + 0.5) * MARKER_SIZE_STEP
    end
    if not markerSize or markerSize < MIN_MARKER_SIZE or markerSize > MAX_MARKER_SIZE then
        markerSize = DEFAULT_MARKER_SIZE
    end
    MinimapMarkerHelperDB.markerSize = markerSize
    local minimapIconScale = tonumber(MinimapMarkerHelperDB.minimapIconScale)
    if minimapIconScale then
        minimapIconScale = math.floor(minimapIconScale / MINIMAP_ICON_SCALE_STEP + 0.5) * MINIMAP_ICON_SCALE_STEP
    end
    if not minimapIconScale or minimapIconScale < MIN_MINIMAP_ICON_SCALE or minimapIconScale > MAX_MINIMAP_ICON_SCALE then
        minimapIconScale = DEFAULT_MINIMAP_ICON_SCALE
    end
    MinimapMarkerHelperDB.minimapIconScale = minimapIconScale
    if type(MinimapMarkerHelperDB.markers) ~= "table" then
        MinimapMarkerHelperDB.markers = {}
    end

    local cleanedMarkers = {}
    local occupiedSectors = {}
    for markerID, value in pairs(MinimapMarkerHelperDB.markers) do
        local sector = value
        if type(value) == "table" then
            sector = sectorFromPosition(value.x, value.y)
        end
        if isValidMarker(markerID) and isValidSector(sector) and not occupiedSectors[sector] then
            cleanedMarkers[markerID] = sector
            occupiedSectors[sector] = true
        end
    end
    MinimapMarkerHelperDB.markers = cleanedMarkers

    if type(MinimapMarkerHelperDB.profiles) ~= "table" then
        MinimapMarkerHelperDB.profiles = {}
    end
    for profileName, profile in pairs(MinimapMarkerHelperDB.profiles) do
        if type(profileName) ~= "string" or type(profile) ~= "table" then
            MinimapMarkerHelperDB.profiles[profileName] = nil
        else
            MinimapMarkerHelperDB.profiles[profileName] = {
                markers = copyMarkers(profile.markers),
            }
        end
    end
    if next(MinimapMarkerHelperDB.profiles) == nil then
        MinimapMarkerHelperDB.profiles[DEFAULT_PROFILE_NAME] = {
            markers = copyMarkers(cleanedMarkers),
        }
    end
    if type(MinimapMarkerHelperDB.activeProfile) ~= "string" or not MinimapMarkerHelperDB.profiles[MinimapMarkerHelperDB.activeProfile] then
        MinimapMarkerHelperDB.activeProfile = DEFAULT_PROFILE_NAME
        if not MinimapMarkerHelperDB.profiles[DEFAULT_PROFILE_NAME] then
            for profileName in pairs(MinimapMarkerHelperDB.profiles) do
                MinimapMarkerHelperDB.activeProfile = profileName
                break
            end
        end
    end
end

local function normalizeProfileName(profileName)
    if type(profileName) ~= "string" then
        return nil
    end
    profileName = profileName:match("^%s*(.-)%s*$")
    if profileName == "" then
        return nil
    end
    return profileName:sub(1, 24)
end

local function saveProfile(profileName)
    profileName = normalizeProfileName(profileName)
    if not profileName then
        return nil
    end
    MinimapMarkerHelperDB.profiles[profileName] = {
        markers = copyMarkers(MinimapMarkerHelperDB.markers),
    }
    MinimapMarkerHelperDB.activeProfile = profileName
    return profileName
end

local function loadProfile(profileName)
    profileName = normalizeProfileName(profileName)
    local profile = profileName and MinimapMarkerHelperDB.profiles[profileName]
    if not profile then
        return nil
    end
    MinimapMarkerHelperDB.markers = copyMarkers(profile.markers)
    MinimapMarkerHelperDB.activeProfile = profileName
    selectedMarker = nil
    refreshAll()
    return profileName
end

local function createMarkerTexture(parent, size)
    local texture = parent:CreateTexture(nil, "OVERLAY")
    texture:SetSize(size, size)
    texture:Hide()
    return texture
end

local function refreshEntranceBorder()
    if not MinimapMarkerHelperDB then
        return
    end

    for lineIndex = 1, SECTOR_COUNT * 2 do
        local line = boardLines[lineIndex]
        if line then
            line:SetVertexColor(0.72, 0.76, 0.68, 0.85)
        end
    end

    local entranceSector = MinimapMarkerHelperDB.markers[8]
    if not isValidSector(entranceSector) then
        return
    end

    local entranceLines = {
        entranceSector,
        entranceSector % SECTOR_COUNT + 1,
        entranceSector + SECTOR_COUNT,
    }
    for _, lineIndex in ipairs(entranceLines) do
        local line = boardLines[lineIndex]
        if line then
            line:SetVertexColor(unpack(ENTRANCE_BORDER_COLOR))
        end
    end
end

local function refreshBoard()
    if not board or not MinimapMarkerHelperDB then
        return
    end

    for markerID = 1, 8 do
        local marker = boardMarkers[markerID]
        local x, y = sectorPosition(MinimapMarkerHelperDB.markers[markerID])
        if x and marker then
            marker:ClearAllPoints()
            marker:SetPoint("CENTER", board, "TOPLEFT", x * board:GetWidth(), -y * board:GetHeight())
            marker:SetTexture(RAID_ICON_TEXTURE:format(markerID))
            marker:Show()
        elseif marker then
            marker:Hide()
        end

        local button = paletteButtons[markerID]
        if button then
            local selected = selectedMarker == markerID
            button.selection:SetShown(selected)
            button:SetBackdropColor(selected and 0.28 or 0.12, selected and 0.20 or 0.12, selected and 0.04 or 0.12, 1)
            button:SetBackdropBorderColor(selected and 1 or 0, selected and 0.82 or 0, selected and 0.16 or 0, selected and 1 or 0)
        end
    end
    refreshEntranceBorder()
end

local function refreshMinimap()
    if not minimapOverlay or not MinimapMarkerHelperDB then
        return
    end

    local showMarkers = MinimapMarkerHelperDB.addonEnabled
    minimapOverlay:SetShown(showMarkers)
    if not showMarkers then
        return
    end

    local width = Minimap:GetWidth()
    local height = Minimap:GetHeight()
    local markerSize = MinimapMarkerHelperDB.markerSize
    if not width or not height or width <= 0 or height <= 0 then
        return
    end

    for markerID = 1, 8 do
        local marker = minimapMarkers[markerID]
        local x, y = sectorPosition(MinimapMarkerHelperDB.markers[markerID])
        if x and marker then
            marker:ClearAllPoints()
            marker:SetSize(markerSize, markerSize)
            marker:SetPoint("CENTER", minimapOverlay, "TOPLEFT", x * width, -y * height)
            marker:SetTexture(RAID_ICON_TEXTURE:format(markerID))
            marker:Show()
        elseif marker then
            marker:Hide()
        end
    end
end

local function updateMinimapIconScale()
    if not MinimapMarkerHelperDB or not Minimap or type(Minimap.SetIconScale) ~= "function" then
        return
    end

    local iconScale = MinimapMarkerHelperDB.addonEnabled and MinimapMarkerHelperDB.minimapIconScale or DEFAULT_MINIMAP_ICON_SCALE
    pcall(Minimap.SetIconScale, Minimap, iconScale)
end

local function updateGroundTextures()
    if not MinimapMarkerHelperDB or not C_Minimap or not C_Minimap.SetDrawGroundTextures then
        return
    end

    local showGroundTextures = not MinimapMarkerHelperDB.addonEnabled or not MinimapMarkerHelperDB.hideGroundTextures
    pcall(C_Minimap.SetDrawGroundTextures, showGroundTextures)
end

refreshAll = function()
    refreshBoard()
    refreshMinimap()
    updateMinimapIconScale()
    updateGroundTextures()
end

local function selectMarker(markerID)
    selectedMarker = markerID
    refreshBoard()
end

local function setLine(line, x1, y1, x2, y2)
    local deltaX = x2 - x1
    local deltaY = y2 - y1
    line:ClearAllPoints()
    line:SetSize(math.sqrt(deltaX * deltaX + deltaY * deltaY), 2)
    line:SetPoint("CENTER", board, "CENTER", (x1 + x2) / 2, (y1 + y2) / 2)
    line:SetRotation(atan2(deltaY, deltaX))
end

local function buildBoardGeometry()
    local radius = math.min(board:GetWidth(), board:GetHeight()) * BOARD_RADIUS
    local vertices = {}
    for index = 1, SECTOR_COUNT do
        local angle = FIRST_BOUNDARY_ANGLE + (index - 1) * SECTOR_ANGLE
        vertices[index] = { x = math.cos(angle) * radius, y = math.sin(angle) * radius }
    end

    for index = 1, SECTOR_COUNT do
        local radialLine = boardLines[index]
        local outerLine = boardLines[index + SECTOR_COUNT]
        local current = vertices[index]
        local nextVertex = vertices[index % SECTOR_COUNT + 1]
        setLine(radialLine, 0, 0, current.x, current.y)
        setLine(outerLine, current.x, current.y, nextVertex.x, nextVertex.y)
    end
end

local function placeMarkerFromClick()
    if not selectedMarker or not board then
        return
    end

    local scale = board:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    local left = board:GetLeft()
    local top = board:GetTop()
    local width = board:GetWidth()
    local height = board:GetHeight()
    if not scale or not left or not top or not width or not height or width <= 0 or height <= 0 then
        return
    end

    cursorX = cursorX / scale
    cursorY = cursorY / scale
    local x = (cursorX - left) / width - 0.5
    local y = 0.5 - (top - cursorY) / height
    if x * x + y * y > BOARD_RADIUS * BOARD_RADIUS then
        return
    end

    local sector = sectorFromAngle(atan2(y, x))
    for markerID, occupiedSector in pairs(MinimapMarkerHelperDB.markers) do
        if markerID ~= selectedMarker and occupiedSector == sector then
            MinimapMarkerHelperDB.markers[markerID] = nil
        end
    end
    MinimapMarkerHelperDB.markers[selectedMarker] = sector
    refreshBoard()
    refreshMinimap()
end

local function createCheckbox(parent, label, x, y, getter, setter)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)
    checkbox:SetPoint("TOPLEFT", x, y)
    checkbox.label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    checkbox.label:SetText(label)
    checkbox:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)
    checkbox:SetScript("OnShow", function(self)
        self:SetChecked(getter() and true or false)
    end)
    return checkbox
end

local function buildPanel()
    panel = CreateFrame("Frame", "MinimapMarkerHelperOptions", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0, 0, 0, 0.92)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Minimap Marker Helper")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    board = CreateFrame("Button", nil, panel, "BackdropTemplate")
    board:SetSize(540, 540)
    board:SetPoint("TOPLEFT", 24, -52)
    board:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    board:SetBackdropColor(0.08, 0.12, 0.10, 1)
    board:SetScript("OnClick", placeMarkerFromClick)

    for index = 1, SECTOR_COUNT * 2 do
        local line = board:CreateTexture(nil, "ARTWORK")
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
        line:SetVertexColor(0.72, 0.76, 0.68, 0.85)
        boardLines[index] = line
    end
    buildBoardGeometry()

    for markerID = 1, 8 do
        boardMarkers[markerID] = createMarkerTexture(board, 42)
    end

    local function createOptionSection(titleText, y, contentHeight)
        local height = optionSectionHeight(contentHeight)
        local section = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        section:SetSize(RIGHT_COLUMN_WIDTH, height)
        section:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_COLUMN_X, y)
        section:SetFrameLevel(panel:GetFrameLevel())
        section:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        section:SetBackdropColor(0.04, 0.06, 0.09, 0.82)
        section:SetBackdropBorderColor(0.42, 0.42, 0.42, 0.9)
        section.title = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        section.title:SetPoint("TOPLEFT", 12, -10)
        section.title:SetText(titleText)
        return y - SECTION_TITLE_TO_CONTENT_GAP, y - height - SECTION_GAP
    end

    local nextSectionY = -PANEL_TOP_PADDING
    local addonContentY
    addonContentY, nextSectionY = createOptionSection("애드온", nextSectionY, ADDON_CONTENT_HEIGHT)
    local markerContentY
    markerContentY, nextSectionY = createOptionSection("징표", nextSectionY, MARKER_CONTENT_HEIGHT)
    local settingsContentY
    settingsContentY, nextSectionY = createOptionSection("설정", nextSectionY, SETTINGS_CONTENT_HEIGHT)
    local profileContentY
    profileContentY = createOptionSection("프로필", nextSectionY, PROFILE_CONTENT_HEIGHT)

    for markerID = 1, 8 do
        local button = CreateFrame("Button", nil, panel, "BackdropTemplate")
        local column = (markerID - 1) % 2
        local row = math.floor((markerID - 1) / 2)
        button:SetSize(MARKER_BUTTON_WIDTH, MARKER_BUTTON_HEIGHT)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT",
            RIGHT_CONTENT_X + column * (MARKER_BUTTON_WIDTH + MARKER_BUTTON_COLUMN_GAP),
            markerContentY - row * (MARKER_BUTTON_HEIGHT + MARKER_BUTTON_ROW_GAP))
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        button:SetBackdropColor(0.12, 0.12, 0.12, 1)
        button:SetBackdropBorderColor(0, 0, 0, 0)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(27, 27)
        button.icon:SetPoint("LEFT", 4, 0)
        button.icon:SetTexture(RAID_ICON_TEXTURE:format(markerID))
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.text:SetPoint("LEFT", button.icon, "RIGHT", 2, 0)
        button.text:SetText(MARKER_NAMES[markerID])
        button.selection = button:CreateTexture(nil, "HIGHLIGHT")
        button.selection:SetAllPoints()
        button.selection:SetColorTexture(0.95, 0.82, 0.15, 0.16)
        button.selection:Hide()
        button:SetScript("OnClick", function()
            selectMarker(markerID)
        end)
        paletteButtons[markerID] = button
    end

    local delete = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    delete:SetSize(180, 28)
    delete:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_CONTENT_X, markerContentY - MARKER_GRID_HEIGHT - MARKER_ACTION_GAP)
    delete:SetText("선택한 징표 삭제")
    delete:SetScript("OnClick", function()
        if selectedMarker then
            MinimapMarkerHelperDB.markers[selectedMarker] = nil
            refreshBoard()
            refreshMinimap()
        end
    end)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(132, 28)
    reset:SetPoint("LEFT", delete, "RIGHT", 8, 0)
    reset:SetText("전체 초기화")
    reset:SetScript("OnClick", function()
        MinimapMarkerHelperDB.markers = {}
        selectedMarker = nil
        refreshBoard()
        refreshMinimap()
    end)

    local markerSizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    markerSizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_CONTENT_X, settingsContentY)
    markerSizeLabel:SetText("미니맵 징표 크기")

    local markerSizeValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    markerSizeValue:SetPoint("LEFT", markerSizeLabel, "RIGHT", 10, 0)

    local markerSizeSlider = CreateFrame("Slider", nil, panel, "UISliderTemplate")
    markerSizeSlider:SetSize(260, 17)
    markerSizeSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_CONTENT_X, settingsContentY - SLIDER_LABEL_TO_SLIDER_OFFSET)
    markerSizeSlider:SetMinMaxValues(MIN_MARKER_SIZE, MAX_MARKER_SIZE)
    markerSizeSlider:SetValueStep(MARKER_SIZE_STEP)
    markerSizeSlider:SetObeyStepOnDrag(true)

    local minimumLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minimumLabel:SetPoint("TOPLEFT", markerSizeSlider, "BOTTOMLEFT", 0, -2)
    minimumLabel:SetText(MIN_MARKER_SIZE .. " px")

    local maximumLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    maximumLabel:SetPoint("TOPRIGHT", markerSizeSlider, "BOTTOMRIGHT", 0, -2)
    maximumLabel:SetText(MAX_MARKER_SIZE .. " px")

    local function syncMarkerSizeSlider()
        markerSizeSlider:SetValue(MinimapMarkerHelperDB.markerSize)
        markerSizeValue:SetText(MinimapMarkerHelperDB.markerSize .. " px")
    end

    markerSizeSlider:SetScript("OnValueChanged", function(_, value)
        local markerSize = math.floor(value / MARKER_SIZE_STEP + 0.5) * MARKER_SIZE_STEP
        if markerSize == MinimapMarkerHelperDB.markerSize then
            return
        end
        MinimapMarkerHelperDB.markerSize = markerSize
        markerSizeValue:SetText(markerSize .. " px")
        refreshMinimap()
    end)
    syncMarkerSizeSlider()

    local minimapIconScaleLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    minimapIconScaleLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_CONTENT_X, settingsContentY - SETTINGS_SECOND_LABEL_OFFSET)
    minimapIconScaleLabel:SetText("기본 미니맵 아이콘 크기")

    local minimapIconScaleValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    minimapIconScaleValue:SetPoint("LEFT", minimapIconScaleLabel, "RIGHT", 10, 0)

    local minimapIconScaleSlider = CreateFrame("Slider", nil, panel, "UISliderTemplate")
    minimapIconScaleSlider:SetSize(260, 17)
    minimapIconScaleSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_CONTENT_X,
        settingsContentY - SETTINGS_SECOND_LABEL_OFFSET - SLIDER_LABEL_TO_SLIDER_OFFSET)
    minimapIconScaleSlider:SetMinMaxValues(MIN_MINIMAP_ICON_SCALE, MAX_MINIMAP_ICON_SCALE)
    minimapIconScaleSlider:SetValueStep(MINIMAP_ICON_SCALE_STEP)
    minimapIconScaleSlider:SetObeyStepOnDrag(true)

    local minimapIconScaleMinimumLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minimapIconScaleMinimumLabel:SetPoint("TOPLEFT", minimapIconScaleSlider, "BOTTOMLEFT", 0, -2)
    minimapIconScaleMinimumLabel:SetText(string.format("%.1f×", MIN_MINIMAP_ICON_SCALE))

    local minimapIconScaleMaximumLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minimapIconScaleMaximumLabel:SetPoint("TOPRIGHT", minimapIconScaleSlider, "BOTTOMRIGHT", 0, -2)
    minimapIconScaleMaximumLabel:SetText(string.format("%.1f×", MAX_MINIMAP_ICON_SCALE))

    local function syncMinimapIconScaleSlider()
        minimapIconScaleSlider:SetValue(MinimapMarkerHelperDB.minimapIconScale)
        minimapIconScaleValue:SetText(string.format("%.1f×", MinimapMarkerHelperDB.minimapIconScale))
    end

    minimapIconScaleSlider:SetScript("OnValueChanged", function(_, value)
        local minimapIconScale = math.floor(value / MINIMAP_ICON_SCALE_STEP + 0.5) * MINIMAP_ICON_SCALE_STEP
        if minimapIconScale == MinimapMarkerHelperDB.minimapIconScale then
            return
        end
        MinimapMarkerHelperDB.minimapIconScale = minimapIconScale
        minimapIconScaleValue:SetText(string.format("%.1f×", minimapIconScale))
        updateMinimapIconScale()
    end)
    syncMinimapIconScaleSlider()

    local updateAddonControlState
    local addonCheckbox = createCheckbox(panel, "애드온 사용", RIGHT_CONTENT_X, addonContentY,
        function() return MinimapMarkerHelperDB.addonEnabled end,
        function(value)
            MinimapMarkerHelperDB.addonEnabled = value
            refreshAll()
            if updateAddonControlState then
                updateAddonControlState()
            end
        end)

    local groundTextureCheckbox = createCheckbox(panel, "미니맵 배경 숨기기", RIGHT_CONTENT_X,
        settingsContentY - SETTINGS_GROUND_CHECKBOX_OFFSET,
        function() return MinimapMarkerHelperDB.hideGroundTextures end,
        function(value)
            MinimapMarkerHelperDB.hideGroundTextures = value
            updateGroundTextures()
        end)

    local profileDropdown = CreateFrame("Frame", "MinimapMarkerHelperProfileDropdown", panel, "UIDropDownMenuTemplate")
    profileDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_COLUMN_X - 5, profileContentY)
    UIDropDownMenu_SetWidth(profileDropdown, 115)
    profileDropdown.Text:SetJustifyH("LEFT")

    local profileNameBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    profileNameBox:SetSize(110, 24)
    profileNameBox:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_CONTENT_X + 150, profileContentY)
    profileNameBox:SetAutoFocus(false)
    profileNameBox:SetMaxLetters(24)

    local function getProfileNames()
        local profileNames = {}
        for profileName in pairs(MinimapMarkerHelperDB.profiles) do
            table.insert(profileNames, profileName)
        end
        table.sort(profileNames)
        return profileNames
    end

    local function updateProfileDropdown()
        UIDropDownMenu_SetText(profileDropdown, MinimapMarkerHelperDB.activeProfile)
    end

    UIDropDownMenu_Initialize(profileDropdown, function(_, level)
        for _, profileName in ipairs(getProfileNames()) do
            local selectedProfileName = profileName
            local info = UIDropDownMenu_CreateInfo()
            info.text = selectedProfileName
            info.checked = selectedProfileName == MinimapMarkerHelperDB.activeProfile
            info.func = function()
                loadProfile(selectedProfileName)
                updateProfileDropdown()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local addProfileButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addProfileButton:SetSize(60, 26)
    addProfileButton:SetPoint("LEFT", profileNameBox, "RIGHT", 6, 0)
    addProfileButton:SetText("추가")
    addProfileButton:SetScript("OnClick", function()
        local profileName = normalizeProfileName(profileNameBox:GetText())
        if profileName and not MinimapMarkerHelperDB.profiles[profileName] then
            saveProfile(profileName)
            profileNameBox:SetText("")
            profileNameBox:ClearFocus()
            updateProfileDropdown()
        end
    end)

    local saveProfileButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    saveProfileButton:SetSize(138, 26)
    saveProfileButton:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_CONTENT_X,
        profileContentY - PROFILE_ROW_HEIGHT - PROFILE_ROW_GAP)
    saveProfileButton:SetText("프로필 저장")
    saveProfileButton:SetScript("OnClick", function()
        saveProfile(MinimapMarkerHelperDB.activeProfile)
        updateProfileDropdown()
    end)

    local deleteProfileButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    deleteProfileButton:SetSize(104, 26)
    deleteProfileButton:SetPoint("LEFT", saveProfileButton, "RIGHT", 6, 0)
    deleteProfileButton:SetText("프로필 삭제")
    deleteProfileButton:SetScript("OnClick", function()
        local profileName = MinimapMarkerHelperDB.activeProfile
        local profileCount = 0
        for _ in pairs(MinimapMarkerHelperDB.profiles) do
            profileCount = profileCount + 1
        end
        if profileCount <= 1 then
            return
        end
        MinimapMarkerHelperDB.profiles[profileName] = nil
        if MinimapMarkerHelperDB.activeProfile == profileName then
            for nextProfileName in pairs(MinimapMarkerHelperDB.profiles) do
                loadProfile(nextProfileName)
                break
            end
        end
        updateProfileDropdown()
    end)

    updateAddonControlState = function()
        local isEnabled = MinimapMarkerHelperDB.addonEnabled
        groundTextureCheckbox:SetEnabled(isEnabled)
        markerSizeSlider:SetEnabled(isEnabled)
        minimapIconScaleSlider:SetEnabled(isEnabled)
        profileNameBox:SetEnabled(isEnabled)
        addProfileButton:SetEnabled(isEnabled)
        saveProfileButton:SetEnabled(isEnabled)
        deleteProfileButton:SetEnabled(isEnabled)
        if isEnabled then
            UIDropDownMenu_EnableDropDown(profileDropdown)
        else
            UIDropDownMenu_DisableDropDown(profileDropdown)
        end
    end

    panel:SetScript("OnShow", function()
        addonCheckbox:SetChecked(MinimapMarkerHelperDB.addonEnabled)
        groundTextureCheckbox:SetChecked(MinimapMarkerHelperDB.hideGroundTextures)
        syncMarkerSizeSlider()
        syncMinimapIconScaleSlider()
        updateProfileDropdown()
        updateAddonControlState()
        refreshBoard()
    end)
    panel:Hide()
    if UISpecialFrames then
        table.insert(UISpecialFrames, "MinimapMarkerHelperOptions")
    end
end

local function togglePanel()
    if not panel then
        buildPanel()
    end
    panel:SetShown(not panel:IsShown())
end

local function buildMinimapUI()
    minimapOverlay = CreateFrame("Frame", nil, Minimap)
    minimapOverlay:SetAllPoints(Minimap)
    minimapOverlay:SetFrameStrata("MEDIUM")
    minimapOverlay:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    minimapOverlay:EnableMouse(false)

    for markerID = 1, 8 do
        minimapMarkers[markerID] = createMarkerTexture(minimapOverlay, 24)
    end

    local button = CreateFrame("Button", "MinimapMarkerHelperMinimapButton", Minimap)
    button:SetSize(24, 24)
    button:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -4, -4)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexture(ADDON_PATH .. "Media\\MinimapMarkerHelperIcon.png")
    button:SetScript("OnClick", togglePanel)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Minimap Marker Helper")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    Minimap:HookScript("OnSizeChanged", refreshMinimap)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name)
    if event ~= "ADDON_LOADED" or name ~= ADDON_NAME then
        return
    end

    initializeDatabase()
    buildMinimapUI()
    refreshAll()
end)
