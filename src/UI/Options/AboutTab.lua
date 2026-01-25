local _, ns = ...

-- UI/Options/AboutTab.lua
-- About tab with version information

ns.UI = ns.UI or {}
ns.UI.Options = ns.UI.Options or {}

function ns.UI.Options:GetAboutTab(WhackAMole)
    return {
        type = "group",
        name = "关于",
        order = 5,
        args = {
            title = {
                type = "description",
                name = "|cff00ccffWhackAMole|r MVP",
                fontSize = "large",
                order = 1
            },
            version = {
                type = "description",
                name = "版本: 1.2 (APL版)\n\n专为 WotLK 3.3.5a 设计。",    
                fontSize = "medium",
                order = 2
            },
            features = {
                type = "description",
                name = [[
|cff00ff00核心特性:|r
• APL (Action Priority List) 引擎
• SimulationCraft 脚本支持
• 多职业/专精配置
• 可视化技能推荐
• 配置导入/导出
• 内置 APL 编辑器

|cffff8800技术栈:|r
• AceAddon-3.0 框架
• LibCustomGlow 高亮效果
• 模块化架构设计
                ]],
                fontSize = "small",
                order = 3
            }
        }
    }
end
