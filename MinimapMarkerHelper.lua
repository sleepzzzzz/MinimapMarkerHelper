local ADDON_NAME = ...

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

local function isValidMarker(markerID)
    return type(markerID) == "number" and markerID >= 1 and markerID <= 8 and markerID == math.floor(markerID)
end

local function isValidSector(sector)
    return type(sector) == "number" and sector >= 1 and sector <= SECTOR_COUNT and sector == math.floor(sector)
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

    if type(MinimapMarkerHelperDB.enabled) ~= "boolean" then
        MinimapMarkerHelperDB.enabled = true
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
end

local function createMarkerTexture(parent, size)
    local texture = parent:CreateTexture(nil, "OVERLAY")
    texture:SetSize(size, size)
    texture:Hide()
    return texture
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
end

local function refreshMinimap()
    if not minimapOverlay or not MinimapMarkerHelperDB then
        return
    end

    local showMarkers = MinimapMarkerHelperDB.enabled
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

local function updateGroundTextures()
    if not MinimapMarkerHelperDB or not C_Minimap or not C_Minimap.SetDrawGroundTextures then
        return
    end

    pcall(C_Minimap.SetDrawGroundTextures, not MinimapMarkerHelperDB.hideGroundTextures)
end

local function refreshAll()
    refreshBoard()
    refreshMinimap()
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
    panel:SetSize(950, 625)
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

    local paletteTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    paletteTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 590, -57)
    paletteTitle:SetText("Raid Markers")

    for markerID = 1, 8 do
        local button = CreateFrame("Button", nil, panel, "BackdropTemplate")
        local column = (markerID - 1) % 2
        local row = math.floor((markerID - 1) / 2)
        button:SetSize(156, 36)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", 590 + column * 165, -82 - row * 44)
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
    delete:SetPoint("TOPLEFT", panel, "TOPLEFT", 590, -270)
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
    markerSizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 590, -326)
    markerSizeLabel:SetText("미니맵 징표 크기")

    local markerSizeValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    markerSizeValue:SetPoint("LEFT", markerSizeLabel, "RIGHT", 10, 0)

    local markerSizeSlider = CreateFrame("Slider", nil, panel, "UISliderTemplate")
    markerSizeSlider:SetSize(260, 17)
    markerSizeSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 590, -350)
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

    local markerCheckbox = createCheckbox(panel, "미니맵에 징표 표시", 590, -405,
        function() return MinimapMarkerHelperDB.enabled end,
        function(value)
            MinimapMarkerHelperDB.enabled = value
            refreshMinimap()
        end)

    local groundTextureCheckbox = createCheckbox(panel, "미니맵 배경 숨기기", 590, -440,
        function() return MinimapMarkerHelperDB.hideGroundTextures end,
        function(value)
            MinimapMarkerHelperDB.hideGroundTextures = value
            updateGroundTextures()
        end)

    panel:SetScript("OnShow", function()
        markerCheckbox:SetChecked(MinimapMarkerHelperDB.enabled)
        groundTextureCheckbox:SetChecked(MinimapMarkerHelperDB.hideGroundTextures)
        syncMarkerSizeSlider()
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
    button.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
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
