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
	self.PrimaryColor = if PrimaryColor then Color3.fromHex(PrimaryColor) else Color3.fromRGB(17, 15, 24)
	self.SecondaryColor = if SecondaryColor then Color3.fromHex(SecondaryColor) else Color3.fromRGB(1, 3, 7)
	self.TertiaryColor = if TertiaryColor then Color3.fromHex(TertiaryColor) else Color3.fromRGB(130, 49, 205)
	self.TextColor = if TextColor then Color3.fromHex(TextColor) else Color3.fromRGB(255, 255, 255)
	self.Cursor = nil
	
	self.CursorSize = tonumber(self.plugin:GetSetting("3DCurs_CursorSize") or 40) 
	self.CursorImage = self.plugin:GetSetting("3DCurs_CursorImage") or 10127689049
	self.ImageType = self.plugin:GetSetting("3DCurs_ImageType") or 0
	self.SettingsConnections = {}
	self.ColorPickerObject = nil
	
	local settingsWidgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Float,
		false,
		false, -- closes menu after plugin reload
		300,
		228,
		300,
		228
	)
	self.settingsWidget = plugin:CreateDockWidgetPluginGui("3DCursorSettings",settingsWidgetInfo)
	self.settingsWidget.Title = "Settings"
	self.settingsUI = script.Parent.Parent.SettingsUI.SettingsFrame:Clone()
	self.settingsUI.Parent = self.settingsWidget
	--local openSettings = false
	
	
	local colorPickerWidgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Float,
		false,
		false, -- closes menu after plugin reload
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
				if canUseButtons then
					canUseButtons = false
					colorCache = {ColorName,self[ColorName]}
					self.ColorPickerObject = ColorPicker.new(plugin,colorPickerWidget,self[ColorName])
					
					table.insert(self.SettingsConnections,self.ColorPickerObject.ColorChangeEvent.Event:Connect(function(currentColor : Color3)
						self[ColorName] = currentColor
						self:SetColors()
					end))
					
					table.insert(self.SettingsConnections,self.ColorPickerObject.ColorSaveEvent.Event:Connect(function(currentColor : Color3)
						self[ColorName] = currentColor
						self.plugin:SetSetting("3DCurs_"..ColorName,currentColor:ToHex())
						self.ColorPickerObject:CloseConnections()
						self.ColorPickerObject = nil
						canUseButtons = true
						colorCache = nil
					end))
					
					table.insert(self.SettingsConnections,self.ColorPickerObject.ColorCancelEvent.Event:Connect(function()
						self[ColorName] = colorCache[2]
						self.ColorPickerObject:CloseConnections()
						self.ColorPickerObject = nil
						self:SetColors()
						canUseButtons = true
						colorCache = nil
					end))
					self.ColorPickerObject:UpdateColor()
					colorPickerWidget.Enabled = true
				end
			end
			table.insert(self.SettingsConnections,ColorSection.TextColor.BackLabel.TextColorButton.MouseButton1Click:Connect(function()

				ColorButton("TextColor")

			end))
			
			table.insert(self.SettingsConnections,ColorSection.PrimaryColor.PrimaryColorButton.MouseButton1Click:Connect(function()
				ColorButton("PrimaryColor")
			end))
			
			table.insert(self.SettingsConnections,ColorSection.SecondaryColor.BackLabel.SecondaryColorButton.MouseButton1Click:Connect(function()
				ColorButton("SecondaryColor")
			end))
			
			table.insert(self.SettingsConnections,ColorSection.TertiaryColor.TertiaryColorButton.MouseButton1Click:Connect(function()
				ColorButton("TertiaryColor")
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
				
				if check and check > 0 then
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
					self.PrimaryColor = Color3.fromRGB(17, 15, 24)
					self.SecondaryColor = Color3.fromRGB(1, 3, 7)
					self.TertiaryColor = Color3.fromRGB(130, 49, 205)
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
	end)
	
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
	local SelToCursor = ContextMenu.SelToCursor.Frame.SelToCursor
	local CursorToSel = ContextMenu.CursorToSel.Frame.CursorToSel
	local CursorToOrigin = ContextMenu.CursorToOrigin.Frame.CursorToOrigin
	local SelToCursorOff = ContextMenu.SelToCursorOff.Frame.SelToCursorOff
	local PivotToCursor = ContextMenu.PivotToCursor.Frame.PivotToCursor
	local SelToActive = ContextMenu.SelToActive.Frame.SelToActive
	local ColorSection = self.settingsUI.ColorSection
	local CursorSection = self.settingsUI.CursorSection
	
	local PrimaryColor = {
		
		-- Settings
		
		ColorSection.PrimaryColor.PrimaryColorButton,
		CursorSection.CursorSize.BackLabel.TextBox,
		self.settingsUI,
		
		-- ContextMenu
		ContextMenu.CenterStroke,
		SelToCursor,
		CursorToSel,
		CursorToOrigin,
		SelToCursorOff,
		PivotToCursor,
		SelToActive,
	}
	
	local SecondaryColor = {
		
		-- Settings
		
		ColorSection.SecondaryColor.BackLabel.SecondaryColorButton,
		ColorSection.PrimaryColor.BackLabel,
		ColorSection.TertiaryColor.BackLabel,
		ColorSection.SecondaryColor.BackLabel,
		ColorSection.TextColor.BackLabel,
		CursorSection.CursorImage.TextBox,
		CursorSection.CursorImage.BackLabel,
		CursorSection.CursorSize.BackLabel,
		self.settingsUI.SaveOperations.Save,		
		
	}
	
	local TertiaryColor = {
		
		-- Settings
		
		ColorSection.TertiaryColor.TertiaryColorButton,
		self.settingsUI,
		CursorSection.CursorImage.TextBox,
		CursorSection.CursorSize.BackLabel.TextBox,
		self.settingsUI.SaveOperations.Reset,
		self.settingsUI.SaveOperations.Save,
		ContextMenu.centerinset,
		
		-- ContextMenu
		
		SelToCursor,
		CursorToSel,
		CursorToOrigin,
		SelToCursorOff,
		PivotToCursor,
		SelToActive,
	}
	
	
	local TextColor = {
		
		-- Settings
		
		CursorSection.CursorSize.TextLabel,
		CursorSection.CursorSize.BackLabel.TextBox,
		CursorSection.CursorImage.TextBox,
		CursorSection.CursorImage.BackLabel.TextLabel,
		ColorSection.PrimaryColor.BackLabel.TextLabel,
		ColorSection.SecondaryColor.TextLabel,
		ColorSection.TertiaryColor.BackLabel.TextLabel,
		ColorSection.TextColor.TextLabel,
		ColorSection.TextColor.BackLabel.TextColorButton,
		
		--ContextMenu
		
		SelToCursor.ImageLabel,
		CursorToSel.ImageLabel,
		CursorToOrigin.ImageLabel,
		SelToCursorOff.ImageLabel,
		PivotToCursor.ImageLabel,
		SelToActive.ImageLabel,
		
		SelToCursor.ImageLabel.ItemText,
		CursorToSel.ImageLabel.ItemText,
		CursorToOrigin.ImageLabel.ItemText,
		SelToCursorOff.ImageLabel.ItemText,
		PivotToCursor.ImageLabel.ItemText,
		SelToActive.ImageLabel.ItemText,

		ContextMenu.ContextArc,
	}

	if self.ColorPickerObject then
		local colorPickerFrame = self.ColorPickerObject.ColorPicker
		local options = colorPickerFrame.Options
		local hsv = options.HSV
		local hex = options.Hex
		local rgb = options.RGB
		table.insert(PrimaryColor,colorPickerFrame)
		table.insert(PrimaryColor,hsv)
		table.insert(PrimaryColor,hex)
		table.insert(PrimaryColor,rgb)
		table.insert(PrimaryColor,colorPickerFrame.SaveFrame)
		
		table.insert(SecondaryColor,options)
		table.insert(SecondaryColor,hsv.HueValue)
		table.insert(SecondaryColor,hsv.BrightnessValue)
		table.insert(SecondaryColor,hsv.SaturationValue)
		table.insert(SecondaryColor,hex.Value)
		table.insert(SecondaryColor,rgb.Value)
		
		table.insert(TertiaryColor,options)
		table.insert(TertiaryColor,hsv.HueValue)
		table.insert(TertiaryColor,hsv.BrightnessValue)
		table.insert(TertiaryColor,hsv.SaturationValue)
		table.insert(TertiaryColor,hex.Value)
		table.insert(TertiaryColor,rgb.Value)
		table.insert(TertiaryColor,hsv)
		table.insert(TertiaryColor,hex)
		table.insert(TertiaryColor,rgb)
		table.insert(TertiaryColor,colorPickerFrame.SaveFrame)
		table.insert(TertiaryColor,colorPickerFrame)
		
		table.insert(TextColor,hsv.HueValue)
		table.insert(TextColor,hsv.BrightnessValue)
		table.insert(TextColor,hsv.SaturationValue)
		table.insert(TextColor,hsv.Hue)
		table.insert(TextColor,hsv.Sat)
		table.insert(TextColor,hsv.Val)
		table.insert(TextColor,hsv.HSV)
		table.insert(TextColor,hex.Hex)
		table.insert(TextColor,hex.Value)
		table.insert(TextColor,rgb.RGB)
		table.insert(TextColor,rgb.Value)
	end
	
	
	for i,v in PrimaryColor do
		if v.Name == "CenterStroke" then
			v.UIStroke.Color = self.PrimaryColor	
		else
			v.BackgroundColor3 = self.PrimaryColor
		end	
	end
	
	for i,v in SecondaryColor do
		v.BackgroundColor3 = self.SecondaryColor
	end
	
	for i,v in TertiaryColor do
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
	
	for i,v in TextColor do
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
	for i,v in self.SettingsConnections do
		v:Disconnect()
	end
end

return Settings
