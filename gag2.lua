--[[
    REMOTE SCANNER + WEBHOOK TESTER (GAG2)
    - Quét tất cả RemoteEvent / RemoteFunction trong game
    - Hiển thị danh sách remote tìm thấy
    - Cho phép chọn remote để hook / invoke
    - Nhập webhook và gửi dữ liệu test
    - Hỗ trợ getgc, hookfunction, syn.request
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ===== BIẾN TOÀN CỤC =====
local SelectedRemote = nil
local WebhookURL = ""
local RemoteList = {}

-- ===== HÀM QUÉT REMOTE =====
local function scanRemotes()
    local remotes = {}
    local keywords = {"shop", "stock", "weather", "seed", "gear", "crate", "prop", "inventory", "buy", "sell", "harvest", "plant", "water", "fertilize", "upgrade", "craft", "trade", "quest", "reward", "daily", "spin", "chest", "open", "claim", "collect", "interact", "action", "request", "response", "data", "update", "sync", "load", "save", "get", "set", "invoke", "call", "fire", "send", "receive"}
    
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local lower = obj.Name:lower()
            local matched = false
            for _, kw in ipairs(keywords) do
                if lower:find(kw) then
                    matched = true
                    break
                end
            end
            if matched then
                table.insert(remotes, obj)
            end
        end
    end
    
    -- Thêm cả remote không match keyword nhưng nằm trong ReplicatedStorage/Players
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local parent = obj.Parent
            if parent and (parent:IsA("ReplicatedStorage") or parent:IsA("Player") or parent:IsA("Workspace")) then
                local already = false
                for _, r in ipairs(remotes) do
                    if r == obj then already = true break end
                end
                if not already then
                    table.insert(remotes, obj)
                end
            end
        end
    end
    
    return remotes
end

-- ===== TẠO UI =====
local function createUI()
    local guiParent = LocalPlayer:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RemoteScannerUI"
    screenGui.Parent = guiParent

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 480, 0, 560)
    mainFrame.Position = UDim2.new(0.5, -240, 0.5, -280)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    -- Tiêu đề
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "🔍 Remote Scanner + Webhook Tester"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame

    -- Nút quét
    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(0.4, 0, 0, 30)
    scanBtn.Position = UDim2.new(0.05, 0, 0, 40)
    scanBtn.BackgroundColor3 = Color3.fromRGB(60,120,200)
    scanBtn.Text = "🔄 Quét lại Remote"
    scanBtn.TextColor3 = Color3.fromRGB(255,255,255)
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.TextSize = 14
    scanBtn.Parent = mainFrame

    -- Danh sách remote
    local remoteListBox = Instance.new("ScrollingFrame")
    remoteListBox.Size = UDim2.new(0.45, 0, 0, 300)
    remoteListBox.Position = UDim2.new(0.05, 0, 0, 80)
    remoteListBox.BackgroundColor3 = Color3.fromRGB(40,40,50)
    remoteListBox.BorderSizePixel = 0
    remoteListBox.Parent = mainFrame

    local remoteListLayout = Instance.new("UIListLayout")
    remoteListLayout.Parent = remoteListBox
    remoteListLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Khung thông tin chi tiết remote
    local detailFrame = Instance.new("Frame")
    detailFrame.Size = UDim2.new(0.42, 0, 0, 300)
    detailFrame.Position = UDim2.new(0.53, 0, 0, 80)
    detailFrame.BackgroundColor3 = Color3.fromRGB(40,40,50)
    detailFrame.BorderSizePixel = 0
    detailFrame.Parent = mainFrame

    local detailLabel = Instance.new("TextLabel")
    detailLabel.Size = UDim2.new(1, 0, 0, 20)
    detailLabel.Position = UDim2.new(0, 0, 0, 5)
    detailLabel.BackgroundTransparency = 1
    detailLabel.Text = "Chọn remote để xem chi tiết"
    detailLabel.TextColor3 = Color3.fromRGB(200,200,200)
    detailLabel.TextSize = 13
    detailLabel.Font = Enum.Font.Gotham
    detailLabel.Parent = detailFrame

    local detailContent = Instance.new("TextBox")
    detailContent.Size = UDim2.new(0.9, 0, 0, 250)
    detailContent.Position = UDim2.new(0.05, 0, 0, 30)
    detailContent.BackgroundColor3 = Color3.fromRGB(30,30,40)
    detailContent.TextColor3 = Color3.fromRGB(220,220,220)
    detailContent.Text = ""
    detailContent.TextWrapped = true
    detailContent.ReadOnly = true
    detailContent.Font = Enum.Font.Gotham
    detailContent.TextSize = 12
    detailContent.Parent = detailFrame

    -- Webhook URL
    local urlLabel = Instance.new("TextLabel")
    urlLabel.Size = UDim2.new(0.4, 0, 0, 20)
    urlLabel.Position = UDim2.new(0.05, 0, 0, 400)
    urlLabel.BackgroundTransparency = 1
    urlLabel.Text = "🔗 Webhook URL:"
    urlLabel.TextColor3 = Color3.fromRGB(200,200,200)
    urlLabel.TextSize = 13
    urlLabel.TextXAlignment = Enum.TextXAlignment.Left
    urlLabel.Parent = mainFrame

    local urlBox = Instance.new("TextBox")
    urlBox.Size = UDim2.new(0.85, 0, 0, 25)
    urlBox.Position = UDim2.new(0.05, 0, 0, 420)
    urlBox.BackgroundColor3 = Color3.fromRGB(50,50,60)
    urlBox.TextColor3 = Color3.fromRGB(255,255,255)
    urlBox.Text = ""
    urlBox.PlaceholderText = "Dán webhook URL..."
    urlBox.Font = Enum.Font.Gotham
    urlBox.TextSize = 13
    urlBox.Parent = mainFrame

    local setUrlBtn = Instance.new("TextButton")
    setUrlBtn.Size = UDim2.new(0.85, 0, 0, 25)
    setUrlBtn.Position = UDim2.new(0.05, 0, 0, 450)
    setUrlBtn.BackgroundColor3 = Color3.fromRGB(60,120,200)
    setUrlBtn.Text = "✅ Set Webhook"
    setUrlBtn.TextColor3 = Color3.fromRGB(255,255,255)
    setUrlBtn.Font = Enum.Font.GothamBold
    setUrlBtn.TextSize = 13
    setUrlBtn.Parent = mainFrame

    -- Payload tùy chỉnh
    local payloadLabel = Instance.new("TextLabel")
    payloadLabel.Size = UDim2.new(0.4, 0, 0, 20)
    payloadLabel.Position = UDim2.new(0.05, 0, 0, 485)
    payloadLabel.BackgroundTransparency = 1
    payloadLabel.Text = "📦 Payload (json):"
    payloadLabel.TextColor3 = Color3.fromRGB(200,200,200)
    payloadLabel.TextSize = 13
    payloadLabel.TextXAlignment = Enum.TextXAlignment.Left
    payloadLabel.Parent = mainFrame

    local payloadBox = Instance.new("TextBox")
    payloadBox.Size = UDim2.new(0.85, 0, 0, 40)
    payloadBox.Position = UDim2.new(0.05, 0, 0, 505)
    payloadBox.BackgroundColor3 = Color3.fromRGB(50,50,60)
    payloadBox.TextColor3 = Color3.fromRGB(255,255,255)
    payloadBox.Text = ""
    payloadBox.PlaceholderText = '{"test": "data"} (bỏ trống để tự động lấy dữ liệu từ remote)'
    payloadBox.Font = Enum.Font.Gotham
    payloadBox.TextSize = 12
    payloadBox.TextWrapped = true
    payloadBox.Parent = mainFrame

    -- Nút gửi test
    local testBtn = Instance.new("TextButton")
    testBtn.Size = UDim2.new(0.4, 0, 0, 30)
    testBtn.Position = UDim2.new(0.05, 0, 0, 550)
    testBtn.BackgroundColor3 = Color3.fromRGB(200,80,80)
    testBtn.Text = "📤 Test Send Webhook"
    testBtn.TextColor3 = Color3.fromRGB(255,255,255)
    testBtn.Font = Enum.Font.GothamBold
    testBtn.TextSize = 14
    testBtn.Parent = mainFrame

    -- Log
    local logBox = Instance.new("TextBox")
    logBox.Size = UDim2.new(0.85, 0, 0, 30)
    logBox.Position = UDim2.new(0.05, 0, 0, 585)
    logBox.BackgroundColor3 = Color3.fromRGB(20,20,30)
    logBox.TextColor3 = Color3.fromRGB(200,200,200)
    logBox.Text = ""
    logBox.ReadOnly = true
    logBox.Font = Enum.Font.Gotham
    logBox.TextSize = 12
    logBox.Parent = mainFrame

    -- Nút đóng
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0.08, 0, 0, 20)
    closeBtn.Position = UDim2.new(0.92, -20, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    closeBtn.Font = Enum.Font.Gotham
    closeBtn.TextSize = 14
    closeBtn.Parent = mainFrame
    closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

    return {
        screenGui = screenGui,
        scanBtn = scanBtn,
        remoteListBox = remoteListBox,
        detailContent = detailContent,
        urlBox = urlBox,
        setUrlBtn = setUrlBtn,
        payloadBox = payloadBox,
        testBtn = testBtn,
        logBox = logBox
    }
end

-- ===== HIỂN THỊ DANH SÁCH REMOTE =====
local function populateRemoteList(ui, remotes)
    -- Xóa các button cũ
    for _, child in ipairs(ui.remoteListBox:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    for _, remote in ipairs(remotes) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 25)
        btn.BackgroundColor3 = Color3.fromRGB(50,50,60)
        btn.Text = remote:GetFullName() .. " [" .. remote.ClassName .. "]"
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = ui.remoteListBox
        
        btn.MouseButton1Click:Connect(function()
            SelectedRemote = remote
            local info = "📡 " .. remote:GetFullName() .. "\n🔹 Class: " .. remote.ClassName .. "\n🔸 Parent: " .. tostring(remote.Parent)
            if remote:IsA("RemoteFunction") then
                info = info .. "\n⚡ (RemoteFunction - có thể InvokeServer)"
            else
                info = info .. "\n⚡ (RemoteEvent - có thể FireServer)"
            end
            -- Thử lấy vài property
            local success, res = pcall(function() return remote:GetFullName() end)
            info = info .. "\n\n💡 Click 'Test Send' để gửi dữ liệu từ remote này (nếu có payload tự động)."
            ui.detailContent.Text = info
        end)
    end
end

-- ===== GỬI WEBHOOK =====
local function sendWebhook(url, embed)
    if not url or url == "" then
        warn("⚠️ Webhook URL chưa set")
        return false
    end
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
                warn("❌ Status: " .. tostring(resp.StatusCode))
            end
        else
            HttpService:PostAsync(url, payload)
        end
    end)
    if not success then
        warn("❌ Lỗi gửi: " .. tostring(err))
        return false
    end
    return true
end

-- ===== XỬ LÝ TEST SEND =====
local function handleTestSend(ui)
    if not SelectedRemote then
        ui.logBox.Text = "❌ Chưa chọn remote!"
        return
    end
    if not WebhookURL or WebhookURL == "" then
        ui.logBox.Text = "❌ Chưa set webhook URL!"
        return
    end
    
    local payloadText = ui.payloadBox.Text
    local dataToSend = nil
    
    -- Nếu payload trống, thử lấy dữ liệu từ remote
    if payloadText == "" or payloadText == "" then
        ui.logBox.Text = "⏳ Đang lấy dữ liệu từ remote..."
        -- Thử invoke (nếu là RemoteFunction)
        if SelectedRemote:IsA("RemoteFunction") then
            local success, result = pcall(function()
                return SelectedRemote:InvokeServer()
            end)
            if success then
                dataToSend = result
            else
                -- Thử với tham số rỗng
                local success2, result2 = pcall(function()
                    return SelectedRemote:InvokeServer({})
                end)
                if success2 then
                    dataToSend = result2
                else
                    ui.logBox.Text = "❌ Không thể invoke remote: " .. tostring(err)
                    return
                end
            end
        else
            -- RemoteEvent: không thể lấy dữ liệu trực tiếp, ta sẽ gửi một thông báo đơn giản
            dataToSend = "RemoteEvent - chỉ có thể FireServer, không lấy được dữ liệu."
        end
    else
        -- Parse payload nhập vào
        local success, parsed = pcall(HttpService.JSONDecode, HttpService, payloadText)
        if success then
            dataToSend = parsed
        else
            ui.logBox.Text = "❌ Payload JSON không hợp lệ. Sử dụng dạng object."
            return
        end
    end
    
    -- Tạo embed từ dữ liệu
    local embed = {
        title = "📡 Remote Test: " .. SelectedRemote.Name,
        description = "Dữ liệu từ remote (hoặc payload)",
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
            table.insert(embed.fields, { name = "Dữ liệu", value = HttpService:JSONEncode(dataToSend), inline = false })
        end
    else
        embed.description = tostring(dataToSend)
    end
    
    -- Gửi
    ui.logBox.Text = "⏳ Đang gửi webhook..."
    local ok = sendWebhook(WebhookURL, embed)
    if ok then
        ui.logBox.Text = "✅ Đã gửi thành công!"
    else
        ui.logBox.Text = "❌ Gửi thất bại!"
    end
end

-- ===== HOOK REMOTE (TÙY CHỌN) =====
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

-- ===== QUÉT VÀ HIỂN THỊ =====
local function scanAndPopulate(ui)
    RemoteList = scanRemotes()
    populateRemoteList(ui, RemoteList)
    ui.logBox.Text = "📡 Đã tìm thấy " .. #RemoteList .. " remote liên quan"
    
    -- Hook tất cả RemoteEvent để bắt dữ liệu
    for _, r in ipairs(RemoteList) do
        if r:IsA("RemoteEvent") then
            hookRemote(r)
        end
    end
    print("🔗 Đã hook " .. #RemoteList .. " remote (chỉ RemoteEvent)")
end

-- ===== KHỞI TẠO =====
local ui = createUI()

-- Sự kiện nút quét
ui.scanBtn.MouseButton1Click:Connect(function()
    scanAndPopulate(ui)
end)

-- Set webhook
ui.setUrlBtn.MouseButton1Click:Connect(function()
    local url = ui.urlBox.Text
    if url and url ~= "" then
        WebhookURL = url
        ui.logBox.Text = "✅ Webhook đã cập nhật"
    else
        ui.logBox.Text = "❌ URL không hợp lệ"
    end
end)

-- Test send
ui.testBtn.MouseButton1Click:Connect(function()
    handleTestSend(ui)
end)

-- Quét lần đầu
task.wait(0.5)
scanAndPopulate(ui)

print("🚀 Remote Scanner đã sẵn sàng. Hãy chọn remote và test gửi!")
