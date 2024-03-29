local ColorPicker = {}
ColorPicker.__index = ColorPicker


local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local SCALE_FROM_CENTER = 0.908203125

function ColorPicker.new(plugin : Plugin, ColorPickerWidget : DockWidgetPluginGui,currentColor : Color3)
	local self = setmetatable(ColorPicker,{})
	local h,s,b = currentColor:ToHSV()
	self.degreesAroundCenter = h*360
	self.Saturation = s
	self.Brightness = b
	self.ColorPicker = script.Parent.Parent.Parent.ColorPicker.ColorPicker:Clone()
	self.ColorPicker.Parent = ColorPickerWidget
	self.ColorPickerWidget = ColorPickerWidget
	self.ColorLabel = self.ColorPicker.ImageLabel
	self.Options = self.ColorPicker.Options
	self.Connections = {}
	self.plugin = plugin
	self.background = Instance.new("Frame")
	self.background.Parent = ColorPickerWidget
	self.background.Size = UDim2.new(1,0,1,0)
	self.background.BackgroundColor3 = Color3.fromRGB(150,150,150)
	self.background.ZIndex = 0
	
	self.ColorChangeEvent = Instance.new("BindableEvent")
	self.ColorSaveEvent = Instance.new("BindableEvent")
	self.ColorCancelEvent = Instance.new("BindableEvent")
	
	self:CreateConnections()
	
	
	return self
end



function ColorPicker:UpdateColor()
	
	
	local degreesToHue = self.degreesAroundCenter/360
	
	local currentColor = Color3.fromHSV(degreesToHue,self.Saturation,self.Brightness)
	
	self.ColorPicker.Options.CurrentColor.BackgroundColor3 = currentColor
	self.ColorLabel.Frame.BackgroundColor3 = Color3.fromHSV(degreesToHue,1,1)
	self.ColorLabel.Ticker.BackgroundColor3 = Color3.fromHSV(degreesToHue,1,1)
	self.ColorLabel.Frame.Ticker.BackgroundColor3 = currentColor
	
	local vectorForHue = Vector2.new(math.cos(math.rad(self.degreesAroundCenter)),math.sin(math.rad(self.degreesAroundCenter)))
	local newTickerPosition = (-vectorForHue) * SCALE_FROM_CENTER/2 + Vector2.one/2
	
	
	self.ColorLabel.Frame.Rotation = self.degreesAroundCenter + 225
	self.ColorLabel.Ticker.Position = UDim2.fromScale(newTickerPosition.X,newTickerPosition.Y)
	
	
	self.ColorLabel.Frame.Ticker.Position = UDim2.fromScale(self.Saturation,1-self.Brightness)
	
	
	self.Options.HSV.HueValue.Text = math.round(self.degreesAroundCenter)
	self.Options.HSV.SaturationValue.Text = math.round(self.Saturation*255)
	self.Options.HSV.BrightnessValue.Text = math.round(self.Brightness*255)
	self.Options.Hex.Value.Text = `#{currentColor:ToHex():upper()}`
	self.Options.RGB.Value.Text = `{math.round(currentColor.R*255)}, {math.floor(currentColor.G*255)}, {math.floor(currentColor.B*255)}`

	self.ColorChangeEvent:Fire(currentColor)
end

function ColorPicker:CreateConnections()
	local debounceOne = true
	local debounceTwo = true
	
	local function debounceOneFunc(input : InputObject,sucess)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			debounceOne = not debounceOne
		end
	end
	local function debounceTwoFunc(input : InputObject,sucess)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			debounceTwo = not debounceTwo
		end
	end
	
	table.insert(self.Connections,self.ColorLabel.InputBegan:Connect(debounceOneFunc))
	table.insert(self.Connections,self.ColorLabel.InputEnded:Connect(debounceOneFunc))

	table.insert(self.Connections,self.ColorLabel.Frame.InputBegan:Connect(debounceTwoFunc))
	table.insert(self.Connections,self.ColorLabel.Frame.InputEnded:Connect(debounceTwoFunc))
	
	table.insert(self.Connections,RunService.RenderStepped:Connect(function()
		if not debounceTwo then

			local degreesToHue = self.degreesAroundCenter/360

			local mouse = self.ColorPickerWidget:GetRelativeMousePosition()
			local mousePosition = -((self.ColorLabel.Frame.AbsolutePosition + self.ColorLabel.Frame.AbsoluteSize/2) - Vector2.new(mouse.X,mouse.Y))  --- GuiService:GetGuiInset()
			local rotAmount = 135 - self.degreesAroundCenter
			local rotationMatrix = {
				math.cos(math.rad(rotAmount)),-math.sin(math.rad(rotAmount)),
				math.sin(math.rad(rotAmount)), math.cos(math.rad(rotAmount))
			}

			local mouseDistance = mousePosition.Magnitude
			local rotatedX = mousePosition.X * rotationMatrix[1] + mousePosition.Y * rotationMatrix[2]
			local rotatedY = mousePosition.X * rotationMatrix[3] + mousePosition.Y * rotationMatrix[4]

			local framePos =  (Vector2.new(rotatedX,rotatedY) + self.ColorLabel.Frame.AbsoluteSize/2)/self.ColorLabel.Frame.AbsoluteSize

			self.Saturation = math.clamp(framePos.X,0,1)
			self.Brightness = math.clamp(1 - framePos.Y,0,1)
			self:UpdateColor()

		elseif not debounceOne and debounceTwo then
			local mouse = self.ColorPickerWidget:GetRelativeMousePosition()
			local mousePosition = (self.ColorLabel.AbsolutePosition + self.ColorLabel.AbsoluteSize/2) - Vector2.new(mouse.X,mouse.Y) --+ GuiService:GetGuiInset()

			self.degreesAroundCenter = math.deg(math.acos(Vector2.new(1,0).Unit:Dot(mousePosition.Unit))) -- could have used atan2 :/

			if mousePosition.Y < 0 then
				self.degreesAroundCenter = 360 - self.degreesAroundCenter
			end

			self:UpdateColor()
		end
	end))

	local function brightSat(typeOfVal : "Brightness" | "Saturation")
		local currentText = self.Options.HSV[`{typeOfVal}Value`].Text

		local match = currentText:match("^(%d%d?%d?)$")

		if match and tonumber(match) <= 255 and tonumber(match) >= 0  then

			self[typeOfVal] = match / 255
			self:UpdateColor()

		else
			self.Options.HSV[`{typeOfVal}Value`].Text = math.round(self[typeOfVal]*255)
		end
	end
	
	table.insert(self.Connections,self.Options.HSV.BrightnessValue.FocusLost:Connect(function() brightSat("Brightness") end))
	
	table.insert(self.Connections,self.Options.HSV.SaturationValue.FocusLost:Connect(function() brightSat("Saturation") end))
	
	table.insert(self.Connections,self.Options.HSV.HueValue.FocusLost:Connect(function()
		
		local currentText = self.Options.HSV.HueValue.Text
		
		local match = currentText:match("^(%d%d?%d?)$")
		
		if match and tonumber(match) <= 360 and tonumber(match) >= 0 then
			
			self.degreesAroundCenter = match
			self:UpdateColor()
			
		else
			self.Options.HSV.HueValue.Text = math.round(self.degreesAroundCenter)
		end
		
	end))
	
	table.insert(self.Connections,self.Options.Hex.Value.FocusLost:Connect(function()
		
		local currentText = self.Options.Hex.Value.Text:upper()
		local r,g,b = currentText:match("^#?(%x%x)(%x%x)(%x%x)$")
		
		if not r or not g or not b then
			r,g,b = currentText:match("^#?(%x)(%x)(%x)$")
			if not r or not g or not b then
				local currentColor = Color3.fromHSV(self.degreesAroundCenter/360,self.Saturation,self.Brightness)
				self.Options.Hex.Value.Text = "#" .. currentColor:ToHex():upper()
				return
			end
		end
		
		local color3FromHex = Color3.fromHex(r..g..b)
		local h,s,b = color3FromHex:ToHSV() 
		self.degreesAroundCenter = h*360
		self.Saturation = s
		self.Brightness = b
		self:UpdateColor()
		
	end))
	
	table.insert(self.Connections,self.Options.RGB.Value.FocusLost:Connect(function()
		
		local currentText = self.Options.RGB.Value.Text
		local r,g,b = currentText:match("^(%d%d?%d?),? ?(%d%d?%d?),? ?(%d%d?%d?)$")
		
		local color3FromHex
		if not r or not g or not b or tonumber(r) > 255 or tonumber(g) > 255 or tonumber(b) > 255 or tonumber(r) < 0 or tonumber(g) < 0 or tonumber(b) < 0 then
			
			local currentColor = Color3.fromHSV(self.degreesAroundCenter/360,self.Saturation,self.Brightness)
			self.Options.RGB.Value.Text = `{math.round(currentColor.R*255)}, {math.floor(currentColor.G*255)}, {math.floor(currentColor.B*255)}`
			return
		end
		
		local color3FromHex = Color3.fromRGB(tonumber(r),tonumber(g),tonumber(b))
		local h,s,b = color3FromHex:ToHSV() 
		self.degreesAroundCenter = h*360
		self.Saturation = s
		self.Brightness = b
		self:UpdateColor()
		
	end))
	
	table.insert(self.Connections,self.ColorPicker.SaveFrame.SaveButton.MouseButton1Click:Connect(function()
		self.ColorPicker.Parent.Enabled = false
		self.ColorSaveEvent:Fire(Color3.fromHSV(self.degreesAroundCenter/360,self.Saturation,self.Brightness))
	end))
	
	self.ColorPicker.Parent:BindToClose(function()
		self.ColorCancelEvent:Fire()
	end)
end

function ColorPicker:CloseConnections()
	for i,v in self.Connections do
		v:Disconnect()
	end
	if self.ColorPicker.Parent then
		self.ColorPicker.Parent.Enabled = false
	end
	
	self.ColorChangeEvent:Destroy()
	self.ColorSaveEvent:Destroy()
	self.ColorCancelEvent:Destroy()
	self.ColorPicker:Destroy()
end

return ColorPicker
