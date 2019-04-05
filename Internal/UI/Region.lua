--[[

MIT License

Copyright (c) 2019 Mitchell Davis <coding.jackalope@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]

local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local MenuState = require(SLAB_PATH .. ".Internal.UI.MenuState")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Style = require(SLAB_PATH .. ".Style")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")

local Region = {}
local Instances = {}
local Stack = {}
local ActiveInstance = nil
local ScrollPad = 3.0
local ScrollBarSize = 10.0
local WheelX = 0.0
local WheelY = 0.0
local WheelSpeed = 3.0
local HotInstance = nil
local WheelInsance = nil

local function GetXScrollSize(Instance)
	if Instance ~= nil then
		return math.max(Instance.W - (Instance.ContentW - Instance.W), 20.0)
	end
	return 0.0
end

local function GetYScrollSize(Instance)
	if Instance ~= nil then
		return math.max(Instance.H - (Instance.ContentH - Instance.H), 20.0)
	end
	return 0.0
end

local function IsScrollHovered(Instance, X, Y)
	local HasScrollX, HasScrollY = false, false

	if Instance ~= nil then
		if Instance.HasScrollX then
			local PosY = Instance.Y + Instance.H - ScrollPad - ScrollBarSize
			local SizeX = GetXScrollSize(Instance)
			local PosX = Instance.ScrollPosX
			HasScrollX = Instance.X + PosX <= X and X < Instance.X + PosX + SizeX and PosY <= Y and Y < PosY + ScrollBarSize
		end

		if Instance.HasScrollY then
			local PosX = Instance.X + Instance.W - ScrollPad - ScrollBarSize
			local SizeY = GetYScrollSize(Instance)
			local PosY = Instance.ScrollPosY
			HasScrollY = PosX <= X and X < PosX + ScrollBarSize and Instance.Y + PosY <= Y and Y < Instance.Y + PosY + SizeY
		end
	end
	return HasScrollX, HasScrollY
end

local function Contains(Instance, X, Y)
	if Instance ~= nil then
		return Instance.X <= X and X <= Instance.X + Instance.W and Instance.Y <= Y and Y <= Instance.Y + Instance.H
	end
	return false
end

local function UpdateScrollBars(Instance, IsObstructed)
	if Instance.IgnoreScroll then
		return
	end

	Instance.HasScrollX = Instance.ContentW > Instance.W
	Instance.HasScrollY = Instance.ContentH > Instance.H

	local X, Y = Instance.MouseX, Instance.MouseY
	Instance.HoverScrollX, Instance.HoverScrollY = IsScrollHovered(Instance, X, Y)
	local XSize = Instance.W - GetXScrollSize(Instance)
	local YSize = Instance.H - GetYScrollSize(Instance)

	local IsMouseDragging = Mouse.IsDragging(1)
	local IsMouseReleased = Mouse.IsReleased(1)

	local DeltaX, DeltaY = Mouse.GetDelta()

	if not IsObstructed and Contains(Instance, X, Y) or (Instance.HoverScrollX or Instance.HoverScrollY) then
		Instance.ScrollAlphaX = 1.0
		Instance.ScrollAlphaY = 1.0

		if WheelInsance == Instance then
			if WheelX ~= 0.0 then
				Instance.ScrollPosX = Instance.ScrollPosX + WheelX
				Instance.IsScrollingX = true
				IsMouseDragging = true
				IsMouseReleased = true
				WheelX = 0.0
			end

			if WheelY ~= 0.0 then
				Instance.ScrollPosY = Instance.ScrollPosY - WheelY
				Instance.IsScrollingY = true
				IsMouseDragging = true
				IsMouseReleased = true
				WheelY = 0.0
			end

			WheelInsance = nil
		end

		HotInstance = Instance
	else
		local dt = love.timer.getDelta()
		Instance.ScrollAlphaX = math.max(Instance.ScrollAlphaX - dt, 0.0)
		Instance.ScrollAlphaY = math.max(Instance.ScrollAlphaY - dt, 0.0)
	end

	if HotInstance == Instance and not Contains(Instance, X, Y) then
		HotInstance = nil
	end

	if Instance.HasScrollX then
		if Instance.HasScrollY then
			XSize = XSize - ScrollBarSize - ScrollPad
		end
		if Instance.HoverScrollX or Instance.IsScrollingX then
			MenuState.RequestClose = false

			if IsMouseDragging then
				Instance.IsScrollingX = true

				Instance.ScrollPosX = math.max(Instance.ScrollPosX + DeltaX, 0.0)
			end

			if Instance.IsScrollingX and IsMouseReleased then
				Instance.IsScrollingX = false
			end
		end
		Instance.ScrollPosX = math.min(Instance.ScrollPosX, XSize)
	end

	if Instance.HasScrollY then
		if Instance.HasScrollX then
			YSize = YSize - ScrollBarSize - ScrollPad
		end
		if Instance.HoverScrollY or Instance.IsScrollingY then
			MenuState.RequestClose = false

			if IsMouseDragging then
				Instance.IsScrollingY = true
				
				Instance.ScrollPosY = math.max(Instance.ScrollPosY + DeltaY, 0.0)
			end

			if Instance.IsScrollingY and IsMouseReleased then
				Instance.IsScrollingY = false
			end
		end
		Instance.ScrollPosY = math.min(Instance.ScrollPosY, YSize)
	end

	local XRatio, YRatio = 0.0, 0.0
	if XSize ~= 0.0 then
		XRatio = math.max(Instance.ScrollPosX / XSize, 0.0)
	end
	if YSize ~= 0.0 then
		YRatio = math.max(Instance.ScrollPosY / YSize, 0.0)
	end

	local TX = math.max(Instance.ContentW - Instance.W, 0.0) * -XRatio
	local TY = math.max(Instance.ContentH - Instance.H, 0.0) * -YRatio
	Instance.Transform:setTransformation(TX, TY)
end

local function DrawScrollBars(Instance)
	if not Instance.HasScrollX and not Instance.HasScrollY then
		return
	end

	if HotInstance ~= Instance then
		Instance.ScrollAlphaX = 0.0
		Instance.ScrollAlphaY = 0.0
	end

	if Instance.HasScrollX then
		local XSize = GetXScrollSize(Instance)
		local Color = Utility.MakeColor(Style.ScrollBarColor)
		if Instance.HoverScrollX or Instance.IsScrollingX then
			Color = Utility.MakeColor(Style.ScrollBarHoveredColor)
		end
		Color[4] = Instance.ScrollAlphaX
		local XPos = Instance.ScrollPosX
		DrawCommands.Rectangle('fill', Instance.X + XPos, Instance.Y + Instance.H - ScrollPad - ScrollBarSize, XSize, ScrollBarSize, Color)
	end

	if Instance.HasScrollY then
		local YSize = GetYScrollSize(Instance)
		local Color = Utility.MakeColor(Style.ScrollBarColor)
		if Instance.HoverScrollY or Instance.IsScrollingY then
			Color = Utility.MakeColor(Style.ScrollBarHoveredColor)
		end
		Color[4] = Instance.ScrollAlphaY
		local YPos = Instance.ScrollPosY
		DrawCommands.Rectangle('fill', Instance.X + Instance.W - ScrollPad - ScrollBarSize, Instance.Y + YPos, ScrollBarSize, YSize, Color)
	end
end

local function GetInstance(Id)
	if Id == nil then
		return ActiveInstance
	end

	if Instances[Id] == nil then
		local Instance = {}
		Instance.Id = Id
		Instance.X = 0.0
		Instance.Y = 0.0
		Instance.W = 0.0
		Instance.H = 0.0
		Instance.SX = 0.0
		Instance.SY = 0.0
		Instance.ContentW = 0.0
		Instance.ContentH = 0.0
		Instance.HasScrollX = false
		Instance.HasScrollY = false
		Instance.HoverScrollX = false
		Instance.HoverScrollY = false
		Instance.IsScrollingX = false
		Instance.IsScrollingY = false
		Instance.ScrollPosX = 0.0
		Instance.ScrollPosY = 0.0
		Instance.ScrollAlphaX = 0.0
		Instance.ScrollAlphaY = 0.0
		Instance.Intersect = false
		Instance.Transform = love.math.newTransform()
		Instance.Transform:reset()
		Instances[Id] = Instance
	end
	return Instances[Id]
end

function Region.Begin(Id, Options)
	Options = Options == nil and {} or Options
	Options.X = Options.X == nil and 0.0 or Options.X
	Options.Y = Options.Y == nil and 0.0 or Options.Y
	Options.W = Options.W == nil and 0.0 or Options.W
	Options.H = Options.H == nil and 0.0 or Options.H
	Options.SX = Options.SX == nil and Options.X or Options.SX
	Options.SY = Options.SY == nil and Options.Y or Options.SY
	Options.ContentW = Options.ContentW == nil and 0.0 or Options.ContentW
	Options.ContentH = Options.ContentH == nil and 0.0 or Options.ContentH
	Options.AutoSizeContent = Options.AutoSizeContent == nil and false or Options.AutoSizeContent
	Options.BgColor = Options.BgColor == nil and Style.WindowBackgroundColor or Options.BgColor
	Options.NoOutline = Options.NoOutline == nil and false or Options.NoOutline
	Options.NoBackground = Options.NoBackground == nil and false or Options.NoBackground
	Options.IsObstructed = Options.IsObstructed == nil and false or Options.IsObstructed
	Options.Intersect = Options.Intersect == nil and false or Options.Intersect
	Options.IgnoreScroll = Options.IgnoreScroll == nil and false or Options.IgnoreScroll
	Options.MouseX = Options.MouseX == nil and 0.0 or Options.MouseX
	Options.MouseY = Options.MouseY == nil and 0.0 or Options.MouseY
	Options.ResetContent = Options.ResetContent == nil and false or Options.ResetContent

	local Instance = GetInstance(Id)
	Instance.X = Options.X
	Instance.Y = Options.Y
	Instance.W = Options.W
	Instance.H = Options.H
	Instance.SX = Options.SX
	Instance.SY = Options.SY
	Instance.Intersect = Options.Intersect
	Instance.IgnoreScroll = Options.IgnoreScroll
	Instance.MouseX = Options.MouseX
	Instance.MouseY = Options.MouseY

	if Options.ResetContent then
		Instance.ContentW = 0.0
		Instance.ContentH = 0.0
	end

	if not Options.AutoSizeContent then
		Instance.ContentW = Options.ContentW
		Instance.ContentH = Options.ContentH
	end

	ActiveInstance = Instance
	table.insert(Stack, 1, ActiveInstance)

	UpdateScrollBars(Instance, Options.IsObstructed)

	if not Options.NoBackground then
		DrawCommands.Rectangle('fill', Instance.X, Instance.Y, Instance.W, Instance.H, Options.BgColor)
	end
	if not Options.NoOutline then
		DrawCommands.Rectangle('line', Instance.X, Instance.Y, Instance.W, Instance.H)
	end
	DrawCommands.TransformPush()
	DrawCommands.ApplyTransform(Instance.Transform)
	Region.ApplyScissor()
end

function Region.End()
	DrawCommands.TransformPop()
	DrawScrollBars(ActiveInstance)

	if HotInstance == ActiveInstance and WheelInsance == nil and (WheelX ~= 0.0 or WheelY ~= 0.0) then
		WheelInsance = ActiveInstance
	end

	if ActiveInstance.Intersect then
		DrawCommands.IntersectScissor()
	else
		DrawCommands.Scissor()
	end

	ActiveInstance = nil
	table.remove(Stack, 1)

	if #Stack > 0 then
		ActiveInstance = Stack[1]
	end
end

function Region.IsHoverScrollBar(Id)
	local Instance = GetInstance(Id)
	if Instance ~= nil then
		return Instance.HoverScrollX or Instance.HoverScrollY
	end
	return false
end

function Region.Translate(Id, X, Y)
	local Instance = GetInstance(Id)
	if Instance ~= nil then
		Instance.Transform:translate(X, Y)
	end
end

function Region.Transform(Id, X, Y)
	local Instance = GetInstance(Id)
	if Instance ~= nil then
		return Instance.Transform:transformPoint(X, Y)
	end
	return X, Y
end

function Region.InverseTransform(Id, X, Y)
	local Instance = GetInstance(Id)
	if Instance ~= nil then
		return Instance.Transform:inverseTransformPoint(X, Y)
	end
	return X, Y
end

function Region.ResetTransform(Id)
	local Instance = GetInstance(Id)
	if Instance ~= nil then
		Instance.Transform:reset()
	end
end

function Region.IsActive(Id)
	if ActiveInstance ~= nil then
		return ActiveInstance.Id == Id
	end
	return false
end

function Region.AddItem(X, Y, W, H)
	if ActiveInstance ~= nil then
		local NewW = X + W - ActiveInstance.X
		local NewH = Y + H - ActiveInstance.Y
		ActiveInstance.ContentW = math.max(ActiveInstance.ContentW, NewW)
		ActiveInstance.ContentH = math.max(ActiveInstance.ContentH, NewH)
	end
end

function Region.ApplyScissor()
	if ActiveInstance ~= nil then
		if ActiveInstance.Intersect then
			DrawCommands.IntersectScissor(ActiveInstance.SX, ActiveInstance.SY, ActiveInstance.W, ActiveInstance.H)
		else
			DrawCommands.Scissor(ActiveInstance.SX, ActiveInstance.SY, ActiveInstance.W, ActiveInstance.H)
		end
	end
end

function Region.GetBounds()
	if ActiveInstance ~= nil then
		return ActiveInstance.X, ActiveInstance.Y, ActiveInstance.W, ActiveInstance.H
	end
	return 0.0, 0.0, 0.0, 0.0
end

function Region.GetContentSize()
	if ActiveInstance ~= nil then
		return ActiveInstance.ContentW, ActiveInstance.ContentH
	end
	return 0.0, 0.0
end

function Region.Contains(X, Y)
	if ActiveInstance ~= nil then
		return ActiveInstance.X <= X and X <= ActiveInstance.X + ActiveInstance.W and ActiveInstance.Y <= Y and Y <= ActiveInstance.Y + ActiveInstance.H
	end
	return false
end

function Region.ResetContentSize(Id)
	local Instance = GetInstance(Id)
	if Instance ~= nil then
		Instance.ContentW = 0.0
		Instance.ContentH = 0.0
	end
end

function Region.GetScrollPad()
	return ScrollPad
end

function Region.WheelMoved(X, Y)
	WheelX = X * WheelSpeed
	WheelY = Y * WheelSpeed
end

function Region.GetHotInstanceId()
	if HotInstance ~= nil then
		return HotInstance.Id
	end

	return ''
end

return Region
