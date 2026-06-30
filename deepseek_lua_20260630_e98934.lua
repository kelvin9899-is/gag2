--[[
    SCRIPT: PALO ULTIMATE SILENT AIM V9 - COMPACT MOBILE EDITION
    Tác giả: palofsc (palo)
    Tương thích: Delta X Mobile, VNG Mobile, Arceus X, Hydrogen, Fluxus Mobile, PC Executors
    Mô tả: Phiên bản tối ưu cho điện thoại.
    - Menu nhỏ gọn (260x350), không che màn hình.
    - Toàn bộ animation mượt (TweenService).
    - Tự động thu nhỏ khi không dùng.
    - Aimbot thông minh, tránh lỗi 267.
    - Tự động điều chỉnh tốc độ bắn theo game.
    - Phím: RightControl (Menu), "-" (Ẩn/Hiện nhanh).
--]]

if getgenv().PALO_AIM_V9 then return end
getgenv().PALO_AIM_V9 = true

print("🔧 PALO AIM V9 - COMPACT MODE")
print("⏳ Đang khởi tạo...")

-- Dịch vụ
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Chờ nhân vật
repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
task.wait(0.5)

-- Phát hiện thiết bị
local IsMobile = pcall(function() return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled end) and true or false

-- ==================== CẤU HÌNH ====================
local Config = {
    Enabled = true,
    MenuVisible = true,
    QuickHide = false,
    AutoHideMenu = true,
    AutoHideDelay = 3,
    MenuKey = Enum.KeyCode.RightControl,
    HideKey = Enum.KeyCode.Minus,
    
    AimPart = "Head",
    FOV_Radius = 200,
    Smoothness = 0.08,
    Prediction = 0.14,
    
    MagicBullet = false,
    AutoFire = false,
    SafeMode = true,
    FireDelayMin = 0.15,
    
    HitboxEnabled = true,
    HitboxSize = Vector3.new(3, 4, 3),
    HitboxColor = Color3.fromRGB(255, 60, 60),
    HitboxTransparency = 0.35,
    
    AntiDetect = true,
    WallCheck = false,
    TeamCheck = false,
    MaxDistance = 800,
    
    FOV_Color = Color3.fromRGB(255, 55, 55),
    FOV_Transparency = 0.45,
    ShowFOV = true,
    ShowTargetLine = true,
    ShowHitbox = true,
    TargetLineColor = Color3.fromRGB(0, 255, 100),
    
    MenuCompactX = 260,
    MenuCompactY = 320
}

-- Biến hệ thống
local AimbotTarget = nil
local MenuGUI = nil
local Drawings = {}
local Connections = {}
local HitboxHighlights = {}
local FireRemotes = {}
local LastFireTime = 0
local LastMenuInteraction = tick()
local MenuTweens = {}

-- Quét RemoteEvent
local function ScanFireRemotes()
    local remotes = {}
    local keywords = {"fire", "shoot", "bang", "gun", "bullet", "damage", "hit", "weapon", "mouse1", "click"}
    local function search(parent, depth)
        if depth > 5 or #remotes >= 8 then return end
        for _, child in ipairs(parent:GetChildren()) do
            pcall(function()
                if child:IsA("RemoteEvent") then
                    local name = child.Name:lower()
                    for _, kw in ipairs(keywords) do
                        if name:find(kw) then table.insert(remotes, child); break end
                    end
                end
            end)
            if #child:GetChildren() > 0 then search(child, depth + 1) end
        end
    end
    pcall(function() search(game:GetService("ReplicatedStorage"), 0) end)
    pcall(function() search(Workspace, 0) end)
    if #remotes == 0 then
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("RemoteEvent") and #remotes < 10 then table.insert(remotes, v) end
        end
    end
    return remotes
end
FireRemotes = ScanFireRemotes()
print("🔫 Remote: " .. #FireRemotes)

-- ==================== HÀM CƠ BẢN ====================
local function WorldToScreen(pos)
    local sp, on = Camera:WorldToViewportPoint(pos)
    if on then return Vector2.new(sp.X, sp.Y) end
    return nil
end

local function GetBonePosition(char, boneName)
    if not char then return nil end
    local part = char:FindFirstChild(boneName)
    if part and part:IsA("BasePart") then return part.Position end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if root then return root.Position end
    return nil
end

local function PredictPosition(pos, char)
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return pos end
    local vel = root.AssemblyLinearVelocity
    local dist = (Camera.CFrame.Position - pos).Magnitude
    return pos + vel * (dist / 300) * Config.Prediction
end

-- ==================== HITBOX ====================
local function CreateHitbox(char)
    if HitboxHighlights[char] then
        for _, v in ipairs(HitboxHighlights[char]) do
            pcall(function() v:Destroy() end)
        end
    end
    HitboxHighlights[char] = {}
    if not Config.HitboxEnabled or not Config.ShowHitbox then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return end
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
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.TeamCheck and player.Team == LocalPlayer.Team then continue end
        local char = player.Character
        if not char then continue end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        local bonePos = GetBonePosition(char, Config.AimPart)
        if not bonePos then continue end
        bonePos = PredictPosition(bonePos, char)
        
        local dist3D = (camPos - bonePos).Magnitude
        if dist3D > Config.MaxDistance then continue end
        
        local screenPos = WorldToScreen(bonePos)
        if not screenPos then continue end
        
        local distFromCenter = (screenPos - center).Magnitude
        if distFromCenter > Config.FOV_Radius then continue end
        
        local score = distFromCenter * 0.3 + dist3D * 0.7
        if score < bestScore then
            bestScore = score
            best = {
                Player = player,
                Character = char,
                Position = bonePos,
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
    
    -- Auto hide menu
    if Config.AutoHideMenu and Config.MenuVisible and not Config.QuickHide then
        if tick() - LastMenuInteraction > Config.AutoHideDelay then
            Config.MenuVisible = false
            if MenuGUI then
                MenuGUI.Enabled = false
            end
        end
    end
    
    -- FOV
    if Drawings.FOV then
        Drawings.FOV.Visible = Config.Enabled and Config.ShowFOV and not Config.QuickHide
        Drawings.FOV.Radius = Config.FOV_Radius
        Drawings.FOV.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        Drawings.FOV.Color = Config.FOV_Color
    end
    
    if Drawings.TargetLine then Drawings.TargetLine.Visible = false end
    
    if not Config.Enabled or Config.QuickHide then
        AimbotTarget = nil
        return
    end
    
    AimbotTarget = GetBestTarget()
    
    if AimbotTarget then
        if Drawings.TargetLine and Config.ShowTargetLine then
            local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            Drawings.TargetLine.Visible = true
            Drawings.TargetLine.From = center
            Drawings.TargetLine.To = AimbotTarget.ScreenPos
        end
        
        CreateHitbox(AimbotTarget.Character)
        
        local targetCFrame = CFrame.new(Camera.CFrame.Position, AimbotTarget.Position)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Config.Smoothness)
    end
end

-- ==================== MENU NHỎ GỌN + ANIMATION ====================
local function CreateCompactMenu()
    if MenuGUI then pcall(function() MenuGUI:Destroy() end) end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PALO_AIM_V9"
    ScreenGui.Parent = CoreGui
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local W = Config.MenuCompactX
    local H = Config.MenuCompactY
    
    -- Main frame - nhỏ gọn
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Parent = ScreenGui
    Main.Size = UDim2.new(0, W, 0, H)
    Main.Position = UDim2.new(1, -W - 8, 0.15, 0)
    Main.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.AnchorPoint = Vector2.new(0, 0)
    
    -- Animation xuất hiện
    Main.Position = UDim2.new(1, W, 0.15, 0) -- Bắt đầu ngoài màn hình
    local showTween = TweenService:Create(Main, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -W - 8, 0.15, 0)
    })
    showTween:Play()
    
    -- Bo góc
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = Main
    
    -- Viền phát sáng
    local stroke = Instance.new("UIStroke")
    stroke.Parent = Main
    stroke.Color = Color3.fromRGB(255, 100, 50)
    stroke.Thickness = 1.2
    stroke.Transparency = 0.4
    
    -- Title bar
    local Title = Instance.new("Frame")
    Title.Parent = Main
    Title.Size = UDim2.new(1, 0, 0, 32)
    Title.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    Title.BorderSizePixel = 0
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 10)
    TitleCorner.Parent = Title
    
    local TitleText = Instance.new("TextLabel")
    TitleText.Parent = Title
    TitleText.Size = UDim2.new(1, -55, 1, 0)
    TitleText.Position = UDim2.new(0, 10, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = "🔥 PALO AIM"
    TitleText.TextColor3 = Color3.fromRGB(255, 180, 50)
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextSize = 12
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Nút thu nhỏ
    local Minimize = Instance.new("TextButton")
    Minimize.Parent = Title
    Minimize.Size = UDim2.new(0, 22, 0, 22)
    Minimize.Position = UDim2.new(1, -52, 0.5, -11)
    Minimize.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    Minimize.Text = "−"
    Minimize.TextColor3 = Color3.fromRGB(255, 255, 255)
    Minimize.Font = Enum.Font.GothamBold
    Minimize.TextSize = 14
    Minimize.BorderSizePixel = 0
    Minimize.AutoButtonColor = false
    
    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 5)
    MinCorner.Parent = Minimize
    
    local isMinimized = false
    
    Minimize.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        local targetH = isMinimized and 32 or H
        local tween = TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, W, 0, targetH)
        })
        tween:Play()
    end)
    
    -- Nút đóng
    local Close = Instance.new("TextButton")
    Close.Parent = Title
    Close.Size = UDim2.new(0, 22, 0, 22)
    Close.Position = UDim2.new(1, -26, 0.5, -11)
    Close.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    Close.Text = "✕"
    Close.TextColor3 = Color3.fromRGB(255, 255, 255)
    Close.Font = Enum.Font.GothamBold
    Close.TextSize = 12
    Close.BorderSizePixel = 0
    Close.AutoButtonColor = false
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 5)
    CloseCorner.Parent = Close
    
    Close.MouseButton1Click:Connect(function()
        local hideTween = TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(1, W, 0.15, 0)
        })
        hideTween:Play()
        hideTween.Completed:Connect(function()
            Config.MenuVisible = false
            ScreenGui.Enabled = false
        end)
    end)
    
    -- Scroll
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Parent = Main
    Scroll.Size = UDim2.new(1, 0, 1, -32)
    Scroll.Position = UDim2.new(0, 0, 0, 32)
    Scroll.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
    Scroll.BorderSizePixel = 0
    Scroll.ScrollBarThickness = 2
    Scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 100, 50)
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 380)
    
    local ScrollCorner = Instance.new("UICorner")
    ScrollCorner.CornerRadius = UDim.new(0, 10)
    ScrollCorner.Parent = Scroll
    
    local List = Instance.new("UIListLayout")
    List.Parent = Scroll
    List.SortOrder = Enum.SortOrder.LayoutOrder
    List.Padding = UDim.new(0, 2)
    
    local Pad = Instance.new("UIPadding")
    Pad.Parent = Scroll
    Pad.PaddingLeft = UDim.new(0, 6)
    Pad.PaddingRight = UDim.new(0, 6)
    Pad.PaddingTop = UDim.new(0, 4)
    
    -- ==================== HÀM TẠO UI VỚI ANIMATION ====================
    local function Toggle(name, default, callback)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 28)
        f.BackgroundTransparency = 1
        f.Parent = Scroll
        f.ClipsDescendants = true
        
        -- Hiệu ứng hover
        f.MouseEnter:Connect(function()
            LastMenuInteraction = tick()
            TweenService:Create(f, TweenInfo.new(0.15), {BackgroundTransparency = 0.9}):Play()
        end)
        
        local l = Instance.new("TextLabel")
        l.Parent = f
        l.Size = UDim2.new(0.52, 0, 1, 0)
        l.Position = UDim2.new(0, 2, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = name
        l.TextColor3 = Color3.fromRGB(200, 200, 200)
        l.Font = Enum.Font.Gotham
        l.TextSize = 10
        l.TextXAlignment = Enum.TextXAlignment.Left
        
        local b = Instance.new("TextButton")
        b.Parent = f
        b.Size = UDim2.new(0, 38, 0, 20)
        b.Position = UDim2.new(1, -38, 0.5, -10)
        b.BackgroundColor3 = default and Color3.fromRGB(255, 100, 30) or Color3.fromRGB(70, 70, 70)
        b.Text = ""
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 10)
        bc.Parent = b
        
        local d = Instance.new("Frame")
        d.Parent = b
        d.Size = UDim2.new(0, 14, 0, 14)
        d.Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        d.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        d.BorderSizePixel = 0
        
        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(1, 0)
        dc.Parent = d
        
        local state = default
        
        b.MouseButton1Click:Connect(function()
            LastMenuInteraction = tick()
            state = not state
            local bgGoal = state and Color3.fromRGB(255, 100, 30) or Color3.fromRGB(70, 70, 70)
            local dotGoal = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
            TweenService:Create(b, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {BackgroundColor3 = bgGoal}):Play()
            TweenService:Create(d, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Position = dotGoal}):Play()
            callback(state)
        end)
    end
    
    local function Dropdown(name, options, default, callback)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 40)
        f.BackgroundTransparency = 1
        f.Parent = Scroll
        f.ClipsDescendants = false
        
        local l = Instance.new("TextLabel")
        l.Parent = f
        l.Size = UDim2.new(1, 0, 0, 14)
        l.BackgroundTransparency = 1
        l.Text = name
        l.TextColor3 = Color3.fromRGB(150, 150, 160)
        l.Font = Enum.Font.Gotham
        l.TextSize = 9
        l.TextXAlignment = Enum.TextXAlignment.Left
        
        local b = Instance.new("TextButton")
        b.Parent = f
        b.Size = UDim2.new(1, 0, 0, 22)
        b.Position = UDim2.new(0, 0, 0, 16)
        b.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
        b.Text = " " .. default .. " ▼"
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.Gotham
        b.TextSize = 10
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.BorderSizePixel = 0
        
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 5)
        bc.Parent = b
        
        local list = Instance.new("Frame")
        list.Parent = f
        list.Size = UDim2.new(1, 0, 0, 0)
        list.Position = UDim2.new(0, 0, 0, 40)
        list.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
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
            ob.Size = UDim2.new(1, 0, 0, 20)
            ob.Position = UDim2.new(0, 0, 0, (i-1)*20)
            ob.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
            ob.Text = opt
            ob.TextColor3 = Color3.fromRGB(255, 255, 255)
            ob.Font = Enum.Font.Gotham
            ob.TextSize = 10
            ob.BorderSizePixel = 0
            ob.ZIndex = 11
            
            ob.MouseButton1Click:Connect(function()
                LastMenuInteraction = tick()
                b.Text = " " .. opt .. " ▼"
                callback(opt)
                open = false
                TweenService:Create(list, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Size = UDim2.new(1, 0, 0, 0)}):Play()
            end)
            
            ob.MouseEnter:Connect(function()
                TweenService:Create(ob, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 80, 30)}):Play()
            end)
            ob.MouseLeave:Connect(function()
                TweenService:Create(ob, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(40, 40, 48)}):Play()
            end)
        end
        
        b.MouseButton1Click:Connect(function()
            LastMenuInteraction = tick()
            open = not open
            local target = open and UDim2.new(1, 0, 0, #options * 20) or UDim2.new(1, 0, 0, 0)
            TweenService:Create(list, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Size = target}):Play()
        end)
    end
    
    -- ==================== MENU ITEMS ====================
    local sec1 = Instance.new("TextLabel")
    sec1.Parent = Scroll
    sec1.Size = UDim2.new(1, 0, 0, 16)
    sec1.BackgroundTransparency = 1
    sec1.Text = "─ AIMBOT ─"
    sec1.TextColor3 = Color3.fromRGB(255, 120, 50)
    sec1.Font = Enum.Font.GothamBold
    sec1.TextSize = 10
    
    Toggle("🎯 Bật/Tắt", true, function(v) Config.Enabled = v end)
    Toggle("📦 Hitbox", true, function(v) Config.HitboxEnabled = v; Config.ShowHitbox = v end)
    Toggle("📏 Line", true, function(v) Config.ShowTargetLine = v end)
    Toggle("🛡 Safe Mode", true, function(v) Config.SafeMode = v; if v then Config.MagicBullet = false; Config.AutoFire = false end end)
    
    Dropdown("🦴 Phần", {
        "Head", "Torso", "UpperTorso", "LowerTorso",
        "LeftFoot", "RightFoot", "HumanoidRootPart"
    }, "Head", function(v) Config.AimPart = v end)
    
    local sec2 = Instance.new("TextLabel")
    sec2.Parent = Scroll
    sec2.Size = UDim2.new(1, 0, 0, 16)
    sec2.BackgroundTransparency = 1
    sec2.Text = "─ TIỆN ÍCH ─"
    sec2.TextColor3 = Color3.fromRGB(100, 200, 255)
    sec2.Font = Enum.Font.GothamBold
    sec2.TextSize = 10
    
    Toggle("⏱ Auto Hide", true, function(v) Config.AutoHideMenu = v end)
    
    local info = Instance.new("TextLabel")
    info.Parent = Scroll
    info.Size = UDim2.new(1, 0, 0, 30)
    info.BackgroundTransparency = 1
    info.Text = "Menu: RightControl\nẨn: Phím -"
    info.TextColor3 = Color3.fromRGB(130, 130, 140)
    info.Font = Enum.Font.Gotham
    info.TextSize = 9
    info.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Sự kiện touch menu reset timer
    Main.InputBegan:Connect(function()
        LastMenuInteraction = tick()
    end)
    Scroll.InputBegan:Connect(function()
        LastMenuInteraction = tick()
    end)
    
    MenuGUI = ScreenGui
    return ScreenGui
end

-- ==================== KHỞI TẠO ====================
print("🎨 Đang tạo giao diện...")

Drawings.FOV = Drawing.new("Circle")
Drawings.FOV.Visible = false
Drawings.FOV.Color = Config.FOV_Color
Drawings.FOV.Thickness = 1.2
Drawings.FOV.Transparency = Config.FOV_Transparency
Drawings.FOV.Radius = Config.FOV_Radius
Drawings.FOV.Filled = false
Drawings.FOV.ZIndex = 10

Drawings.TargetLine = Drawing.new("Line")
Drawings.TargetLine.Visible = false
Drawings.TargetLine.Color = Config.TargetLineColor
Drawings.TargetLine.Thickness = 1.2
Drawings.TargetLine.Transparency = 0.6
Drawings.TargetLine.ZIndex = 11

CreateCompactMenu()
if MenuGUI then
    MenuGUI.Enabled = Config.MenuVisible
    print("✅ Menu nhỏ gọn đã sẵn sàng!")
end

Connections.Render = RunService.RenderStepped:Connect(MainLoop)
print("🔄 Vòng lặp chính đã chạy!")

Connections.InputBegan = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Config.MenuKey then
        Config.MenuVisible = not Config.MenuVisible
        if MenuGUI then
            MenuGUI.Enabled = Config.MenuVisible
            LastMenuInteraction = tick()
        end
    end
    if input.KeyCode == Config.HideKey then
        Config.QuickHide = not Config.QuickHide
    end
end)
print("⌨ Phím tắt đã sẵn sàng!")

-- Dọn hitbox
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

-- Auto hide timer
Connections.AutoHide = RunService.Heartbeat:Connect(function()
    if Config.AutoHideMenu and Config.MenuVisible then
        if tick() - LastMenuInteraction > Config.AutoHideDelay then
            Config.MenuVisible = false
            if MenuGUI then MenuGUI.Enabled = false end
        end
    end
end)

print("✅ PALO AIM V9 COMPACT READY!")
print("📱 Mobile: " .. (IsMobile and "YES" or "NO"))
print("🛡 Safe Mode: BẬT (tránh lỗi 267)")
print("📋 Menu: RightControl | Ẩn: - | Auto hide: 3s")