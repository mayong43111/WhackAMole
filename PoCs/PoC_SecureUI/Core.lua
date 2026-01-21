local btnName = "PoC_SecureButton_Test"
local btn = CreateFrame("Button", btnName, UIParent, "SecureActionButtonTemplate")

btn:SetSize(64, 64)
btn:SetPoint("CENTER", 0, 0)

-- Texture
local tex = btn:CreateTexture(nil, "BACKGROUND")
tex:SetAllPoints()
tex:SetColorTexture(1, 0, 0, 0.5) -- Red Box
btn.tex = tex

-- Text
local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
fs:SetPoint("CENTER")
fs:SetText("Click\nMe")

-- Secure Attributes
-- Try to cast Hearthstone or something generic
btn:SetAttribute("type", "spell")
btn:SetAttribute("spell", "Attack") -- Auto Attack

btn:RegisterForClicks("AnyUp")

print("PoC_SecureUI: Red Button Created in Center. Clicks should toggle Auto Attack.")

-- API Check
print("InCombatLockdown status: " .. tostring(InCombatLockdown()))

local function UpdateButton(spellName)
    if InCombatLockdown() then
        print("Cannot update in combat!")
        return
    end
    print("Updating button to: " .. spellName)
    btn:SetAttribute("spell", spellName)
end

SLASH_POCUI1 = "/pocui"
SlashCmdList["POCUI"] = function(msg)
    if msg and msg ~= "" then
        UpdateButton(msg)
    end
end
