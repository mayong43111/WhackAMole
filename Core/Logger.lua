local addon, ns = ...
ns.Logger = {}
local L = ns.Logger

L.enabled = false
L.lines = {}
L.maxLines = 1000 -- Hard limit to prevent memory issues

function L:Start()
    -- Clear previous logs explicitly
    self.lines = {}
    self.enabled = true
    self:Log("Logging started.")
    print("|cff00ff00WhackAMole Logging Started.|r")
end

function L:Stop()
    self.enabled = false
    self:Log("Logging stopped.")
    print("|cffff0000WhackAMole Logging Stopped.|r Type /wam log show to view.")
end

function L:Log(msg)
    if not self.enabled then return end
    -- Note: date("%H:%M:%S") gives real time. In detailed analysis, state.now might also be useful.
    local time = date("%H:%M:%S") 
    table.insert(self.lines, string.format("[%s] %s", time, msg))
    
    if #self.lines > self.maxLines then
        table.remove(self.lines, 1)
    end
end

function L:Show()
    local AceGUI = LibStub("AceGUI-3.0")
    if not AceGUI then
        print("WhackAMole: AceGUI-3.0 not found.")
        return
    end
    
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("WhackAMole Debug Log")
    frame:SetLayout("Fill")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    
    local edit = AceGUI:Create("MultiLineEditBox")
    edit:SetLabel("Log Output (Ctrl+A, Ctrl+C to copy)")
    
    local text = table.concat(self.lines, "\n")
    if text == "" then text = "No logs recorded." end
    
    edit:SetText(text)
    edit:SetFullWidth(true)
    edit:SetFullHeight(true)
    edit:DisableButton(true) -- Hide the "Accept" button
    
    frame:AddChild(edit)
end
