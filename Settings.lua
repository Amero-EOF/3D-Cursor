local Settings = {}
Settings.__index = Settings
local MarketplaceService = game:GetService("MarketplaceService")
local ContentProvider = game:GetService("ContentProvider")
local ColorPicker = require(script.ColorPicker)

-- ImageType
-- rbxassetid = 0
-- rbxthum = 1


function Settings.new(plugin,settingsButton,cursorButton)
	local self = setmetatable(Settings,{})
	
	self.plugin = plugin
	local PrimaryColor = self.plugin:GetSetting("3DCurs_PrimaryColor")
	local SecondaryColor = self.plugin:GetSetting("3DCurs_SecondaryColor")
	local TertiaryColor = self.plugin:GetSetting("3DCurs_TertiaryColor")
	local TextColor = self.plugin:GetSetting("3DCurs_TextColor")
	self.PrimaryColor = PrimaryColor and Color3.fromHex(PrimaryColor) or Color3.fromRGB(10, 16, 30)
	self.SecondaryColor = SecondaryColor and Color3.fromHex(SecondaryColor) or Color3.fromRGB(1, 3, 7)
	self.TertiaryColor = TertiaryColor and Color3.fromHex(TertiaryColor) or Color3.fromRGB(64, 5, 72)
	self.TextColor = TextColor and Color3.fromHex(TextColor) or Color3.fromRGB(255, 255, 255)
	self.Cursor = nil
	if self.plugin:GetSetting("3DCurs_CursorSize") then
		self.CursorSize = tonumber(self.plugin:GetSetting("3DCurs_CursorSize"))
	else
		self.CursorSize = 40
	end
	self.CursorImage = self.plugin:GetSetting("3DCurs_CursorImage") or 10127689049
	self.ImageType = self.plugin:GetSetting("3DCurs_ImageType") or 0
	self.SettingsConnections = {}
	self.ColorPickerObject = nil
	self.settingsWidget = nil
	
	local settingsWidgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Float,
		false,
		true, -- closes menu after plugin reload
		300,
		228,
		300,
		228
	)
	self.settingsWidget = plugin:CreateDockWidgetPluginGui("3DCursorSettings",settingsWidgetInfo)
	self.settingsWidget.Title = "Settings"
	self.settingsUI = script.Parent.Parent.SettingsUI.SettingsFrame
	self.settingsUI.Parent = self.settingsWidget
	--local openSettings = false
	
	
	local colorPickerWidgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Float,
		false,
		true, -- closes menu after plugin reload
		462,
		266,
		462,
		266
	)
	local colorPickerWidget : DockWidgetPluginGui = plugin:CreateDockWidgetPluginGui("3DCursorColorPicker",colorPickerWidgetInfo)
	
	local colorCache = nil
	local cursorSizeCache = nil
	local cursorImageCache = nil
	
	settingsButton.Click:Connect(function()
		--openSettings = not openSettings
		if not self.settingsWidget.Enabled then
			local ColorSection = self.settingsUI.ColorSection
			local CursorSection = self.settingsUI.CursorSection
			local SaveOperations = self.settingsUI.SaveOperations
			
			local canUseButtons = true
			self.settingsWidget.Enabled = true
			
			--[[
			#################
			# Color Section #
			#################
			--]]
			
			
			local function ColorButton(ColorName)
				canUseButtons = false
				colorPickerWidget.Enabled = true
				colorCache = {ColorName,self[ColorName]}
				self.ColorPickerObject = ColorPicker.new(plugin,colorPickerWidget,self[ColorName])
				
				local changeEvent = nil
				local saveEvent = nil
				local cancelEvent = nil
				
				changeEvent = self.ColorPickerObject.ColorChangeEvent.Event:Connect(function(currentColor : Color3)
					self[ColorName] = currentColor
					self:SetColors()
				end)
				saveEvent = self.ColorPickerObject.ColorSaveEvent.Event:Connect(function(currentColor : Color3)
					self[ColorName] = currentColor
					self.plugin:SetSetting("3DCurs_"..ColorName,currentColor:ToHex())
					self.ColorPickerObject:CloseConnections()
					self.ColorPickerObject = nil
					canUseButtons = true
					colorCache = nil
				end)
				
				cancelEvent = self.ColorPickerObject.ColorCancelEvent.Event:Connect(function()
					self[ColorName] = colorCache[2]
					self.ColorPickerObject:CloseConnections()
					self.ColorPickerObject = nil
					self:SetColors()
					canUseButtons = true
					colorCache = nil
				end)
			end
			table.insert(self.SettingsConnections,ColorSection.TextColor.BackLabel.TextColorButton.MouseButton1Click:Connect(function()
				if canUseButtons then
					ColorButton("TextColor")
				end
			end))
			
			table.insert(self.SettingsConnections,ColorSection.PrimaryColor.PrimaryColorButton.MouseButton1Click:Connect(function()
				if canUseButtons then
					ColorButton("PrimaryColor")	
				end	
			end))
			
			table.insert(self.SettingsConnections,ColorSection.SecondaryColor.BackLabel.SecondaryColorButton.MouseButton1Click:Connect(function()
				if canUseButtons then
					ColorButton("SecondaryColor")
				end				
			end))
			
			table.insert(self.SettingsConnections,ColorSection.TertiaryColor.TertiaryColorButton.MouseButton1Click:Connect(function()
				if canUseButtons then
					ColorButton("TertiaryColor")
				end	
			end))
			
			--[[
			#################
			# Color Section #
			#################
			--]]
			------------------------------------------------------------------
			--[[
			##################
			# Cursor Section #
			##################
			--]]
			local cursorSizeTextBox = CursorSection.CursorSize.BackLabel.TextBox
			table.insert(self.SettingsConnections,cursorSizeTextBox.FocusLost:Connect(function()
				local check = tonumber(cursorSizeTextBox.Text)
				
				if check then
					cursorSizeCache = self.CursorSize
					self.CursorSize = math.floor(check)
					self:SetCursor()
				else
					cursorSizeTextBox.Text = self.CursorSize
				end
			end))
			
			local cursorImageTextBox = CursorSection.CursorImage.TextBox
			
			table.insert(self.SettingsConnections,cursorImageTextBox.FocusLost:Connect(function()
				local check = string.match(cursorImageTextBox.Text,"%d+")
				check = tonumber(check)
				if check then

					local success = false
					local imageId = nil
					local counter = 0
					local imageType = nil
					ContentProvider:PreloadAsync({"rbxassetid://" .. check,string.format("rbxthumb://type=Asset&id=%s&w=420&h=420", check)},function(assetId : string,assetStatus : Enum.AssetFetchStatus)
						if assetStatus == Enum.AssetFetchStatus.Success then
							success = true
							imageId = assetId
							imageType = counter
						end
						counter+=1
					end)

					if success then	
						cursorImageCache = self.CursorImage
						cursorImageTextBox.Text = check
						self.CursorImage = check
						self.ImageType = imageType
						self:SetCursor()
						return
					end
				end
				cursorImageTextBox.Text = self.CursorImage
			end))
			
			
			--[[
			##################
			# Cursor Section #
			##################
			--]]
			------------------------------------------------------------------
			--[[
			################
			# Save Section #
			################
			--]]
			
			table.insert(self.SettingsConnections,SaveOperations.Reset.ResetToDefault.MouseButton1Click:Connect(function()
				if not self.ColorPickerObject then -- this could cause people to think that they have an issue not resetting if the color picker still exists, however this will stay.
					self.PrimaryColor = Color3.fromRGB(10, 16, 30)
					self.SecondaryColor = Color3.fromRGB(1, 3, 7)
					self.TertiaryColor = Color3.fromRGB(64, 5, 72)
					self.TextColor = Color3.fromRGB(255, 255, 255)
					self.CursorSize = 40
					self.CursorImage = 10127689049
					self.ImageType = 0
					
					self.plugin:SetSetting("3DCurs_PrimaryColor",self.PrimaryColor:ToHex())
					self.plugin:SetSetting("3DCurs_SecondaryColor",self.SecondaryColor:ToHex())
					self.plugin:SetSetting("3DCurs_TertiaryColor",self.TertiaryColor:ToHex())
					self.plugin:SetSetting("3DCurs_TextColor",self.TextColor:ToHex())
					self.plugin:SetSetting("3DCurs_CursorSize",self.CursorSize)
					self.plugin:SetSetting("3DCurs_CursorImage",self.CursorImage)
					self.plugin:SetSetting("3DCurs_ImageType",self.ImageType)
					colorCache = nil
					cursorSizeCache = nil
					cursorImageCache = nil
					self:SetColors()
					self:SetCursor()
					self.settingsWidget.Enabled = false
				end
			end))
			
			table.insert(self.SettingsConnections,SaveOperations.Save.SaveButton.MouseButton1Click:Connect(function()
				if not self.ColorPickerObject then -- this could cause people to think that they have an issue not saving if the color picker still exists, however this will stay.
					self.plugin:SetSetting("3DCurs_CursorSize",self.CursorSize)
					self.plugin:SetSetting("3DCurs_CursorImage",self.CursorImage) 
					self.plugin:SetSetting("3DCurs_ImageType",self.ImageType)
					--openSettings = false
					--settingsButton:SetActive(false)
					colorCache = nil
					cursorSizeCache = nil
					cursorImageCache = nil
					self.settingsWidget.Enabled = false
					self:SetCursor()
				end
			end))
			
			
			
		else
			self.settingsWidget.Enabled = false
		end
		
		--settingsWidget.Enabled = openSettings
	end)
	self.settingsWidget:GetPropertyChangedSignal("Enabled"):Connect(function()
		settingsButton:SetActive(self.settingsWidget.Enabled)
		if self.ColorPickerObject then
			self.ColorPickerObject:CloseConnections()
			self.ColorPickerObject = nil
			if colorCache then
				self[colorCache[1]] = colorCache[2]
				self:SetColors()
			end
		end
		
		if self.settingsWidget.Enabled == false then
			if cursorSizeCache then
				self.CursorSize = cursorSizeCache
			elseif cursorImageCache then
				self.CursorImage = cursorImageCache
			end
			self:SetCursor()
			self:CloseConnections()
		end
		--openSettings = settingsWidget.Enabled
	end)
	
	--settingsWidget:BindToClose(function()
	--	print("hey")
	--	settingsButton:SetActive(false)
	--	settingsWidget.Enabled = false
	--	openSettings = false
	--	print(settingsButton.Name)
	--	--settingsButton:SetActive(false)
	--end)
	
	self:SetCursor()
	self:SetColors()
	
	return self
end

function Settings:SetCursor()
	local CursorSection = self.settingsUI.CursorSection
	local cursorSizeTextBox = CursorSection.CursorSize.BackLabel.TextBox
	local cursorImageTextBox = CursorSection.CursorImage.TextBox
	
	cursorSizeTextBox.Text = self.CursorSize
	cursorImageTextBox.Text = self.CursorImage
	if self.Cursor then
		self.Cursor.Size = UDim2.new(0,self.CursorSize,0,self.CursorSize)
		if self.ImageType == 0 then
			self.Cursor.ImageLabel.Image = "rbxassetid://" .. self.CursorImage
		else
			self.Cursor.ImageLabel.Image = string.format("rbxthumb://type=Asset&id=%s&w=420&h=420", self.CursorImage)
		end
	end
	
end


function Settings:SetColors()
	
	local ContextMenu = script.Parent.Parent.ContextMenu.Frame
	
	local PrimaryColor = {
		
		-- Settings
		
		self.settingsUI.ColorSection.PrimaryColor.PrimaryColorButton,
		self.settingsUI.CursorSection.CursorSize.BackLabel.TextBox,
		self.settingsUI,
		
		-- ContextMenu
		
		ContextMenu.CursorToOrigin,
		ContextMenu.CursorToSel,
		ContextMenu.SelToCursor,
		ContextMenu.SelToCursorOff,
		ContextMenu.CenterStroke
		
	}
	
	local SecondaryColor = {
		
		-- Settings
		
		self.settingsUI.ColorSection.SecondaryColor.BackLabel.SecondaryColorButton,
		self.settingsUI.ColorSection.PrimaryColor.BackLabel,
		self.settingsUI.ColorSection.TertiaryColor.BackLabel,
		self.settingsUI.ColorSection.SecondaryColor.BackLabel,
		self.settingsUI.ColorSection.TextColor.BackLabel,
		self.settingsUI.CursorSection.CursorImage.TextBox,
		self.settingsUI.CursorSection.CursorImage.BackLabel,
		self.settingsUI.CursorSection.CursorSize.BackLabel,
		self.settingsUI.SaveOperations.Save,		
		
	}
	
	local TertiaryColor = {
		
		-- Settings
		
		self.settingsUI.ColorSection.TertiaryColor.TertiaryColorButton,
		self.settingsUI,
		self.settingsUI.CursorSection.CursorImage.TextBox,
		self.settingsUI.CursorSection.CursorSize.BackLabel.TextBox,
		self.settingsUI.SaveOperations.Reset,
		self.settingsUI.SaveOperations.Save,
		
		-- ContextMenu
		
		ContextMenu.Frame,
		ContextMenu.CursorToOrigin,
		ContextMenu.CursorToSel,
		ContextMenu.SelToCursor,
		ContextMenu.SelToCursorOff,
	}
	
	local TextColor = {
		
		-- Settings
		
		self.settingsUI.CursorSection.CursorSize.TextLabel,
		self.settingsUI.CursorSection.CursorSize.BackLabel.TextBox,
		self.settingsUI.CursorSection.CursorImage.TextBox,
		self.settingsUI.CursorSection.CursorImage.BackLabel.TextLabel,
		self.settingsUI.ColorSection.PrimaryColor.BackLabel.TextLabel,
		self.settingsUI.ColorSection.SecondaryColor.TextLabel,
		self.settingsUI.ColorSection.TertiaryColor.BackLabel.TextLabel,
		self.settingsUI.ColorSection.TextColor.TextLabel,
		self.settingsUI.ColorSection.TextColor.BackLabel.TextColorButton,
		
		--ContextMenu
		
		ContextMenu.CursorToOrigin.ImageLabel,
		ContextMenu.CursorToSel.ImageLabel,
		ContextMenu.SelToCursor.ImageLabel,
		ContextMenu.SelToCursorOff.ImageLabel,
		ContextMenu.ContextArc,
		ContextMenu.CursorToOrigin.ImageLabel.ItemText,
		ContextMenu.CursorToSel.ImageLabel.ItemText,
		ContextMenu.SelToCursor.ImageLabel.ItemText,
		ContextMenu.SelToCursorOff.ImageLabel.ItemText,
	}
	if self.ColorPickerObject then
		local colorPickerFrame = self.ColorPickerObject.ColorPicker
		table.insert(PrimaryColor,colorPickerFrame)
		table.insert(PrimaryColor,colorPickerFrame.Options.HSV)
		table.insert(PrimaryColor,colorPickerFrame.Options.Hex)
		table.insert(PrimaryColor,colorPickerFrame.Options.RGB)
		table.insert(PrimaryColor,colorPickerFrame.SaveFrame)
		
		table.insert(SecondaryColor,colorPickerFrame.Options)
		table.insert(SecondaryColor,colorPickerFrame.Options.HSV.HueValue)
		table.insert(SecondaryColor,colorPickerFrame.Options.HSV.BrightnessValue)
		table.insert(SecondaryColor,colorPickerFrame.Options.HSV.SaturationValue)
		table.insert(SecondaryColor,colorPickerFrame.Options.Hex.Value)
		table.insert(SecondaryColor,colorPickerFrame.Options.RGB.Value)
		
		table.insert(TertiaryColor,colorPickerFrame.Options)
		table.insert(TertiaryColor,colorPickerFrame.Options.HSV.HueValue)
		table.insert(TertiaryColor,colorPickerFrame.Options.HSV.BrightnessValue)
		table.insert(TertiaryColor,colorPickerFrame.Options.HSV.SaturationValue)
		table.insert(TertiaryColor,colorPickerFrame.Options.Hex.Value)
		table.insert(TertiaryColor,colorPickerFrame.Options.RGB.Value)
		table.insert(TertiaryColor,colorPickerFrame.Options.HSV)
		table.insert(TertiaryColor,colorPickerFrame.Options.Hex)
		table.insert(TertiaryColor,colorPickerFrame.Options.RGB)
		table.insert(TertiaryColor,colorPickerFrame.SaveFrame)
		table.insert(TertiaryColor,colorPickerFrame)
		
		table.insert(TextColor,colorPickerFrame.Options.HSV.HueValue)
		table.insert(TextColor,colorPickerFrame.Options.HSV.BrightnessValue)
		table.insert(TextColor,colorPickerFrame.Options.HSV.SaturationValue)
		table.insert(TextColor,colorPickerFrame.Options.HSV.Hue)
		table.insert(TextColor,colorPickerFrame.Options.HSV.Sat)
		table.insert(TextColor,colorPickerFrame.Options.HSV.Val)
		table.insert(TextColor,colorPickerFrame.Options.HSV.HSV)
		table.insert(TextColor,colorPickerFrame.Options.Hex.Hex)
		table.insert(TextColor,colorPickerFrame.Options.Hex.Value)
		table.insert(TextColor,colorPickerFrame.Options.RGB.RGB)
		table.insert(TextColor,colorPickerFrame.Options.RGB.Value)
	end
	
	
	for i,v in pairs(PrimaryColor) do
		if v.Name == "CenterStroke" then
			v.UIStroke.Color = self.PrimaryColor	
		else
			v.BackgroundColor3 = self.PrimaryColor
		end	
	end
	
	for i,v in pairs(SecondaryColor) do
		v.BackgroundColor3 = self.SecondaryColor
	end
	
	for i,v in pairs(TertiaryColor) do
		if v:IsA("TextButton") then
			v.BackgroundColor3 = self.TertiaryColor
		else
			local uiStroke = v:FindFirstChildWhichIsA("UIStroke")
			if uiStroke then
				uiStroke.Color = self.TertiaryColor
			else
				v.BorderColor3 = self.TertiaryColor
			end
		end
	end
	
	for i,v in pairs(TextColor) do
		if v:IsA("ImageLabel") then
			v.ImageColor3 = self.TextColor
		elseif v:IsA("TextButton") then
			v.BackgroundColor3 = self.TextColor
		else
			v.TextColor3 = self.TextColor
		end
	end
end

function Settings:SetCursorObject(cursor)
	self.Cursor = cursor
end


function Settings:CloseConnections()
	for i,v in pairs(self.SettingsConnections) do
		v:Disconnect()
	end
end

return Settings
