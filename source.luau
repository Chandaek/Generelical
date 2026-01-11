-- VARIABLES --
local VERSION = "1.0.0"

-- TYPES --
export type SupportedUi =
	| "CanvasGroup"
	| "Frame"
	| "ImageButton"
	| "ImageLabel"
	| "ScreenGui"
	| "ScrollingFrame"
	| "TextBox"
	| "TextButton"
	| "TextLabel"
	| "UIAspectRatioConstraint"
	| "UIGradient"
	| "UIGridLayout"
	| "UIListLayout"
	| "UIPadding"
	| "UIStroke"

export type PrimaryCallback = (InputObject, boolean) -> ()

export type TouchLike = PrimaryCallback | { PrimaryCallback }

export type Properties = { [string]: any, TouchBegan: TouchLike?, TouchEnded: TouchLike? }

-- MODULE --
local source: {
	Version: string,
	Bind: (self: any, uiInstance: Instance, properties: Properties) -> (),
	Create: (self: any, uiClassName: SupportedUi) -> { Instance: Instance, Bind: (self: any, Properties) -> () },
} = {}
source.Version = VERSION

local UiClasses: { [SupportedUi]: () -> Instance } = {
	CanvasGroup = function() return Instance.new("CanvasGroup") end,
	Frame = function() return Instance.new("Frame") end,
	ImageButton = function() return Instance.new("ImageButton") end,
	ImageLabel = function() return Instance.new("ImageLabel") end,
	ScreenGui = function() return Instance.new("ScreenGui") end,
	ScrollingFrame = function() return Instance.new("ScrollingFrame") end,
	TextBox = function() return Instance.new("TextBox") end,
	TextButton = function() return Instance.new("TextButton") end,
	TextLabel = function() return Instance.new("TextLabel") end,
	UIAspectRatioConstraint = function() return Instance.new("UIAspectRatioConstraint") end,
	UIGradient = function() return Instance.new("UIGradient") end,
	UIGridLayout = function() return Instance.new("UIGridLayout") end,
	UIListLayout = function() return Instance.new("UIListLayout") end,
	UIPadding = function() return Instance.new("UIPadding") end,
	UIStroke = function() return Instance.new("UIStroke") end,
}

local function isGuiObject(u: any): boolean
	return type(u) == "userdata" and u ~= nil and type(u.IsA) == "function" and u:IsA("GuiObject")
end

local function isPrimaryInput(input: any): boolean
	if typeof(input) ~= "Instance" and type(input) ~= "userdata" then
		-- best-effort; treat unknown as not primary
		return false
	end
	
	local ok, t = pcall(function() return input.UserInputType end)
	if not ok then return false end
	
	if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
		return true
	end
	
	-- gamepad types like Gamepad1, Gamepad2, etc.
	if tostring(t):match("^Gamepad") then
		return true
	end
	
	if t == Enum.UserInputType.Keyboard then
		local keyOk, kc = pcall(function() return input.KeyCode end)
		if keyOk and (kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return) then
			return true
		end
	end
	
	return false
end

local UiUnique: {
	TouchBegan: (GuiObject, PrimaryCallback) -> (),
	TouchEnded: (GuiObject, PrimaryCallback) -> (),
} = {} :: any

UiUnique.TouchBegan = function(ui: GuiObject, func: PrimaryCallback)
	if not isGuiObject(ui) or type(func) ~= "function" then
		return
	end
	
	ui.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if isPrimaryInput(input) then
			pcall(func, input, gameProcessed)
		end
	end)
end

UiUnique.TouchEnded = function(ui: GuiObject, func: PrimaryCallback)
	if not isGuiObject(ui) or type(func) ~= "function" then
		return
	end
	
	ui.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if isPrimaryInput(input) then
			pcall(func, input, gameProcessed)
		end
	end)
end

function source:Bind(uiInstance: Instance, properties: Properties)
	if typeof(uiInstance) ~= "Instance" then
		warn("source:Bind - uiInstance is not an Instance")
		return
	end
	
	if type(properties) ~= "table" then
		return
	end
	
	for prop, value in pairs(properties) do
		-- skip special handlers
		if UiUnique[prop] then
			continue
		end
		
		local ok, err = pcall(function()
			uiInstance[prop] = value
		end)
		
		if not ok then
			local name = (type(uiInstance) == "userdata" and uiInstance.Name) or tostring(uiInstance)
			warn(("Failed to set property '%s' on %s: %s"):format(tostring(prop), tostring(name), tostring(err)))
		end
	end
	
	local function bindList(key: string)
		local list = properties[key]
		if list == nil then return end
		-- only GUI objects support InputBegan/InputEnded
		if not isGuiObject(uiInstance) then
			warn(("Attempted to bind '%s' on non-GuiObject %s"):format(tostring(key), tostring(uiInstance)))
			return
		end
		
		local binder = UiUnique[key]
		if not binder then return end
		
		if type(list) == "function" then
			binder(uiInstance :: GuiObject, list)
		elseif type(list) == "table" then
			for _, fn in ipairs(list) do
				if type(fn) == "function" then
					binder(uiInstance :: GuiObject, fn)
				end
			end
		end
	end
	
	bindList("TouchBegan")
	bindList("TouchEnded")
end

function source:Create(uiClassName: SupportedUi)
	local ctor = UiClasses[uiClassName]
	if not ctor then
		error(("UiClass '%s' is not supported."):format(tostring(uiClassName)))
		return
	end
	
	local inst = ctor()
	return {
		Instance = inst,
		Bind = function(_, properties: Properties)
			return source:Bind(inst, properties)
		end,
	}
end

return source
