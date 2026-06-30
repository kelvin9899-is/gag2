--[[
    SCRIPT: PALO ULTIMATE SILENT AIM V6 - MOBILE EDITION
    Tác giả: palofsc (palo)
    Tương thích: Delta X Mobile, VNG Mobile, Arceus X, Hydrogen, Fluxus Mobile
    Mô tả: Aimbot hình học không cần RemoteEvent. Hitbox 3D vuông.
    Tự động thích ứng Mobile (cảm ứng, không cần chuột).
    Phím: RightControl (Menu), "-" (Ẩn/Hiện nhanh), Aim tự động.
--]]

if getgenv().PALO_AIM_V6 then
    getgenv().PALO_AIM_V6 = nil
    task.wait(0.2)
end
getgenv().PALO_AIM_V6 = true

-- ==================== DỊCH VỤ ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Chờ nhân vật
repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
task.wait(1)

-- ==================== PHÁT HIỆN MOBILE ====================
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
print("📱 Chế độ: " .. (IsMobile and "MOBILE" or "PC"))

-- ==================== CẤU HÌNH ====================
local Config = {
    Enabled = true, -- Mặc định bật cho Mobile
    MenuVisible = true,
    QuickHide = false,
    MenuKey = Enum.KeyCode.RightControl,
    HideKey = Enum.KeyCode.Minus,
    
    AimPart = "Head",
    AimMode = "Auto", -- Auto cho Mobile
    FOV_Radius = 250,
    Smoothness = 0.05, -- Mượt hơn cho Mobile
    Prediction = 0.15,
    
    HitboxEnabled = true,
    HitboxSize = Vector3.new(3, 4, 3),
    HitboxColor = Color3.fromRGB(255, 0, 0),
    HitboxTransparency = 0.35,
    
    WallCheck = true,
    TeamCheck = false,
    MaxDistance = 800,
    
    FOV_Color = Color3.fromRGB(255, 60, 60),
    FOV_Transparency = 0.5,
    ShowHitbox = true,
    ShowFOV = true,
    ShowTargetLine = true,
    TargetLineColor = Color3.fromRGB(0, 255, 100),
    
    -- Mobile riêng
    AutoAim = true, -- Tự động aim không cần nhấn
    AimDelay = 0.01,
    ShakeReduction = 0.03
}

-- ==================== HỆ THỐNG ====================
local AimbotTarget = nil
local MenuGUI = nil
local Drawings = {}
local Connections = {}
local HitboxHighlights = {}

-- ==================== HÀM TỌA ĐỘ HÌNH HỌC ====================
local function WorldToScreen(worldPos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
    if not onScreen then return nil end
    return Vector2.new(screenPos.X, screenPos.Y)
end

local function GetDistanceFromCenter(worldPos)
    local screenPos = WorldToScreen(worldPos)
    if not screenPos then return math.huge, nil end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    return (screenPos - center).Magnitude, screenPos
end

local function GetBonePosition(char, boneName)
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    
    local rigType = humanoid.RigType
    local boneMap = {}
    
    if rigType == Enum.HumanoidRigType.R6 then
        boneMap = {
            Head = "Head", Torso = "Torso",
            LeftArm = "Left Arm", RightArm = "Right Arm",
            LeftLeg = "Left Leg", RightLeg = "Right Leg",
            HumanoidRootPart = "HumanoidRootPart"
        }
    else
        boneMap = {
            Head = "Head", UpperTorso = "UpperTorso",
            LowerTorso = "LowerTorso",
            LeftFoot = "LeftFoot", RightFoot = "RightFoot",
            LeftHand = "LeftHand", RightHand = "RightHand",
            HumanoidRootPart = "HumanoidRootPart"
        }
    end
    
    local partName = boneMap[boneName]
    if partName then
        local part = char:FindFirstChild(partName)
        if part and part:IsA("BasePart") then return part.Position, part end
    end
    
    -- Fallback
    local part = char:FindFirstChild(boneName)
    if part and part:IsA("BasePart") then return part.Position, part end
    
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if root then return root.Position, root end
    
    return nil, nil
end

local function PredictPosition(pos, char)
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return pos end
    
    local vel = root.AssemblyLinearVelocity
    local dist = (Camera.CFrame.Position - pos).Magnitude
    local time = dist / 200
    return pos + vel * time * Config.Prediction
end

local function IsWallBetween(camPos, targetPos, char)
    local ignore = {char}
    if char then
        for _, v in ipairs(char:GetDescendants()) do
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
    
    return result ~= nil and result.Instance.Transparency < 0.4
end

-- ==================== HÀM TẠO HITBOX 3D ====================
local function CreateHitbox(char)
    -- Xóa hitbox cũ
    if HitboxHighlights[char] then
        for _, v in ipairs(HitboxHighlights[char]) do
            pcall(function() v:Destroy() end)
        end
    end
    HitboxHighlights[char] = {}
    
    if not Config.HitboxEnabled or not Config.ShowHitbox then return end
    
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return end
    
    -- Tạo wireframe box quanh nhân vật
    local box = Instance.new("BoxHandleAdornment")
    box.Parent = root
    box.Adornee = root
    box.Size = Config.HitboxSize
    box.Color3 = Config.HitboxColor
    box.Transparency = Config.HitboxTransparency
    box.AlwaysOnTop = true
    box.ZIndex = 5
    
    table.insert(HitboxHighlights[char], box)
end

-- ==================== TÌM MỤC TIÊU ====================
local function GetBestTarget()
    local best = nil
    local bestScore = math.huge
    local camPos = Camera.CFrame.Position
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.TeamCheck and player.Team == LocalPlayer.Team then continue end
        
        local char = player.Character
        if not char then continue end
        
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        local bonePos, bonePart = GetBonePosition(char, Config.AimPart)
        if not bonePos then continue end
        
        bonePos = PredictPosition(bonePos, char)
        
        local dist3D = (camPos - bonePos).Magnitude
        if dist3D > Config.MaxDistance then continue end
        
        local distFromCenter, screenPos = GetDistanceFromCenter(bonePos)
        if distFromCenter > Config.FOV_Radius then continue end
        
        if Config.WallCheck and IsWallBetween(camPos, bonePos, char) then continue end
        
        -- Điểm: ưu tiên gần tâm + gần khoảng cách
        local score = distFromCenter * 0.6 + dist3D * 0.4
        
        if score < bestScore then
            bestScore = score
            best = {
                Player = player,
                Character = char,
                Position = bonePos,
                Part = bonePart,
                ScreenPos = screenPos,
                Distance = dist3D
            }
        end
    end
    
    return best
end

-- ==================== VÒNG LẶP CHÍNH ====================
local function MainLoop()
    if not Camera or Camera.Parent == nil then
        Camera = Workspace.CurrentCamera
        if not Camera then return end
    end
    
    -- Cập nhật FOV
    if Drawings.FOV then
        Drawings.FOV.Visible = Config.Enabled and Config.ShowFOV and not Config.QuickHide
        Drawings.FOV.Radius = Config.FOV_Radius
        Drawings.FOV.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        Drawings.FOV.Color = Config.FOV_Color
        Drawings.FOV.Transparency = Config.FOV_Transparency
    end
    
    -- Cập nhật đường line
    if Drawings.TargetLine then
        Drawings.TargetLine.Visible = false
    end
    
    if not Config.Enabled or Config.QuickHide then
        AimbotTarget = nil
        return
    end
    
    AimbotTarget = GetBestTarget()
    
    if AimbotTarget then
        -- Vẽ line đến mục tiêu
        if Drawings.TargetLine and Config.ShowTargetLine then
            local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            Drawings.TargetLine.Visible = true
            Drawings.TargetLine.From = screenCenter
            Drawings.TargetLine.To = AimbotTarget.ScreenPos
            Drawings.TargetLine.Color = Config.TargetLineColor
        end
        
        -- Tạo hitbox cho mục tiêu
        if Config.HitboxEnabled and Config.ShowHitbox then
            CreateHitbox(AimbotTarget.Character)
        end
        
        -- Auto Aim
        if Config.AutoAim or (Config.AimMode == "Auto") then
            local targetCFrame = CFrame.new(Camera.CFrame.Position, AimbotTarget.Position)
            local smooth = Config.Smoothness
            
            -- Giảm rung cho Mobile
            if IsMobile then
                smooth = Config.Smoothness + Config.ShakeReduction
            end
            
            local finalCFrame = Camera.CFrame:Lerp(targetCFrame, smooth)
            Camera.CFrame = finalCFrame
        end
    end
end

-- ==================== MENU MOBILE TỐI ƯU ====================
local function CreateMobileMenu()
    if MenuGUI then pcall(function() MenuGUI:Destroy() end) end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PALO_AIM_V6"
    ScreenGui.Parent = CoreGui
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Main - tối ưu cho màn hình nhỏ
    local sizeX = IsMobile and 300 or 340
    local sizeY = IsMobile and 380 or 420
    
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Parent = ScreenGui
    Main.Size = UDim2.new(0, sizeX, 0, sizeY)
    Main.Position = UDim2.new(0.5, -sizeX/2, 0.4, -sizeY/2)
    Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = Main
    
    local stroke = Instance.new("UIStroke")
    stroke.Parent = Main
    stroke.Color = Color3.fromRGB(255, 80, 80)
    stroke.Thickness = 1.5
    
    -- Title
    local Title = Instance.new("Frame")
    Title.Parent = Main
    Title.Size = UDim2.new(1, 0, 0, 38)
    Title.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    Title.BorderSizePixel = 0
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 10)
    TitleCorner.Parent = Title
    
    local TitleText = Instance.new("TextLabel")
    TitleText.Parent = Title
    TitleText.Size = UDim2.new(1, -45, 1, 0)
    TitleText.Position = UDim2.new(0, 14, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = IsMobile and "📱 PALO AIM MOBILE" or "🎯 PALO AIM V6"
    TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextSize = IsMobile and 14 or 15
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    
    local Close = Instance.new("TextButton")
    Close.Parent = Title
    Close.Size = UDim2.new(0, 28, 0, 28)
    Close.Position = UDim2.new(1, -33, 0.5, -14)
    Close.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    Close.Text = "✕"
    Close.TextColor3 = Color3.fromRGB(255, 255, 255)
    Close.Font = Enum.Font.GothamBold
    Close.TextSize = 14
    Close.BorderSizePixel = 0
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 7)
    CloseCorner.Parent = Close
    
    Close.MouseButton1Click:Connect(function()
        Config.MenuVisible = false
        ScreenGui.Enabled = false
    end)
    
    -- Scroll
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Parent = Main
    Scroll.Size = UDim2.new(1, 0, 1, -38)
    Scroll.Position = UDim2.new(0, 0, 0, 38)
    Scroll.BackgroundColor3 = Color3.fromRGB(17, 17, 22)
    Scroll.BorderSizePixel = 0
    Scroll.ScrollBarThickness = 3
    Scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 80, 80)
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 500)
    
    local ScrollCorner = Instance.new("UICorner")
    ScrollCorner.CornerRadius = UDim.new(0, 10)
    ScrollCorner.Parent = Scroll
    
    local List = Instance.new("UIListLayout")
    List.Parent = Scroll
    List.SortOrder = Enum.SortOrder.LayoutOrder
    List.Padding = UDim.new(0, 3)
    
    local Pad = Instance.new("UIPadding")
    Pad.Parent = Scroll
    Pad.PaddingLeft = UDim.new(0, 6)
    Pad.PaddingRight = UDim.new(0, 6)
    Pad.PaddingTop = UDim.new(0, 4)
    
    -- Hàm tạo Toggle
    local function Toggle(name, default, callback)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 32)
        f.BackgroundTransparency = 1
        f.Parent = Scroll
        
        local l = Instance.new("TextLabel")
        l.Parent = f
        l.Size = UDim2.new(0.55, 0, 1, 0)
        l.BackgroundTransparency = 1
        l.Text = name
        l.TextColor3 = Color3.fromRGB(200, 200, 200)
        l.Font = Enum.Font.Gotham
        l.TextSize = IsMobile and 11 or 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        
        local b = Instance.new("TextButton")
        b.Parent = f
        b.Size = UDim2.new(0, 44, 0, 22)
        b.Position = UDim2.new(1, -44, 0.5, -11)
        b.BackgroundColor3 = default and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(80, 80, 80)
        b.Text = ""
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 11)
        bc.Parent = b
        
        local d = Instance.new("Frame")
        d.Parent = b
        d.Size = UDim2.new(0, 16, 0, 16)
        d.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        d.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        d.BorderSizePixel = 0
        
        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(1, 0)
        dc.Parent = d
        
        local state = default
        b.MouseButton1Click:Connect(function()
            state = not state
            b.BackgroundColor3 = state and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(80, 80, 80)
            d.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            callback(state)
        end)
    end
    
    -- Hàm tạo Dropdown
    local function Dropdown(name, options, default, callback)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 46)
        f.BackgroundTransparency = 1
        f.Parent = Scroll
        
        local l = Instance.new("TextLabel")
        l.Parent = f
        l.Size = UDim2.new(1, 0, 0, 16)
        l.BackgroundTransparency = 1
        l.Text = name
        l.TextColor3 = Color3.fromRGB(160, 160, 170)
        l.Font = Enum.Font.Gotham
        l.TextSize = 10
        l.TextXAlignment = Enum.TextXAlignment.Left
        
        local b = Instance.new("TextButton")
        b.Parent = f
        b.Size = UDim2.new(1, 0, 0, 26)
        b.Position = UDim2.new(0, 0, 0, 18)
        b.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        b.Text = "  " .. default .. "  ▼"
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.Gotham
        b.TextSize = 11
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.BorderSizePixel = 0
        
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 5)
        bc.Parent = b
        
        local list = Instance.new("Frame")
        list.Parent = f
        list.Size = UDim2.new(1, 0, 0, 0)
        list.Position = UDim2.new(0, 0, 0, 46)
        list.BackgroundColor3 = Color3.fromRGB(38, 38, 45)
        list.BorderSizePixel = 0
        list.ClipsDescendants = true
        list.ZIndex = 10
        
        local lc = Instance.new("UICorner")
        lc.CornerRadius = UDim.new(0, 4)
        lc.Parent = list
        
        local open = false
        
        for i, opt in ipairs(options) do
            local ob = Instance.new("TextButton")
            ob.Parent = list
            ob.Size = UDim2.new(1, 0, 0, 22)
            ob.Position = UDim2.new(0, 0, 0, (i-1)*22)
            ob.BackgroundColor3 = Color3.fromRGB(42, 42, 50)
            ob.Text = opt
            ob.TextColor3 = Color3.fromRGB(255, 255, 255)
            ob.Font = Enum.Font.Gotham
            ob.TextSize = 11
            ob.BorderSizePixel = 0
            ob.ZIndex = 11
            
            ob.MouseButton1Click:Connect(function()
                b.Text = "  " .. opt .. "  ▼"
                callback(opt)
                open = false
                list.Size = UDim2.new(1, 0, 0, 0)
            end)
        end
        
        b.MouseButton1Click:Connect(function()
            open = not open
            list.Size = open and UDim2.new(1, 0, 0, #options * 22) or UDim2.new(1, 0, 0, 0)
        end)
    end
    
    -- ==================== XÂY DỰNG MENU ====================
    local sec1 = Instance.new("TextLabel")
    sec1.Parent = Scroll
    sec1.Size = UDim2.new(1, 0, 0, 18)
    sec1.BackgroundTransparency = 1
    sec1.Text = "─  AIMBOT  ─"
    sec1.TextColor3 = Color3.fromRGB(255, 100, 100)
    sec1.Font = Enum.Font.GothamBold
    sec1.TextSize = 12
    
    Toggle("🎯 Bật/Tắt", true, function(v) Config.Enabled = v end)
    Toggle("📦 Hitbox 3D", true, function(v) Config.HitboxEnabled = v; Config.ShowHitbox = v end)
    Toggle("🧱 Kiểm Tra Tường", true, function(v) Config.WallCheck = v end)
    Toggle("👥 Team Check", false, function(v) Config.TeamCheck = v end)
    Toggle("📏 Đường Line", true, function(v) Config.ShowTargetLine = v end)
    
    Dropdown("🦴 Phần Cơ Thể", {
        "Head", "Torso", "UpperTorso", "LowerTorso",
        "LeftFoot", "RightFoot", "HumanoidRootPart"
    }, "Head", function(v) Config.AimPart = v end)
    
    local sec2 = Instance.new("TextLabel")
    sec2.Parent = Scroll
    sec2.Size = UDim2.new(1, 0, 0, 18)
    sec2.BackgroundTransparency = 1
    sec2.Text = "─  PHÍM TẮT  ─"
    sec2.TextColor3 = Color3.fromRGB(100, 255, 100)
    sec2.Font = Enum.Font.GothamBold
    sec2.TextSize = 12
    
    local info = Instance.new("TextLabel")
    info.Parent = Scroll
    info.Size = UDim2.new(1, 0, 0, 35)
    info.BackgroundTransparency = 1
    info.Text = "Menu: RightControl (PC)\nẨn/Hiện nhanh: Phím  - "
    info.TextColor3 = Color3.fromRGB(140, 140, 150)
    info.Font = Enum.Font.Gotham
    info.TextSize = 10
    info.TextXAlignment = Enum.TextXAlignment.Center
    
    MenuGUI = ScreenGui
    return ScreenGui
end

-- ==================== KHỞI TẠO ====================
local function Init()
    -- FOV Circle
    Drawings.FOV = Drawing.new("Circle")
    Drawings.FOV.Visible = false
    Drawings.FOV.Color = Config.FOV_Color
    Drawings.FOV.Thickness = 1.5
    Drawings.FOV.Transparency = Config.FOV_Transparency
    Drawings.FOV.Radius = Config.FOV_Radius
    Drawings.FOV.Filled = false
    Drawings.FOV.ZIndex = 10
    
    -- Target Line
    Drawings.TargetLine = Drawing.new("Line")
    Drawings.TargetLine.Visible = false
    Drawings.TargetLine.Color = Config.TargetLineColor
    Drawings.TargetLine.Thickness = 1.2
    Drawings.TargetLine.Transparency = 0.7
    Drawings.TargetLine.ZIndex = 11
    
    -- Menu
    local menu = CreateMobileMenu()
    menu.Enabled = Config.MenuVisible
    
    -- Vòng lặp
    Connections.Render = RunService.RenderStepped:Connect(MainLoop)
    
    -- Phím tắt Menu
    Connections.InputBegan = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        
        -- RightControl mở menu
        if input.KeyCode == Config.MenuKey then
            Config.MenuVisible = not Config.MenuVisible
            if MenuGUI then MenuGUI.Enabled = Config.MenuVisible end
        end
        
        -- "-" ẩn/hiện nhanh
        if input.KeyCode == Config.HideKey then
            Config.QuickHide = not Config.QuickHide
            if Drawings.FOV then Drawings.FOV.Visible = not Config.QuickHide and Config.Enabled end
            if Drawings.TargetLine then Drawings.TargetLine.Visible = not Config.QuickHide and Config.Enabled end
        end
    end)
    
    -- Dọn dẹp hitbox cũ
    Connections.Heartbeat = RunService.Heartbeat:Connect(function()
        for char, highlights in pairs(HitboxHighlights) do
            if not char or not char.Parent then
                for _, v in ipairs(highlights) do
                    pcall(function() v:Destroy() end)
                end
                HitboxHighlights[char] = nil
            end
        end
    end)
    
    print("✅ PALO AIM V6 MOBILE READY!")
    print("📱 Mobile: " .. (IsMobile and "YES" or "NO"))
    print("🎯 AutoAim: ON | Hitbox: ON")
    print("⌨ Menu: RightControl | Hide: -")
end

pcall(Init)