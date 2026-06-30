--[[
    SCRIPT: PALO ULTIMATE SILENT AIM V3.0
    Tác giả: palofsc (palo)
    Mô tả: Hệ thống Aimbot tối ưu nhất cho Roblox.
    - Tự động phát hiện R6/R15/Rthro.
    - Hỗ trợ tất cả game bắn súng phổ biến (Arsenal, Phantom Forces, Bad Business, Counter Blox, v.v.).
    - Tự động quét RemoteEvent bắn.
    - Dự đoán chuyển động, kiểm tra tường, FOV linh hoạt.
    - Giao diện menu chuyên nghiệp, ẩn/hiện mượt.
--]]

-- Bảo vệ môi trường
if getgenv().PALO_AIM_V3 then
    getgenv().PALO_AIM_V3 = nil
    task.wait(0.2)
end
getgenv().PALO_AIM_V3 = true

-- Dịch vụ
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Chờ tải nhân vật
repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
task.wait(1)

-- ==================== CẤU HÌNH ====================
local Config = {
    -- Toggle chính
    Enabled = false,
    MenuVisible = true,
    MenuKey = Enum.KeyCode.RightControl,
    
    -- Aimbot
    AimPart = "Head",
    AimKey = Enum.UserInputType.MouseButton2,
    FOV_Radius = 200,
    Smoothness = 0.06,
    Prediction = 0.135,
    
    -- Kiểm tra
    WallCheck = true,
    VisibilityCheck = false,
    TeamCheck = false,
    
    -- Tự động bắn
    AutoFire = false,
    AutoFireDelay = 0.09,
    
    -- Giao diện
    FOV_Color = Color3.fromRGB(255, 50, 50),
    FOV_Transparency = 0.6,
    FOV_Filled = false,
    
    -- Nâng cao
    TargetLock = false,
    NearestFirst = true,
    MaxDistance = 500,
    AntiGroundShake = true
}

-- ==================== BIẾN HỆ THỐNG ====================
local AimbotTarget = nil
local FireRemotes = {}
local LastFire = 0
local FOV_Drawing = nil
local TargetESP_Drawing = nil
local MenuGUI = nil
local Connections = {}

-- ==================== HÀM TỰ ĐỘNG TÌM REMOTE BẮN ====================
local function ScanFireRemotes()
    local remotes = {}
    local keywords = {
        "fire", "shoot", "bang", "gun", "bullet", "damage", "hit",
        "weapon", "remoteevent", "shootgun", "firegun", "firebullet",
        "fireevent", "shootevent", "weaponfire", "fireweapon",
        "bulletfire", "serverbullet", "fire_server", "shoot_server",
        "fire_remote", "shoot_remote", "weapon_remote", "bangserver",
        "firehit", "firehitbox", "mouse1", "leftclick", "trigger"
    }
    
    local function search(parent, depth)
        if depth > 8 or #remotes >= 15 then return end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("RemoteEvent") then
                local name = child.Name:lower()
                for _, kw in ipairs(keywords) do
                    if name:find(kw) then
                        table.insert(remotes, child)
                        break
                    end
                end
            end
            if #child:GetChildren() > 0 then
                search(child, depth + 1)
            end
        end
    end
    
    search(ReplicatedStorage, 0)
    search(Workspace, 0)
    
    if LocalPlayer.PlayerGui then
        search(LocalPlayer.PlayerGui, 0)
    end
    
    -- Fallback: lấy tất cả
    if #remotes == 0 then
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("RemoteEvent") and #remotes < 20 then
                table.insert(remotes, v)
            end
        end
    end
    
    return remotes
end

-- ==================== HÀM XÁC ĐỊNH KHUNG XƯƠNG ====================
local function GetSkeletonMap(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    
    local rigType = humanoid.RigType
    
    if rigType == Enum.HumanoidRigType.R6 then
        return {
            Head = "Head",
            Torso = "Torso",
            LeftArm = "Left Arm",
            RightArm = "Right Arm",
            LeftLeg = "Left Leg",
            RightLeg = "Right Leg",
            Root = "HumanoidRootPart"
        }
    elseif rigType == Enum.HumanoidRigType.R15 then
        return {
            Head = "Head",
            UpperTorso = "UpperTorso",
            LowerTorso = "LowerTorso",
            LeftUpperArm = "LeftUpperArm",
            RightUpperArm = "RightUpperArm",
            LeftLowerArm = "LeftLowerArm",
            RightLowerArm = "RightLowerArm",
            LeftHand = "LeftHand",
            RightHand = "RightHand",
            LeftUpperLeg = "LeftUpperLeg",
            RightUpperLeg = "RightUpperLeg",
            LeftLowerLeg = "LeftLowerLeg",
            RightLowerLeg = "RightLowerLeg",
            LeftFoot = "LeftFoot",
            RightFoot = "RightFoot",
            Root = "HumanoidRootPart"
        }
    else
        -- Fallback
        local map = {Root = "HumanoidRootPart"}
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                map[part.Name] = part.Name
            end
        end
        return map
    end
end

-- ==================== HÀM LẤY VỊ TRÍ XƯƠNG ====================
local function GetBonePosition(character, boneName)
    local skeleton = GetSkeletonMap(character)
    if not skeleton then return nil end
    
    -- Tìm chính xác
    if skeleton[boneName] then
        local part = character:FindFirstChild(skeleton[boneName])
        if part and part:IsA("BasePart") then
            return part.Position, part
        end
    end
    
    -- Tìm gần đúng
    for _, partName in pairs(skeleton) do
        if partName:lower():find(boneName:lower()) then
            local part = character:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                return part.Position, part
            end
        end
    end
    
    return nil, nil
end

-- ==================== HÀM KIỂM TRA TƯỜNG ====================
local function IsWallBlocking(camPos, targetPos, targetChar)
    local ignore = {targetChar}
    if targetChar then
        for _, v in ipairs(targetChar:GetDescendants()) do
            if v:IsA("BasePart") then table.insert(ignore, v) end
        end
    end
    if LocalPlayer.Character then
        for _, v in ipairs(LocalPlayer.Character:GetDescendants()) do
            if v:IsA("BasePart") then table.insert(ignore, v) end
        end
    end
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = ignore
    
    local dir = (targetPos - camPos).Unit
    local dist = (targetPos - camPos).Magnitude
    local result = Workspace:Raycast(camPos, dir * dist, params)
    
    if result and result.Instance then
        if result.Instance.Transparency < 0.4 and result.Instance.CanCollide ~= false then
            return true
        end
    end
    return false
end

-- ==================== HÀM DỰ ĐOÁN VỊ TRÍ ====================
local function PredictPosition(targetPos, targetChar)
    local root = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso")
    if not root then return targetPos end
    
    local velocity = root.AssemblyLinearVelocity
    local dist = (Camera.CFrame.Position - targetPos).Magnitude
    local travelTime = dist / 150
    return targetPos + (velocity * travelTime * Config.Prediction)
end

-- ==================== HÀM TÍNH ĐIỂM NGẮM VÒNG TRÒN ====================
local function CalculateAimPoint(targetPos)
    local camPos = Camera.CFrame.Position
    local dir = (targetPos - camPos).Unit
    local dist = (targetPos - camPos).Magnitude
    
    local radius = math.clamp(0.04 + dist * 0.0015, 0.04, 0.25)
    local right = dir:Cross(Vector3.new(0, 1, 0))
    if right.Magnitude < 0.01 then right = dir:Cross(Vector3.new(1, 0, 0)) end
    right = right.Unit
    local up = dir:Cross(right).Unit
    
    local angle = math.random() * math.pi * 2
    return targetPos + (right * math.cos(angle) + up * math.sin(angle)) * radius
end

-- ==================== HÀM TÌM MỤC TIÊU TỐT NHẤT ====================
local function GetBestTarget()
    local best = nil
    local bestScore = math.huge
    local camPos = Camera.CFrame.Position
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.TeamCheck and player.Team == LocalPlayer.Team then continue end
        
        local char = player.Character
        if not char then continue end
        
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        -- Lấy vị trí xương
        local bonePos, bonePart = GetBonePosition(char, Config.AimPart)
        if not bonePos then
            -- Fallback: HumanoidRootPart
            bonePart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            if bonePart then bonePos = bonePart.Position end
        end
        if not bonePos then continue end
        
        -- Dự đoán
        bonePos = PredictPosition(bonePos, char)
        
        -- Khoảng cách 3D
        local dist3D = (camPos - bonePos).Magnitude
        if dist3D > Config.MaxDistance then continue end
        
        -- Chuyển sang màn hình
        local screenPos, onScreen = Camera:WorldToViewportPoint(bonePos)
        if not onScreen then continue end
        
        local screenVec = Vector2.new(screenPos.X, screenPos.Y)
        local distFromCenter = (screenVec - screenCenter).Magnitude
        
        -- Kiểm tra FOV
        if distFromCenter > Config.FOV_Radius then continue end
        
        -- Kiểm tra tường
        if Config.WallCheck and IsWallBlocking(camPos, bonePos, char) then
            continue
        end
        
        -- Kiểm tra nhìn thấy
        if Config.VisibilityCheck then
            local ignoreList = {char}
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then table.insert(ignoreList, v) end
            end
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Blacklist
            params.FilterDescendantsInstances = ignoreList
            local ray = Workspace:Raycast(camPos, (bonePos - camPos).Unit * 500, params)
            if ray and ray.Instance.Transparency < 0.3 then continue end
        end
        
        -- Tính điểm
        local score = Config.NearestFirst and dist3D or distFromCenter
        
        if score < bestScore then
            bestScore = score
            best = {
                Player = player,
                Character = char,
                Position = bonePos,
                Part = bonePart,
                ScreenPos = screenVec,
                Distance = dist3D
            }
        end
    end
    
    return best
end

-- ==================== HÀM BẮN ====================
local function FireWeapon(targetPos)
    local now = tick()
    if now - LastFire < Config.AutoFireDelay then return end
    LastFire = now
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then tool = backpack:FindFirstChildOfClass("Tool") end
    end
    if not tool then return end
    
    -- Tìm remote trong tool
    local remote = nil
    for _, r in ipairs(FireRemotes) do
        if r:IsDescendantOf(tool) then
            remote = r
            break
        end
    end
    if not remote and #FireRemotes > 0 then
        remote = FireRemotes[1]
    end
    if not remote then return end
    
    -- Gửi sự kiện
    pcall(function()
        remote:FireServer(targetPos, targetPos, tool, char:FindFirstChild("HumanoidRootPart"))
    end)
end

-- ==================== VÒNG LẶP CHÍNH ====================
local function MainLoop()
    if not Camera or Camera.Parent == nil then
        Camera = Workspace.CurrentCamera
        if not Camera then return end
    end
    
    -- FOV Drawing
    if FOV_Drawing then
        FOV_Drawing.Visible = Config.Enabled and Config.MenuVisible
        FOV_Drawing.Radius = Config.FOV_Radius
        FOV_Drawing.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOV_Drawing.Color = Config.FOV_Color
        FOV_Drawing.Transparency = Config.FOV_Transparency
    end
    
    -- ESP
    if TargetESP_Drawing then
        TargetESP_Drawing.Visible = false
    end
    
    if not Config.Enabled then
        AimbotTarget = nil
        return
    end
    
    -- Tìm mục tiêu
    AimbotTarget = GetBestTarget()
    
    if AimbotTarget then
        -- ESP
        if TargetESP_Drawing then
            TargetESP_Drawing.Visible = true
            TargetESP_Drawing.Position = AimbotTarget.ScreenPos
        end
        
        -- Kiểm tra AimKey
        local shouldAim = false
        if Config.AimKey == Enum.UserInputType.MouseButton2 then
            shouldAim = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        else
            shouldAim = true
        end
        
        if shouldAim then
            local aimPoint = CalculateAimPoint(AimbotTarget.Position)
            local targetCFrame = CFrame.new(Camera.CFrame.Position, aimPoint)
            local smoothCFrame = Camera.CFrame:Lerp(targetCFrame, Config.Smoothness)
            Camera.CFrame = smoothCFrame
            
            -- Auto bắn
            if Config.AutoFire and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                FireWeapon(AimbotTarget.Position)
            end
        end
    end
end

-- ==================== GIAO DIỆN MENU ====================
local function CreateMenu()
    if MenuGUI then MenuGUI:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PALO_AIM_V3_MENU"
    ScreenGui.Parent = CoreGui
    ScreenGui.ResetOnSpawn = false
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "Main"
    MainFrame.Parent = ScreenGui
    MainFrame.Size = UDim2.new(0, 340, 0, 440)
    MainFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.ClipsDescendants = true
    
    -- Bo góc + viền
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = MainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Parent = MainFrame
    stroke.Color = Color3.fromRGB(80, 80, 200)
    stroke.Thickness = 1.2
    stroke.Transparency = 0.5
    
    -- Tiêu đề
    local Title = Instance.new("Frame")
    Title.Parent = MainFrame
    Title.Size = UDim2.new(1, 0, 0, 44)
    Title.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    Title.BorderSizePixel = 0
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 10)
    TitleCorner.Parent = Title
    
    local TitleText = Instance.new("TextLabel")
    TitleText.Parent = Title
    TitleText.Size = UDim2.new(1, -60, 1, 0)
    TitleText.Position = UDim2.new(0, 18, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = "🎯 PALO ULTIMATE AIM V3"
    TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextSize = 15
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    
    local Close = Instance.new("TextButton")
    Close.Parent = Title
    Close.Size = UDim2.new(0, 30, 0, 30)
    Close.Position = UDim2.new(1, -38, 0.5, -15)
    Close.BackgroundColor3 = Color3.fromRGB(200, 45, 45)
    Close.Text = "✕"
    Close.TextColor3 = Color3.fromRGB(255, 255, 255)
    Close.Font = Enum.Font.GothamBold
    Close.TextSize = 16
    Close.BorderSizePixel = 0
    Close.AutoButtonColor = false
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 8)
    CloseCorner.Parent = Close
    
    Close.MouseButton1Click:Connect(function()
        Config.MenuVisible = false
        ScreenGui.Enabled = false
    end)
    
    Close.MouseEnter:Connect(function()
        TweenService:Create(Close, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 60, 60)}):Play()
    end)
    Close.MouseLeave:Connect(function()
        TweenService:Create(Close, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 45, 45)}):Play()
    end)
    
    -- Nội dung scroll
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Parent = MainFrame
    Scroll.Size = UDim2.new(1, 0, 1, -44)
    Scroll.Position = UDim2.new(0, 0, 0, 44)
    Scroll.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    Scroll.BorderSizePixel = 0
    Scroll.ScrollBarThickness = 3
    Scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 200)
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 680)
    Scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    
    local ScrollCorner = Instance.new("UICorner")
    ScrollCorner.CornerRadius = UDim.new(0, 10)
    ScrollCorner.Parent = Scroll
    
    local List = Instance.new("UIListLayout")
    List.Parent = Scroll
    List.SortOrder = Enum.SortOrder.LayoutOrder
    List.Padding = UDim.new(0, 4)
    
    local Padding = Instance.new("UIPadding")
    Padding.Parent = Scroll
    Padding.PaddingLeft = UDim.new(0, 8)
    Padding.PaddingRight = UDim.new(0, 8)
    Padding.PaddingTop = UDim.new(0, 6)
    
    -- Hàm tạo Toggle
    local function MakeToggle(name, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 34)
        frame.BackgroundTransparency = 1
        frame.Parent = Scroll
        
        local label = Instance.new("TextLabel")
        label.Parent = frame
        label.Size = UDim2.new(0.6, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        
        local btn = Instance.new("TextButton")
        btn.Parent = frame
        btn.Size = UDim2.new(0, 50, 0, 24)
        btn.Position = UDim2.new(1, -50, 0.5, -12)
        btn.BackgroundColor3 = default and Color3.fromRGB(55, 160, 55) or Color3.fromRGB(85, 85, 85)
        btn.Text = ""
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 12)
        btnCorner.Parent = btn
        
        local dot = Instance.new("Frame")
        dot.Parent = btn
        dot.Size = UDim2.new(0, 18, 0, 18)
        dot.Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        dot.BorderSizePixel = 0
        
        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = dot
        
        local state = default
        
        btn.MouseButton1Click:Connect(function()
            state = not state
            local bg = state and Color3.fromRGB(55, 160, 55) or Color3.fromRGB(85, 85, 85)
            local pos = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = bg}):Play()
            TweenService:Create(dot, TweenInfo.new(0.2), {Position = pos}):Play()
            callback(state)
        end)
        
        return frame
    end
    
    -- Hàm tạo Dropdown
    local function MakeDropdown(name, options, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 50)
        frame.BackgroundTransparency = 1
        frame.Parent = Scroll
        
        local label = Instance.new("TextLabel")
        label.Parent = frame
        label.Size = UDim2.new(1, 0, 0, 18)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(170, 170, 180)
        label.Font = Enum.Font.Gotham
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        
        local btn = Instance.new("TextButton")
        btn.Parent = frame
        btn.Size = UDim2.new(1, 0, 0, 28)
        btn.Position = UDim2.new(0, 0, 0, 20)
        btn.BackgroundColor3 = Color3.fromRGB(38, 38, 45)
        btn.Text = "  " .. default .. "  ▼"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.ClipsDescendants = false
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn
        
        local list = Instance.new("Frame")
        list.Parent = frame
        list.Size = UDim2.new(1, 0, 0, 0)
        list.Position = UDim2.new(0, 0, 0, 50)
        list.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
        list.BorderSizePixel = 0
        list.ClipsDescendants = true
        list.ZIndex = 10
        
        local listCorner = Instance.new("UICorner")
        listCorner.CornerRadius = UDim.new(0, 4)
        listCorner.Parent = list
        
        local open = false
        
        -- Tạo các option
        for i, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Parent = list
            optBtn.Size = UDim2.new(1, 0, 0, 24)
            optBtn.Position = UDim2.new(0, 0, 0, (i-1)*24)
            optBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
            optBtn.Text = opt
            optBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 11
            optBtn.BorderSizePixel = 0
            optBtn.ZIndex = 11
            optBtn.AutoButtonColor = false
            
            optBtn.MouseButton1Click:Connect(function()
                btn.Text = "  " .. opt .. "  ▼"
                callback(opt)
                open = false
                TweenService:Create(list, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
            end)
            
            optBtn.MouseEnter:Connect(function()
                TweenService:Create(optBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(65, 65, 180)}):Play()
            end)
            optBtn.MouseLeave:Connect(function()
                TweenService:Create(optBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(45, 45, 52)}):Play()
            end)
        end
        
        btn.MouseButton1Click:Connect(function()
            open = not open
            local target = open and UDim2.new(1, 0, 0, #options * 24) or UDim2.new(1, 0, 0, 0)
            TweenService:Create(list, TweenInfo.new(0.25), {Size = target}):Play()
        end)
        
        return frame
    end
    
    -- ==================== XÂY DỰNG MENU ====================
    
    -- Section chính
    local secMain = Instance.new("TextLabel")
    secMain.Parent = Scroll
    secMain.Size = UDim2.new(1, 0, 0, 22)
    secMain.BackgroundTransparency = 1
    secMain.Text = "─  CÀI ĐẶT CHÍNH  ─"
    secMain.TextColor3 = Color3.fromRGB(130, 130, 255)
    secMain.Font = Enum.Font.GothamBold
    secMain.TextSize = 13
    
    MakeToggle("🎯 Bật/Tắt Aimbot", false, function(v) Config.Enabled = v end)
    MakeToggle("🔒 Khóa Mục Tiêu", false, function(v) Config.TargetLock = v end)
    
    MakeDropdown("🦴 Phần Cơ Thể", {
        "Head", "UpperTorso", "LowerTorso", "Torso",
        "LeftArm", "RightArm", "LeftLeg", "RightLeg",
        "LeftFoot", "RightFoot", "HumanoidRootPart"
    }, "Head", function(v) Config.AimPart = v end)
    
    -- Section bắn
    local secFire = Instance.new("TextLabel")
    secFire.Parent = Scroll
    secFire.Size = UDim2.new(1, 0, 0, 22)
    secFire.BackgroundTransparency = 1
    secFire.Text = "─  TỰ ĐỘNG BẮN  ─"
    secFire.TextColor3 = Color3.fromRGB(255, 130, 130)
    secFire.Font = Enum.Font.GothamBold
    secFire.TextSize = 13
    
    MakeToggle("🔫 Tự Động Bắn", false, function(v) Config.AutoFire = v end)
    
    -- Section kiểm tra
    local secCheck = Instance.new("TextLabel")
    secCheck.Parent = Scroll
    secCheck.Size = UDim2.new(1, 0, 0, 22)
    secCheck.BackgroundTransparency = 1
    secCheck.Text = "─  KIỂM TRA  ─"
    secCheck.TextColor3 = Color3.fromRGB(130, 255, 130)
    secCheck.Font = Enum.Font.GothamBold
    secCheck.TextSize = 13
    
    MakeToggle("🧱 Kiểm Tra Tường", true, function(v) Config.WallCheck = v end)
    MakeToggle("👁 Kiểm Tra Nhìn Thấy", false, function(v) Config.VisibilityCheck = v end)
    MakeToggle("👥 Kiểm Tra Đồng Đội", false, function(v) Config.TeamCheck = v end)
    
    -- Section giao diện
    local secUI = Instance.new("TextLabel")
    secUI.Parent = Scroll
    secUI.Size = UDim2.new(1, 0, 0, 22)
    secUI.BackgroundTransparency = 1
    secUI.Text = "─  GIAO DIỆN  ─"
    secUI.TextColor3 = Color3.fromRGB(255, 255, 130)
    secUI.Font = Enum.Font.GothamBold
    secUI.TextSize = 13
    
    MakeDropdown("🎨 Màu FOV", {"Đỏ", "Xanh Dương", "Xanh Lá", "Vàng", "Tím", "Trắng", "Cam"}, "Đỏ", function(v)
        local colors = {
            ["Đỏ"] = Color3.fromRGB(255, 50, 50),
            ["Xanh Dương"] = Color3.fromRGB(50, 50, 255),
            ["Xanh Lá"] = Color3.fromRGB(50, 255, 50),
            ["Vàng"] = Color3.fromRGB(255, 255, 50),
            ["Tím"] = Color3.fromRGB(180, 50, 255),
            ["Trắng"] = Color3.fromRGB(255, 255, 255),
            ["Cam"] = Color3.fromRGB(255, 150, 50)
        }
        Config.FOV_Color = colors[v]
    end)
    
    -- Thông tin
    local info = Instance.new("TextLabel")
    info.Parent = Scroll
    info.Size = UDim2.new(1, 0, 0, 40)
    info.BackgroundTransparency = 1
    info.Text = "Phím Menu: RightControl\nNhấn giữ Chuột Phải để Aim"
    info.TextColor3 = Color3.fromRGB(140, 140, 150)
    info.Font = Enum.Font.Gotham
    info.TextSize = 11
    info.TextXAlignment = Enum.TextXAlignment.Center
    
    MenuGUI = ScreenGui
    return ScreenGui
end

-- ==================== KHỞI TẠO ====================
local function Init()
    -- Quét RemoteEvent
    FireRemotes = ScanFireRemotes()
    print("🔫 PALO V3: Tìm thấy " .. #FireRemotes .. " RemoteEvent bắn")
    
    -- Tạo FOV Drawing
    FOV_Drawing = Drawing.new("Circle")
    FOV_Drawing.Visible = false
    FOV_Drawing.Color = Config.FOV_Color
    FOV_Drawing.Thickness = 1.5
    FOV_Drawing.Transparency = Config.FOV_Transparency
    FOV_Drawing.Radius = Config.FOV_Radius
    FOV_Drawing.Filled = Config.FOV_Filled
    FOV_Drawing.ZIndex = 10
    
    -- Tạo ESP Drawing
    TargetESP_Drawing = Drawing.new("Circle")
    TargetESP_Drawing.Visible = false
    TargetESP_Drawing.Color = Color3.fromRGB(0, 255, 80)
    TargetESP_Drawing.Thickness = 2
    TargetESP_Drawing.Transparency = 1
    TargetESP_Drawing.Radius = 14
    TargetESP_Drawing.Filled = false
    TargetESP_Drawing.ZIndex = 11
    
    -- Tạo menu
    local menu = CreateMenu()
    menu.Enabled = Config.MenuVisible
    
    -- Kết nối vòng lặp
    Connections.Render = RunService.RenderStepped:Connect(MainLoop)
    
    -- Phím tắt menu
    Connections.Input = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Config.MenuKey then
            Config.MenuVisible = not Config.MenuVisible
            if MenuGUI then MenuGUI.Enabled = Config.MenuVisible end
        end
    end)
    
    -- Cập nhật nhân vật khi respawn
    Connections.Character = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
    end)
    
    print("✅ PALO ULTIMATE AIM V3 ĐÃ SẴN SÀNG!")
    print("📋 Menu: RightControl | Aim: Chuột Phải")
    print("🎯 Phần mặc định: Head | Tường: BẬT")
end

-- Thực thi
pcall(Init)