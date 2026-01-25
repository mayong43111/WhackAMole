local _, ns = ...

-- UI/Grid_refactored.lua
-- Main Grid module (refactored) - delegates to sub-modules

-- This file serves as the main entry point for the Grid UI system.
-- It loads all sub-modules and provides a unified API.

-- Sub-modules are loaded in the following order (via TOC):
-- 1. GridState.lua      - State management and configuration
-- 2. GridFrame.lua      - Frame creation and layout
-- 3. GridSlots.lua      - Button slot management
-- 4. GridDragDrop.lua   - Drag-and-drop interactions
-- 5. GridVisuals.lua    - Visual updates (cooldowns, glows)

-- All public API functions are defined in the sub-modules and accessible via:
-- ns.UI.Grid:Initialize(database)
-- ns.UI.Grid:Create(layout, config)
-- ns.UI.Grid:SetLock(isLocked)
-- ns.UI.Grid:UpdateButtonSpell(btn, spellName)
-- ns.UI.Grid:ClearAllAssignments()
-- ns.UI.Grid:OpenContextMenu(anchor)
-- ns.UI.Grid:UpdateVisuals(activeSlot, nextSlot, activeAction, nextAction)
-- ns.UI.Grid:GetSlotDef(slotIndex)

-- Internal state is accessible via:
-- ns.UI.GridState.db
-- ns.UI.GridState.container
-- ns.UI.GridState.slots
-- ns.UI.GridState.locked
-- etc.

-- Note: This refactored structure maintains 100% backward compatibility
-- with the original Grid.lua interface.
