--[[
    REMOTE SCANNER PRO - MOBILE FRIENDLY
    Kích thước nhỏ, kéo thả được, thu nhỏ, hỗ trợ cảm ứng.
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- ===== BIẾN TOÀN CỤC =====
local SelectedRemote = nil
local WebhookURL = ""
local RemoteList = {}
local isMinimized = false
local isDragging = false
local dragOffset = nil
local isResizing = false
local resizeOffset = nil
local uiElements = {}

-- ===== HÀM TẠO UI (KÍCH THƯỚC NHỎ) =====
local function createUI()
    local guiParent = LocalPlayer:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RemoteScannerPro"
    screenGui.Parent = guiParent
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Main Frame (kích thước nhỏ, có thể kéo thả)
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 340, 0, 440) -- Nhỏ hơn
    mainFrame.Position = UDim2.new(0.5, -170, 0.5, -220)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 27, 35)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui

    -- Bóng đổ
    local shadow = Instance.new("ImageLabel")
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://1316045217"
    shadow.ImageColor3 = Color3.fromRGB(0,0,0)
    shadow.ImageTransparency = 0.6
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10,10,10,10)
    shadow.Parent = mainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame

    -- ===== HEADER (Kéo thả) =====
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 35)
    header.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
    header.BackgroundTransparency = 0.3
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header

    -- Tiêu đề
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.6, 0, 1, 0)
    title.Position = UDim2.new(0.05, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🔍 Scanner"
    title.TextColor3 = Color3.fromRGB(230, 230, 245)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    -- Nút thu nhỏ
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 28, 0, 28)
    minBtn.Position = UDim2.new(0.9, -60, 0, 3)
    minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    minBtn.BackgroundTransparency = 0.5
    minBtn.BorderSizePixel = 0
    minBtn.Text = "─"
    minBtn.TextColor3 = Color3.fromRGB(255,255,255)
    minBtn.TextSize = 18
    minBtn.Font = Enum.Font.Gotham
    minBtn.Parent = header
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 6)
    minCorner.Parent = minBtn

    -- Nút đóng (thu nhỏ thành icon)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(0.9, -28, 0, 3)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    closeBtn.TextSize = 15
    closeBtn.Font = Enum.Font.Gotham
    closeBtn.Parent = header
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn

    -- ===== NỘI DUNG =====
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 1, -35)
    content.Position = UDim2.new(0, 0, 0, 35)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = content

    -- Hàng 1: quét + số lượng
    local row1 = Instance.new("Frame")
    row1.Size = UDim2.new(1, 0, 0, 30)
    row1.BackgroundTransparency = 1
    row1.Parent = content

    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(0.4, 0, 1, 0)
    scanBtn.Position = UDim2.new(0.05, 0, 0, 0)
    scanBtn.BackgroundColor3 = Color3.fromRGB(60, 130, 220)
    scanBtn.Text = "🔄 Quét"
    scanBtn.TextColor3 = Color3.fromRGB(255,255,255)
    scanBtn.TextSize = 13
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.Parent = row1
    local scanCorner = Instance.new("UICorner")
    scanCorner.CornerRadius = UDim.new(0, 6)
    scanCorner.Parent = scanBtn

    local countLabel = Instance.new("TextLabel")
    countLabel.Size = UDim2.new(0.4, 0, 1, 0)
    countLabel.Position = UDim2.new(0.55, 0, 0, 0)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = "0 remote"
    countLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    countLabel.TextSize = 12
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextXAlignment = Enum.TextXAlignment.Left
    countLabel.Parent = row1

    -- Hàng 2: danh sách remote + chi tiết (chia đôi)
    local row2 = Instance.new("Frame")
    row2.Size = UDim2.new(1, 0, 0, 150)
    row2.BackgroundTransparency = 1
    row2.Parent = content

    -- Danh sách
    local remoteListBox = Instance.new("ScrollingFrame")
    remoteListBox.Size = UDim2.new(0.45, -4, 1, 0)
    remoteListBox.Position = UDim2.new(0.02, 0, 0, 0)
    remoteListBox.BackgroundColor3 = Color3.fromRGB(35, 37, 47)
    remoteListBox.BackgroundTransparency = 0.5
    remoteListBox.BorderSizePixel = 0
    remoteListBox.Parent = row2
    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 6)
    listCorner.Parent = remoteListBox

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = remoteListBox

    -- Chi tiết
    local detailFrame = Instance.new("Frame")
    detailFrame.Size = UDim2.new(0.5, -4, 1, 0)
    detailFrame.Position = UDim2.new(0.48, 0, 0, 0)
    detailFrame.BackgroundColor3 = Color3.fromRGB(35, 37, 47)
    detailFrame.BackgroundTransparency = 0.5
    detailFrame.BorderSizePixel = 0
    detailFrame.Parent = row2
    local detailCorner = Instance.new("UICorner")
    detailCorner.CornerRadius = UDim.new(0, 6)
    detailCorner.Parent = detailFrame

    local detailLabel = Instance.new("TextLabel")
    detailLabel.Size = UDim2.new(1, 0, 0, 18)
    detailLabel.Position = UDim2.new(0, 0, 0, 2)
    detailLabel.BackgroundTransparency = 1
    detailLabel.Text = "Chọn remote"
    detailLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    detailLabel.TextSize = 11
    detailLabel.Font = Enum.Font.Gotham
    detailLabel.Parent = detailFrame

    local detailContent = Instance.new("TextBox")
    detailContent.Size = UDim2.new(0.9, 0, 0, 120)
    detailContent.Position = UDim2.new(0.05, 0, 0, 22)
    detailContent.BackgroundColor3 = Color3.fromRGB(25, 27, 35)
    detailContent.BackgroundTransparency = 0.5
    detailContent.TextColor3 = Color3.fromRGB(210, 210, 230)
    detailContent.Text = ""
    detailContent.TextWrapped = true
    detailContent.ReadOnly = true
    detailContent.Font = Enum.Font.Gotham
    detailContent.TextSize = 10
    detailContent.Parent = detailFrame
    local detailContentCorner = Instance.new("UICorner")
    detailContentCorner.CornerRadius = UDim.new(0, 4)
    detailContentCorner.Parent = detailContent

    -- Hàng 3: Webhook + payload
    local row3 = Instance.new("Frame")
    row3.Size = UDim2.new(1, 0, 0, 90)
    row3.BackgroundTransparency = 1
    row3.Parent = content

    -- Webhook
    local urlLabel = Instance.new("TextLabel")
    urlLabel.Size = UDim2.new(0.3, 0, 0, 18)
    urlLabel.Position = UDim2.new(0.02, 0, 0, 0)
    urlLabel.BackgroundTransparency = 1
    urlLabel.Text = "🔗 URL:"
    urlLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    urlLabel.TextSize = 12
    urlLabel.Font = Enum.Font.Gotham
    urlLabel.TextXAlignment = Enum.TextXAlignment.Left
    urlLabel.Parent = row3

    local urlBox = Instance.new("TextBox")
    urlBox.Size = UDim2.new(0.6, 0, 0, 22)
    urlBox.Position = UDim2.new(0.25, 0, 0, 0)
    urlBox.BackgroundColor3 = Color3.fromRGB(45, 47, 57)
    urlBox.TextColor3 = Color3.fromRGB(255,255,255)
    urlBox.Text = ""
    urlBox.PlaceholderText = "Webhook URL"
    urlBox.Font = Enum.Font.Gotham
    urlBox.TextSize = 11
    urlBox.Parent = row3
    local urlBoxCorner = Instance.new("UICorner")
    urlBoxCorner.CornerRadius = UDim.new(0, 4)
    urlBoxCorner.Parent = urlBox

    local setUrlBtn = Instance.new("TextButton")
    setUrlBtn.Size = UDim2.new(0.15, 0, 0, 22)
    setUrlBtn.Position = UDim2.new(0.86, 0, 0, 0)
    setUrlBtn.BackgroundColor3 = Color3.fromRGB(60, 130, 220)
    setUrlBtn.Text = "Set"
    setUrlBtn.TextColor3 = Color3.fromRGB(255,255,255)
    setUrlBtn.TextSize = 12
    setUrlBtn.Font = Enum.Font.GothamBold
    setUrlBtn.Parent = row3
    local setUrlCorner = Instance.new("UICorner")
    setUrlCorner.CornerRadius = UDim.new(0, 4)
    setUrlCorner.Parent = setUrlBtn

    -- Payload
    local payloadLabel = Instance.new("TextLabel")
    payloadLabel.Size = UDim2.new(0.3, 0, 0, 18)
    payloadLabel.Position = UDim2.new(0.02, 0, 0, 25)
    payloadLabel.BackgroundTransparency = 1
    payloadLabel.Text = "📦 Payload:"
    payloadLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    payloadLabel.TextSize = 12
    payloadLabel.Font = Enum.Font.Gotham
    payloadLabel.TextXAlignment = Enum.TextXAlignment.Left
    payloadLabel.Parent = row3

    local payloadBox = Instance.new("TextBox")
    payloadBox.Size = UDim2.new(0.95, 0, 0, 35)
    payloadBox.Position = UDim2.new(0.02, 0, 0, 43)
    payloadBox.BackgroundColor3 = Color3.fromRGB(45, 47, 57)
    payloadBox.TextColor3 = Color3.fromRGB(255,255,255)
    payloadBox.Text = ""
    payloadBox.PlaceholderText = '{"test":"data"} (bỏ trống auto)'
    payloadBox.Font = Enum.Font.Gotham
    payloadBox.TextSize = 10
    payloadBox.TextWrapped = true
    payloadBox.Parent = row3
    local payloadCorner = Instance.new("UICorner")
    payloadCorner.CornerRadius = UDim.new(0, 4)
    payloadCorner.Parent = payloadBox

    -- Hàng 4: nút test + log
    local row4 = Instance.new("Frame")
    row4.Size = UDim2.new(1, 0, 0, 55)
    row4.BackgroundTransparency = 1
    row4.Parent = content

    local testBtn = Instance.new("TextButton")
    testBtn.Size = UDim2.new(0.35, 0, 0, 28)
    testBtn.Position = UDim2.new(0.05, 0, 0, 0)
    testBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
    testBtn.Text = "📤 Test"
    testBtn.TextColor3 = Color3.fromRGB(255,255,255)
    testBtn.TextSize = 13
    testBtn.Font = Enum.Font.GothamBold
    testBtn.Parent = row4
    local testCorner = Instance.new("UICorner")
    testCorner.CornerRadius = UDim.new(0, 6)
    testCorner.Parent = testBtn

    local logBox = Instance.new("TextBox")
    logBox.Size = UDim2.new(0.55, 0, 0, 28)
    logBox.Position = UDim2.new(0.42, 0, 0, 0)
    logBox.BackgroundColor3 = Color3.fromRGB(25, 27, 35)
    logBox.BackgroundTransparency = 0.5
    logBox.TextColor3 = Color3.fromRGB(200, 200, 200)
    logBox.Text = "Ready"
    logBox.TextWrapped = true
    logBox.ReadOnly = true
    logBox.Font = Enum.Font.Gotham
    logBox.TextSize = 11
    logBox.Parent = row4
    local logCorner = Instance.new("UICorner")
    logCorner.CornerRadius = UDim.new(0, 4)
    logCorner.Parent = logBox

    -- Resize handle
    local resizeHandle = Instance.new("Frame")
    resizeHandle.Size = UDim2.new(0, 16, 0, 16)
    resizeHandle.Position = UDim2.new(1, -16, 1, -16)
    resizeHandle.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    resizeHandle.BackgroundTransparency = 0.5
    resizeHandle.BorderSizePixel = 0
    resizeHandle.Parent = mainFrame
    local resizeCorner = Instance.new("UICorner")
    resizeCorner.CornerRadius = UDim.new(0, 3)
    resizeCorner.Parent = resizeHandle

    -- Mini icon (thu nhỏ)
    local miniIcon = Instance.new("TextButton")
    miniIcon.Size = UDim2.new(0, 45, 0, 45)
    miniIcon.Position = UDim2.new(0, 10, 0, 10)
    miniIcon.BackgroundColor3 = Color3.fromRGB(30, 32, 42)
    miniIcon.BorderSizePixel = 0
    miniIcon.Text = "🔍"
    miniIcon.TextSize = 22
    miniIcon.TextColor3 = Color3.fromRGB(255,255,255)
    miniIcon.Visible = false
    miniIcon.Parent = screenGui
    local miniCorner = Instance.new("UICorner")
    miniCorner.CornerRadius = UDim.new(1, 0)
    miniCorner.Parent = miniIcon

    -- Lưu tham chiếu
    uiElements = {
        screenGui = screenGui,
        mainFrame = mainFrame,
        header = header,
        miniIcon = miniIcon,
        scanBtn = scanBtn,
        countLabel = countLabel,
        remoteListBox = remoteListBox,
        detailContent = detailContent,
        urlBox = urlBox,
        setUrlBtn = setUrlBtn,
        payloadBox = payloadBox,
        testBtn = testBtn,
        logBox = logBox,
        resizeHandle = resizeHandle
    }

    return uiElements
end

-- ===== CÁC HÀM CHỨC NĂNG (giữ nguyên) =====
local function populateRemoteList(ui, remotes)
    local listBox = ui.remoteListBox
    for _, child in ipairs(listBox:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, remote in ipairs(remotes) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 20)
        btn.BackgroundColor3 = Color3.fromRGB(50, 52, 65)
        btn.BackgroundTransparency = 0.3
        btn.Text = remote.Name
        btn.TextColor3 = Color3.fromRGB(210, 210, 230)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 10
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.TextTruncate = Enum.TextTruncate.AtEnd
        btn.BorderSizePixel = 0
        btn.Parent = listBox
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 3)
        btnCorner.Parent = btn

        local function select()
            SelectedRemote = remote
            local info = "📡 " .. remote:GetFullName() .. "\n🔹 " .. remote.ClassName .. "\n🔸 " .. tostring(remote.Parent)
            if remote:IsA("RemoteFunction") then
                info = info .. "\n⚡ Invoke"
            else
                info = info .. "\n⚡ Fire"
            end
            ui.detailContent.Text = info
        end
        btn.MouseButton1Click:Connect(select)
        btn.TouchTap:Connect(select)
    end
    ui.countLabel.Text = #remotes .. " remote"
end

local function scanRemotes()
    local remotes = {}
    local keywords = {"shop","stock","weather","seed","gear","crate","prop","inventory","buy","sell","harvest","plant","water","fertilize","upgrade","craft","trade","quest","reward","daily","spin","chest","open","claim","collect","interact","action","request","response","data","update","sync","load","save","get","set","invoke","call","fire","send","receive"}
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local lower = obj.Name:lower()
            local matched = false
            for _, kw in ipairs(keywords) do
                if lower:find(kw) then matched = true; break end
            end
            if matched then table.insert(remotes, obj) end
        end
    end
    -- Thêm remote trong ReplicatedStorage/Players
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local parent = obj.Parent
            if parent and (parent:IsA("ReplicatedStorage") or parent:IsA("Player") or parent:IsA("Workspace")) then
                local already = false
                for _, r in ipairs(remotes) do if r == obj then already = true; break end end
                if not already then table.insert(remotes, obj) end
            end
        end
    end
    return remotes
end

local function hookRemote(remote)
    if remote:IsA("RemoteEvent") then
        if remote._hooked then return end
        remote._hooked = true
        local old = remote.OnClientEvent
        hookfunction(remote.OnClientEvent, function(...)
            local args = {...}
            print("📨 [HOOK] " .. remote:GetFullName() .. " nhận:", unpack(args))
            if old then old(...) end
        end)
    end
end

local function sendWebhook(url, embed)
    if not url or url == "" then return false, "Missing URL" end
    local payload = HttpService:JSONEncode({ embeds = { embed } })
    local success, err = pcall(function()
        local requestFunc = syn and syn.request or http and http.request or request or http_request
        if requestFunc then
            local resp = requestFunc({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload
            })
            if resp and resp.StatusCode ~= 200 and resp.StatusCode ~= 204 then
                error("Status: " .. tostring(resp.StatusCode))
            end
        else
            HttpService:PostAsync(url, payload)
        end
    end)
    return success, err
end

local function handleTestSend(ui)
    if not SelectedRemote then ui.logBox.Text = "❌ Chưa chọn remote!"; return end
    if not WebhookURL or WebhookURL == "" then ui.logBox.Text = "❌ Chưa set webhook!"; return end

    local payloadText = ui.payloadBox.Text
    local dataToSend = nil

    if payloadText == "" then
        ui.logBox.Text = "⏳ Lấy data từ remote..."
        if SelectedRemote:IsA("RemoteFunction") then
            local success, result = pcall(function() return SelectedRemote:InvokeServer() end)
            if success then
                dataToSend = result
            else
                local success2, result2 = pcall(function() return SelectedRemote:InvokeServer({}) end)
                if success2 then
                    dataToSend = result2
                else
                    ui.logBox.Text = "❌ Invoke thất bại"
                    return
                end
            end
        else
            dataToSend = "RemoteEvent - không lấy được data."
        end
    else
        local success, parsed = pcall(HttpService.JSONDecode, HttpService, payloadText)
        if success then
            dataToSend = parsed
        else
            ui.logBox.Text = "❌ JSON không hợp lệ"
            return
        end
    end

    local embed = {
        title = "📡 " .. SelectedRemote.Name,
        description = "Dữ liệu từ remote",
        color = 3447003,
        fields = {},
        timestamp = DateTime.now():ToIsoDate(),
        footer = { text = "Remote Scanner" }
    }

    if type(dataToSend) == "table" then
        for k, v in pairs(dataToSend) do
            if type(v) ~= "function" then
                table.insert(embed.fields, {
                    name = tostring(k),
                    value = type(v) == "table" and HttpService:JSONEncode(v) or tostring(v),
                    inline = false
                })
            end
        end
        if #embed.fields == 0 then
            table.insert(embed.fields, { name = "Data", value = HttpService:JSONEncode(dataToSend), inline = false })
        end
    else
        embed.description = tostring(dataToSend)
    end

    ui.logBox.Text = "⏳ Đang gửi..."
    local ok, err = sendWebhook(WebhookURL, embed)
    if ok then
        ui.logBox.Text = "✅ Gửi thành công!"
    else
        ui.logBox.Text = "❌ Gửi thất bại: " .. tostring(err)
    end
end

local function toggleMinimize(ui, minimize)
    local main = ui.mainFrame
    local mini = ui.miniIcon
    if minimize then
        isMinimized = true
        local tween1 = TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0,0,0,0),
            Position = UDim2.new(0.5,0,0.5,0)
        })
        tween1:Play()
        tween1.Completed:Connect(function()
            main.Visible = false
            mini.Visible = true
            mini.Size = UDim2.new(0,0,0,0)
            mini.Position = UDim2.new(0,10,0,10)
            mini.Visible = true
            local tween2 = TweenService:Create(mini, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0,45,0,45)
            })
            tween2:Play()
        end)
    else
        isMinimized = false
        mini.Visible = false
        main.Visible = true
        main.Size = UDim2.new(0,0,0,0)
        main.Position = UDim2.new(0.5,0,0.5,0)
        local tween = TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0,340,0,440),
            Position = UDim2.new(0.5,-170,0.5,-220)
        })
        tween:Play()
    end
end

-- ===== KHỞI TẠO UI VÀ SỰ KIỆN =====
local ui = createUI()
local mainFrame = ui.mainFrame
local header = ui.header

local function scanAndPopulate()
    RemoteList = scanRemotes()
    populateRemoteList(ui, RemoteList)
    for _, r in ipairs(RemoteList) do
        if r:IsA("RemoteEvent") then hookRemote(r) end
    end
    ui.logBox.Text = "📡 Tìm thấy " .. #RemoteList .. " remote"
end
scanAndPopulate()

ui.scanBtn.MouseButton1Click:Connect(scanAndPopulate)
ui.scanBtn.TouchTap:Connect(scanAndPopulate)

ui.setUrlBtn.MouseButton1Click:Connect(function()
    local url = ui.urlBox.Text
    if url and url ~= "" then
        WebhookURL = url
        ui.logBox.Text = "✅ Webhook set"
    else
        ui.logBox.Text = "❌ URL rỗng"
    end
end)
ui.setUrlBtn.TouchTap:Connect(function()
    local url = ui.urlBox.Text
    if url and url ~= "" then
        WebhookURL = url
        ui.logBox.Text = "✅ Webhook set"
    else
        ui.logBox.Text = "❌ URL rỗng"
    end
end)

ui.testBtn.MouseButton1Click:Connect(function() handleTestSend(ui) end)
ui.testBtn.TouchTap:Connect(function() handleTestSend(ui) end)

ui.header:FindFirstChild("minBtn").MouseButton1Click:Connect(function() toggleMinimize(ui, true) end)
ui.header:FindFirstChild("minBtn").TouchTap:Connect(function() toggleMinimize(ui, true) end)

ui.header:FindFirstChild("closeBtn").MouseButton1Click:Connect(function() toggleMinimize(ui, true) end)
ui.header:FindFirstChild("closeBtn").TouchTap:Connect(function() toggleMinimize(ui, true) end)

ui.miniIcon.MouseButton1Click:Connect(function() toggleMinimize(ui, false) end)
ui.miniIcon.TouchTap:Connect(function() toggleMinimize(ui, false) end)

-- ===== KÉO THẢ =====
local function startDrag(input)
    if isMinimized then return end
    isDragging = true
    local pos = (input.UserInputType == Enum.UserInputType.Touch) and input.Position or input.Position
    dragOffset = Vector2.new(pos.X - mainFrame.AbsolutePosition.X, pos.Y - mainFrame.AbsolutePosition.Y)
end

local function updateDrag(input)
    if not isDragging or isMinimized then return end
    local pos = (input.UserInputType == Enum.UserInputType.Touch) and input.Position or input.Position
    local newX = pos.X - dragOffset.X
    local newY = pos.Y - dragOffset.Y
    mainFrame.Position = UDim2.new(0, newX, 0, newY)
end

local function stopDrag()
    isDragging = false
end

-- Mouse
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then startDrag(input) end
end)
header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then updateDrag(input) end
end)
header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then stopDrag() end
end)

-- Touch
header.TouchBegan:Connect(function(touch) startDrag(touch) end)
header.TouchMoved:Connect(function(touch) updateDrag(touch) end)
header.TouchEnded:Connect(function() stopDrag() end)

-- ===== RESIZE =====
local resizeHandle = ui.resizeHandle
local function startResize(input)
    if isMinimized then return end
    isResizing = true
    local pos = (input.UserInputType == Enum.UserInputType.Touch) and input.Position or input.Position
    resizeOffset = Vector2.new(mainFrame.AbsoluteSize.X - pos.X, mainFrame.AbsoluteSize.Y - pos.Y)
end

local function updateResize(input)
    if not isResizing or isMinimized then return end
    local pos = (input.UserInputType == Enum.UserInputType.Touch) and input.Position or input.Position
    local newWidth = pos.X + resizeOffset.X - mainFrame.AbsolutePosition.X
    local newHeight = pos.Y + resizeOffset.Y - mainFrame.AbsolutePosition.Y
    if newWidth < 280 then newWidth = 280 end
    if newHeight < 350 then newHeight = 350 end
    mainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
end

local function stopResize()
    isResizing = false
end

-- Mouse
resizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then startResize(input) end
end)
resizeHandle.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then updateResize(input) end
end)
resizeHandle.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then stopResize() end
end)

-- Touch
resizeHandle.TouchBegan:Connect(function(touch) startResize(touch) end)
resizeHandle.TouchMoved:Connect(function(touch) updateResize(touch) end)
resizeHandle.TouchEnded:Connect(function() stopResize() end)

print("✅ Remote Scanner Pro (Mobile) đã sẵn sàng!")
