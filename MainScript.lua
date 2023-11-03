--!strict

--TODO: potentially an issue with parts selected inside of models.

--TODO: Issue with focused text labels inside the color picker if you drag, it will activate the rotation of the color circle when dragged inside
-- the frame.

local currentVersion = "1.1.4"
local CoreGui = game:GetService("CoreGui")


--local CrushmeroToolbar : PluginToolbar = game:GetService("CoreGui"):WaitForChild("PluginToolbars"):FindFirstChild("CrushmeroToolbar") 

local HttpService = game:GetService("HttpService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SelectionService = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local TweenService = game:GetService("TweenService")
local StudioService = game:GetService("StudioService")
local Settings = require(script.Settings)

local plugin : Plugin = plugin

local CrushmeroToolbar : PluginToolbar = plugin:CreateToolbar("CrushmeroToolbar")

local cursorButton = CrushmeroToolbar:CreateButton("3dCursor-7019951","","rbxassetid://11492805727","3dCursor")
local settingsButton = CrushmeroToolbar:CreateButton("3dCursorSettings-7019951","","rbxassetid://10316639852","Settings")

local mouse = plugin:GetMouse()

local TWEEN_TIME = 0.22
local open = false
local cursor
local cursorAttachment : Attachment

local settingsObject = Settings.new(plugin,settingsButton,cursorButton)

local cursorFolder 

local cursorPosition = nil

local newContextMenu : ScreenGui

local events = {}

type ContextButton = {
	index : number,
	range : {number},
	buttons : {Enum.KeyCode},
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

type FrameInfo = {
	size : UDim2,
	object : Frame,
	originalRotation : number,
	originalAnchor : Vector2
}


local CONTEXT_MENU_SIZE = 6
local contextButtons : ContextButtons = {
	SelToCursor = {
		index = 1,
		range = {315,45},
		buttons = {Enum.KeyCode.One,Enum.KeyCode.KeypadOne},
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
		index = 2,
		range = {45,90},
		buttons = {Enum.KeyCode.Two,Enum.KeyCode.KeypadTwo},
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
		index = 3,
		range = {90,135},
		buttons = {Enum.KeyCode.Three,Enum.KeyCode.KeypadThree},
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
		index = 4,
		range = {135,225},
		buttons = {Enum.KeyCode.Four,Enum.KeyCode.KeypadFour},
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
		index = 5,
		range = {225,270},
		buttons = {Enum.KeyCode.Five,Enum.KeyCode.KeypadFive},
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
		index = 6,
		range = {270,315},
		buttons = {Enum.KeyCode.Six,Enum.KeyCode.KeypadSix},
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




local currentContextButton : ("SelToCursor" | "SelToCursorOff" | "CursorToOrigin" | "CursorToSel" | "PivotToCursor" | "SelToActive")? = nil
local tweenConnections : {RBXScriptConnection} = {}


local function ResetButtons()

	if events["mouseMoveConnection"] then
		events["mouseMoveConnection"]:Disconnect()
	end

	if currentContextButton then
		contextButtons[currentContextButton].buttonFunction()
		currentContextButton = nil
	end

	if tweenConnections then
		for i,v in tweenConnections do
			v:Disconnect()
		end
	end

	--for i,v in contextButtons :: {[string]:ContextButton} do
	--	if v.object then
	--		ContextActionService:UnbindAction(v.object.Name)
	--	end
	--end
	if newContextMenu then
		newContextMenu:Destroy()
	end
end


function sHandler(_, inputState : Enum.UserInputState?, _ : InputObject?, bypass : boolean?, enable : boolean?)
	if bypass and enable or inputState == Enum.UserInputState.Begin then
		local primaryColor = plugin:GetSetting("3DCurs_PrimaryColor")
		local tertiaryColor = plugin:GetSetting("3DCurs_TertiaryColor")
		buttonColors.Normal = if primaryColor then Color3.fromHex(primaryColor) else Color3.fromRGB(17, 15, 24)
		buttonColors.Highlight = if tertiaryColor then Color3.fromHex(tertiaryColor) else Color3.fromRGB(130, 49, 205)
		
		

		newContextMenu = script.Parent.ContextMenu:Clone() :: ScreenGui

		local contextFrame : never = newContextMenu:FindFirstChild("Frame") :: never
		contextButtons.SelToCursor.object = contextFrame.SelToCursor.Frame.SelToCursor
		contextButtons.CursorToSel.object = contextFrame.CursorToSel.Frame.CursorToSel
		contextButtons.CursorToOrigin.object = contextFrame.CursorToOrigin.Frame.CursorToOrigin
		contextButtons.SelToCursorOff.object = contextFrame.SelToCursorOff.Frame.SelToCursorOff
		contextButtons.PivotToCursor.object = contextFrame.PivotToCursor.Frame.PivotToCursor
		contextButtons.SelToActive.object = contextFrame.SelToActive.Frame.SelToActive
		
		local frameCapXMin = (contextButtons.SelToCursorOff.object :: Frame)
		local frameCapXMax = (contextButtons.CursorToOrigin.object :: Frame)
		local frameCapYMin = (contextButtons.SelToCursor.object :: Frame)
		local frameCapYMax = (contextButtons.CursorToSel.object :: Frame)
		
		newContextMenu.Parent = game.CoreGui
		
		local camera : Camera = workspace:FindFirstChildWhichIsA("Camera")
		local cameraSize = camera.ViewportSize
		local scaleAmount = cameraSize / newContextMenu.AbsoluteSize
		
		
		local middlePos = (newContextMenu.AbsolutePosition + newContextMenu.AbsoluteSize/2)

		local frameCapXMinVal = middlePos.X - frameCapXMin.AbsolutePosition.X
		local frameCapXMaxVal = cameraSize.X - (frameCapXMax.AbsolutePosition.X - middlePos.X + frameCapXMax.AbsoluteSize.X)
		
		
		local frameCapYMinVal = middlePos.Y - frameCapYMin.AbsolutePosition.Y
		local frameCapYMaxVal = cameraSize.Y - (frameCapYMax.AbsolutePosition.Y - middlePos.Y + frameCapYMax.AbsoluteSize.Y)
		local initMousePos
		if frameCapXMinVal > frameCapXMaxVal or frameCapYMinVal > frameCapYMaxVal then
			initMousePos = Vector2.new(mouse.X,mouse.Y)
		else
			initMousePos = Vector2.new(math.clamp(mouse.X,frameCapXMinVal,frameCapXMaxVal),math.clamp(mouse.Y,frameCapYMinVal,frameCapYMaxVal))
		end
		local originalPositionAndSize : {FrameInfo} = {}

		for i,v in contextButtons :: never do
			local object : Frame = v.object :: Frame
			
			if not object then continue end
			local rotSmallFrame : Frame = object.Parent :: Frame
			if not rotSmallFrame then continue end
			local rotBigFrame = rotSmallFrame.Parent :: Frame
			if not rotBigFrame then continue end

			originalPositionAndSize[v.index] = {
				size = object.Size,
				object = object,
				originalRotation = rotSmallFrame.Rotation :: number,
				originalAnchor = object.AnchorPoint
			}

			rotSmallFrame.Position = UDim2.fromScale(0.5,0.5)
			object.AnchorPoint = Vector2.new(0.5,1)
			rotBigFrame.Rotation = 180
			rotSmallFrame.Rotation = -180

			object.Size = UDim2.fromScale(0,0)

			--ContextActionService:BindAction(object.Name,function()
			--	currentContextButton = i
			--	ContextActionService:UnbindAction("3DCursorContextMenuExtra")
			--	ResetButtons()
			--end, false, table.unpack(v.buttons))
		end


		local frameTween = TweenInfo.new(TWEEN_TIME,Enum.EasingStyle.Sine)

		local tweenGoal = {Position=UDim2.fromScale(0.5,1)}
		local transparencyGoal = {Transparency = 0}
		local imagetransparencyGoal = {ImageTransparency = 0}
		local textTransparencyGoal = {TextTransparency = 0}

		local camera = game.Workspace:FindFirstChildWhichIsA("Camera");
		
		(newContextMenu :: never).Frame.Position = UDim2.fromScale(initMousePos.X/camera.ViewportSize.X,initMousePos.Y/camera.ViewportSize.Y)
		newContextMenu.Archivable = false
		local contextArc : Frame = (newContextMenu :: never).Frame.ContextArc

		events["mouseMoveConnection"] = RunService.RenderStepped:Connect(function(dt)
			local mousePosition = initMousePos - Vector2.new(mouse.X,mouse.Y)
			local degreesAroundCenter = (180 - math.deg(math.atan2(mousePosition.Unit.X,mousePosition.Unit.Y))) + 90

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
						if not button then return end
						button.BackgroundColor3 = buttonColors.Highlight
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


		newContextMenu.Enabled = true
		
			
		for i,v in originalPositionAndSize do
			local object : Frame = v.object :: Frame
			local transparencyTime = TweenInfo.new(TWEEN_TIME,Enum.EasingStyle.Sine)
			local imageLabel = v.object:FindFirstChild("ImageLabel")

			local UIStroke = object:FindFirstChild("UIStroke")

			if not imageLabel then continue end
			local itemText = imageLabel:FindFirstChild("ItemText")
			local itemLabel = imageLabel:FindFirstChild("ItemLabel")

			if not itemText or not itemLabel then continue end

			TweenService:Create(UIStroke,transparencyTime,transparencyGoal):Play()
			TweenService:Create(imageLabel,transparencyTime,imagetransparencyGoal):Play()
			TweenService:Create(itemText,transparencyTime,textTransparencyGoal):Play()
			TweenService:Create(itemLabel,transparencyTime,textTransparencyGoal):Play()
			TweenService:Create(object,frameTween,{Size=v.size,BackgroundTransparency = 0}):Play()
			
			local rotSmallFrame : Frame = object.Parent :: Frame
			if not rotSmallFrame then continue end

			local rotBigFrame : Frame = rotSmallFrame.Parent :: Frame
			if not rotBigFrame then continue end

			TweenService:Create(rotSmallFrame,frameTween,tweenGoal):Play()
			local startTime = os.clock()
			local connection : RBXScriptConnection = nil
			connection = RunService.RenderStepped:Connect(function(dt)

				if (os.clock() - startTime >= TWEEN_TIME and connection) or (not rotSmallFrame or not rotBigFrame) then
					connection:Disconnect()
				end

				local alpha = TweenService:GetValue((os.clock() - startTime) / TWEEN_TIME,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)

				rotSmallFrame.Rotation = alpha * v.originalRotation
				rotBigFrame.Rotation = -(alpha * v.originalRotation)
				object.AnchorPoint = Vector2.new(0.5,1):Lerp(v.originalAnchor,alpha)
			end)
			table.insert(tweenConnections,connection)
			task.wait(TWEEN_TIME/CONTEXT_MENU_SIZE)
		end
		return Enum.ContextActionResult.Sink
	else

		ResetButtons()
		return Enum.ContextActionResult.Pass
	end
end


function shiftHandler(actionName, inputState : Enum.UserInputState, inputObj : InputObject)
	if inputState == Enum.UserInputState.Begin then

		ContextActionService:BindAction("3DCursorContextMenuExtra",sHandler,false,Enum.KeyCode.C)
		
	elseif inputState == Enum.UserInputState.End then
		ContextActionService:UnbindAction("3DCursorContextMenuExtra")
		ResetButtons()
	end

	return Enum.ContextActionResult.Pass
end


local triggeredTime : number?
local keybindDebounce : boolean = false
local loaded : boolean = false
local firstTime : boolean = false

cursorButton.Click:Connect(function()
	if open then
		unload() 
		open = false 
		cursorButton:SetActive(open)
		return
	end
	local playerID = StudioService:GetUserId()
	-- Hotfix for persisting cursor info.
	for i,v in workspace.Terrain:GetChildren() do
		if (v.Name == "CursorAttachment" and v.Owner.Value == playerID) or 
		   (v.Name == "3DCursorFolder"   and v.Owner.Value == playerID) then
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
	
	local cursorOwner = Instance.new("StringValue")
	cursorOwner.Value = playerID
	cursorOwner.Parent = cursorFolder
	cursorOwner.Name = "Owner"
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
	cursorAttachment.CFrame = CFrame.new(cursorPosition.Value)
	cursorAttachment.Name = "CursorAttachment"
	cursorAttachment.Archivable = false
	cursorAttachment.Parent = workspace.Terrain
	
	cursorOwner:Clone().Parent = cursorAttachment
	
	cursorAttachment:GetPropertyChangedSignal("CFrame"):Connect(function()
		cursorPosition.Value = cursorAttachment.CFrame.Position
	end)
	
	cursor = script.Parent["3DCursor"]:Clone()
	cursor.Adornee = cursorAttachment
	cursor.Archivable = false
	local cursorSize : number = tonumber(plugin:GetSetting("3DCurs_CursorSize") or 40) :: number

	cursor.Size = UDim2.new(0,cursorSize,0,cursorSize )
	

	cursor.ImageLabel.Image = if (plugin:GetSetting("3DCurs_ImageType") or 0) == 0 then `rbxassetid://{plugin:GetSetting("3DCurs_CursorImage") or 10127689049}` 
								else `rbxthumb://type=Asset&id={plugin:GetSetting("3DCurs_CursorImage")}&w=420&h=420")`

	cursor.Parent = CoreGui
	settingsObject:SetCursorObject(cursor)
	

	ContextActionService:BindAction("3DCursorContextMenu",shiftHandler,false,Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift)
	
	open = true
	cursorButton:SetActive(open)
end)



plugin.Unloading:Connect(unload)
plugin.Deactivation:Connect(unload)
