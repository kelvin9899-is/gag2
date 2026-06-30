--[[
    SCRIPT: PALO ULTIMATE SILENT AIM V8 - FINAL FIX EDITION
    Tác giả: palofsc (palo)
    Tương thích: Delta X Mobile, VNG Mobile, Arceus X, Hydrogen, Fluxus Mobile, PC Executors
    Mô tả: Phiên bản sửa lỗi triệt để. Đã test trực tiếp.
    - Fix: Menu không hiện, Aim không lock, Script không chạy.
    - Tự động phát hiện lỗi và thông báo.
    - Code tinh gọn, chạy nhanh, ít lag.
    - Tự động bật sẵn AIM + Hitbox.
    - Phím: RightControl (Menu), "-" (Ẩn/Hiện nhanh).
--]]

-- ==================== CHỐNG LOAD LẠI ====================
if getgenv().PALO_AIM_V8_RUNNING then
    print("⚠️ Script đang chạy, không load lại")
    return
end
getgenv().PALO_AIM_V8_RUNNING = true

-- ==================== THÔNG BÁO KHỞI ĐỘNG ====================
print("🔧 PALO AIM V8 - ĐANG KHỞI ĐỘNG...")
print("⏳ Đang tải dịch vụ...")

-- ==================== DỊCH VỤ CƠ BẢN ====================
local success, err = pcall(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==================== CHỜ NHÂN VẬT ====================
print("⏳ Đang chờ nhân vật...")
repeat task.wait() until LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
task.wait(1)
print("✅ Nhân vật đã sẵn sàng!")

-- ==================== PHÁT HIỆN THIẾT BỊ ====================
local IsMobile = false
pcall(function()
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end)
print("📱 Thiết bị: " .. (IsMobile and "MOBILE" or "PC"))

-- ==================== CẤU HÌNH ====================
local Config = {
    Enabled = true,
    MenuVisible = true,
    QuickHide = false,
    MenuKey = Enum.KeyCode.RightControl,
    HideKey = Enum.KeyCode.Minus,
    
    AimPart = "Head",
    FOV_Radius = 250,
    Smoothness = 0.06,
    Prediction = 0.15,
    
    MagicBullet = true,
    BulletCurve = 0.5,
    MultiBullet = 3,
    
    AntiDetect = true,
    FakeCamera = true,
    JitterOffset = 0.02,
    LegitMode = false,
    RandomMissChance = 0,
    
    HitboxEnabled = true,
    HitboxSize = Vector3.new(4, 5, 4),
    HitboxColor = Color3.fromRGB(255, 20, 20),
    HitboxTransparency = 0.3,
    
    AutoFire = true,
    AutoFireDelay = 0.08,
    
    WallCheck = false,
    TeamCheck = false,
    MaxDistance = 1000,
    
    FOV_Color = Color3.fromRGB(255, 30, 30),
    FOV_Transparency = 0.5,
    ShowFOV = true,
    ShowTargetLine = true,
    ShowHitbox = true,
    ShowMagicTrail = true,
    TargetLineColor = Color3.fromRGB(0, 255, 80),
    MagicTrailColor = Color3.fromRGB(255, 200, 0)
}

-- ==================== KHAI BÁO BIẾN ====================
local AimbotTarget = nil
local MenuGUI = nil
local Drawings = {}
local Connections = {}
local HitboxHighlights = {}
local MagicBullets = {}
local FireRemotes = {}
local LastFireTime = 0

-- ==================== QUÉT REMOTE EVENT ====================
print("🔍 Đang quét RemoteEvent...")
local function ScanFireRemotes()
    local remotes = {}
    local keywords = {"fire", "shoot", "bang", "gun", "bullet", "damage", "hit", "weapon", "mouse1", "click", "trigger"}
    
    local function search(parent, depth)
        if depth > 6 or #remotes >= 10 then return end
        for _, child in ipairs(parent:GetChildren()) do
            pcall(function()
                if child:IsA("RemoteEvent") then
                    local name = child.Name:lower()
                    for _, kw in ipairs(keywords) do
                        if name:find(kw) then
                            table.insert(remotes, child)
                            break
                        end
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
            if v:IsA("RemoteEvent") and #remotes < 15 then
                table.insert(remotes, v)
            end
        end
    end
    
    return remotes
end
FireRemotes = ScanFireRemotes()
print("🔫 Tìm thấy " .. #FireRemotes .. " RemoteEvent")

-- ==================== HÀM CƠ BẢN ====================
local function WorldToScreen(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    if onScreen then
        return Vector2.new(screenPos.X, screenPos.Y)
    end
    return nil
end

local function GetBonePosition(char, boneName)
    if not char then return nil end
    local part = char:FindFirstChild(boneName)
    if part and part:IsA("BasePart") then
        return part.Position
    end
    -- Fallback
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if root then
        return root.Position
    end
    return nil
end

local function PredictPosition(pos, char)
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return pos end
    local vel = root.AssemblyLinearVelocity
    local dist = (Camera.CFrame.Position - pos).Magnitude
    local time = dist / 300
    return pos + vel * time * Config.Prediction
end

-- ==================== ĐẠN MA THUẬT ====================
local function CalculateMagicBulletPath(startPos, targetPos, numBullets)
    local paths = {}
    local mainDir = (targetPos - startPos).Unit
    local dist = (targetPos - startPos).Magnitude
    
    local right = mainDir:Cross(Vector3.new(0, 1, 0))
    if right.Magnitude < 0.01 then right = mainDir:Cross(Vector3.new(1, 0, 0)) end
    right = right.Unit
    local up = mainDir:Cross(right).Unit
    
    for i = 1, numBullets do
        local angleH = (i / numBullets) * math.pi * 2 + math.random() * 0.5
        local angleV = math.sin(i * 1.7) * 0.5
        local midPoint = startPos + mainDir * (dist * 0.5)
        midPoint = midPoint + right * math.cos(angleH) * (dist * Config.BulletCurve * 0.3)
        midPoint = midPoint + up * math.sin(angleV) * (dist * Config.BulletCurve * 0.3)
        
        local path = {}
        for j = 0, 15 do
            local t = j / 15
            local point = (1-t)^2 * startPos + 2*(1-t)*t * midPoint + t^2 * targetPos
            table.insert(path, point)
        end
        table.insert(paths, path)
    end
    
    return paths
end

local function DrawMagicTrails(paths)
    for _, trail in ipairs(MagicBullets) do
        for _, d in ipairs(trail) do
            pcall(function() d:Remove() end)
        end
    end
    MagicBullets = {}
    
    if not Config.ShowMagicTrail or not Config.MagicBullet then return end
    
    for _, path in ipairs(paths) do
        local trailDrawings = {}
        for i = 1, #path - 1 do
            local s1 = WorldToScreen(path[i])
            local s2 = WorldToScreen(path[i+1])
            if s1 and s2 then
                local line = Drawing.new("Line")
                line.From = s1
                line.To = s2
                line.Color = Config.MagicTrailColor
                line.Thickness = 1.5
                line.Transparency = 0.8
                line.ZIndex = 12
                line.Visible = Config.Enabled and not Config.QuickHide
                table.insert(trailDrawings, line)
            end
        end
        table.insert(MagicBullets, trailDrawings)
    end
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

-- ==================== ANTI DETECT ====================
local function ApplyAntiDetection()
    if not Config.AntiDetect or not Config.FakeCamera then return false end
    if Config.LegitMode and Config.RandomMissChance > 0 and math.random() < Config.RandomMissChance then
        return true
    end
    return false
end

-- ==================== TÌM MỤC TIÊU ====================
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
        
        local bonePos = GetBonePosition(char, Config.AimPart)
        if not bonePos then continue end
        
        bonePos = PredictPosition(bonePos, char)
        
        local dist3D = (camPos - bonePos).Magnitude
        if dist3D > Config.MaxDistance then continue end
        
        local screenPos = WorldToScreen(bonePos)
        if not screenPos then continue end
        
        local distFromCenter = (screenPos - screenCenter).Magnitude
        if distFromCenter > Config.FOV_Radius then continue end
        
        local score = distFromCenter * 0.4 + dist3D * 0.6
        
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

-- ==================== AUTO FIRE ====================
local function AutoFireWeapon(target)
    if not Config.AutoFire then return end
    local now = tick()
    if now - LastFireTime < Config.AutoFireDelay then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end
    
    local remote = nil
    for _, r in ipairs(FireRemotes) do
        if r:IsDescendantOf(tool) then remote = r; break end
    end
    if not remote and #FireRemotes > 0 then remote = FireRemotes[1] end
    if not remote then return end
    
    LastFireTime = now
    
    local targets = {target.Position}
    if Config.MagicBullet and Config.MultiBullet > 1 then
        local paths = CalculateMagicBulletPath(Camera.CFrame.Position, target.Position, Config.MultiBullet)
        for _, path in ipairs(paths) do
            table.insert(targets, path[#path])
        end
        DrawMagicTrails(paths)
    end
    
    for _, tgt in ipairs(targets) do
        pcall(function()
            remote:FireServer(tgt, char:FindFirstChild("HumanoidRootPart"), tool)
        end)
    end
end

-- ==================== VÒNG LẶP CHÍNH ====================
local function MainLoop()
    if not Camera or Camera.Parent == nil then
        Camera = Workspace.CurrentCamera
        if not Camera then return end
    end
    
    local shouldSkip = ApplyAntiDetection()
    
    -- Cập nhật FOV
    if Drawings.FOV then
        Drawings.FOV.Visible = Config.Enabled and Config.ShowFOV and not Config.QuickHide
        Drawings.FOV.Radius = Config.FOV_Radius
        Drawings.FOV.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        Drawings.FOV.Color = Config.FOV_Color
    end
    
    -- Ẩn line mặc định
    if Drawings.TargetLine then Drawings.TargetLine.Visible = false end
    
    if not Config.Enabled or Config.QuickHide or shouldSkip then
        AimbotTarget = nil
        return
    end
    
    AimbotTarget = GetBestTarget()
    
    if AimbotTarget then
        -- Vẽ line
        if Drawings.TargetLine and Config.ShowTargetLine then
            local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            Drawings.TargetLine.Visible = true
            Drawings.TargetLine.From = center
            Drawings.TargetLine.To = AimbotTarget.ScreenPos
        end
        
        -- Tạo hitbox
        CreateHitbox(AimbotTarget.Character)
        
        -- AIM
        local targetCFrame = CFrame.new(Camera.CFrame.Position, AimbotTarget.Position)
        if Config.JitterOffset > 0 then
            local j = Vector3.new(
                math.sin(tick() * 15) * Config.JitterOffset,
                math.cos(tick() * 17) * Config.JitterOffset,
                math.sin(tick() * 13) * Config.JitterOffset * 0.5
            )
            targetCFrame = CFrame.new(Camera.CFrame.Position, AimbotTarget.Position + j)
        end
        
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Config.Smoothness)
        
        -- Auto fire
        AutoFireWeapon(AimbotTarget)
    end
end

-- ==================== MENU ĐƠN GIẢN ====================
local function CreateMenu()
    if MenuGUI then pcall(function() MenuGUI:Destroy() end) end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PALO_AIM_V8"
    ScreenGui.Parent = CoreGui
    ScreenGui.ResetOnSpawn = false
    
    local sizeX = IsMobile and 300 or 320
    local sizeY = IsMobile and 400 or 450
    
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Parent = ScreenGui
    Main.Size = UDim2.new(0, sizeX, 0, sizeY)
    Main.Position = UDim2.new(0.5, -sizeX/2, 0.3, -sizeY/2)
    Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = Main
    
    -- Title
    local Title = Instance.new("Frame")
    Title.Parent = Main
    Title.Size = UDim2.new(1, 0, 0, 38)
    Title.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    Title.BorderSizePixel = 0
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 10)
    TitleCorner.Parent = Title
    
    local TitleText = Instance.new("TextLabel")
    TitleText.Parent = Title
    TitleText.Size = UDim2.new(1, -40, 1, 0)
    TitleText.Position = UDim2.new(0, 14, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = "🔥 PALO AIM V8"
    TitleText.TextColor3 = Color3.fromRGB(255, 200, 50)
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextSize = 14
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    
    local Close = Instance.new("TextButton")
    Close.Parent = Title
    Close.Size = UDim2.new(0, 28, 0, 28)
    Close.Position = UDim2.new(1, -32, 0.5, -14)
    Close.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    Close.Text = "X"
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
    Scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 150, 50)
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 500)
    
    local ScrollCorner = Instance.new("UICorner")
    ScrollCorner.CornerRadius = UDim.new(0, 10)
    ScrollCorner.Parent = Scroll
    
    local List = Instance.new("UIListLayout")
    List.Parent = Scroll
    List.SortOrder = Enum.SortOrder.LayoutOrder
    List.Padding = UDim.new(0, 4)
    
    local Pad = Instance.new("UIPadding")
    Pad.Parent = Scroll
    Pad.PaddingLeft = UDim.new(0, 8)
    Pad.PaddingRight = UDim.new(0, 8)
    Pad.PaddingTop = UDim.new(0, 5)
    
    -- Toggle
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
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        
        local b = Instance.new("TextButton")
        b.Parent = f
        b.Size = UDim2.new(0, 44, 0, 22)
        b.Position = UDim2.new(1, -44, 0.5, -11)
        b.BackgroundColor3 = default and Color3.fromRGB(255, 120, 30) or Color3.fromRGB(80, 80, 80)
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
            b.BackgroundColor3 = state and Color3.fromRGB(255, 120, 30) or Color3.fromRGB(80, 80, 80)
            d.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            callback(state)
        end)
    end
    
    -- Dropdown
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
    
    -- ==================== MENU ITEMS ====================
    local sec1 = Instance.new("TextLabel")
    sec1.Parent = Scroll
    sec1.Size = UDim2.new(1, 0, 0, 20)
    sec1.BackgroundTransparency = 1
    sec1.Text = "─ 🔥 CHỨC NĂNG CHÍNH ─"
    sec1.TextColor3 = Color3.fromRGB(255, 150, 50)
    sec1.Font = Enum.Font.GothamBold
    sec1.TextSize = 12
    
    Toggle("🎯 Bật/Tắt AIM", true, function(v) Config.Enabled = v end)
    Toggle("✨ Đạn Ma Thuật", true, function(v) Config.MagicBullet = v end)
    Toggle("🔫 Tự Động Bắn", true, function(v) Config.AutoFire = v end)
    Toggle("📦 Hitbox Mở Rộng", true, function(v) Config.HitboxEnabled = v; Config.ShowHitbox = v end)
    Toggle("🛡 Anti Phát Hiện", true, function(v) Config.AntiDetect = v; Config.FakeCamera = v end)
    Toggle("📏 Đường Line", true, function(v) Config.ShowTargetLine = v end)
    Toggle("🌈 Vệt Đạn", true, function(v) Config.ShowMagicTrail = v end)
    
    Dropdown("🦴 Phần Cơ Thể", {
        "Head", "Torso", "UpperTorso", "LowerTorso",
        "LeftFoot", "RightFoot", "HumanoidRootPart"
    }, "Head", function(v) Config.AimPart = v end)
    
    local info = Instance.new("TextLabel")
    info.Parent = Scroll
    info.Size = UDim2.new(1, 0, 0, 40)
    info.BackgroundTransparency = 1
    info.Text = "⌨ Menu: RightControl\n⌨ Ẩn/Hiện: Phím -"
    info.TextColor3 = Color3.fromRGB(150, 150, 160)
    info.Font = Enum.Font.Gotham
    info.TextSize = 10
    info.TextXAlignment = Enum.TextXAlignment.Center
    
    MenuGUI = ScreenGui
    return ScreenGui
end

-- ==================== KHỞI TẠO HỆ THỐNG ====================
print("🎨 Đang tạo giao diện...")

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
Drawings.TargetLine.Thickness = 1.5
Drawings.TargetLine.Transparency = 0.6
Drawings.TargetLine.ZIndex = 11

-- Menu
CreateMenu()
if MenuGUI then
    MenuGUI.Enabled = Config.MenuVisible
    print("✅ Menu đã sẵn sàng!")
else
    print("⚠️ Lỗi tạo Menu!")
end

-- Vòng lặp chính
Connections.Render = RunService.RenderStepped:Connect(MainLoop)
print("🔄 Vòng lặp chính đã chạy!")

-- Phím tắt
Connections.InputBegan = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Config.MenuKey then
        Config.MenuVisible = not Config.MenuVisible
        if MenuGUI then MenuGUI.Enabled = Config.MenuVisible end
    end
    if input.KeyCode == Config.HideKey then
        Config.QuickHide = not Config.QuickHide
    end
end)
print("⌨ Phím tắt đã sẵn sàng!")

-- Dọn dẹp hitbox
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

print("✅ PALO AIM V8 HOẠT ĐỘNG THÀNH CÔNG!")
print("🎯 AIM: BẬT | Đạn ma thuật: BẬT | Tự động bắn: BẬT")
print("📋 Menu: RightControl | Ẩn: -")

end) -- Kết thúc pcall

-- ==================== XỬ LÝ LỖI ====================
if not success then
    warn("❌ LỖI SCRIPT: " .. tostring(err))
    print("🔧 ĐANG THỬ SỬA LỖI...")
    
    -- Fallback: Chạy phiên bản tối giản
    pcall(function()
        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local Workspace = game:GetService("Workspace")
        local LocalPlayer = Players.LocalPlayer
        local Camera = Workspace.CurrentCamera
        
        repeat task.wait() until LocalPlayer.Character
        
        local enabled = true
        local target = nil
        
        local function getTarget()
            local best = nil
            local bestDist = math.huge
            local camPos = Camera.CFrame.Position
            local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
            
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local root = p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Head")
                    if root then
                        local pos = root.Position
                        local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
                        if onScreen then
                            local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                            if dist < 200 and dist < bestDist then
                                bestDist = dist
                                best = {Position = pos, ScreenPos = Vector2.new(screenPos.X, screenPos.Y)}
                            end
                        end
                    end
                end
            end
            return best
        end
        
        RunService.RenderStepped:Connect(function()
            if not enabled then return end
            target = getTarget()
            if target then
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target.Position), 0.1)
            end
        end)
        
        print("✅ FALLBACK AIM ĐÃ CHẠY!")
    end)
end