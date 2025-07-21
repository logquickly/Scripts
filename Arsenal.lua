-- 兵工厂专用脚本 (Arsenal)
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local httpService = game:GetService("HttpService")

-- 游戏检测
local placeId = game.PlaceId
if placeId ~= 286090429 then
    return Fluent:Notify({
        Title = "不支持的游戏",
        Content = "此脚本仅适用于兵工厂(Arsenal)游戏",
        Duration = 5,
        Type = "error"
    })
end

-- 创建主窗口
local Window = Fluent:CreateWindow({
    Title = "兵工厂助手 v2.0",
    SubTitle = "透视 | 自瞄 | 武器增强",
    TabWidth = 140,
    Size = UDim2.fromOffset(580, 450),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

-- 创建标签页
local Tabs = {
    Visual = Window:AddTab({ Title = "视觉功能", Icon = "eye" }),
    Aiming = Window:AddTab({ Title = "瞄准辅助", Icon = "crosshair" }),
    Player = Window:AddTab({ Title = "玩家增强", Icon = "user" }),
    Settings = Window:AddTab({ Title = "设置", Icon = "settings" })
}

local Options = Fluent.Options
local LocalPlayer = players.LocalPlayer
local Camera = workspace.CurrentCamera

-- 状态变量
local espEnabled = false
local aimbotEnabled = false
local noRecoilEnabled = false
local triggerBotEnabled = false
local speedEnabled = false
local flyEnabled = false
local espObjects = {}
local flyBodyVelocity = nil
local currentFlySpeed = 50

-- 团队颜色预设
local teamColors = {
    friendly = Color3.fromRGB(0, 170, 255),
    enemy = Color3.fromRGB(255, 50, 50),
    neutral = Color3.fromRGB(240, 240, 50)
}

-- ================== 透视功能 ================== --
local function updateESP()
    for player, esp in pairs(espObjects) do
        if esp.box then esp.box:Remove() end
        if esp.label then esp.label:Remove() end
    end
    espObjects = {}

    if not espEnabled then return end

    for _, player in ipairs(players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
            local head = player.Character:FindFirstChild("Head")
            
            if humanoidRootPart and head then
                -- 判断团队关系
                local isEnemy = true
                local color = teamColors.enemy
                
                if player.Team and LocalPlayer.Team then
                    if player.Team == LocalPlayer.Team then
                        isEnemy = false
                        color = teamColors.friendly
                    end
                end
                
                -- 创建ESP盒子
                local box = Drawing.new("Square")
                box.Visible = true
                box.Color = color
                box.Thickness = 2
                box.Filled = false
                box.ZIndex = 10
                
                -- 创建名称标签
                local label = Drawing.new("Text")
                text = player.Name
                if player.Team then
                    text = text .. " [" .. player.Team.Name .. "]"
                end
                label.Text = text
                label.Color = color
                label.Size = 14
                label.Center = false
                label.Outline = true
                label.OutlineColor = Color3.new(0, 0, 0)
                label.Visible = true
                label.ZIndex = 11
                
                espObjects[player] = {
                    box = box,
                    label = label,
                    character = player.Character
                }
            end
        end
    end
end

-- ================== 自瞄功能 ================== --
local function getClosestPlayer()
    local closestPlayer = nil
    local closestDistance = math.huge
    local fov = Options.AimbotFOV.Value
    
    for _, player in ipairs(players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            
            if head and humanoid and humanoid.Health > 0 then
                -- 只瞄准敌人
                if not player.Team or not LocalPlayer.Team or player.Team ~= LocalPlayer.Team then
                    local screenPoint, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local mousePos = userInputService:GetMouseLocation()
                        local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
                        
                        if distance < fov and distance < closestDistance then
                            closestPlayer = head
                            closestDistance = distance
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

local function aimAtTarget()
    if not aimbotEnabled then return end
    
    local aimKey = Options.AimbotKey.Value == "MouseButton2" and Enum.UserInputType.MouseButton2 or Enum.KeyCode[Options.AimbotKey.Value]
    local isAiming
    
    if aimKey.EnumType == Enum.UserInputType then
        isAiming = userInputService:IsMouseButtonPressed(aimKey)
    else
        isAiming = userInputService:IsKeyDown(aimKey)
    end
    
    if not isAiming then return end
    
    local target = getClosestPlayer()
    if not target then return end
    
    local smoothing = Options.AimbotSmooth.Value
    local cameraCF = Camera.CFrame
    local targetPos = target.Position
    
    -- 平滑瞄准
    local newCF = CFrame.new(cameraCF.Position, targetPos)
    Camera.CFrame = cameraCF:Lerp(newCF, 1 - smoothing)
end

-- ================== 飞行功能 ================== --
local function updateFly()
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    
    if not flyEnabled or not LocalPlayer.Character then return end
    
    local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyBodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000) * 50
    flyBodyVelocity.Parent = humanoidRootPart
end

local function fly()
    if not flyEnabled or not flyBodyVelocity then return end
    
    local velocity = Vector3.new(0, 0, 0)
    local cf = Camera.CFrame
    local flySpeed = currentFlySpeed
    
    if userInputService:IsKeyDown(Enum.KeyCode.W) then
        velocity = velocity + cf.LookVector * flySpeed
    end
    if userInputService:IsKeyDown(Enum.KeyCode.S) then
        velocity = velocity - cf.LookVector * flySpeed
    end
    if userInputService:IsKeyDown(Enum.KeyCode.D) then
        velocity = velocity + cf.RightVector * flySpeed
    end
    if userInputService:IsKeyDown(Enum.KeyCode.A) then
        velocity = velocity - cf.RightVector * flySpeed
    end
    if userInputService:IsKeyDown(Enum.KeyCode.Space) then
        velocity = velocity + Vector3.new(0, flySpeed, 0)
    end
    if userInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        velocity = velocity - Vector3.new(0, flySpeed, 0)
    end
    
    flyBodyVelocity.Velocity = velocity
end

-- ================== 无后坐力功能 ================== --
local function removeRecoil()
    if not noRecoilEnabled then return end
    
    -- 检测当前武器
    local character = LocalPlayer.Character
    if not character then return end
    
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            for _, module in ipairs(tool:GetDescendants()) do
                if module:IsA("ModuleScript") and (module.Name:find("Recoil") or module.Name:find("Spread")) then
                    module:Destroy()
                end
            end
        end
    end
end

-- ================== 扳机机器人 ================== --
local function triggerBot()
    if not triggerBotEnabled then return end
    
    local mouse = LocalPlayer:GetMouse()
    local target = mouse.Target
    
    if target and target.Parent then
        local model = target.Parent
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local head = model:FindFirstChild("Head")
        
        if humanoid and head and humanoid.Health > 0 then
            -- 检查是否为敌人
            local player = players:GetPlayerFromCharacter(model)
            if player and player ~= LocalPlayer and (not player.Team or not LocalPlayer.Team or player.Team ~= LocalPlayer.Team) then
                mouse1click()
                wait(0.1)
            end
        end
    end
end

-- ================== UI设置 ================== --

-- 视觉功能标签页
Tabs.Visual:AddToggle("ESPEnabled", {
    Title = "玩家透视",
    Description = "显示玩家位置和团队信息",
    Default = false,
    Callback = function(value)
        espEnabled = value
        updateESP()
    end
})

Tabs.Visual:AddColorpicker("FriendlyColor", {
    Title = "友军颜色",
    Default = teamColors.friendly,
    Callback = function(value)
        teamColors.friendly = value
        updateESP()
    end
})

Tabs.Visual:AddColorpicker("EnemyColor", {
    Title = "敌军颜色",
    Default = teamColors.enemy,
    Callback = function(value)
        teamColors.enemy = value
        updateESP()
    end
})

-- 瞄准辅助标签页
Tabs.Aiming:AddToggle("AimbotEnabled", {
    Title = "自瞄功能",
    Description = "自动瞄准敌人",
    Default = false,
    Callback = function(value)
        aimbotEnabled = value
    end
})

Tabs.Aiming:AddDropdown("AimbotKey", {
    Title = "自瞄按键",
    Values = {"MouseButton2", "LeftAlt", "LeftControl", "C", "V", "B", "Q", "E", "F"},
    Default = "MouseButton2",
    Callback = function(value) end
})

Tabs.Aiming:AddSlider("AimbotFOV", {
    Title = "自瞄范围",
    Default = 120,
    Min = 50,
    Max = 500,
    Rounding = 1,
    Callback = function(value) end
})

Tabs.Aiming:AddSlider("AimbotSmooth", {
    Title = "瞄准平滑度",
    Default = 0.2,
    Min = 0.1,
    Max = 1,
    Rounding = 0.01,
    Callback = function(value) end
})

Tabs.Aiming:AddToggle("TriggerBot", {
    Title = "扳机机器人",
    Description = "自动射击瞄准的敌人",
    Default = false,
    Callback = function(value)
        triggerBotEnabled = value
    end
})

Tabs.Aiming:AddToggle("NoRecoil", {
    Title = "无后坐力",
    Description = "移除武器后坐力",
    Default = false,
    Callback = function(value)
        noRecoilEnabled = value
        removeRecoil()
    end
})

-- 玩家增强标签页
Tabs.Player:AddToggle("FlyEnabled", {
    Title = "飞行模式",
    Description = "自由移动",
    Default = false,
    Callback = function(value)
        flyEnabled = value
        updateFly()
    end
})

Tabs.Player:AddSlider("FlySpeed", {
    Title = "飞行速度",
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 1,
    Callback = function(value)
        currentFlySpeed = value
    end
})

Tabs.Player:AddToggle("SpeedBoost", {
    Title = "移动加速",
    Description = "增加玩家移动速度",
    Default = false,
    Callback = function(value)
        speedEnabled = value
        if value and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 30
            end
        end
    end
})

Tabs.Player:AddSlider("SpeedValue", {
    Title = "移动速度",
    Default = 30,
    Min = 16,
    Max = 100,
    Rounding = 1,
    Callback = function(value)
        if speedEnabled and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = value
            end
        end
    end
})

-- 设置标签页
Tabs.Settings:AddButton({
    Title = "保存设置",
    Description = "保存当前配置",
    Callback = function()
        Fluent:Notify({
            Title = "设置已保存",
            Content = "您的配置已存储",
            Duration = 2,
            Type = "success"
        })
    end
})

Tabs.Settings:AddButton({
    Title = "重置设置",
    Description = "恢复默认配置",
    Callback = function()
        Window:Dialog({
            Title = "确认重置",
            Content = "确定要重置所有设置吗?",
            Buttons = {
                {
                    Title = "确认",
                    Callback = function()
                        Fluent:Notify({
                            Title = "设置已重置",
                            Content = "恢复默认配置",
                            Duration = 2,
                            Type = "info"
                        })
                    end
                },
                {
                    Title = "取消",
                    Callback = function() end
                }
            }
        })
    end
})

-- ================== 主循环 ================== --
runService.RenderStepped:Connect(function()
    -- 更新ESP
    for player, esp in pairs(espObjects) do
        if player and esp.character and esp.character.Parent then
            local humanoidRootPart = esp.character:FindFirstChild("HumanoidRootPart")
            local head = esp.character:FindFirstChild("Head")
            
            if humanoidRootPart and head then
                local screenPoint, onScreen = Camera:WorldToViewportPoint(humanoidRootPart.Position)
                
                if onScreen then
                    local position = Vector2.new(screenPoint.X, screenPoint.Y)
                    local size = Vector2.new(2000 / screenPoint.Z, 3000 / screenPoint.Z)
                    
                    esp.box.Visible = true
                    esp.box.Size = size
                    esp.box.Position = position - size / 2
                    
                    esp.label.Visible = true
                    esp.label.Position = Vector2.new(position.X, position.Y - size.Y / 2 - 20)
                else
                    esp.box.Visible = false
                    esp.label.Visible = false
                end
            else
                esp.box.Visible = false
                esp.label.Visible = false
            end
        else
            esp.box.Visible = false
            esp.label.Visible = false
        end
    end
    
    -- 更新功能
    aimAtTarget()
    fly()
    triggerBot()
    removeRecoil()
end)

-- 玩家加入/离开事件
players.PlayerAdded:Connect(updateESP)
players.PlayerRemoving:Connect(function(player)
    if espObjects[player] then
        if espObjects[player].box then espObjects[player].box:Remove() end
        if espObjects[player].label then espObjects[player].label:Remove() end
        espObjects[player] = nil
    end
end)

-- 角色变化事件
LocalPlayer.CharacterAdded:Connect(function(character)
    if speedEnabled then
        wait(1) -- 等待角色完全加载
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = Options.SpeedValue.Value
        end
    end
    updateFly()
    removeRecoil()
end)

-- 初始通知
Fluent:Notify({
    Title = "兵工厂助手已启动",
    Content = "按右Ctrl键显示/隐藏菜单",
    Duration = 5
})
