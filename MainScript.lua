

--TODO: potentially an issue with parts selected inside of models.

local currentVersion = "1.0.1"

local CoreGui = game:GetService("CoreGui")
local toolbar : PluginToolbar = plugin:CreateToolbar("Crushmero Suite")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SelectionService = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local TweenService = game:GetService("TweenService")
local Settings = require(script.Settings)
local cursorButton : PluginToolbarButton = (toolbar:CreateButton("3dCursor","","rbxassetid://10316640187","3dCursor") :: PluginToolbarButton)
local settingsButton : PluginToolbarButton = (toolbar:CreateButton("3dCursorSettings","","rbxassetid://10316639852","Settings") :: PluginToolbarButton)

local mouse = plugin:GetMouse()

local camera = game.Workspace.Camera
local open = false
local cursor
local cursorAttachment

local settingsObject = Settings.new(plugin,settingsButton,cursorButton)

local cursorFolder 

local cursorPosition = nil

local newContextMenu = nil

local events = {}

type ContextButton = {
	range : {number},
	buttonFunction : ()->()
}

type ContextButtons = {
	SelToCursor : ContextButton,
	SelToCursorOff : ContextButton,
	CursorToSel : ContextButton,
	CursorToOrigin : ContextButton
}


local contextButtons : ContextButtons = {
	SelToCursor = {
		range = {45,135},
		buttonFunction = function()
			ChangeHistoryService:SetWaypoint("Begin Selection To Cursor")
			local selectedObjects = SelectionService:Get()
			
			for i,v in pairs(selectedObjects) do
				if v:IsA("Model") or v:IsA("BasePart") then
					
					local originalOrientation = v:GetPivot().Rotation
					v:PivotTo(CFrame.new(cursorPosition.Value) * originalOrientation)
					
				end
			end
			
			ChangeHistoryService:SetWaypoint("End Selection To Cursor")
		end,
	},
	SelToCursorOff = {
		range = {135,225},
		buttonFunction = function()
			ChangeHistoryService:SetWaypoint("Begin Selection To Cursor With Offset")
			
			local selectedObjects = SelectionService:Get()
			
			local newObjects = {}
			local midPoint = Vector3.zero
			for i,v in pairs(selectedObjects) do
				if v:IsA("Model") or v:IsA("BasePart") then
					
					midPoint += v:GetPivot().Position
					table.insert(newObjects,v)
				end
			end
			midPoint /= #newObjects
			
			
			for i,v in pairs(newObjects) do
				local originalOrientation = v:GetPivot().Rotation
				local objectOffset = v:GetPivot().Position - midPoint
				v:PivotTo(CFrame.new(cursorPosition.Value + objectOffset) * originalOrientation)
			end
			
			ChangeHistoryService:SetWaypoint("End Selection To Cursor With Offset")
		end,
	},
	CursorToOrigin = {
		range = {225,315},
		buttonFunction = function()
			ChangeHistoryService:SetWaypoint("Begin Cursor To World Origin")
			cursorPosition.Value = Vector3.new(0,0,0)
			if cursorAttachment then
				cursorAttachment.Position = cursorPosition.Value
			end
			ChangeHistoryService:SetWaypoint("End Cursor To World Origin")
		end,
	},
	CursorToSel = {
		range = {315,45},
		buttonFunction = function()
			ChangeHistoryService:SetWaypoint("Begin Cursor To Selection")
			local selectedObjects = SelectionService:Get()
			local midPoint = Vector3.zero
			local amountOfMoveableObjects = 0
			
			for i,v in pairs(selectedObjects) do
				if v:IsA("Model") or v:IsA("BasePart") then
					midPoint += v:GetPivot().Position
					amountOfMoveableObjects+=1
				end
			end
			if amountOfMoveableObjects > 0 then
				cursorPosition.Value = midPoint/amountOfMoveableObjects
				cursorAttachment.Position = cursorPosition.Value
			end
			ChangeHistoryService:SetWaypoint("End Cursor To Selection")
		end,
		
	},
	
}


local buttonColors = {
	Normal = Color3.fromRGB(10, 16, 30),
	Highlight = Color3.fromRGB(144, 43, 142)
}




function unload()
	ContextActionService:UnbindAction("3DCursorContextMenu")
	ContextActionService:UnbindAction("3DCursorContextMenuExtra")
	settingsObject:SetCursorObject(nil)
	if cursorPosition then
		plugin:SetSetting("3DCurs_3DCursorPos",cursorPosition.Value.X .. "," .. cursorPosition.Value.Y .. "," .. cursorPosition.Value.Z)
	end
	
	if cursorFolder then
		cursorFolder:Destroy()
	end
	
	if cursorAttachment then
		cursorAttachment:Destroy()
	end	
	if cursor then
		cursor:Destroy()
	end
	
	if newContextMenu then
		newContextMenu:Destroy()
	end
	
	open = false
	cursorButton:SetActive(false)
	for i,v in pairs(events) do
		v:Disconnect()
	end
end

function resetOldButton(currentContextButton,i)
	if currentContextButton and currentContextButton ~= i then
		local oldButton = newContextMenu.Frame:FindFirstChild(currentContextButton)
		if oldButton then
			oldButton.BackgroundColor3 = buttonColors.Normal
		else
			warn("old button unable to be found!")
		end
	end
end


cursorButton.Click:Connect(function()
	if not open then
		
		cursorFolder = Instance.new("Folder")
		
		cursorFolder.Name = "3DCursorFolder"
		cursorFolder.Archivable = false
		cursorFolder.Parent = game.Workspace.Terrain
		
		cursorPosition = Instance.new("Vector3Value")
		
		cursorPosition.Name = "CursorPositionValue"
		cursorPosition.Archivable = false
		cursorPosition.Parent = cursorFolder
		
		
		local cursorSavedPosition : string? = plugin:GetSetting("3DCurs_3DCursorPos")
		
		if cursorSavedPosition then
			local xyz = string.split(cursorSavedPosition,",")
			cursorPosition.Value = Vector3.new(tonumber(xyz[1]),tonumber(xyz[2]),tonumber(xyz[3]))
		else
			cursorPosition.Value = Vector3.new(0,0,0)
		end		
		
		cursorAttachment = Instance.new("Attachment")
		cursorAttachment.Position = cursorPosition.Value
		cursorAttachment.Name = "CursorAttachment"
		cursorAttachment.Archivable = false
		cursorAttachment.Parent = workspace.Terrain
		cursor = script.Parent["3DCursor"]:Clone()
		cursor.Adornee = cursorAttachment
		cursor.Archivable = false
		local cursorSize = plugin:GetSetting("3DCurs_CursorSize")
		if cursorSize then
			cursorSize = tonumber(plugin:GetSetting("3DCurs_CursorSize"))
		else
			cursorSize = 40
		end
		cursor.Size = UDim2.new(0,cursorSize,0,cursorSize)
		
		local imageType = plugin:GetSetting("3DCurs_ImageType") or 0
		if imageType == 0 then
			cursor.ImageLabel.Image = "rbxassetid://".. (plugin:GetSetting("3DCurs_CursorImage") or 10127689049)
		else
			cursor.ImageLabel.Image = string.format("rbxthumb://type=Asset&id=%s&w=420&h=420", plugin:GetSetting("3DCurs_CursorImage"))
		end
		
		
		cursor.Parent = CoreGui
		settingsObject:SetCursorObject(cursor)
		
		local currentContextButton : "SelToCursor" | "SelToCursorOff" | "CursorToOrigin" | "CursorToSel" | nil = nil
		
		local mouseMoveConnection
		ContextActionService:BindAction("3DCursorContextMenu",function(actionName, inputState : Enum.UserInputState, inputObj : InputObject)
			
			if inputState == Enum.UserInputState.Begin then
				
				
				
				ContextActionService:BindAction("3DCursorContextMenuExtra",function(actionName, inputStateTwo : Enum.UserInputState, inputObjTwo : InputObject)
					
					if inputStateTwo == Enum.UserInputState.Begin then
						
						if plugin:GetSetting("3DCurs_PrimaryColor") then
							local color = plugin:GetSetting("3DCurs_PrimaryColor")
							
							buttonColors.Normal = Color3.fromHex(color)
						else
							buttonColors.Normal = Color3.fromRGB(10,16,30)
						end
						
						if plugin:GetSetting("3DCurs_TertiaryColor") then
							local SecondaryColor = plugin:GetSetting("3DCurs_SecondaryColor")
							
							buttonColors.Highlight = Color3.fromHex(SecondaryColor)
						else
							buttonColors.Highlight = Color3.fromRGB(144, 43, 142)
						end
						
						local initMousePos = Vector2.new(mouse.X,mouse.Y)
						
						
						newContextMenu = script.Parent.ContextMenu:Clone()
						local originalPositionAndSize = {}
						for i,v in pairs(contextButtons) do
							local object = newContextMenu.Frame:FindFirstChild(i)
							
							if object then
								originalPositionAndSize[object] = {object.Position,object.Size}
								
							end
							object.Position = UDim2.fromScale(0.5,0.5)
							object.Size = UDim2.fromScale(0,0)
							
						end
						
						for i,v in pairs(originalPositionAndSize) do
							TweenService:Create(i,TweenInfo.new(0.1,Enum.EasingStyle.Sine),{Position=v[1],Size=v[2]}):Play()
						end
						
						newContextMenu.Enabled = true
						newContextMenu.Frame.Position = UDim2.fromScale(initMousePos.X/camera.ViewportSize.X,initMousePos.Y/camera.ViewportSize.Y)
						newContextMenu.Archivable = false
						newContextMenu.Parent = game.CoreGui
						
						events["mouseMoveConnection"] = RunService.RenderStepped:Connect(function(dt)
							local mousePosition = initMousePos - Vector2.new(mouse.X,mouse.Y)
							local degreesAroundCenter = math.deg(math.acos(Vector2.new(-1,0).Unit:Dot(mousePosition.Unit)))
							--local topOrBottom = if  then false else true
							local distanceFromCenter = mousePosition.Magnitude
							if mousePosition.Y < 0 then
								degreesAroundCenter = 360 - degreesAroundCenter
							end
							--print(degreesAroundCenter)
							
							newContextMenu.Frame.ContextArc.Rotation = 360 - degreesAroundCenter
							
							-- rotate pointer bit for inner circle here, you could use the unit vector and degrees for rotation??
							
							
							
							
							if distanceFromCenter > newContextMenu.Frame.CenterStroke.AbsoluteSize.X/2 then
								newContextMenu.Frame.ContextArc.Visible = true
								for i,v in pairs(contextButtons) do
									if i == "CursorToSel" then
										-- need to check "or" because we are at the maximum and minimum therefore there is no
										-- overlap with the rest if we use "or"
										if degreesAroundCenter > v.range[1] or degreesAroundCenter < v.range[2] then
											resetOldButton(currentContextButton,i)
											
											currentContextButton = i
											local button = newContextMenu.Frame:FindFirstChild(i)
											if button then
												button.BackgroundColor3 = buttonColors.Highlight
											else
												warn("button unable to be found!")
											end
											break
										end
									else
										if degreesAroundCenter > v.range[1] and degreesAroundCenter < v.range[2] then
											resetOldButton(currentContextButton,i)
											currentContextButton = i
											local button = newContextMenu.Frame:FindFirstChild(i)
											if button then
												button.BackgroundColor3 = buttonColors.Highlight
											else
												warn("button unable to be found!")
											end
											break
										end
									end
								end
							else
								newContextMenu.Frame.ContextArc.Visible = false
								if currentContextButton then
									resetOldButton(currentContextButton,nil)
									currentContextButton = nil
								end
							end
						end)
						
						return Enum.ContextActionResult.Sink
					else
						
						if events["mouseMoveConnection"] then
							events["mouseMoveConnection"]:Disconnect()
						end
						
						if currentContextButton then
							contextButtons[currentContextButton].buttonFunction()
							currentContextButton = nil
						end
						
						if newContextMenu then
							newContextMenu:Destroy()
						end
						
					end
				end,false,Enum.KeyCode.C)
			elseif inputState == Enum.UserInputState.End then
				
				ContextActionService:UnbindAction("3DCursorContextMenuExtra")
				
				if currentContextButton then
					contextButtons[currentContextButton].buttonFunction()
					currentContextButton = nil
				end
				
				if newContextMenu then
					newContextMenu:Destroy()
				end
				if events["mouseMoveConnection"] then
					events["mouseMoveConnection"]:Disconnect()
				end
				
				
			end
			
			return Enum.ContextActionResult.Pass
		end,false,Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift)
		
		open = true
	else
		unload()
		
		open = false
	end
	cursorButton:SetActive(open)
end)







plugin.Unloading:Connect(unload)

plugin.Deactivation:Connect(unload)
