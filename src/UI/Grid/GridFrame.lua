local _, ns = ...

-- UI/Grid/GridFrame.lua
-- Manages main grid frame creation and layout

ns.UI = ns.UI or {}
ns.UI.Grid = ns.UI.Grid or {}

-- Calculate dynamic layout (max 5 columns)
local function CalculateLayout(count, layout)
    local cols, rows
    
    if layout.cols and layout.rows then
        cols = layout.cols
        rows = layout.rows
    else
        local MAX_COLS = 5
        if count <= MAX_COLS then
            cols = count
            rows = 1
        else
            rows = math.ceil(count / MAX_COLS)
            cols = math.ceil(count / rows)
        end
    end
    
    -- Ensure min dimensions
    if cols < 1 then cols = 1 end
    if rows < 1 then rows = 1 end
    
    return cols, rows
end

-- Create or update main container frame
local function CreateMainFrame(width, height)
    local state = ns.UI.GridState
    
    if not state.container then
        state.container = CreateFrame("Frame", "WhackAMoleGrid", UIParent)
    end
    
    state.container:SetSize(width, height)
    state.container:Show()
    
    -- Restore Position
    local pos = state.db and state.db.position
    if pos and pos.point then
        state.container:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
    else
        state.container:SetPoint("CENTER", 0, -220)
    end
    
    -- Enable dragging
    state.container:SetMovable(true)
    state.container:EnableMouse(true)
    
    return state.container
end

-- Create background texture
local function CreateBackground(container)
    local state = ns.UI.GridState
    
    if not state.bg then
        state.bg = container:CreateTexture(nil, "BACKGROUND")
        state.bg:SetAllPoints()
        state.bg:SetColorTexture(0, 0, 0, 0.5)
    end
    
    return state.bg
end

-- Create drag handle
local function CreateDragHandle(container)
    local state = ns.UI.GridState
    
    if not state.handle then
        state.handle = CreateFrame("Button", "WhackAMoleDragHandle", container)
        state.handle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        local handleTex = state.handle:CreateTexture(nil, "ARTWORK")
        handleTex:SetAllPoints()
        state.handle.tex = handleTex
        
        local handleText = state.handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        handleText:SetPoint("CENTER")
        state.handle.text = handleText
        
        -- Mouse events for dragging
        state.handle:SetScript("OnMouseDown", function(f, button)
            if button == "LeftButton" and not state.locked then
                container:StartMoving()
            end
        end)
        
        state.handle:SetScript("OnMouseUp", function(f, button)
            if button == "LeftButton" then
                if not state.locked then
                    container:StopMovingOrSizing()
                    -- Save Position
                    local point, _, relPoint, x, y = container:GetPoint()
                    if state.db then
                        state.db.position = { 
                            point = point, 
                            relativePoint = relPoint, 
                            x = x, 
                            y = y 
                        }
                    end
                end
            elseif button == "RightButton" then
                ns.UI.Grid:OpenContextMenu(f)
            end
        end)
    end
    
    return state.handle
end

-- Main Grid Creation Function
function ns.UI.Grid:Create(layout, config, restoreAssignments)
    local state = ns.UI.GridState
    
    if state.container then 
        state.container:Hide() 
        print("[WhackAMole] Grid: Hiding existing container for rebuild")
    end
    
    -- 清空所有现有按钮的状态（在创建前）
    if not InCombatLockdown() and state.slots then
        for i, btn in pairs(state.slots) do
            if btn then
                btn:SetAttribute("type", nil)
                btn:SetAttribute("spell", nil)
                if btn.icon then
                    btn.icon:SetTexture(nil)
                    btn.icon:SetAlpha(0)
                end
            end
        end
    end
    
    local iconSize = config.iconSize or state.DEFAULT_ICON_SIZE
    local spacing = config.spacing or state.DEFAULT_SPACING

    -- Count slots
    local count = 0
    for _ in pairs(layout.slots) do count = count + 1 end
    
    -- Calculate layout dimensions
    local cols, rows = CalculateLayout(count, layout)
    local width = cols * (iconSize + spacing)
    local height = rows * (iconSize + spacing)
    
    -- Create UI components
    local container = CreateMainFrame(width, height)
    CreateBackground(container)
    CreateDragHandle(container)
    
    -- Set initial lock state
    self:SetLock(true)

    -- Reset slots and create buttons
    state.slots = {}
    ns.UI.Grid:CreateSlots(layout, iconSize, spacing, cols, rows)
    
    -- Restore saved assignments (默认为true，切换配置时传false)
    if restoreAssignments ~= false then
        ns.UI.Grid:RestoreAssignments()
    end
end
