local _, ns = ...
ns.SpecRegistry = {}
ns.SpecRegistry.handlers = {}

-- Register a handler function for a specific class
function ns.SpecRegistry:Register(class, func)
    self.handlers[class] = func
end

-- Execute the detection logic for a specific class
function ns.SpecRegistry:Detect(class)
    local func = self.handlers[class]
    if func then
        return func()
    end
    return nil
end
