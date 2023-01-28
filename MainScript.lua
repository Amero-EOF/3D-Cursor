--TODO: potentially an issue with parts selected inside of models.

local currentVersion = "1.1.0"
local CoreGui = game:GetService("CoreGui")
local toolbar : PluginToolbar = plugin:CreateToolbar("Crushmero Suite")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SelectionService = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local TweenService = game:GetService("TweenService")
local Settings = require(script.Settings)
local cursorButton : PluginToolbarButton = (toolbar:CreateButton("3dCursor","","rbxassetid://11492805727","3dCursor") :: PluginToolbarButton)
local settingsButton : PluginToolbarButton = (toolbar:CreateButton("3dCursorSettings","","rbxassetid://10316639852","Settings") :: PluginToolbarButton)

local mouse = plugin:GetMouse()


local open = false
local cursor
local cursorAttachment : Attachment

local settingsObject = Settings.new(plugin,settingsButton,cursorButton)

local cursorFolder 

local cursorPosition = nil

local newContextMenu : ScreenGui

local events = {}

type ContextButton = {
	range : {number},
	object : Frame?,
	buttonFunction : ()->()
}

type ContextButtons = {
	SelToCursor : ContextButton,
	SelToActive : ContextButton,
	SelToCursorOff : ContextButton,
	CursorToSel : ContextButton,
	PivotToCursor : ContextButton,
	CursorToOrigin : ContextButton
}


local contextButtons : ContextButtons = {
	SelToCursor = {
		range = {315,45},
		buttonFunction = function()
			ChangeHistoryService:SetWaypoint("Begin Selection To Cursor")
			local selectedObjects = SelectionService:Get()
			
			for i,v in selectedObjects do
				if v:IsA("Model") or v:IsA("BasePart") then
					
					local originalOrientation = v:GetPivot().Rotation
					v:PivotTo(CFrame.new(cursorPosition.Value) * originalOrientation)
					
				end
			end
			
			ChangeHistoryService:SetWaypoint("End Selection To Cursor")
		end,
	},
	SelToActive = {
		range = {45,90},
		buttonFunction = function()
			ChangeHistoryService:SetWaypoint("Begin Selection To Active")
			local selectedObjects : {PVInstance} = SelectionService:Get()
			local amountOfObjects = #selectedObjects
			if amountOfObjects >= 2 then
				for i,v in selectedObjects do
					if i < amountOfObjects then
						v:PivotTo(v:GetPivot().Rotation + selectedObjects[amountOfObjects]:GetPivot().Position)
					end
				end
			end
			ChangeHistoryService:SetWaypoint("End Selection To Active")
		end,
	},
	CursorToOrigin = {
		range = {90,135},
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
		range = {135,225},
		buttonFunction = function()
			ChangeHistoryService:SetWaypoint("Begin Cursor To Selection")
			local selectedObjects = SelectionService:Get()
			local midPoint = Vector3.zero
			local amountOfMoveableObjects = 0
			
			for i,v in selectedObjects do
				if v:IsA("Model") or v:IsA("BasePart") then
					midPoint += v:GetPivot().Position
					amountOfMoveableObjects+=1
				end
			end
			if amountOfMoveableObjects > 0 and cursorAttachment then
				cursorPosition.Value = midPoint/amountOfMoveableObjects
				cursorAttachment.Position = cursorPosition.Value
			end
			ChangeHistoryService:SetWaypoint("End Cursor To Selection")
		end,
		
	},
	PivotToCursor = {
		range = {225,270},
		buttonFunction = function()
			ChangeHistoryService:SetWaypoint("Begin Pivot To Cursor")
			local selectedObjects = SelectionService:Get()
			for i,v in selectedObjects do
				if v:IsA("Model") then
					if v.PrimaryPart then
						v.PrimaryPart.PivotOffset = (v.PrimaryPart.CFrame:ToObjectSpace(CFrame.new(cursorPosition.Value)))
					else
						v.WorldPivot = CFrame.new(cursorPosition.Value) * v:GetPivot().Rotation 
					end
				elseif v:IsA("BasePart") then
					v.PivotOffset = (v.CFrame:ToObjectSpace(CFrame.new(cursorPosition.Value)))--:ToObjectSpace(v:GetPivot().Rotation)
				end
			end
			
			ChangeHistoryService:SetWaypoint("End Pivot To Cursor")
		end,
	},
	SelToCursorOff = {
		range = {270,315},
		buttonFunction = function()
			ChangeHistoryService:SetWaypoint("Begin Selection To Cursor With Offset")
			
			local selectedObjects = SelectionService:Get()
			if #selectedObjects > 0 then
				local newObjects = {}
				local midPoint = Vector3.zero
				for i,v in selectedObjects do
					if v:IsA("Model") or v:IsA("BasePart") then
						
						midPoint += v:GetPivot().Position
						table.insert(newObjects,v)
					end
				end
				midPoint /= #newObjects
				
				
				for i,v in newObjects do
					local originalOrientation = v:GetPivot().Rotation
					local objectOffset = v:GetPivot().Position - midPoint
					v:PivotTo(CFrame.new(cursorPosition.Value + objectOffset) * originalOrientation)
				end
			end
			ChangeHistoryService:SetWaypoint("End Selection To Cursor With Offset")
		end,
	},
	
}


local buttonColors = {
	Normal = Color3.fromRGB(17, 15, 24),
	Highlight = Color3.fromRGB(130, 49, 205)
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
	for i,v in events :: never do
		v:Disconnect()
	end
end

function resetOldButton(currentContextButton,i)
	if currentContextButton and currentContextButton ~= i then
		local oldButton = contextButtons[currentContextButton].object
		if oldButton then
			oldButton.BackgroundColor3 = buttonColors.Normal
		else
			warn("old button unable to be found!")
		end
	end
end


cursorButton.Click:Connect(function()
	if not open then
		-- Hotfix for persisting cursor info.
		for i,v in workspace.Terrain:GetChildren() do
			if v.Name == "CursorAttachment" or v.Name == "3DCursorFolder" then
				v:Destroy()
			end
		end
		
		for i,v in CoreGui:GetChildren() do
			if v.Name == "3DCursor" then
				v:Destroy()
			end
		end
		
		cursorFolder = Instance.new("Folder")
		
		cursorFolder.Name = "3DCursorFolder"
		cursorFolder.Archivable = false
		cursorFolder.Parent = game.Workspace.Terrain
		
		
		cursorPosition = Instance.new("Vector3Value")
		
		cursorPosition.Name = "CursorPositionValue"
		cursorPosition.Archivable = false
		cursorPosition.Parent = cursorFolder
		
		
		local cursorSavedPosition : string? = plugin:GetSetting("3DCurs_3DCursorPos")
		cursorPosition.Value = Vector3.new(0,0,0)
		if cursorSavedPosition then
			local xyz = string.split(cursorSavedPosition,",")
			cursorPosition.Value = Vector3.new(table.unpack(xyz :: never))
		end	
		
		cursorAttachment = Instance.new("Attachment")
		cursorAttachment.Position = cursorPosition.Value
		cursorAttachment.Name = "CursorAttachment"
		cursorAttachment.Archivable = false
		cursorAttachment.Parent = workspace.Terrain
		
			
		cursor = script.Parent["3DCursor"]:Clone()
		cursor.Adornee = cursorAttachment
		cursor.Archivable = false
		local cursorSize : number? = tonumber(plugin:GetSetting("3DCurs_CursorSize") or 40)

		cursor.Size = UDim2.new(0,cursorSize,0,cursorSize)
		

		cursor.ImageLabel.Image = if (plugin:GetSetting("3DCurs_ImageType") or 0) == 0 then `rbxassetid://{plugin:GetSetting("3DCurs_CursorImage") or 10127689049}` 
									else `rbxthumb://type=Asset&id={plugin:GetSetting("3DCurs_CursorImage")}&w=420&h=420")`

		cursor.Parent = CoreGui
		settingsObject:SetCursorObject(cursor)
		
		local currentContextButton : ("SelToCursor" | "SelToCursorOff" | "CursorToOrigin" | "CursorToSel" | "PivotToCursor" | "SelToActive")? = nil

		local function ResetButtons()
			
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

		ContextActionService:BindAction("3DCursorContextMenu",function(actionName, inputState : Enum.UserInputState, inputObj : InputObject)
						
			if inputState == Enum.UserInputState.Begin then
				
				ContextActionService:BindAction("3DCursorContextMenuExtra",function(actionName, inputStateTwo : Enum.UserInputState, inputObjTwo : InputObject)
					
					if inputStateTwo == Enum.UserInputState.Begin then
						local primaryColor = plugin:GetSetting("3DCurs_PrimaryColor")
						local tertiaryColor = plugin:GetSetting("3DCurs_TertiaryColor")
						buttonColors.Normal = if primaryColor then Color3.fromHex(primaryColor) else Color3.fromRGB(17, 15, 24)
						buttonColors.Highlight = if tertiaryColor then Color3.fromHex(tertiaryColor) else Color3.fromRGB(130, 49, 205)
						
						local initMousePos = Vector2.new(mouse.X,mouse.Y)
						
						newContextMenu = script.Parent.ContextMenu:Clone()
						
						local contextFrame : never = newContextMenu:FindFirstChild("Frame") :: never
						contextButtons.SelToCursor.object = contextFrame.SelToCursor.SelToCursor
						contextButtons.CursorToSel.object = contextFrame.CursorToSel.CursorToSel
						contextButtons.CursorToOrigin.object = contextFrame.CursorToOrigin.Frame.CursorToOrigin
						contextButtons.SelToCursorOff.object = contextFrame.SelToCursorOff.Frame.SelToCursorOff
						contextButtons.PivotToCursor.object = contextFrame.PivotToCursor.Frame.PivotToCursor
						contextButtons.SelToActive.object = contextFrame.SelToActive.Frame.SelToActive
						
						local originalPositionAndSize = {}
						
						for i,v in contextButtons :: {[string]:ContextButton} do
							local object = v.object
							
							if object then
								originalPositionAndSize[object] = object.Size
								if object.Name == "SelToCursor" or object.Name == "CursorToSel" then
									object.Position = UDim2.fromScale(0.5,0.5)
								else
									if object.Parent then
										(object.Parent :: Frame).Position = UDim2.fromScale(0.5,0.5)
									end
								end
								
								object.Size = UDim2.fromScale(0,0)
							end
						end
						
						local frameTween = TweenInfo.new(0.1,Enum.EasingStyle.Sine)
						local tweenGoal = {Position=UDim2.fromScale(0.5,1)}
						for i,v in originalPositionAndSize do
							TweenService:Create(i,frameTween,{Size=v}):Play()
							if i.Parent then
								if i.Parent.Name == "SelToCursor" or i.Parent.Name == "CursorToSel" then
									TweenService:Create(i,frameTween,tweenGoal):Play()
								else
									
									TweenService:Create(i.Parent,frameTween,tweenGoal):Play()
								end
							end
						end
						local camera = game.Workspace:FindFirstChildWhichIsA("Camera")
						newContextMenu.Enabled = true
						(newContextMenu :: never).Frame.Position = UDim2.fromScale(initMousePos.X/camera.ViewportSize.X,initMousePos.Y/camera.ViewportSize.Y)
						newContextMenu.Archivable = false
						newContextMenu.Parent = game.CoreGui
						
						events["mouseMoveConnection"] = RunService.RenderStepped:Connect(function(dt)
							local mousePosition = initMousePos - Vector2.new(mouse.X,mouse.Y)
							local degreesAroundCenter = (180 - math.deg(math.atan2(mousePosition.Unit.X,mousePosition.Unit.Y))) + 90
							local contextArc : Frame = (newContextMenu :: never).Frame.ContextArc
							local distanceFromCenter = mousePosition.Magnitude
							contextArc.Rotation = degreesAroundCenter

							local offsetDegreesAroundCenter = ( degreesAroundCenter + 90) % 360
							
							if distanceFromCenter > (newContextMenu :: never).Frame.CenterStroke.AbsoluteSize.X/2 then
								contextArc.Visible = true
								for i,v in contextButtons :: never do

									if (i == "SelToCursor" and 
										(offsetDegreesAroundCenter > v.range[1] or  
										offsetDegreesAroundCenter < v.range[2])) or
										(offsetDegreesAroundCenter > v.range[1] and 
										offsetDegreesAroundCenter < v.range[2]) then -- need to check "or" because we are at the maximum and minimum therefore there is no overlap with the rest if we use "or"
										
										resetOldButton(currentContextButton,i)
										currentContextButton = i
										local button = v.object
										if button then
											button.BackgroundColor3 = buttonColors.Highlight
										else
											warn("button unable to be found!")
										end
										break
									end
								end
							else
								contextArc.Visible = false
								if currentContextButton then
									resetOldButton(currentContextButton,nil)
									currentContextButton = nil
								end
							end
						end)
						
						return Enum.ContextActionResult.Sink
					else
						
						ResetButtons()
						return Enum.ContextActionResult.Pass
					end
				end,false,Enum.KeyCode.C)
			elseif inputState == Enum.UserInputState.End then
				ContextActionService:UnbindAction("3DCursorContextMenuExtra")
				ResetButtons()
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
