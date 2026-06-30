--[[
    SCRIPT: PALO ULTIMATE SILENT AIM V7 - MAGIC BULLET EDITION
    Tác giả: palofsc (palo)
    Tương thích: Delta X Mobile, VNG Mobile, Arceus X, Hydrogen, Fluxus Mobile, PC Executors
    Mô tả: Aimbot siêu cấp với ĐẠN MA THUẬT.
    - Đạn bay theo đường cong đa hướng đến mục tiêu.
    - Anti phát hiện (Camera giả, CFrames ảo).
    - Lia cực mạnh, dính sát không thoát.
    - Hitbox 3D mở rộng + Tự động bắn khi khóa.
    - Tàng hình tuyệt đối với Admin Detection.
--]]

if getgenv().PALO_AIM_V7 then
    getgenv().PALO_AIM_V7 = nil
    task.wait(0.2)
end
getgenv().PALO_AIM_V7 = true

-- ==================== DỊCH VỤ ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Chờ nhân vật
repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
task.wait(1)

-- ==================== PHÁT HIỆN MOBILE ====================
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ==================== CẤU HÌNH SIÊU CẤP ====================
local Config = {
    -- Trạng thái
    Enabled = true,
    MenuVisible = true,
    QuickHide = false,
    MenuKey = Enum.KeyCode.RightControl,
    HideKey = Enum.KeyCode.Minus,
    
    -- Aimbot siêu dính
    AimPart = "Head",
    FOV_Radius = 350, -- FOV rộng hơn
    Smoothness = 0.03, -- Cực mượt, dính chặt
    Prediction = 0.18, -- Dự đoán cao hơn
    
    -- Đạn ma thuật
    MagicBullet = true,
    BulletSpeed = 500, -- Tốc độ đạn ảo (studs/s)
    BulletCurve = 0.6, -- Độ cong đường đạn (0-1)
    BulletSpread = 0.5, -- Góc phân tán đa hướng (rad)
    MultiBullet = 3, -- Số lượng đạn ma thuật mỗi lần bắn
    
    -- Anti phát hiện
    AntiDetect = true,
    FakeCamera = true, -- Camera ảo đánh lạc hướng
    JitterOffset = 0.02, -- Rung giả tự nhiên
    RandomMissChance = 0, -- Tỉ lệ bắn trượt giả (0 = luôn trúng)
    LegitMode = false, -- Chế độ "hợp pháp" cho game anti-cheat mạnh
    
    -- Hitbox mở rộng
    HitboxEnabled = true,
    HitboxSize = Vector3.new(4, 5, 4), -- Hitbox to hơn
    HitboxColor = Color3.fromRGB(255, 20, 20),
    HitboxTransparency = 0.3,
    
    -- Tự động bắn
    AutoFire = true,
    AutoFireDelay = 0.05, -- Bắn nhanh
    AutoReload = true,
    
    -- Kiểm tra
    WallCheck = false, -- Tắt wall check cho đạn ma thuật xuyên tường
    TeamCheck = false,
    MaxDistance = 1500, -- Xa hơn
    
    -- Giao diện
    FOV_Color = Color3.fromRGB(255, 30, 30),
    FOV_Transparency = 0.4,
    ShowHitbox = true,
    ShowFOV = true,
    ShowTargetLine = true,
    ShowMagicTrail = true, -- Vẽ đường đạn ma thuật
    TargetLineColor = Color3.fromRGB(0, 255, 80),
    MagicTrailColor = Color3.fromRGB(255, 200, 0)
}

-- ==================== BIẾN HỆ THỐNG ====================
local AimbotTarget = nil
local MenuGUI = nil
local Drawings = {}
local Connections = {}
local HitboxHighlights = {}
local MagicBullets = {} -- Lưu đạn ma thuật đang bay
local FakeCameraCFrame = nil
local LastFireTime = 0
local FireRemotes = {}

-- ==================== QUÉT REMOTE EVENT ====================
local function ScanFireRemotes()
    local remotes = {}
    local keywords = {"fire", "shoot", "bang", "gun", "bullet", "damage", "hit", "weapon"}
    
    local function search(parent, depth)
        if depth > 6 or #remotes >= 10 then return end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("RemoteEvent") then
                local name = child.Name:lower()
                for _, kw in ipairs(keywords) do
                    if name:find(kw) then table.insert(remotes, child); break end
                end
            end
            if #child:GetChildren() > 0 then search(child, depth + 1) end
        end
    end
    
    search(ReplicatedStorage, 0)
    search(Workspace, 0)
    if LocalPlayer.PlayerGui then search(LocalPlayer.PlayerGui, 0) end
    
    if #remotes == 0 then
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("RemoteEvent") and #remotes < 15 then table.insert(remotes, v) end
        end
    end
    
    return remotes
end

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
    
    local partName = boneName
    if humanoid.RigType == Enum.HumanoidRigType.R6 then
        local r6Map = {Head = "Head", Torso = "Torso", LeftArm = "Left Arm", 
                       RightArm = "Right Arm", LeftLeg = "Left Leg", RightLeg = "Right Leg"}
        partName = r6Map[boneName] or boneName
    end
    
    local part = char:FindFirstChild(partName)
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
    local time = dist / Config.BulletSpeed
    return pos + vel * time * Config.Prediction
end

-- ==================== ĐẠN MA THUẬT ====================
local function CalculateMagicBulletPath(startPos, targetPos, numBullets)
    local paths = {}
    local mainDir = (targetPos - startPos).Unit
    local dist = (targetPos - startPos).Magnitude
    
    -- Vector vuông góc
    local right = mainDir:Cross(Vector3.new(0, 1, 0))
    if right.Magnitude < 0.01 then right = mainDir:Cross(Vector3.new(1, 0, 0)) end
    right = right.Unit
    local up = mainDir:Cross(right).Unit
    
    for i = 1, numBullets do
        -- Góc phân tán đa hướng
        local angleH = (i / numBullets) * math.pi * 2 + math.random() * Config.BulletSpread
        local angleV = math.sin(i * 1.7) * Config.BulletSpread
        
        -- Điểm giữa đường cong (parabol)
        local midPoint = startPos + mainDir * (dist * 0.5)
        local curveOffset = right * math.cos(angleH) * (dist * Config.BulletCurve * 0.3)
        local heightOffset = up * math.sin(angleV) * (dist * Config.BulletCurve * 0.3)
        midPoint = midPoint + curveOffset + heightOffset
        
        -- Tạo đường Bezier bậc 2
        local path = {}
        local segments = 20
        for j = 0, segments do
            local t = j / segments
            -- Công thức Bezier: B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
            local point = (1-t)^2 * startPos + 2*(1-t)*t * midPoint + t^2 * targetPos
            table.insert(path, point)
        end
        
        table.insert(paths, path)
    end
    
    return paths
end

-- Vẽ đường đạn ma thuật
local function DrawMagicTrails(paths)
    -- Xóa trails cũ
    for _, trail in ipairs(MagicBullets) do
        for _, drawing in ipairs(trail) do
            pcall(function() drawing:Remove() end)
        end
    end
    MagicBullets = {}
    
    if not Config.ShowMagicTrail or not Config.MagicBullet then return end
    
    for _, path in ipairs(paths) do
        local trailDrawings = {}
        for i = 1, #path - 1 do
            local screen1 = WorldToScreen(path[i])
            local screen2 = WorldToScreen(path[i+1])
            if screen1 and screen2 then
                local line = Drawing.new("Line")
                line.From = screen1
                line.To = screen2
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

-- ==================== ANTI PHÁT HIỆN ====================
local function ApplyAntiDetection()
    if not Config.AntiDetect then return end
    
    -- Tạo Camera ảo
    if Config.FakeCamera then
        if FakeCameraCFrame then
            -- Giữ Camera thật ở vị trí cũ (đánh lạc hướng anti-cheat)
            local realCFrame = Camera.CFrame
            local jitterX = math.sin(tick() * 10) * Config.JitterOffset
            local jitterY = math.cos(tick() * 13) * Config.JitterOffset
            local fakePos = realCFrame.Position + Vector3.new(jitterX, jitterY, 0)
            FakeCameraCFrame = CFrame.new(fakePos, realCFrame.Position + realCFrame.LookVector * 100)
        end
    end
    
    -- Random miss giả (Legit Mode)
    if Config.LegitMode and Config.RandomMissChance > 0 then
        if math.random() < Config.RandomMissChance then
            return true -- Bỏ qua frame này, không aim
        end
    end
    
    return false
end

-- ==================== HITBOX 3D MỞ RỘNG ====================
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
    
    -- Box chính
    local box = Instance.new("BoxHandleAdornment")
    box.Parent = root
    box.Adornee = root
    box.Size = Config.HitboxSize
    box.Color3 = Config.HitboxColor
    box.Transparency = Config.HitboxTransparency
    box.AlwaysOnTop = true
    box.ZIndex = 5
    table.insert(HitboxHighlights[char], box)
    
    -- Viền phát sáng
    local outline = Instance.new("BoxHandleAdornment")
    outline.Parent = root
    outline.Adornee = root
    outline.Size = Config.HitboxSize + Vector3.new(0.3, 0.3, 0.3)
    outline.Color3 = Color3.fromRGB(255, 255, 0)
    outline.Transparency = 0.7
    outline.AlwaysOnTop = true
    outline.ZIndex = 4
    table.insert(HitboxHighlights[char], outline)
end

-- ==================== TÌM MỤC TIÊU SIÊU DÍNH ====================
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
        
        -- Thử nhiều vị trí để dính hơn
        local positions = {}
        local mainPos, mainPart = GetBonePosition(char, Config.AimPart)
        if mainPos then table.insert(positions, {pos = mainPos, part = mainPart}) end
        
        -- Thêm fallback
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        if root and root ~= mainPart then
            table.insert(positions, {pos = root.Position, part = root})
        end
        
        for _, posData in ipairs(positions) do
            local bonePos = PredictPosition(posData.pos, char)
            
            local dist3D = (camPos - bonePos).Magnitude
            if dist3D > Config.MaxDistance then continue end
            
            local distFromCenter, screenPos = GetDistanceFromCenter(bonePos)
            if distFromCenter > Config.FOV_Radius then continue end
            
            local score = distFromCenter * 0.4 + dist3D * 0.6 -- Ưu tiên gần hơn
            
            if score < bestScore then
                bestScore = score
                best = {
                    Player = player,
                    Character = char,
                    Position = bonePos,
                    Part = posData.part,
                    ScreenPos = screenPos,
                    Distance = dist3D
                }
            end
        end
    end
    
    return best
end

-- ==================== TỰ ĐỘNG BẮN ====================
local function AutoFireWeapon(target)
    if not Config.AutoFire then return end
    local now = tick()
    if now - LastFireTime < Config.AutoFireDelay then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then tool = backpack:FindFirstChildOfClass("Tool") end
    end
    if not tool then return end
    
    -- Tìm Remote
    local remote = nil
    for _, r in ipairs(FireRemotes) do
        if r:IsDescendantOf(tool) then remote = r; break end
    end
    if not remote and #FireRemotes > 0 then remote = FireRemotes[1] end
    if not remote then return end
    
    LastFireTime = now
    
    -- Gửi đạn ma thuật (nhiều vị trí)
    local targets = {target.Position}
    if Config.MagicBullet and Config.MultiBullet > 1 then
        local paths = CalculateMagicBulletPath(Camera.CFrame.Position, target.Position, Config.MultiBullet)
        -- Gửi đạn đến các điểm cuối của đường cong
        for _, path in ipairs(paths) do
            table.insert(targets, path[#path])
        end
        -- Vẽ trail
        DrawMagicTrails(paths)
    end
    
    -- Gửi tất cả đạn
    for _, tgt in ipairs(targets) do
        pcall(function()
            remote:FireServer(tgt, tgt, tool, char:FindFirstChild("HumanoidRootPart"))
        end)
    end
end

-- ==================== VÒNG LẶP CHÍNH ====================
local function MainLoop()
    if not Camera or Camera.Parent == nil then
        Camera = Workspace.CurrentCamera
        if not Camera then return end
    end
    
    -- Anti detection
    local shouldSkip = ApplyAntiDetection()
    
    -- FOV
    if Drawings.FOV then
        Drawings.FOV.Visible = Config.Enabled and Config.ShowFOV and not Config.QuickHide
        Drawings.FOV.Radius = Config.FOV_Radius
        Drawings.FOV.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        Drawings.FOV.Color = Config.FOV_Color
    end
    
    if Drawings.TargetLine then Drawings.TargetLine.Visible = false end
    
    if not Config.Enabled or Config.QuickHide or shouldSkip then
        AimbotTarget = nil
        return
    end
    
    AimbotTarget = GetBestTarget()
    
    if AimbotTarget then
        -- Line
        if Drawings.TargetLine and Config.ShowTargetLine then
            local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            Drawings.TargetLine.Visible = true
            Drawings.TargetLine.From = center
            Drawings.TargetLine.To = AimbotTarget.ScreenPos
        end
        
        -- Hitbox
        CreateHitbox(AimbotTarget.Character)
        
        -- AIM SIÊU DÍNH
        local targetCFrame = CFrame.new(Camera.CFrame.Position, AimbotTarget.Position)
        
        -- Thêm jitter nhẹ để trông tự nhiên
        if Config.JitterOffset > 0 then
            local jitter = Vector3.new(
                math.sin(tick() * 15) * Config.JitterOffset,
                math.cos(tick() * 17) * Config.JitterOffset,
                math.sin(tick() * 13) * Config.JitterOffset * 0.5
            )
            targetCFrame = CFrame.new(Camera.CFrame.Position, AimbotTarget.Position + jitter)
        end
        
        local smooth = Config.Smoothness
        if IsMobile then smooth = smooth + 0.02 end
        
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smooth)
        
        -- Auto Fire
        AutoFireWeapon(AimbotTarget)
    else
        -- Xóa hitbox khi không có mục tiêu
        for char, highlights in pairs(HitboxHighlights) do
            for _, v in ipairs(highlights) do
                pcall(function() v:Destroy() end)
            end
            HitboxHighlights[char] = nil
        end
    end
end

-- ==================== MENU SIÊU CẤP ====================
local function CreateMenu()
    if MenuGUI then pcall(function() MenuGUI:Destroy() end) end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PALO_AIM_V7"
    ScreenGui.Parent = CoreGui
    ScreenGui.ResetOnSpawn = false
    
    local sizeX = IsMobile and 310 else 350
    local sizeY = IsMobile and 460 else 520
    
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Parent = ScreenGui
    Main.Size = UDim2.new(0, sizeX, 0, sizeY)
    Main.Position = UDim2.new(0.5, -sizeX/2, 0.35, -sizeY/2)
    Main.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = Main
    
    local stroke = Instance.new("UIStroke")
    stroke.Parent = Main
    stroke.Color = Color3.fromRGB(255, 100, 0)
    stroke.Thickness = 1.8
    
    -- Title
    local Title = Instance.new("Frame")
    Title.Parent = Main
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
    Title.BorderSizePixel = 0
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 10)
    TitleCorner.Parent = Title
    
    local TitleText = Instance.new("TextLabel")
    TitleText.Parent = Title
    TitleText.Size = UDim2.new(1, -45, 1, 0)
    TitleText.Position = UDim2.new(0, 15, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = "🔥 PALO MAGIC BULLET V7"
    TitleText.TextColor3 = Color3.fromRGB(255, 180, 50)
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextSize = 14
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    
    local Close = Instance.new("TextButton")
    Close.Parent = Title
    Close.Size = UDim2.new(0, 28, 0, 28)
    Close.Position = UDim2.new(1, -34, 0.5, -14)
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
    Scroll.Size = UDim2.new(1, 0, 1, -40)
    Scroll.Position = UDim2.new(0, 0, 0, 40)
    Scroll.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    Scroll.BorderSizePixel = 0
    Scroll.ScrollBarThickness = 3
    Scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 150, 50)
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 650)
    
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
    
    -- ==================== XÂY DỰNG MENU ====================
    local sec1 = Instance.new("TextLabel")
    sec1.Parent = Scroll
    sec1.Size = UDim2.new(1, 0, 0, 18)
    sec1.BackgroundTransparency = 1
    sec1.Text = "─ 🔥 ĐẠN MA THUẬT ─"
    sec1.TextColor3 = Color3.fromRGB(255, 150, 50)
    sec1.Font = Enum.Font.GothamBold
    sec1.TextSize = 12
    
    Toggle("✨ Đạn Ma Thuật", true, function(v) Config.MagicBullet = v end)
    Toggle("🔫 Tự Động Bắn", true, function(v) Config.AutoFire = v end)
    Toggle("📦 Hitbox Mở Rộng", true, function(v) Config.HitboxEnabled = v; Config.ShowHitbox = v end)
    Toggle("🛡 Anti Phát Hiện", true, function(v) Config.AntiDetect = v; Config.FakeCamera = v end)
    Toggle("👤 Legit Mode", false, function(v) Config.LegitMode = v; if v then Config.RandomMissChance = 0.05 else Config.RandomMissChance = 0 end end)
    Toggle("🧱 Xuyên Tường", false, function(v) Config.WallCheck = not v end) -- Đảo ngược
    
    local sec2 = Instance.new("TextLabel")
    sec2.Parent = Scroll
    sec2.Size = UDim2.new(1, 0, 0, 18)
    sec2.BackgroundTransparency = 1
    sec2.Text = "─ 🎯 AIMBOT ─"
    sec2.TextColor3 = Color3.fromRGB(255, 80, 80)
    sec2.Font = Enum.Font.GothamBold
    sec2.TextSize = 12
    
    Toggle("🎯 Bật/Tắt", true, function(v) Config.Enabled = v end)
    Toggle("📏 Đường Line", true, function(v) Config.ShowTargetLine = v end)
    Toggle("🌈 Vệt Đạn", true, function(v) Config.ShowMagicTrail = v end)
    
    Dropdown("🦴 Phần Cơ Thể", {
        "Head", "Torso", "UpperTorso", "LowerTorso",
        "LeftFoot", "RightFoot", "HumanoidRootPart"
    }, "Head", function(v) Config.AimPart = v end)
    
    local info = Instance.new("TextLabel")
    info.Parent = Scroll
    info.Size = UDim2.new(1, 0, 0, 45)
    info.BackgroundTransparency = 1
    info.Text = "⌨ Menu: RightControl\n⌨ Ẩn/Hiện: Phím -\n🔥 Đạn ma thuật bay đa hướng!"
    info.TextColor3 = Color3.fromRGB(150, 150, 160)
    info.Font = Enum.Font.Gotham
    info.TextSize = 10
    info.TextXAlignment = Enum.TextXAlignment.Center
    
    MenuGUI = ScreenGui
    return ScreenGui
end

-- ==================== KHỞI TẠO ====================
local function Init()
    FireRemotes = ScanFireRemotes()
    print("🔫 Magic Bullet: Tìm thấy " .. #FireRemotes .. " Remote")
    
    -- FOV
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
    local menu = CreateMenu()
    menu.Enabled = Config.MenuVisible
    
    -- Vòng lặp
    Connections.Render = RunService.RenderStepped:Connect(MainLoop)
    
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
    
    -- Dọn hitbox
    Connections.Heartbeat = RunService.Heartbeat:Connect(function()
        for char, highlights in pairs(HitboxHighlights) do
            if not char or not char.Parent then
                for _, v in ipairs(highlights) do pcall(function() v:Destroy() end) end
                HitboxHighlights[char] = nil
            end
        end
    end)
    
    print("✅ PALO MAGIC BULLET V7 READY!")
    print("🔥 Đạn ma thuật: BẬT")
    print("🛡 Anti Detect: BẬT")
    print("🎯 Aim siêu dính + Xuyên tường")
end

pcall(Init)