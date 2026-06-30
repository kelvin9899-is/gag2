--[[
    SCRIPT: Silent Aim Skeletal Targeting System for Delta X (Roblox)
    Tác giả: palofsc (palo)
    Mô tả: Hệ thống aimbot sử dụng khung xương nhân vật, phân vùng đầu/thân/chân.
    Tự động phát hiện tường chắn bằng Raycast để tránh ghim xuyên tường.
    Giao diện menu mượt với tính năng ẩn/hiện và bật/tắt chức năng.
    Yêu cầu: Delta Executor hoặc trình thực thi tương thích.
--]]

-- Bảo vệ môi trường thực thi
getgenv().SilentAimLoaded = nil
if getgenv().SilentAimLoaded then return end
getgenv().SilentAimLoaded = true

-- Khởi tạo biến môi trường
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Cấu hình mặc định
local Config = {
    Enabled = false,
    SelectedPart = "Head", -- "Head", "UpperTorso", "LowerTorso", "LeftFoot", "RightFoot"
    FOVRadius = 150,
    Smoothness = 0.12,
    WallCheck = true,
    VisibleCheck = true,
    TeamCheck = false,
    MenuVisible = false,
    MenuKey = Enum.KeyCode.RightControl
}

-- Biến lưu trữ đối tượng
local AimbotTarget = nil
local GUIObjects = {}

-- Hàm tạo giao diện menu chính
local function CreateMenu()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SilentAimMenu"
    ScreenGui.Parent = game.CoreGui
    ScreenGui.Enabled = Config.MenuVisible
    ScreenGui.ResetOnSpawn = false

    -- Khung chính
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.Size = UDim2.new(0, 280, 0, 320)
    MainFrame.Position = UDim2.new(0.5, -140, 0.35, -160)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true

    -- Góc bo tròn cho MainFrame
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = MainFrame

    -- Thanh tiêu đề
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Parent = MainFrame
    TitleBar.Size = UDim2.new(1, 0, 0, 32)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    TitleBar.BorderSizePixel = 0

    local TitleUICorner = Instance.new("UICorner")
    TitleUICorner.CornerRadius = UDim.new(0, 8)
    TitleUICorner.Parent = TitleBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "TitleLabel"
    TitleLabel.Parent = TitleBar
    TitleLabel.Size = UDim2.new(1, -10, 1, 0)
    TitleLabel.Position = UDim2.new(0, 10, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "PALO Aimbot | Delta X"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 14
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Nút đóng menu
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Parent = TitleBar
    CloseButton.Size = UDim2.new(0, 28, 0, 28)
    CloseButton.Position = UDim2.new(1, -30, 0, 2)
    CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.TextSize = 16
    CloseButton.BorderSizePixel = 0

    local CloseUICorner = Instance.new("UICorner")
    CloseUICorner.CornerRadius = UDim.new(0, 6)
    CloseUICorner.Parent = CloseButton

    -- Danh sách chức năng
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Parent = MainFrame
    ContentFrame.Size = UDim2.new(1, 0, 1, -32)
    ContentFrame.Position = UDim2.new(0, 0, 0, 32)
    ContentFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    ContentFrame.BorderSizePixel = 0

    local ContentUICorner = Instance.new("UICorner")
    ContentUICorner.CornerRadius = UDim.new(0, 8)
    ContentUICorner.Parent = ContentFrame

    -- Hàm tạo thanh toggle
    local function CreateToggle(Parent, Name, Default, Callback, YPos)
        local ToggleFrame = Instance.new("Frame")
        ToggleFrame.Name = Name .. "Toggle"
        ToggleFrame.Parent = Parent
        ToggleFrame.Size = UDim2.new(1, -20, 0, 36)
        ToggleFrame.Position = UDim2.new(0, 10, 0, YPos)
        ToggleFrame.BackgroundTransparency = 1

        local ToggleLabel = Instance.new("TextLabel")
        ToggleLabel.Name = "ToggleLabel"
        ToggleLabel.Parent = ToggleFrame
        ToggleLabel.Size = UDim2.new(0.65, 0, 1, 0)
        ToggleLabel.BackgroundTransparency = 1
        ToggleLabel.Text = Name
        ToggleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        ToggleLabel.Font = Enum.Font.Gotham
        ToggleLabel.TextSize = 13
        ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left

        local ToggleButton = Instance.new("TextButton")
        ToggleButton.Name = "ToggleButton"
        ToggleButton.Parent = ToggleFrame
        ToggleButton.Size = UDim2.new(0, 48, 0, 22)
        ToggleButton.Position = UDim2.new(1, -48, 0.5, -11)
        ToggleButton.BackgroundColor3 = Default and Color3.fromRGB(70, 180, 70) or Color3.fromRGB(80, 80, 80)
        ToggleButton.Text = ""
        ToggleButton.BorderSizePixel = 0
        ToggleButton.AutoButtonColor = false

        local ToggleUICorner = Instance.new("UICorner")
        ToggleUICorner.CornerRadius = UDim.new(0, 11)
        ToggleUICorner.Parent = ToggleButton

        local ToggleDot = Instance.new("Frame")
        ToggleDot.Name = "Dot"
        ToggleDot.Parent = ToggleButton
        ToggleDot.Size = UDim2.new(0, 18, 0, 18)
        ToggleDot.Position = Default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        ToggleDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ToggleDot.BorderSizePixel = 0

        local DotUICorner = Instance.new("UICorner")
        DotUICorner.CornerRadius = UDim.new(1, 0)
        DotUICorner.Parent = ToggleDot

        -- Xử lý sự kiện toggle
        local IsToggled = Default

        ToggleButton.MouseButton1Click:Connect(function()
            IsToggled = not IsToggled
            local TweenService = game:GetService("TweenService")
            local goal = {}
            goal.BackgroundColor3 = IsToggled and Color3.fromRGB(70, 180, 70) or Color3.fromRGB(80, 80, 80)
            local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local tween = TweenService:Create(ToggleButton, tweenInfo, goal)
            tween:Play()

            local dotGoal = {}
            dotGoal.Position = IsToggled and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
            local dotTween = TweenService:Create(ToggleDot, tweenInfo, dotGoal)
            dotTween:Play()

            Callback(IsToggled)
        end)

        return ToggleFrame
    end

    -- Hàm tạo dropdown chọn phần cơ thể
    local function CreateDropdown(Parent, Name, Options, Default, Callback, YPos)
        local DropdownFrame = Instance.new("Frame")
        DropdownFrame.Name = Name .. "Dropdown"
        DropdownFrame.Parent = Parent
        DropdownFrame.Size = UDim2.new(1, -20, 0, 50)
        DropdownFrame.Position = UDim2.new(0, 10, 0, YPos)
        DropdownFrame.BackgroundTransparency = 1

        local DropdownLabel = Instance.new("TextLabel")
        DropdownLabel.Parent = DropdownFrame
        DropdownLabel.Size = UDim2.new(1, 0, 0, 18)
        DropdownLabel.BackgroundTransparency = 1
        DropdownLabel.Text = Name
        DropdownLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        DropdownLabel.Font = Enum.Font.Gotham
        DropdownLabel.TextSize = 12
        DropdownLabel.TextXAlignment = Enum.TextXAlignment.Left

        local DropdownButton = Instance.new("TextButton")
        DropdownButton.Name = "DropdownButton"
        DropdownButton.Parent = DropdownFrame
        DropdownButton.Size = UDim2.new(1, 0, 0, 26)
        DropdownButton.Position = UDim2.new(0, 0, 0, 20)
        DropdownButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        DropdownButton.Text = Default
        DropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        DropdownButton.Font = Enum.Font.Gotham
        DropdownButton.TextSize = 13
        DropdownButton.BorderSizePixel = 0
        DropdownButton.AutoButtonColor = false

        local DropdownUICorner = Instance.new("UICorner")
        DropdownUICorner.CornerRadius = UDim.new(0, 6)
        DropdownUICorner.Parent = DropdownButton

        local OptionsList = Instance.new("Frame")
        OptionsList.Name = "OptionsList"
        OptionsList.Parent = DropdownFrame
        OptionsList.Size = UDim2.new(1, 0, 0, 0)
        OptionsList.Position = UDim2.new(0, 0, 0, 48)
        OptionsList.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        OptionsList.BorderSizePixel = 0
        OptionsList.ClipsDescendants = true
        OptionsList.ZIndex = 5

        local OptionsUICorner = Instance.new("UICorner")
        OptionsUICorner.CornerRadius = UDim.new(0, 4)
        OptionsUICorner.Parent = OptionsList

        local IsOpen = false

        -- Tạo các option button
        local OptionButtons = {}
        for i, option in ipairs(Options) do
            local OptionButton = Instance.new("TextButton")
            OptionButton.Name = option
            OptionButton.Parent = OptionsList
            OptionButton.Size = UDim2.new(1, 0, 0, 24)
            OptionButton.Position = UDim2.new(0, 0, 0, (i - 1) * 24)
            OptionButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            OptionButton.Text = option
            OptionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            OptionButton.Font = Enum.Font.Gotham
            OptionButton.TextSize = 12
            OptionButton.BorderSizePixel = 0
            OptionButton.ZIndex = 6
            OptionButton.AutoButtonColor = false

            OptionButton.MouseButton1Click:Connect(function()
                DropdownButton.Text = option
                Callback(option)
                IsOpen = false
                local TweenService = game:GetService("TweenService")
                local tween = TweenService:Create(OptionsList, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, 0)})
                tween:Play()
            end)

            OptionButton.MouseEnter:Connect(function()
                local TweenService = game:GetService("TweenService")
                local tween = TweenService:Create(OptionButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(70, 130, 200)})
                tween:Play()
            end)

            OptionButton.MouseLeave:Connect(function()
                local TweenService = game:GetService("TweenService")
                local tween = TweenService:Create(OptionButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(50, 50, 50)})
                tween:Play()
            end)

            table.insert(OptionButtons, OptionButton)
        end

        DropdownButton.MouseButton1Click:Connect(function()
            IsOpen = not IsOpen
            local TweenService = game:GetService("TweenService")
            local targetSize = IsOpen and UDim2.new(1, 0, 0, #Options * 24) or UDim2.new(1, 0, 0, 0)
            local tween = TweenService:Create(OptionsList, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize})
            tween:Play()
        end)

        return DropdownFrame
    end

    -- Tạo các thành phần UI
    CreateToggle(ContentFrame, "Bật / Tắt Aimbot", Config.Enabled, function(value)
        Config.Enabled = value
    end, 12)

    CreateToggle(ContentFrame, "Kiểm Tra Tường", Config.WallCheck, function(value)
        Config.WallCheck = value
    end, 58)

    CreateToggle(ContentFrame, "Kiểm Tra Đồng Đội", Config.TeamCheck, function(value)
        Config.TeamCheck = value
    end, 104)

    CreateToggle(ContentFrame, "Kiểm Tra Nhìn Thấy", Config.VisibleCheck, function(value)
        Config.VisibleCheck = value
    end, 150)

    CreateDropdown(ContentFrame, "Chọn Phần Cơ Thể", {"Head", "UpperTorso", "LowerTorso", "LeftFoot", "RightFoot"}, "Head", function(value)
        Config.SelectedPart = value
    end, 200)

    -- Nhãn hiển thị phím tắt menu
    local KeybindLabel = Instance.new("TextLabel")
    KeybindLabel.Name = "KeybindLabel"
    KeybindLabel.Parent = ContentFrame
    KeybindLabel.Size = UDim2.new(1, -20, 0, 20)
    KeybindLabel.Position = UDim2.new(0, 10, 0, 275)
    KeybindLabel.BackgroundTransparency = 1
    KeybindLabel.Text = "Phím tắt: RightControl"
    KeybindLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    KeybindLabel.Font = Enum.Font.Gotham
    KeybindLabel.TextSize = 11
    KeybindLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Sự kiện đóng menu
    CloseButton.MouseButton1Click:Connect(function()
        Config.MenuVisible = false
        ScreenGui.Enabled = false
    end)

    -- Lưu trữ ScreenGui để xử lý phím tắt
    GUIObjects.ScreenGui = ScreenGui

    return ScreenGui
end

-- Hàm lấy vị trí khung xương dựa trên tên phần
local function GetSkeletalPosition(Character, PartName)
    local PartMap = {
        ["Head"] = "Head",
        ["UpperTorso"] = "UpperTorso",
        ["LowerTorso"] = "LowerTorso",
        ["LeftFoot"] = "LeftFoot",
        ["RightFoot"] = "RightFoot"
    }

    local partName = PartMap[PartName]
    if not partName or not Character then return nil end

    local part = Character:FindFirstChild(partName)
    if part and part:IsA("BasePart") then
        return part.Position
    end

    return nil
end

-- Hàm kiểm tra tường chắn giữa camera và mục tiêu
local function IsWallBetween(CameraPos, TargetPos, IgnoreList)
    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Blacklist
    RayParams.FilterDescendantsInstances = IgnoreList

    local RayDirection = (TargetPos - CameraPos).Unit * (TargetPos - CameraPos).Magnitude
    local RayResult = Workspace:Raycast(CameraPos, RayDirection, RayParams)

    if RayResult then
        local HitInstance = RayResult.Instance
        -- Kiểm tra nếu raycast trúng vật thể trước khi tới mục tiêu
        if HitInstance and not HitInstance:IsDescendantOf(IgnoreList[1]) then
            return true
        end
    end

    return false
end

-- Hàm tính toán điểm ngắm chính xác dựa trên vòng tròn tâm xương
local function CalculateAimPoint(TargetPosition, CameraPosition)
    -- Tạo vector từ camera tới mục tiêu
    local DirectionToTarget = (TargetPosition - CameraPosition).Unit
    local DistanceToTarget = (TargetPosition - CameraPosition).Magnitude

    -- Tâm vòng tròn tại vị trí xương mục tiêu
    local CenterPoint = TargetPosition

    -- Bán kính vòng tròn dựa trên khoảng cách (giả lập vòng tròn quanh xương)
    local CircleRadius = 0.15 -- Bán kính nhỏ để tập trung chính xác vào xương

    -- Tạo điểm ngẫu nhiên trên vòng tròn trong không gian 2D vuông góc với hướng ngắm
    local RightVector = DirectionToTarget:Cross(Vector3.new(0, 1, 0)).Unit
    local UpVector = DirectionToTarget:Cross(RightVector).Unit

    local RandomAngle = math.random() * math.pi * 2
    local OffsetX = math.cos(RandomAngle) * CircleRadius
    local OffsetY = math.sin(RandomAngle) * CircleRadius

    -- Điểm ngắm cuối cùng nằm trên vòng tròn quanh tâm xương
    local AimPoint = CenterPoint + (RightVector * OffsetX) + (UpVector * OffsetY)

    return AimPoint
end

-- Hàm lấy mục tiêu tốt nhất trong FOV
local function GetBestTarget()
    local BestTarget = nil
    local BestDistance = math.huge
    local CameraPosition = Camera.CFrame.Position

    for _, Player in ipairs(Players:GetPlayers()) do
        -- Kiểm tra điều kiện mục tiêu
        if Player == LocalPlayer then continue end
        if Config.TeamCheck and Player.Team == LocalPlayer.Team then continue end

        local Character = Player.Character
        if not Character then continue end

        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        if not Humanoid or Humanoid.Health <= 0 then continue end

        -- Lấy vị trí phần xương đã chọn
        local TargetPartPos = GetSkeletalPosition(Character, Config.SelectedPart)
        if not TargetPartPos then continue end

        -- Kiểm tra xem mục tiêu có trong tầm nhìn không
        local ScreenPosition, OnScreen = Camera:WorldToViewportPoint(TargetPartPos)
        if not OnScreen then continue end

        local ScreenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local DistanceFromCenter = (Vector2.new(ScreenPosition.X, ScreenPosition.Y) - ScreenCenter).Magnitude

        -- Kiểm tra FOV
        if DistanceFromCenter > Config.FOVRadius then continue end

        -- Kiểm tra tường chắn nếu bật
        if Config.WallCheck then
            local IgnoreList = {Character, LocalPlayer.Character or nil}
            if IsWallBetween(CameraPosition, TargetPartPos, IgnoreList) then
                continue
            end
        end

        -- Kiểm tra khả năng nhìn thấy nếu bật
        if Config.VisibleCheck then
            local RayParams = RaycastParams.new()
            RayParams.FilterType = Enum.RaycastFilterType.Blacklist
            RayParams.FilterDescendantsInstances = {Character, LocalPlayer.Character or nil}
            local RayResult = Workspace:Raycast(CameraPosition, (TargetPartPos - CameraPosition).Unit * 1000, RayParams)
            if RayResult and not RayResult.Instance:IsDescendantOf(Character) then
                continue
            end
        end

        -- Cập nhật mục tiêu tốt nhất (gần tâm màn hình nhất)
        if DistanceFromCenter < BestDistance then
            BestDistance = DistanceFromCenter
            BestTarget = {
                Player = Player,
                Character = Character,
                Position = TargetPartPos,
                ScreenPos = ScreenPosition,
                Distance = DistanceFromCenter
            }
        end
    end

    return BestTarget
end

-- Hàm thực hiện silent aim (di chuyển camera tới mục tiêu và bắn)
local function PerformSilentAim(Target)
    if not Target or not Config.Enabled then return end

    local CameraCFrame = Camera.CFrame
    local CameraPosition = CameraCFrame.Position

    -- Tính điểm ngắm chính xác trên vòng tròn tâm xương
    local AimPoint = CalculateAimPoint(Target.Position, CameraPosition)

    -- Tính toán CFrame mới cho camera
    local LookAtCFrame = CFrame.new(CameraPosition, AimPoint)

    -- Áp dụng độ mượt (smoothness) với Tween hoặc Lerp
    local SmoothedCFrame = CameraCFrame:Lerp(LookAtCFrame, Config.Smoothness)

    -- Cập nhật camera ngay lập tức (silent aim)
    Camera.CFrame = SmoothedCFrame
end

-- Kết nối sự kiện vẽ để xử lý aimbot
local function OnRenderStepped()
    if not Config.Enabled then
        AimbotTarget = nil
        return
    end

    -- Tìm mục tiêu tốt nhất
    AimbotTarget = GetBestTarget()

    -- Nếu có mục tiêu và người dùng đang giữ chuột phải (ngắm) hoặc tự động
    if AimbotTarget then
        -- Mô phỏng ngắm và bắn
        task.spawn(function()
            PerformSilentAim(AimbotTarget)
            -- Mô phỏng bắn nếu vũ khí đang giữ
            local Tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if Tool and Tool:FindFirstChild("Handle") then
                -- Kích hoạt sự kiện bắn từ xa
                local RemoteEvent = Tool:FindFirstChild("RemoteEvent") or Tool:FindFirstChildOfClass("RemoteEvent")
                if RemoteEvent then
                    RemoteEvent:FireServer(AimbotTarget.Position)
                end
            end
        end)
    end
end

-- Hàm vẽ FOV Circle
local function DrawFOV()
    local FOVCircle = Drawing.new("Circle")
    FOVCircle.Visible = false
    FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    FOVCircle.Thickness = 1.5
    FOVCircle.Transparency = 0.7
    FOVCircle.Radius = Config.FOVRadius
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Filled = false

    RunService.RenderStepped:Connect(function()
        FOVCircle.Visible = Config.Enabled and Config.MenuVisible
        FOVCircle.Radius = Config.FOVRadius
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end)

    return FOVCircle
end

-- Hàm chính khởi tạo toàn bộ hệ thống
local function Initialize()
    -- Tạo giao diện
    CreateMenu()

    -- Kết nối vòng lặp chính
    RunService.RenderStepped:Connect(OnRenderStepped)

    -- Phím tắt bật/tắt menu
    UserInputService.InputBegan:Connect(function(Input, GameProcessed)
        if GameProcessed then return end
        if Input.KeyCode == Config.MenuKey then
            Config.MenuVisible = not Config.MenuVisible
            if GUIObjects.ScreenGui then
                GUIObjects.ScreenGui.Enabled = Config.MenuVisible
            end
        end
    end)

    -- Vẽ vòng tròn FOV
    DrawFOV()
end

-- Thực thi
pcall(function()
    Initialize()
end)

-- Thông báo thành công
task.wait(0.5)
print("✅ Silent Aim Skeletal System đã sẵn sàng!")
print("📋 Phím tắt menu: RightControl")
print("🎯 Chọn phần cơ thể để ghim chính xác")
print("🧱 Tự động phát hiện tường chắn")