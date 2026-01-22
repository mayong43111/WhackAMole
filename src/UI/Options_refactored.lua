local _, ns = ...

-- UI/Options_refactored.lua
-- Main options table builder (refactored)

-- This file assembles the complete AceConfig-3.0 options table
-- by combining all sub-tabs from modular files.

-- Sub-modules are loaded in the following order (via TOC):
-- 1. ProfileTab.lua       - Profile selection and documentation
-- 2. ImportExportTab.lua  - Import/Export functionality
-- 3. APLEditorTab.lua     - APL script editor
-- 4. SettingsTab.lua      - General settings
-- 5. AboutTab.lua         - About information

ns.UI = ns.UI or {}

function ns.UI.GetOptionsTable(WhackAMole)
    local args = {}
    
    -- Build options table from sub-modules
    args["profiles"] = ns.UI.Options:GetProfileTab(WhackAMole)
    args["import_export"] = ns.UI.Options:GetImportExportTab(WhackAMole)
    args["apl_editor"] = ns.UI.Options:GetAPLEditorTab(WhackAMole)
    args["settings"] = ns.UI.Options:GetSettingsTab(WhackAMole)
    args["about"] = ns.UI.Options:GetAboutTab(WhackAMole)

    return {
        name = "WhackAMole 选项",
        handler = WhackAMole,
        type = "group",
        childGroups = "tree", -- Tree layout (tabs on left)
        args = args
    }
end
