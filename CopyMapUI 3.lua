--[[
    COPY MAP UI  |  BY MHMMDALVI
    Hanya GUI (tampilan + interaksi). Logika copy/import dipasang lewat:
        UI.OnCopy   = function(services, fileName) ... end
        UI.OnImport = function(path, opts) ... end   -- sudah terpasang (RBXL biner + isi script dari .scripts.json)
        UI.OnScan   = function() ... end   -- opsional
    Update progress dari logika kamu:
        UI.Begin()
        UI.SetProgress(persen, "judul status", "keterangan")
        UI.SetProgress(100, "Selesai", "File tersimpan")
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

---------------------------------------------------------------------
-- THEME
---------------------------------------------------------------------
local T = {
    Window   = Color3.fromRGB(247, 241, 228),
    Panel    = Color3.fromRGB(241, 233, 216),
    Card     = Color3.fromRGB(252, 247, 237),
    Field    = Color3.fromRGB(236, 228, 210),
    Line     = Color3.fromRGB(214, 203, 178),
    Accent   = Color3.fromRGB(255, 184, 28),
    AccentLn = Color3.fromRGB(240, 170, 40),
    Text     = Color3.fromRGB(28, 24, 18),
    Muted    = Color3.fromRGB(135, 125, 108),
    Title    = Color3.fromRGB(176, 92, 200),
    Ok       = Color3.fromRGB(80, 170, 100),
    Bad      = Color3.fromRGB(210, 80, 70),
}

local SERVICES = {
    "Workspace", "Players", "Lighting", "MaterialService",
    "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage",
    "StarterGui", "StarterPack", "StarterPlayer", "Teams",
    "SoundService", "Chat", "TextChatService", "LocalizationService",
}

---------------------------------------------------------------------
-- HELPER
---------------------------------------------------------------------
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end

local function corner(p, r)
    return new("UICorner", {CornerRadius = UDim.new(0, r)}, p)
end

local function stroke(p, color, thick, trans)
    return new("UIStroke", {
        Color = color, Thickness = thick or 1, Transparency = trans or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, p)
end

local function label(parent, props)
    local d = {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = "",
    }
    for k, v in pairs(props) do d[k] = v end
    return new("TextLabel", d, parent)
end

local function button(parent, props)
    local d = {
        AutoButtonColor = false, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = T.Text,
        BackgroundColor3 = T.Card, Text = "",
    }
    for k, v in pairs(props) do d[k] = v end
    local b = new("TextButton", d, parent)
    local base = b.BackgroundColor3
    b.MouseEnter:Connect(function()
        if b:GetAttribute("NoHover") then return end
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.35)}):Play()
    end)
    b.MouseLeave:Connect(function()
        if b:GetAttribute("NoHover") then return end
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = base}):Play()
    end)
    return b
end

local function fmt(n)
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
    return (out:gsub("^%.", ""))
end

local function mmss(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%02d:%02d", sec // 60, sec % 60)
end

---------------------------------------------------------------------
-- PARENT GUI
---------------------------------------------------------------------
local ok, host = pcall(function()
    return (gethui and gethui()) or game:GetService("CoreGui")
end)
if not ok or not host then
    host = Players.LocalPlayer:WaitForChild("PlayerGui")
end
local old = host:FindFirstChild("CopyMapUI")
if old then old:Destroy() end

local UI = {}
UI.Cleanups = {}
local gui = new("ScreenGui", {
    Name = "CopyMapUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, host)

local WIN_W, WIN_H = 760, 440
local main = new("CanvasGroup", {
    Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(WIN_W, WIN_H),
    BackgroundColor3 = T.Window, BorderSizePixel = 0,
}, gui)
corner(main, 18)
stroke(main, T.Line, 1.5)

local scale = new("UIScale", {}, main)
local isOpen, animating, fitK = true, false, 1
local function fitScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    fitK = math.min(1, (vp.X * 0.94) / WIN_W, (vp.Y * 0.94) / WIN_H)
    if isOpen and not animating then scale.Scale = fitK end
end
fitScale()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)
end

---------------------------------------------------------------------
-- DRAG
---------------------------------------------------------------------
local function makeDraggable(handle)
    local dragging, startInput, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startInput, startPos = true, i.Position, main.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = (i.Position - startInput) / scale.Scale
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

---------------------------------------------------------------------
-- HEADER
---------------------------------------------------------------------
local header = new("Frame", {
    Name = "Header", Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1,
}, main)
makeDraggable(header)

local logo = new("Frame", {
    Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(26, 22),
    BackgroundColor3 = T.Accent, Rotation = 45, BorderSizePixel = 0,
}, header)
corner(logo, 3)

label(header, {
    Text = "COPY MAP BY MHMMDALVI", Font = Enum.Font.GothamBold, TextSize = 11,
    TextColor3 = T.Title, Position = UDim2.fromOffset(48, 14), Size = UDim2.fromOffset(240, 28),
})

-- tab pill
local pill = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
    Size = UDim2.fromOffset(300, 34), BackgroundColor3 = T.Field, BorderSizePixel = 0,
}, header)
corner(pill, 17)
stroke(pill, T.Line, 1)

local tabCopy = button(pill, {
    Text = "COPY MAP", Size = UDim2.new(1 / 3, -4, 1, -6), Position = UDim2.fromOffset(3, 3),
    BackgroundColor3 = T.Accent, TextSize = 9,
})
corner(tabCopy, 14)
local tabImport = button(pill, {
    Text = "IMPORT MAP", Size = UDim2.new(1 / 3, -4, 1, -6), Position = UDim2.new(1 / 3, 1, 0, 3),
    BackgroundColor3 = T.Field, TextColor3 = T.Muted, TextSize = 9,
})
corner(tabImport, 14)
local tabReplacer = button(pill, {
    Text = "REPLACER", Size = UDim2.new(1 / 3, -4, 1, -6), Position = UDim2.new(2 / 3, 1, 0, 3),
    BackgroundColor3 = T.Field, TextColor3 = T.Muted, TextSize = 9,
})
corner(tabReplacer, 14)

-- tombol kanan
local function roundIcon(text, x)
    local b = button(header, {
        Text = text, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, x, 0, 9),
        BackgroundColor3 = T.Panel, TextSize = 16, Font = Enum.Font.GothamBold,
    })
    corner(b, 20)
    stroke(b, T.Line, 1)
    return b
end
local btnClose    = roundIcon("X", -52)
local btnMove     = roundIcon("+", -100)   -- juga bisa dipakai untuk drag
local btnSettings = roundIcon("-", -148)   -- kecilkan (animasi)
btnClose.TextSize = 14
makeDraggable(btnMove)

---------------------------------------------------------------------
-- BUKA / TUTUP GUI (BERANIMASI) + TOMBOL MELAYANG
--   *  = kecilkan (animasi) -> tombol melayang CM muncul, tap untuk buka
--   X  = tutup & keluar (animasi)
--   RightCtrl = buka/tutup cepat (PC)
---------------------------------------------------------------------
local OPEN_FROM = 0.84
local animToken = 0
local uiConns = {}

local fab = new("TextButton", {
    Name = "Fab", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 44, 0.5, 0),
    Size = UDim2.fromOffset(0, 0), BackgroundColor3 = T.Accent, Text = "CM", TextColor3 = T.Text,
    Font = Enum.Font.GothamBlack, TextSize = 15, AutoButtonColor = false, BorderSizePixel = 0,
    Visible = false, ZIndex = 50,
}, gui)
corner(fab, 30)
stroke(fab, T.AccentLn, 2)

local fabTip = label(fab, {
    Position = UDim2.new(1, 10, 0.5, -15), AutomaticSize = Enum.AutomaticSize.X,
    Size = UDim2.new(0, 0, 0, 30), BackgroundTransparency = 0, BackgroundColor3 = T.Window,
    Text = "", TextSize = 10, Font = Enum.Font.GothamBold, ZIndex = 51, Visible = false,
    TextTruncate = Enum.TextTruncate.AtEnd,
})
corner(fabTip, 15)
stroke(fabTip, T.AccentLn, 1)
new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}, fabTip)
new("UISizeConstraint", {MaxSize = Vector2.new(420, 30)}, fabTip)

local fabNoteId = 0
function UI.FabNote(text, secs)
    if not fab.Visible then return end
    fabNoteId += 1
    local id = fabNoteId
    fabTip.Text = text
    fabTip.Visible = true
    task.delay(secs or 3, function()
        if id == fabNoteId then fabTip.Visible = false end
    end)
end

local fabMoved = false
do
    local dragging, startIn, startPos = false, nil, nil
    fab.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, fabMoved = true, false
            startIn, startPos = i.Position, fab.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    table.insert(uiConns, UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startIn
            if d.Magnitude > 8 then fabMoved = true end
            if fabMoved then
                fab.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end))
end

local function showFab()
    fab.Visible = true
    fab.Size = UDim2.fromOffset(0, 0)
    TweenService:Create(fab, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.fromOffset(56, 56)}):Play()
end
local function hideFab()
    if not fab.Visible then return end
    fabTip.Visible = false
    local t = TweenService:Create(fab, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Size = UDim2.fromOffset(0, 0)})
    t:Play()
    task.delay(0.2, function()
        if isOpen then fab.Visible = false end
    end)
end

local function openWindow()
    animToken += 1
    local my = animToken
    isOpen = true
    animating = true
    hideFab()
    main.Visible = true
    scale.Scale = fitK * OPEN_FROM
    main.GroupTransparency = 1
    TweenService:Create(scale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = fitK}):Play()
    TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
    task.delay(0.42, function()
        if animToken == my then
            animating = false
            scale.Scale = fitK
        end
    end)
end

local function closeWindow(destroyAfter)
    animToken += 1
    local my = animToken
    isOpen = false
    animating = true
    TweenService:Create(scale, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = fitK * OPEN_FROM}):Play()
    TweenService:Create(main, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1}):Play()
    task.delay(0.26, function()
        if animToken ~= my then return end
        main.Visible = false
        if destroyAfter then gui:Destroy() else showFab() end
    end)
end

function UI.Minimize() if isOpen then closeWindow(false) end end
function UI.Restore()
    if UI.OnRestore then pcall(UI.OnRestore) end
    if not isOpen then openWindow() end
end
function UI.IsOpen() return isOpen end
function UI.OverGui(p)
    if fab.Visible then
        local a, s = fab.AbsolutePosition, fab.AbsoluteSize
        if p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y then return true end
    end
    if isOpen and main.Visible then
        local a, s = main.AbsolutePosition, main.AbsoluteSize
        if p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y then return true end
    end
    return false
end

fab.MouseButton1Click:Connect(function()
    if fabMoved then return end
    UI.Restore()
end)
btnClose.MouseButton1Click:Connect(function() closeWindow(true) end)
btnSettings.MouseButton1Click:Connect(function() closeWindow(false) end)

table.insert(uiConns, UserInputService.InputBegan:Connect(function(i, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if i.KeyCode == Enum.KeyCode.RightControl then
        if isOpen then closeWindow(false) else UI.Restore() end
    end
end))

gui.Destroying:Connect(function()
    for _, c in ipairs(uiConns) do pcall(function() c:Disconnect() end) end
    for _, fn in ipairs(UI.Cleanups) do pcall(fn) end
end)

---------------------------------------------------------------------
-- PAGE: COPY MAP
---------------------------------------------------------------------
local copyPage = new("Frame", {
    Name = "CopyPage", Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58),
    BackgroundTransparency = 1,
}, main)

-- judul kolom
label(copyPage, {
    Text = "SERVICE STUDIO", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(16, 4), Size = UDim2.fromOffset(180, 20),
})
local lblSelected = label(copyPage, {
    Text = "0 dipilih", TextSize = 9, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.fromOffset(204, 4), Size = UDim2.fromOffset(98, 20),
})
label(copyPage, {
    Text = "COPY MAP", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(316, 4), Size = UDim2.fromOffset(120, 20),
})
label(copyPage, {
    Text = "FILE.RBXL  ·  SAMA DENGAN STUDIO", TextSize = 8, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.fromOffset(436, 4), Size = UDim2.fromOffset(310, 20),
})

-- ===== panel kiri =====
local left = new("Frame", {
    Position = UDim2.fromOffset(14, 30), Size = UDim2.fromOffset(290, 340),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, copyPage)
corner(left, 14)
stroke(left, T.Line, 1)

local btnRow = new("Frame", {
    Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 32), BackgroundTransparency = 1,
}, left)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, btnRow)

local function smallBtn(text, order)
    local b = button(btnRow, {
        Text = text, Size = UDim2.new(1 / 3, -6, 1, 0), BackgroundColor3 = T.Field,
        TextSize = 8, LayoutOrder = order,
    })
    corner(b, 10)
    stroke(b, T.Line, 1)
    return b
end
local btnAll   = smallBtn("PILIH SEMUA", 1)
local btnNone  = smallBtn("KOSONGKAN", 2)
local btnScan  = smallBtn("SCAN ULANG", 3)

local list = new("ScrollingFrame", {
    Position = UDim2.fromOffset(8, 52), Size = UDim2.new(1, -16, 1, -60),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = T.AccentLn, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, left)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, list)
new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4)}, list)

-- ===== panel kanan =====
local stats = new("Frame", {
    Position = UDim2.fromOffset(316, 30), Size = UDim2.fromOffset(430, 112),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, copyPage)
corner(stats, 14)
stroke(stats, T.Line, 1)

local function statCard(title, x, y)
    local c = new("Frame", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(203, 44),
        BackgroundColor3 = T.Field, BorderSizePixel = 0,
    }, stats)
    corner(c, 10)
    stroke(c, T.Line, 1, 0.3)
    label(c, {Text = title, Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = T.Muted,
        Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 12)})
    return label(c, {Text = "0", Font = Enum.Font.GothamBold, TextSize = 13,
        Position = UDim2.fromOffset(12, 21), Size = UDim2.new(1, -24, 0, 18)})
end
local valService = statCard("SERVICE", 8, 8)
local valItem    = statCard("ITEM", 219, 8)
local valScript  = statCard("SCRIPT", 8, 60)
local valFormat  = statCard("FORMAT", 219, 60)
valFormat.Text = "RBXL  ·  Binary"

-- nama file
local nameBox = new("Frame", {
    Position = UDim2.fromOffset(316, 150), Size = UDim2.fromOffset(430, 62),
    BackgroundColor3 = T.Card, BorderSizePixel = 0,
}, copyPage)
corner(nameBox, 14)
stroke(nameBox, T.Line, 1)
label(nameBox, {Text = "NAMA FILE  ·  OTOMATIS (EXPERIENCE)", Font = Enum.Font.GothamBold, TextSize = 8,
    TextColor3 = T.Muted, Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(250, 12)})
local lblFileOut = label(nameBox, {Text = "Studio Lite.rbxl", TextSize = 8, TextColor3 = T.AccentLn,
    TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -172, 0, 7), Size = UDim2.fromOffset(160, 12)})

local nameField = new("Frame", {
    Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 28),
    BackgroundColor3 = T.Field, BorderSizePixel = 0,
}, nameBox)
corner(nameField, 8)
stroke(nameField, T.Line, 1)
local nameInput = new("TextBox", {
    Size = UDim2.new(1, -112, 1, 0), Position = UDim2.fromOffset(10, 0),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
    TextColor3 = T.Text, PlaceholderText = "Studio Lite", PlaceholderColor3 = T.Muted,
    Text = "", TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
}, nameField)
local btnAutoName = button(nameField, {
    Text = "NAMA MAP", Size = UDim2.fromOffset(92, 20), AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -4, 0.5, 0), BackgroundColor3 = T.Card, TextSize = 8,
})
corner(btnAutoName, 7)

local function currentFileName()
    local n = nameInput.Text:gsub("[\\/:*?\"<>|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if n == "" then n = "Studio Lite" end
    return n
end
local function refreshFileLabel()
    lblFileOut.Text = currentFileName() .. ".rbxl"
end
nameInput:GetPropertyChangedSignal("Text"):Connect(refreshFileLabel)
btnAutoName.MouseButton1Click:Connect(function()
    local nm = "Studio Lite"
    pcall(function()
        local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        if info and info.Name then nm = info.Name end
    end)
    nameInput.Text = nm
end)
refreshFileLabel()

-- progress
local progBox = new("Frame", {
    Position = UDim2.fromOffset(316, 220), Size = UDim2.fromOffset(430, 98),
    BackgroundColor3 = T.Card, BorderSizePixel = 0,
}, copyPage)
corner(progBox, 14)
stroke(progBox, T.Line, 1)
local progTitle = label(progBox, {Text = "Siap copy map", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 16)})
local progSub = label(progBox, {Text = "Pilih service lalu tekan COPY MAP", TextSize = 9, TextColor3 = T.Muted,
    Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 14)})
local barBg = new("Frame", {
    Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 0, 14),
    BackgroundColor3 = T.Field, BorderSizePixel = 0,
}, progBox)
corner(barBg, 7)
stroke(barBg, T.Line, 1)
local barFill = new("Frame", {
    Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
}, barBg)
corner(barFill, 7)
local lblPct = label(progBox, {Text = "0%", Font = Enum.Font.GothamBold, TextSize = 9,
    Position = UDim2.fromOffset(14, 74), Size = UDim2.fromOffset(100, 14)})
local lblTime = label(progBox, {Text = "00:00", TextSize = 9, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.new(1, -114, 0, 74), Size = UDim2.fromOffset(100, 14)})

local btnCopy = button(copyPage, {
    Text = "COPY MAP", Position = UDim2.fromOffset(316, 326), Size = UDim2.fromOffset(430, 44),
    BackgroundColor3 = T.Accent, TextSize = 12,
})
corner(btnCopy, 12)

---------------------------------------------------------------------
-- PAGE: IMPORT MAP
---------------------------------------------------------------------
local importPage = new("Frame", {
    Name = "ImportPage", Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58),
    BackgroundTransparency = 1, Visible = false,
}, main)

local replacerPage = new("Frame", {
    Name = "ReplacerPage", Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58),
    BackgroundTransparency = 1, Visible = false,
}, main)

label(importPage, {
    Text = "FILE MAP", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(16, 4), Size = UDim2.fromOffset(180, 20),
})
local lblFileCount = label(importPage, {
    Text = "0 file", TextSize = 9, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.fromOffset(204, 4), Size = UDim2.fromOffset(98, 20),
})
label(importPage, {
    Text = "IMPORT MAP", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(316, 4), Size = UDim2.fromOffset(120, 20),
})
label(importPage, {
    Text = "RBXL / RBXM  ·  BINARY", TextSize = 8, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.fromOffset(436, 4), Size = UDim2.fromOffset(310, 20),
})

-- ===== panel kiri: daftar file =====
local impLeft = new("Frame", {
    Position = UDim2.fromOffset(14, 30), Size = UDim2.fromOffset(290, 340),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, importPage)
corner(impLeft, 14)
stroke(impLeft, T.Line, 1)

local btnRefresh = button(impLeft, {
    Text = "MUAT ULANG DAFTAR", Position = UDim2.fromOffset(12, 12),
    Size = UDim2.new(1, -24, 0, 32), BackgroundColor3 = T.Field, TextSize = 8,
})
corner(btnRefresh, 10)
stroke(btnRefresh, T.Line, 1)

local impList = new("ScrollingFrame", {
    Position = UDim2.fromOffset(8, 52), Size = UDim2.new(1, -16, 1, -60),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = T.AccentLn, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, impLeft)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, impList)
new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4)}, impList)

-- ===== panel kanan =====
local impInfo = new("Frame", {
    Position = UDim2.fromOffset(316, 30), Size = UDim2.fromOffset(430, 112),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, importPage)
corner(impInfo, 14)
stroke(impInfo, T.Line, 1)

local function infoCard(title, x, y)
    local c = new("Frame", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(203, 44),
        BackgroundColor3 = T.Field, BorderSizePixel = 0,
    }, impInfo)
    corner(c, 10)
    stroke(c, T.Line, 1, 0.3)
    label(c, {Text = title, Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = T.Muted,
        Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 12)})
    return label(c, {Text = "-", Font = Enum.Font.GothamBold, TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(12, 21), Size = UDim2.new(1, -24, 0, 18)})
end
local valFile = infoCard("FILE", 8, 8)
local valSize = infoCard("UKURAN", 219, 8)
local valInst = infoCard("INSTANCE DIBUAT", 8, 60)
local valStat = infoCard("STATUS", 219, 60)
valStat.Text = "Belum dipilih"

local optBox = new("Frame", {
    Position = UDim2.fromOffset(316, 150), Size = UDim2.fromOffset(430, 62),
    BackgroundColor3 = T.Card, BorderSizePixel = 0,
}, importPage)
corner(optBox, 14)
stroke(optBox, T.Line, 1)

local function toggleRow(text, y, default)
    local state = default
    label(optBox, {Text = text, TextSize = 9, Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -80, 0, 20)})
    local sw = button(optBox, {
        Text = "", Size = UDim2.fromOffset(38, 18), AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, y + 1), BackgroundColor3 = default and T.Accent or T.Field,
    })
    sw:SetAttribute("NoHover", true)
    corner(sw, 9)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(12, 12), BorderSizePixel = 0, BackgroundColor3 = T.Text,
        Position = default and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
    }, sw)
    corner(knob, 6)
    sw.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(sw, TweenInfo.new(0.12), {BackgroundColor3 = state and T.Accent or T.Field}):Play()
        TweenService:Create(knob, TweenInfo.new(0.12), {
            Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
        }):Play()
    end)
    return function() return state end
end
local getStudioMode = toggleRow("Mode Studio Lite (part di-anchor + atribut SL_)", 8, true)
local getSvcProps   = toggleRow("Terapkan properti service (Lighting dll)", 33, false)

local impProg = new("Frame", {
    Position = UDim2.fromOffset(316, 220), Size = UDim2.fromOffset(430, 98),
    BackgroundColor3 = T.Card, BorderSizePixel = 0,
}, importPage)
corner(impProg, 14)
stroke(impProg, T.Line, 1)
local impTitle = label(impProg, {Text = "Siap import map", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 16)})
local impSub = label(impProg, {Text = "Pilih file di daftar lalu tekan IMPORT MAP", TextSize = 9, TextColor3 = T.Muted,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 14)})
local impBarBg = new("Frame", {
    Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 0, 14),
    BackgroundColor3 = T.Field, BorderSizePixel = 0,
}, impProg)
corner(impBarBg, 7)
stroke(impBarBg, T.Line, 1)
local impBar = new("Frame", {
    Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
}, impBarBg)
corner(impBar, 7)
local impPct = label(impProg, {Text = "0%", Font = Enum.Font.GothamBold, TextSize = 9,
    Position = UDim2.fromOffset(14, 74), Size = UDim2.fromOffset(100, 14)})
local impTime = label(impProg, {Text = "00:00", TextSize = 9, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.new(1, -114, 0, 74), Size = UDim2.fromOffset(100, 14)})

local btnImport = button(importPage, {
    Text = "IMPORT MAP", Position = UDim2.fromOffset(316, 326), Size = UDim2.fromOffset(430, 44),
    BackgroundColor3 = T.Accent, TextSize = 12,
})
corner(btnImport, 12)

local function showTab(name)
    local pagesByName = {copy = copyPage, import = importPage, replacer = replacerPage}
    local tabsByName = {copy = tabCopy, import = tabImport, replacer = tabReplacer}
    for k, pg in pairs(pagesByName) do
        local on = k == name
        pg.Visible = on
        tabsByName[k].BackgroundColor3 = on and T.Accent or T.Field
        tabsByName[k].TextColor3 = on and T.Text or T.Muted
        tabsByName[k]:SetAttribute("NoHover", true)
    end
end
tabCopy.MouseButton1Click:Connect(function() showTab("copy") end)
tabImport.MouseButton1Click:Connect(function() showTab("import") end)
tabReplacer.MouseButton1Click:Connect(function() showTab("replacer") end)
showTab("copy")

---------------------------------------------------------------------
-- DAFTAR SERVICE
---------------------------------------------------------------------
local cards, selected, info = {}, {}, {}

local function updateSummary()
    local n, items, scripts = 0, 0, 0
    for _, name in ipairs(SERVICES) do
        if selected[name] then
            n += 1
            local i = info[name]
            if i then items += i.items; scripts += i.scripts end
        end
    end
    lblSelected.Text = n .. " dipilih"
    valService.Text = n .. " / " .. #SERVICES
    valItem.Text = fmt(items)
    valScript.Text = fmt(scripts)
end

local function paintCard(name)
    local c = cards[name]
    if not c then return end
    local on = selected[name]
    TweenService:Create(c.stroke, TweenInfo.new(0.12), {
        Color = on and T.Accent or T.Line, Thickness = on and 1.6 or 1,
    }):Play()
    c.circle.BackgroundColor3 = on and T.Accent or T.Field
    c.dot.Visible = on
end

local function setSelected(name, v)
    selected[name] = v and true or false
    paintCard(name)
    updateSummary()
end

for idx, name in ipairs(SERVICES) do
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = idx,
    }, list)
    corner(card, 12)
    local st = stroke(card, T.Line, 1)
    label(card, {Text = name, Font = Enum.Font.GothamBold, TextSize = 12,
        Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -80, 0, 18)})
    local sub = label(card, {Text = "memindai...", TextSize = 9, TextColor3 = T.Muted,
        Position = UDim2.fromOffset(18, 33), Size = UDim2.new(1, -80, 0, 14)})
    local circle = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(34, 34), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
    }, card)
    corner(circle, 17)
    local dot = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(9, 9), BackgroundColor3 = T.Text, BorderSizePixel = 0,
    }, circle)
    corner(dot, 5)
    local hit = new("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3,
    }, card)
    hit.MouseButton1Click:Connect(function() setSelected(name, not selected[name]) end)

    cards[name] = {frame = card, stroke = st, sub = sub, circle = circle, dot = dot}
    selected[name] = true
    paintCard(name)
end

local scanning = false
local function scan()
    if scanning then return end
    scanning = true
    for _, name in ipairs(SERVICES) do
        local items, scripts = 0, 0
        local okS, svc = pcall(game.GetService, game, name)
        if okS and svc then
            local okD, desc = pcall(svc.GetDescendants, svc)
            if okD then
                items = #desc
                for _, d in ipairs(desc) do
                    if d:IsA("LuaSourceContainer") then scripts += 1 end
                end
            end
        end
        info[name] = {items = items, scripts = scripts}
        local c = cards[name]
        if c and c.frame.Parent then
            c.sub.Text = items > 0 and (fmt(items) .. " item") or "kosong"
            if name == "Workspace" and items > 0 and workspace.StreamingEnabled then
                c.sub.Text = fmt(items) .. " item (streaming)"
            end
        end
        updateSummary()
        task.wait()
    end
    scanning = false
end

btnAll.MouseButton1Click:Connect(function()
    for _, n in ipairs(SERVICES) do selected[n] = true; paintCard(n) end
    updateSummary()
end)
btnNone.MouseButton1Click:Connect(function()
    for _, n in ipairs(SERVICES) do selected[n] = false; paintCard(n) end
    updateSummary()
end)
btnScan.MouseButton1Click:Connect(function()
    if UI.OnScan then task.spawn(UI.OnScan) end
    task.spawn(scan)
end)

---------------------------------------------------------------------
-- PROGRESS API
---------------------------------------------------------------------
local running, t0 = false, 0

function UI.Begin()
    running, t0 = true, os.clock()
    task.spawn(function()
        while running and gui.Parent do
            lblTime.Text = mmss(os.clock() - t0)
            task.wait(0.25)
        end
    end)
end

function UI.SetProgress(pct, title, sub)
    pct = math.clamp(pct or 0, 0, 100)
    TweenService:Create(barFill, TweenInfo.new(0.2), {Size = UDim2.fromScale(pct / 100, 1)}):Play()
    lblPct.Text = math.floor(pct) .. "%"
    if title then progTitle.Text = title end
    if sub then progSub.Text = sub end
    if pct >= 100 then
        running = false
        lblTime.Text = mmss(os.clock() - t0)
    end
end

function UI.GetSelected()
    local out = {}
    for _, n in ipairs(SERVICES) do
        if selected[n] then table.insert(out, n) end
    end
    return out
end

function UI.GetFileName()
    return currentFileName()
end

---------------------------------------------------------------------
-- TOMBOL AKSI
---------------------------------------------------------------------
btnCopy.MouseButton1Click:Connect(function()
    local picked = UI.GetSelected()
    if #picked == 0 then
        progTitle.Text = "Belum ada service dipilih"
        progSub.Text = "Pilih minimal satu service dulu"
        return
    end
    if not UI.OnCopy then
        progTitle.Text = "Fungsi copy belum dipasang"
        progSub.Text = "Isi UI.OnCopy dengan logika copy kamu"
        return
    end
    UI.SetProgress(0, "Memulai copy...", #picked .. " service dipilih")
    UI.Begin()
    task.spawn(UI.OnCopy, picked, UI.GetFileName())
end)


---------------------------------------------------------------------
-- FITUR: COPY MAP (memakai saveinstance dari executor)
---------------------------------------------------------------------
local SAVER_NAMES = {"saveinstance", "save_instance", "SaveInstance", "savegame", "save_game"}

local function findNativeSaver()
    local envs = {}
    pcall(function() if getgenv then envs[#envs + 1] = getgenv() end end)
    pcall(function() if getfenv then envs[#envs + 1] = getfenv(0) end end)
    pcall(function() envs[#envs + 1] = _G end)
    pcall(function() if shared then envs[#envs + 1] = shared end end)
    pcall(function() if syn then envs[#envs + 1] = syn end end)
    pcall(function() if fluxus then envs[#envs + 1] = fluxus end end)
    for _, env in ipairs(envs) do
        for _, n in ipairs(SAVER_NAMES) do
            local okG, f = pcall(function() return env[n] end)
            if okG and type(f) == "function" then return f end
        end
    end
    return nil
end

-- Cadangan: Universal Syn SaveInstance (script open-source, dimuat dari GitHub).
-- Butuh HttpGet + loadstring + writefile di executor.
local cachedUniversal
local function loadUniversalSaver()
    if cachedUniversal then return cachedUniversal end
    local okL, f = pcall(function()
        local src = game:HttpGet("https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau", true)
        return loadstring(src, "saveinstance")()
    end)
    if okL and type(f) == "function" then
        cachedUniversal = f
        return f
    end
    return nil
end

local function getSaver()
    return findNativeSaver() or loadUniversalSaver()
end

local function fileExists(p)
    local okF, r = pcall(function() return isfile and isfile(p) end)
    return okF and r == true
end

local busy = false

local function isValidInstance(inst)
    local okV, v = pcall(function()
        return typeof(inst) == "Instance" and inst.Parent == game
    end)
    return okV and v == true
end

local function shortErr(e, n)
    local s = tostring(e):gsub("%s+", " ")
    return s:sub(1, n or 110)
end

-- Map dengan StreamingEnabled hanya memuat area di sekitar pemain.
-- Sapuan berbentuk cincin persegi yang terus melebar dari posisi pemain: tiap cincin "mengunjungi"
-- titik-titik di tepinya supaya server mengirim bagian map di sana. Tidak ada batas jarak tetap;
-- sapuan berhenti kalau beberapa cincin berturut-turut tidak menambah item lagi (ujung map) atau waktu habis.
UI.StreamStep       = 512       -- jarak antar titik (stud); otomatis dikecilkan kalau radius streaming game kecil
UI.StreamIdleRings  = 3         -- berhenti setelah sekian cincin berturut-turut tanpa item baru (dan area sudah menutupi semua yang termuat)
UI.StreamMaxSeconds = 600       -- batas waktu total sapuan (detik), dijaga watchdog
UI.StreamAbort      = false     -- diset true oleh watchdog kalau sapuan macet
UI.StreamMaxRadius  = 1000000   -- batas jarak (stud), praktis tak terbatas

local function countWorkspace()
    local okD, d = pcall(workspace.GetDescendants, workspace)
    return okD and #d or 0
end

UI.StreamDwell    = 0.2    -- detik menunggu di tiap titik supaya server sempat mengirim map
UI.StreamTeleport = true   -- pindahkan karakter ke tiap titik (jauh lebih ampuh dari RequestStreamAroundAsync saja)
UI.StreamLayers   = true   -- sapu juga lapisan ketinggian (untuk map gunung / bertingkat)
UI.StreamKeep     = true   -- simpan referensi bagian map yang di-stream-out lalu pasang kembali sebelum disimpan
UI.ActiveSession  = nil

local function loadedBounds()
    local mn = Vector3.new(math.huge, math.huge, math.huge)
    local mx = Vector3.new(-math.huge, -math.huge, -math.huge)
    local okD, d = pcall(workspace.GetDescendants, workspace)
    local n = 0
    local charTop = {}
    for _, inst in ipairs(okD and d or {}) do
        if inst:IsA("BasePart") and not inst:IsA("Terrain") then
            local top = inst
            while top.Parent and top.Parent ~= workspace do top = top.Parent end
            local isC = charTop[top]
            if isC == nil then
                isC = top:IsA("Model") and top:FindFirstChildOfClass("Humanoid") ~= nil
                charTop[top] = isC
            end
            local okP, pp = false, nil
            if not isC then okP, pp = pcall(function() return inst.Position end) end
            if okP then
                n += 1
                mn = Vector3.new(math.min(mn.X, pp.X), math.min(mn.Y, pp.Y), math.min(mn.Z, pp.Z))
                mx = Vector3.new(math.max(mx.X, pp.X), math.max(mx.Y, pp.Y), math.max(mx.Z, pp.Z))
            end
        end
    end
    if n == 0 then return nil end
    return mn, mx
end

local function preloadStreaming(onStep)
    local okE, enabled = pcall(function() return workspace.StreamingEnabled end)
    if not (okE and enabled) then return false, 0, 0 end
    local lp = Players.LocalPlayer
    if not lp then return false, 0, 0 end

    local ch = lp.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    local home = hrp and hrp.CFrame
    local center = Vector3.zero
    if hrp then
        center = hrp.Position
    elseif workspace.CurrentCamera then
        center = workspace.CurrentCamera.CFrame.Position
    end

    local step = UI.StreamStep
    local okR, targetR = pcall(function() return workspace.StreamingTargetRadius end)
    if okR and type(targetR) == "number" and targetR > 0 then
        step = math.clamp(math.floor(targetR * 0.9), 64, step)
    end

    -- pelacak: simpan referensi semua instance Workspace yang pernah ada, supaya yang di-stream-out
    -- bisa dipasang kembali ke induknya sebelum saveinstance.
    local added, parentOf, conn = {}, {}, nil
    if UI.StreamKeep then
        local okD, d = pcall(workspace.GetDescendants, workspace)
        for _, inst in ipairs(okD and d or {}) do
            added[#added + 1] = inst
            parentOf[inst] = inst.Parent
        end
        conn = workspace.DescendantAdded:Connect(function(inst)
            added[#added + 1] = inst
            parentOf[inst] = inst.Parent
        end)
    end

    local canTP = UI.StreamTeleport and hrp ~= nil
    local wasAnchored = false
    if canTP then
        wasAnchored = hrp.Anchored
        pcall(function() hrp.Anchored = true end)
    end

    local session = {}
    function session.restore()
        local restored, lost = 0, 0
        for i = 1, #added do
            local inst = added[i]
            local okP, par = pcall(function() return inst.Parent end)
            if okP and par == nil then
                local want = parentOf[inst]
                local isChar = want == workspace and inst:IsA("Model") and inst:FindFirstChildWhichIsA("Humanoid") ~= nil
                if want and want ~= inst and not isChar then
                    local okS = pcall(function() inst.Parent = want end)
                    local okC, nowP = pcall(function() return inst.Parent end)
                    if okS and okC and nowP == want then restored += 1 else lost += 1 end
                end
            end
            if i % 3000 == 0 then task.wait() end
        end
        return restored, lost
    end
    function session.finish()
        if conn then conn:Disconnect(); conn = nil end
        if canTP and hrp and hrp.Parent then
            pcall(function()
                hrp.CFrame = home
                hrp.Anchored = wasAnchored
            end)
        end
        added, parentOf = {}, {}
    end
    UI.ActiveSession = session

    -- RequestStreamAroundAsync kadang tidak pernah kembali; jalankan di thread terpisah
    local firstErr, stuck, useReq, timeouts = nil, 0, true, 0
    local function visit(pos)
        if not useReq then return end
        local finished = false
        task.spawn(function()
            local okV, e = pcall(function() lp:RequestStreamAroundAsync(pos, 1.5) end)
            if not okV and not firstErr then firstErr = tostring(e) end
            finished = true
        end)
        local t = os.clock()
        while not finished and os.clock() - t < 4 do task.wait(0.05) end
        if finished then
            stuck = 0
        else
            timeouts += 1
            if canTP then
                if timeouts >= 2 then useReq = false end   -- teleport tetap jalan, RequestStream dimatikan
            else
                stuck += 1
            end
        end
    end
    local function moveTo(pos)
        if canTP and hrp.Parent then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = CFrame.new(pos)
            end)
        end
        visit(pos)
        task.wait(UI.StreamDwell)
    end
    local function stopped(t0)
        return not gui.Parent or UI.StreamAbort or os.clock() - t0 > UI.StreamMaxSeconds
    end

    local t0 = os.clock()
    moveTo(center)
    local best, idle, rings, visited = countWorkspace(), 0, 0, 1
    local k = 1
    while k * step <= UI.StreamMaxRadius do
        if stopped(t0) then break end
        local pts = {}
        for i = -k, k do
            if math.abs(i) == k then
                for j = -k, k do pts[#pts + 1] = Vector3.new(i * step, 0, j * step) end
            else
                pts[#pts + 1] = Vector3.new(i * step, 0, -k * step)
                pts[#pts + 1] = Vector3.new(i * step, 0, k * step)
            end
        end
        for _, off in ipairs(pts) do
            if stopped(t0) then break end
            moveTo(center + off)
            visited += 1
            if stuck >= 8 then break end
        end
        rings = k
        local now = countWorkspace()
        if now > best then best = now; idle = 0 else idle += 1 end
        if onStep then onStep(k, now, visited, os.clock() - t0) end
        if stuck >= 8 then break end
        if idle >= UI.StreamIdleRings then
            local mn, mx = loadedBounds()
            local ext = 0
            if mn then
                ext = math.max(math.abs(mx.X - center.X), math.abs(mn.X - center.X),
                    math.abs(mx.Z - center.Z), math.abs(mn.Z - center.Z))
            end
            if k * step >= ext then break end
            idle = UI.StreamIdleRings - 1
        end
        k += 1
    end

    -- lapisan ketinggian: map bertingkat/gunung butuh titik di atas & bawah posisi awal
    if UI.StreamLayers and not stopped(t0) then
        local mn, mx = loadedBounds()
        if mn then
            local ys = {}
            local y = center.Y + step
            while y - step < mx.Y and #ys < 12 do ys[#ys + 1] = y; y += step end
            y = center.Y - step
            while y + step > mn.Y and #ys < 24 do ys[#ys + 1] = y; y -= step end
            local gstep = step * 1.5
            local layerPts = 0
            for li, ly in ipairs(ys) do
                if stopped(t0) or stuck >= 8 then break end
                local x = mn.X - step
                while x <= mx.X + step and layerPts < 400 do
                    local z = mn.Z - step
                    while z <= mx.Z + step and layerPts < 400 do
                        if stopped(t0) then break end
                        moveTo(Vector3.new(x, ly, z))
                        layerPts += 1
                        visited += 1
                        z += gstep
                    end
                    x += gstep
                end
                if onStep then onStep(rings, countWorkspace(), visited, os.clock() - t0) end
            end
        end
    end
    return true, rings, best, firstErr
end

---------------------------------------------------------------------
-- ISI SCRIPT: di-decompile sendiri lalu disimpan ke file pendamping
-- <nama>.scripts.json. Saat import, isinya dipasang kembali ke script
-- (rbxl hasil GetObjects tidak membawa isi script, jadi dulu tampak "not found").
---------------------------------------------------------------------
local ScriptKit = {}

local function cleanText(str)
    str = tostring(str or "")
    str = str:gsub("%c", function(c)
        if c == "\n" or c == "\r" or c == "\t" then return c end
        return ""
    end)
    if not utf8.len(str) then str = str:gsub("[\128-\255]", "?") end
    return str
end

local function looksFailed(str)
    if #str > 600 then return false end
    local low = str:lower()
    return low:find("not found", 1, true) ~= nil
        or low:find("failed to decompile", 1, true) ~= nil
        or low:find("decompile failed", 1, true) ~= nil
        or low:find("decompilation failed", 1, true) ~= nil
        or low:find("unable to decompile", 1, true) ~= nil
        or low:find("cannot decompile", 1, true) ~= nil
end

local function grabSource(scr)
    local placeholder = false
    local function ok(r)
        if type(r) ~= "string" or r == "" then return false end
        if looksFailed(r) then placeholder = true return false end
        return true
    end
    local okS, r = pcall(function() return scr.Source end)
    if okS and ok(r) then return r end
    if type(decompile) == "function" then
        local okD, r2 = pcall(decompile, scr)
        if okD and ok(r2) then return r2 end
    end
    if type(gethiddenproperty) == "function" then
        local okH, r3 = pcall(gethiddenproperty, scr, "Source")
        if okH and ok(r3) then return r3 end
    end
    if placeholder then return nil, "placeholder" end
    if type(decompile) ~= "function" then return nil, "tanpa_decompile" end
    return nil, "kosong"
end

-- Pekerja latar belakang: decompile berjalan BERSAMAAN dengan sapuan streaming,
-- jadi waktu membaca script hampir tidak menambah lama copy.
UI.ActiveBG = nil
function ScriptKit.startBackground(serviceNames)
    local bg = {cache = {}, queue = {}, qi = 1, seen = {}, stopped = false, conns = {}}
    local WORKERS, PER_SCRIPT = 6, 20
    function bg.enqueue(inst)
        if bg.seen[inst] then return end
        bg.seen[inst] = true
        bg.queue[#bg.queue + 1] = inst
    end
    for _, name in ipairs(serviceNames or {}) do
        local okS, svc = pcall(game.GetService, game, name)
        if okS and svc then
            local okD, d = pcall(svc.GetDescendants, svc)
            for _, inst in ipairs(okD and d or {}) do
                if inst:IsA("LuaSourceContainer") then bg.enqueue(inst) end
            end
            local okC, c = pcall(function()
                return svc.DescendantAdded:Connect(function(inst)
                    if inst:IsA("LuaSourceContainer") then bg.enqueue(inst) end
                end)
            end)
            if okC and c then bg.conns[#bg.conns + 1] = c end
        end
    end
    local function worker()
        while true do
            local inst = bg.queue[bg.qi]
            if inst then
                bg.qi += 1
                local finished, res = false, nil
                task.spawn(function()
                    local src, why = grabSource(inst)
                    res = {src = src, why = why}
                    finished = true
                end)
                local t1 = os.clock()
                while not finished and os.clock() - t1 < PER_SCRIPT do task.wait(0.05) end
                bg.cache[inst] = finished and res or {why = "timeout"}
            elseif bg.stopped then
                break
            else
                task.wait(0.1)
            end
        end
    end
    for _ = 1, WORKERS do task.spawn(worker) end
    function bg.stop()
        bg.stopped = true
        bg.qi = #bg.queue + 1
        for _, c in ipairs(bg.conns) do pcall(function() c:Disconnect() end) end
        bg.conns = {}
    end
    return bg
end

-- return: jumlah script, jumlah yang berhasil dibaca isinya, teks statistik
function ScriptKit.harvest(instances, report, outPath, exportDir, bg)
    if not bg then bg = ScriptKit.startBackground({}) end
    local list, counter = {}, {}
    for _, svc in ipairs(instances) do
        local okD, d = pcall(svc.GetDescendants, svc)
        for _, inst in ipairs(okD and d or {}) do
            if inst:IsA("LuaSourceContainer") then
                local okN, fn = pcall(inst.GetFullName, inst)
                if okN then
                    counter[fn] = (counter[fn] or 0) + 1
                    list[#list + 1] = {inst = inst, key = fn .. "#" .. counter[fn],
                        class = inst.ClassName, name = inst.Name}
                end
            end
        end
    end
    local total = #list
    if total == 0 then bg.stop() return 0, 0 end

    for _, e in ipairs(list) do bg.enqueue(e.inst) end
    local t0, MAX_TOTAL = os.clock(), 600
    while gui.Parent do
        local done = 0
        for _, e in ipairs(list) do
            if bg.cache[e.inst] then done += 1 end
        end
        if report then report(done, total) end
        if done >= total or os.clock() - t0 > MAX_TOTAL then break end
        task.wait(0.25)
    end
    bg.stop()
    for _, e in ipairs(list) do
        local c = bg.cache[e.inst]
        if c then e.src, e.why = c.src, c.why end
    end

    local out, good = {}, 0
    local tally = {}
    for _, e in ipairs(list) do
        local t = tally[e.class]
        if not t then t = {0, 0}; tally[e.class] = t end
        t[2] += 1
        if e.src then
            good += 1
            t[1] += 1
            out[#out + 1] = {k = e.key, c = e.class, n = e.name, s = cleanText(e.src)}
        end
    end
    local parts = {}
    for _, cls in ipairs({"LocalScript", "ModuleScript", "Script"}) do
        local t = tally[cls]
        if t then
            parts[#parts + 1] = ((cls == "Script") and "Script(server)" or cls) .. " " .. t[1] .. "/" .. t[2]
        end
    end
    local statText = table.concat(parts, " • ")
    local why = {placeholder = 0, tanpa_decompile = 0, kosong = 0, timeout = 0}
    for _, e in ipairs(list) do
        if not e.src then
            local w = e.why or "timeout"
            why[w] = (why[w] or 0) + 1
        end
    end
    local diag = {}
    if why.tanpa_decompile > 0 then diag[#diag + 1] = why.tanpa_decompile .. " executor tanpa decompile" end
    if why.placeholder > 0 then diag[#diag + 1] = why.placeholder .. " hasil decompile 'not found/failed'" end
    if why.kosong > 0 then diag[#diag + 1] = why.kosong .. " kosong (tidak ada bytecode di client)" end
    if why.timeout > 0 then diag[#diag + 1] = why.timeout .. " timeout" end
    if #diag > 0 then statText = statText .. " | gagal: " .. table.concat(diag, ", ") end

    -- ekspor tiap script yang terbaca sebagai file .lua (cadangan kalau pemasangan ke script ditolak)
    local exported = 0
    if good > 0 and exportDir and type(writefile) == "function" then
        if type(makefolder) == "function" then pcall(makefolder, exportDir) end
        for i, e in ipairs(list) do
            if e.src then
                local safe = (e.key:gsub("#", "_"):gsub("[^%w%._%-]", "_"))
                if #safe > 90 then safe = safe:sub(-90) end
                local ext = (e.class == "ModuleScript") and ".module.lua" or ((e.class == "LocalScript") and ".client.lua" or ".server.lua")
                local okW = pcall(writefile, exportDir .. "/" .. string.format("%04d_", i) .. safe .. ext, cleanText(e.src))
                if okW then exported += 1 end
            end
        end
    end
    statText = statText .. (exported > 0 and (" | " .. exported .. " file .lua di folder " .. exportDir) or "")
    if good > 0 then
        local okJ, js = pcall(function()
            return game:GetService("HttpService"):JSONEncode({v = 1, scripts = out})
        end)
        if okJ and type(js) == "string" then
            local okW, errW = pcall(writefile, outPath, js)
            if not okW then pcall(warn, "[CopyMap] gagal menulis " .. outPath .. ": " .. tostring(errW)) end
        else
            pcall(warn, "[CopyMap] JSONEncode script gagal: " .. tostring(js))
        end
    end
    return total, good, statText
end

UI.OnCopy = function(services, fileName)
    if busy then return end
    busy = true
    barFill.BackgroundColor3 = T.Accent

    local function endSession()
        local sess = UI.ActiveSession
        UI.ActiveSession = nil
        if sess then pcall(sess.finish) end
        local bgOld = UI.ActiveBG
        UI.ActiveBG = nil
        if bgOld then pcall(bgOld.stop) end
    end

    local function fail(title, sub)
        endSession()
        running = false
        barFill.BackgroundColor3 = T.Bad
        UI.SetProgress(100, title, sub)
        lblPct.Text = "GAGAL"
        busy = false
    end

    local saver = getSaver()
    if type(saver) ~= "function" then
        return fail("Executor tidak didukung",
            "saveinstance tidak ada & gagal dimuat (butuh HttpGet/loadstring). Pakai executor lain")
    end
    UI.SetProgress(3, "Menyiapkan...", "Fungsi saveinstance siap")

    -- 0a) mulai membaca isi script di latar belakang (berjalan sambil sapuan streaming)
    local bgScripts
    if type(writefile) == "function" then
        local okB, b = pcall(ScriptKit.startBackground, services)
        if okB and b then bgScripts = b; UI.ActiveBG = b end
    end

    -- 0) map streaming: sapu seluruh area (tanpa batas jarak) supaya Workspace lengkap
    local streamed, streamNote = false, nil
    if table.find(services, "Workspace") then
        local before = countWorkspace()
        UI.StreamAbort = false
        local sweepDone, okP, did, rings, peak, serr = false, false, false, 0, nil, nil
        task.spawn(function()
            okP, did, rings, peak, serr = pcall(preloadStreaming, function(k, now, visited, secs)
                UI.SetProgress(3 + 7 * (1 - math.exp(-k / 12)), "Memuat seluruh area map (streaming)...",
                    "cincin " .. k .. " • " .. fmt(now) .. " item • " .. fmt(visited) .. " titik • " .. mmss(secs))
            end)
            sweepDone = true
        end)
        -- watchdog: kalau sapuan melewati batas waktu, hentikan dan lanjut menyimpan
        local sweepT0 = os.clock()
        while not sweepDone and gui.Parent and os.clock() - sweepT0 < UI.StreamMaxSeconds + 15 do
            task.wait(0.25)
        end
        if not sweepDone then
            UI.StreamAbort = true
            okP, did, rings = true, true, rings or 0
            pcall(warn, "[CopyMap] sapuan streaming dihentikan watchdog, lanjut menyimpan")
        end
        if not okP then
            pcall(warn, "[CopyMap] sapuan streaming error: " .. tostring(did))
        end
        if okP and did then
            streamed = true
            -- pasang kembali bagian map yang sempat di-stream-out selama sapuan
            local restored, lost = 0, 0
            if UI.ActiveSession then
                UI.SetProgress(10, "Memulihkan bagian map...", "memasang kembali part yang ter-stream-out")
                local okRs, r1, r2 = pcall(UI.ActiveSession.restore)
                if okRs then restored, lost = r1 or 0, r2 or 0 end
            end
            local after = countWorkspace()
            info.Workspace = info.Workspace or {items = 0, scripts = 0}
            info.Workspace.items = after
            local sc = 0
            local okD, d = pcall(workspace.GetDescendants, workspace)
            for _, inst in ipairs(okD and d or {}) do
                if inst:IsA("LuaSourceContainer") then sc += 1 end
            end
            info.Workspace.scripts = sc
            streamNote = "streaming: " .. fmt(before) .. " -> " .. fmt(after) .. " item (" .. tostring(rings) .. " cincin"
                .. ((restored > 0 or lost > 0) and (", dipulihkan " .. fmt(restored) .. ((lost > 0) and (", gagal " .. fmt(lost)) or "")) or "")
                .. ")"
            if serr then streamNote ..= " • RequestStream error: " .. shortErr(serr, 60) end
            pcall(warn, "[CopyMap] " .. streamNote .. " | puncak " .. fmt(peak or after))
        end
    end

    -- 1) kumpulkan service yang dipilih (buang yang tidak valid / kosong)
    UI.SetProgress(5, "Menyiapkan...", "Mengumpulkan service")
    local instances, totalItems, empty = {}, 0, {}
    local totalScripts = 0
    for _, name in ipairs(services) do
        local okS, svc = pcall(game.GetService, game, name)
        if okS and isValidInstance(svc) then
            local count = info[name] and info[name].items
            if count == nil then
                local okD, d = pcall(svc.GetDescendants, svc)
                count = okD and #d or 0
            end
            if count > 0 then
                table.insert(instances, svc)
                totalItems += count
                totalScripts += (info[name] and info[name].scripts) or 0
            else
                table.insert(empty, name)
            end
        else
            table.insert(empty, name)
        end
    end
    if #instances == 0 then
        return fail("Instance tidak ditemukan",
            "Service yang dipilih kosong / tidak bisa diakses. Pilih Workspace lalu SCAN ULANG")
    end

    -- 1b) baca isi semua script sendiri -> <nama>.scripts.json (dipakai saat import)
    local scriptNote, base = nil, 10
    local decompileInSave = true
    if type(writefile) == "function" then
        local okH, tot, good, stat = pcall(ScriptKit.harvest, instances, function(done, total)
            UI.SetProgress(10 + 15 * (done / math.max(1, total)), "Membaca isi script...",
                done .. " / " .. total .. " script")
        end, fileName .. ".scripts.json", fileName .. "_scripts", bgScripts)
        UI.ActiveBG = nil
        if bgScripts then pcall(bgScripts.stop) end
        if okH and tot and tot > 0 then
            decompileInSave = false   -- sudah di-decompile sendiri; saveinstance tidak perlu mengulang (jauh lebih cepat)
            scriptNote = good .. "/" .. tot .. " isi script terbaca (" .. tostring(stat) .. ")"
            if good > 0 then scriptNote ..= " -> " .. fileName .. ".scripts.json" end
            if good < tot then scriptNote ..= " | sisanya tidak bisa dibaca dari client (Script server tidak punya isi di client)" end
            base = 25
        elseif not okH then
            pcall(warn, "[CopyMap] baca script gagal: " .. tostring(tot))
        end
    end

    if UI.ActiveSession then pcall(UI.ActiveSession.restore) end

    -- 2) jalankan saveinstance (urutan percobaan dari yang paling lengkap)
    local path = fileName .. ".rbxl"
    local finished, saved, wholeGame = false, false, false
    local errs = {}

    task.spawn(function()
        local attempts = {
            {whole = false, run = function()
                return saver({
                    FileName = path, Mode = "invalid", ExtraInstances = instances,
                    Decompile = decompileInSave, DecompileTimeout = 20, ReadMe = false,
                    ShutdownWhenDone = false, ShowStatus = false,
                })
            end},
            -- sebagian executor menambah ekstensi sendiri
            {whole = false, run = function()
                return saver({
                    FileName = fileName, Mode = "invalid", ExtraInstances = instances,
                    Decompile = decompileInSave, ReadMe = false,
                })
            end},
            -- opsi minimal untuk executor yang menolak opsi tak dikenal
            {whole = false, run = function()
                return saver({FileName = path, ExtraInstances = instances})
            end},
            {whole = true, run = function() return saver(path) end},
            {whole = true, run = function() return saver() end},
        }
        for i, a in ipairs(attempts) do
            local okRun, e = pcall(a.run)
            if okRun then
                saved, wholeGame = true, a.whole
                break
            end
            errs[#errs + 1] = shortErr(e, 200)
            pcall(warn, ("[CopyMap] percobaan %d gagal: %s"):format(i, tostring(e)))
        end
        finished = true
    end)

    -- 3) saveinstance tidak memberi progress asli, jadi bar ini hanya estimasi
    local est = math.max(8, totalItems / 400)
    local started = os.clock()
    local note = "Estimasi, tergantung ukuran map dan executor"
    while not finished and gui.Parent do
        local p = base + (90 - base) * (1 - math.exp(-(os.clock() - started) / est))
        UI.SetProgress(p, "Menyimpan map...", note)
        task.wait(0.3)
    end
    endSession()
    if not gui.Parent then busy = false return end

    -- 4) hasil
    if not saved then
        -- tampilkan error percobaan PERTAMA (paling relevan), bukan yang terakhir
        return fail("Gagal menyimpan", shortErr(errs[1] or "unknown", 110))
    end

    local sub = fileExists(path) and (path .. " tersimpan di folder workspace executor")
        or "Selesai, cek folder workspace executor"
    if wholeGame then
        sub = "Executor tidak mendukung pilihan service, seluruh game disimpan. " .. sub
    elseif #empty > 0 then
        sub = #empty .. " service kosong dilewati. " .. sub
    end
    if streamNote then sub = sub .. " [" .. streamNote .. "]" end
    if scriptNote then
        sub = sub .. " | " .. scriptNote
    elseif totalScripts > 0 then
        if type(decompile) ~= "function" then
            sub = sub .. " | " .. totalScripts .. " script TANPA isi (executor tidak punya decompile)"
        else
            sub = sub .. " | " .. totalScripts .. " script (hanya Local/Module; Script server tidak ada di client)"
        end
    end
    UI.SetProgress(100, "Copy map selesai", sub)
    busy = false
end

---------------------------------------------------------------------
-- FITUR: IMPORT MAP (parser RBXL / RBXM biner)
---------------------------------------------------------------------
local InsertService = game:GetService("InsertService")

-- id rotasi CFrame biner -> R00,R01,R02,R10,R11,R12,R20,R21,R22
local ROT = {
    [0x02] = {1,0,0, 0,1,0, 0,0,1},    [0x03] = {1,0,0, 0,0,-1, 0,1,0},
    [0x05] = {1,0,0, 0,-1,0, 0,0,-1},  [0x06] = {1,0,0, 0,0,1, 0,-1,0},
    [0x07] = {0,1,0, 1,0,0, 0,0,-1},   [0x09] = {0,0,1, 1,0,0, 0,1,0},
    [0x0A] = {0,-1,0, 1,0,0, 0,0,1},   [0x0C] = {0,0,-1, 1,0,0, 0,-1,0},
    [0x0D] = {0,1,0, 0,0,1, 1,0,0},    [0x0E] = {0,0,-1, 0,1,0, 1,0,0},
    [0x10] = {0,-1,0, 0,0,-1, 1,0,0},  [0x11] = {0,0,1, 0,-1,0, 1,0,0},
    [0x14] = {-1,0,0, 0,1,0, 0,0,-1},  [0x15] = {-1,0,0, 0,0,1, 0,1,0},
    [0x17] = {-1,0,0, 0,-1,0, 0,0,1},  [0x18] = {-1,0,0, 0,0,-1, 0,-1,0},
    [0x19] = {0,1,0, -1,0,0, 0,0,1},   [0x1B] = {0,0,-1, -1,0,0, 0,1,0},
    [0x1C] = {0,-1,0, -1,0,0, 0,0,-1}, [0x1E] = {0,0,1, -1,0,0, 0,-1,0},
    [0x1F] = {0,1,0, 0,0,-1, -1,0,0},  [0x20] = {0,0,1, 0,1,0, -1,0,0},
    [0x22] = {0,-1,0, 0,0,1, -1,0,0},  [0x23] = {0,0,-1, 0,-1,0, -1,0,0},
}

-- nama properti di file -> nama properti API
local ALIAS = {size = "Size", shape = "Shape", Color3uint8 = "Color"}
local SKIP_PROP = {
    formFactorRaw = true, Attributes = true, AttributesSerialize = true, Tags = true,
    MaterialVariantSerialized = true, UniqueId = true, HistoryId = true, SourceAssetId = true,
    ScriptGuid = true, LinkedSource = true, SecurityCapabilities = true, Capabilities = true,
    DefinesCapabilities = true, NeedsPivotMigration = true, Parent = true,
}
local SKIP_CLASS = {Camera = true, Terrain = true}

-- bisa kamu ubah dari luar
UI.ImportSkipServices = {Players = true}          -- isi service ini tidak diimport
UI.ImportSkipNames = {StudioLiteFolder = true}    -- folder bawaan Studio Lite jangan digandakan
UI.ResolveMesh = nil                              -- opsional: function(meshId) return MeshPart end

---------------------------------------------------------------------
-- LZ4 (pakai bawaan executor kalau ada, kalau tidak pakai Luau murni)
---------------------------------------------------------------------
local function lz4pure(src, outSize)
    local out, ip, op, n = table.create(outSize), 1, 0, #src
    local byte, work = string.byte, 0
    while ip <= n do
        local token = byte(src, ip); ip += 1
        local lit = token // 16
        if lit == 15 then
            local b
            repeat b = byte(src, ip); ip += 1; lit += b until b ~= 255
        end
        for i = 0, lit - 1 do out[op + 1 + i] = byte(src, ip + i) end
        ip += lit; op += lit
        if ip > n then break end
        local offset = byte(src, ip) + byte(src, ip + 1) * 256; ip += 2
        local ml = token % 16
        if ml == 15 then
            local b
            repeat b = byte(src, ip); ip += 1; ml += b until b ~= 255
        end
        ml += 4
        local from = op - offset
        for i = 1, ml do out[op + i] = out[from + i] end
        op += ml
        work += lit + ml
        if work > 400000 then work = 0; task.wait() end
    end
    local parts = {}
    for i = 1, op, 4000 do
        local okC, piece = pcall(function()
            return string.char(table.unpack(out, i, math.min(i + 3999, op)))
        end)
        if not okC then
            local h = {}
            for k = 1, math.min(4, #src) do h[k] = string.format("%02X", byte(src, k)) end
            error("Chunk bukan LZ4 valid (awal data: " .. table.concat(h, " ") .. ")", 0)
        end
        parts[#parts + 1] = piece
    end
    return table.concat(parts)
end

local function lz4(src, outSize)
    local env = (getgenv and getgenv()) or {}
    local fn = env.lz4decompress or lz4decompress
    if type(fn) == "function" then
        local okL, res = pcall(fn, src, outSize)
        if okL and type(res) == "string" and #res == outSize then return res end
    end
    return lz4pure(src, outSize)
end

-- chunk bisa dikompres LZ4 (lama) atau ZSTD (magic 28 B5 2F FD)
local ZSTD_MAGIC = "\40\181\47\253"
local function decompress(src, outSize)
    if src:sub(1, 4) == ZSTD_MAGIC then
        local env = (getgenv and getgenv()) or {}
        local fn = env.zstddecompress or zstddecompress
        if type(fn) ~= "function" then
            error("File memakai kompresi ZSTD, executor tidak punya zstddecompress", 0)
        end
        local okZ, res = pcall(fn, src, outSize)
        if not (okZ and type(res) == "string" and #res == outSize) then
            okZ, res = pcall(fn, src)
        end
        if okZ and type(res) == "string" and #res == outSize then return res end
        error("zstddecompress executor gagal / ukuran tidak cocok", 0)
    end
    return lz4(src, outSize)
end

---------------------------------------------------------------------
-- PEMBACA BINER
---------------------------------------------------------------------
local function zz(u)
    if u % 2 == 0 then return u / 2 end
    return -(u + 1) / 2
end

-- float yang disimpan dengan bit tanda dipindah ke posisi terendah
local function unrot(u)
    local bits = (u // 2) + (u % 2) * 2147483648
    local sign = bits >= 2147483648 and -1 or 1
    local e = (bits // 8388608) % 256
    local m = bits % 8388608
    if e == 0 then return sign * m * 2 ^ -149 end
    if e == 255 then return m == 0 and sign * math.huge or 0 end
    return sign * (1 + m / 8388608) * 2 ^ (e - 127)
end

local function newReader(s)
    local r = {p = 1}
    local byte = string.byte
    function r.u8() local v = byte(s, r.p); r.p += 1; return v end
    function r.u32() local v = string.unpack("<I4", s, r.p); r.p += 4; return v end
    function r.i16() local v = string.unpack("<i2", s, r.p); r.p += 2; return v end
    function r.f32() local v = string.unpack("<f", s, r.p); r.p += 4; return v end
    function r.f64() local v = string.unpack("<d", s, r.p); r.p += 8; return v end
    function r.str()
        local n = r.u32()
        local v = s:sub(r.p, r.p + n - 1)
        r.p += n
        return v
    end
    function r.inter(n, size)
        local out, base = table.create(n), r.p
        if size == 4 then
            for i = 1, n do
                local o = base + i - 1
                out[i] = byte(s, o) * 16777216 + byte(s, o + n) * 65536 + byte(s, o + 2 * n) * 256 + byte(s, o + 3 * n)
            end
        else
            for i = 1, n do
                local o, v = base + i - 1, 0
                for j = 0, 7 do v = v * 256 + byte(s, o + j * n) end
                out[i] = v
            end
        end
        r.p = base + n * size
        return out
    end
    function r.uints(n) return r.inter(n, 4) end
    function r.ints(n)
        local a = r.inter(n, 4)
        for i = 1, n do a[i] = zz(a[i]) end
        return a
    end
    function r.ints64(n)
        local a = r.inter(n, 8)
        for i = 1, n do a[i] = zz(a[i]) end
        return a
    end
    function r.floats(n)
        local a = r.inter(n, 4)
        for i = 1, n do a[i] = unrot(a[i]) end
        return a
    end
    function r.refs(n)
        local a, acc = r.ints(n), 0
        for i = 1, n do acc += a[i]; a[i] = acc end
        return a
    end
    function r.bytesArr(n)
        local a = table.create(n)
        for i = 1, n do a[i] = byte(s, r.p + i - 1) end
        r.p += n
        return a
    end
    return r
end

---------------------------------------------------------------------
-- DECODER TIPE PROPERTI (id tipe -> function(reader, jumlah) -> array nilai)
---------------------------------------------------------------------
local function try(f, ...)
    local okT, v = pcall(f, ...)
    if okT then return v end
    return nil
end

local D = {}
D[0x01] = function(r, n)
    local t = table.create(n)
    for i = 1, n do t[i] = r.str() end
    return t
end
D[0x02] = function(r, n)
    local t = table.create(n)
    for i = 1, n do t[i] = r.u8() ~= 0 end
    return t
end
D[0x03] = function(r, n) return r.ints(n) end
D[0x04] = function(r, n) return r.floats(n) end
D[0x05] = function(r, n)
    local t = table.create(n)
    for i = 1, n do t[i] = r.f64() end
    return t
end
D[0x06] = function(r, n)
    local sc = r.floats(n)
    local of = r.ints(n)
    local t = table.create(n)
    for i = 1, n do t[i] = UDim.new(sc[i], of[i]) end
    return t
end
D[0x07] = function(r, n)
    local sx = r.floats(n)
    local sy = r.floats(n)
    local ox = r.ints(n)
    local oy = r.ints(n)
    local t = table.create(n)
    for i = 1, n do t[i] = UDim2.new(sx[i], ox[i], sy[i], oy[i]) end
    return t
end
D[0x0B] = function(r, n)
    local a = r.uints(n)
    local t = table.create(n)
    for i = 1, n do t[i] = try(BrickColor.new, a[i]) end
    return t
end
D[0x0C] = function(r, n)
    local cr = r.floats(n)
    local cg = r.floats(n)
    local cb = r.floats(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Color3.new(cr[i], cg[i], cb[i]) end
    return t
end
D[0x0D] = function(r, n)
    local x = r.floats(n)
    local y = r.floats(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Vector2.new(x[i], y[i]) end
    return t
end
D[0x0E] = function(r, n)
    local x = r.floats(n)
    local y = r.floats(n)
    local z = r.floats(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Vector3.new(x[i], y[i], z[i]) end
    return t
end
D[0x10] = function(r, n)
    local rots = table.create(n)
    for i = 1, n do
        local id = r.u8()
        if id == 0 then
            local m = table.create(9)
            for j = 1, 9 do m[j] = r.f32() end
            rots[i] = m
        else
            rots[i] = ROT[id] or ROT[0x02]
        end
    end
    local x = r.floats(n)
    local y = r.floats(n)
    local z = r.floats(n)
    local t = table.create(n)
    for i = 1, n do
        local m = rots[i]
        t[i] = try(CFrame.new, x[i], y[i], z[i], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
    end
    return t
end
D[0x12] = function(r, n)
    local a = r.uints(n)
    local t = table.create(n)
    for i = 1, n do t[i] = {enum = a[i]} end
    return t
end
D[0x14] = function(r, n)
    local t = table.create(n)
    for i = 1, n do
        local x = r.i16()
        local y = r.i16()
        local z = r.i16()
        t[i] = Vector3int16.new(x, y, z)
    end
    return t
end
D[0x15] = function(r, n)
    local t = table.create(n)
    for i = 1, n do
        local k = r.u32()
        local kp = {}
        for j = 1, k do
            local tm = r.f32()
            local v = r.f32()
            local env = r.f32()
            kp[j] = NumberSequenceKeypoint.new(tm, v, env)
        end
        t[i] = try(NumberSequence.new, kp)
    end
    return t
end
D[0x16] = function(r, n)
    local t = table.create(n)
    for i = 1, n do
        local k = r.u32()
        local kp = {}
        for j = 1, k do
            local tm = r.f32()
            local cr, cg, cb = r.f32(), r.f32(), r.f32()
            r.f32()
            kp[j] = ColorSequenceKeypoint.new(tm, Color3.new(cr, cg, cb))
        end
        t[i] = try(ColorSequence.new, kp)
    end
    return t
end
D[0x17] = function(r, n)
    local t = table.create(n)
    for i = 1, n do
        local mn = r.f32()
        local mx = r.f32()
        t[i] = NumberRange.new(mn, mx)
    end
    return t
end
D[0x18] = function(r, n)
    local x0 = r.floats(n)
    local y0 = r.floats(n)
    local x1 = r.floats(n)
    local y1 = r.floats(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Rect.new(x0[i], y0[i], x1[i], y1[i]) end
    return t
end
D[0x1A] = function(r, n)
    local cr = r.bytesArr(n)
    local cg = r.bytesArr(n)
    local cb = r.bytesArr(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Color3.fromRGB(cr[i], cg[i], cb[i]) end
    return t
end
D[0x1B] = function(r, n) return r.ints64(n) end

---------------------------------------------------------------------
-- BANTUAN SET PROPERTI
---------------------------------------------------------------------
local enumCache = {}
local function enumItem(enumType, value)
    local map = enumCache[enumType]
    if not map then
        map = {}
        for _, it in ipairs(enumType:GetEnumItems()) do map[it.Value] = it end
        enumCache[enumType] = map
    end
    return map[value]
end

local function setValue(inst, name, val)
    name = ALIAS[name] or name
    if SKIP_PROP[name] or val == nil then return end
    if type(val) == "table" and val.enum then
        local okR, cur = pcall(function() return inst[name] end)
        if okR and typeof(cur) == "EnumItem" then
            local it = enumItem(cur.EnumType, val.enum)
            if it then pcall(function() inst[name] = it end) end
        end
        return
    end
    local okS = pcall(function() inst[name] = val end)
    if not okS and name == "Source" and type(sethiddenproperty) == "function" then
        pcall(sethiddenproperty, inst, "Source", val)
    end
end

local meshCache = {}
local function makeMeshPart(id)
    if meshCache[id] ~= nil then
        return meshCache[id] and meshCache[id]:Clone() or nil
    end
    local okM, mp = pcall(function()
        return InsertService:CreateMeshPartAsync(id, Enum.CollisionFidelity.Default, Enum.RenderFidelity.Automatic)
    end)
    if not (okM and mp) and UI.ResolveMesh then
        local ok2, res = pcall(UI.ResolveMesh, id)
        if ok2 and typeof(res) == "Instance" then mp, okM = res, true end
    end
    meshCache[id] = (okM and mp) and mp or false
    return meshCache[id] and meshCache[id]:Clone() or nil
end

---------------------------------------------------------------------
-- PEMULIHAN ISI SCRIPT (dari <nama>.scripts.json hasil copy map)
---------------------------------------------------------------------
function ScriptKit.sidecarPath(path)
    return (path:gsub("%.[Rr][Bb][Xx][LlMm]$", "")) .. ".scripts.json"
end

function ScriptKit.load(path)
    if type(readfile) ~= "function" then return nil end
    local sp = ScriptKit.sidecarPath(path)
    if type(isfile) == "function" then
        local okF, ex = pcall(isfile, sp)
        if okF and not ex then return nil end
    end
    local okR, raw = pcall(readfile, sp)
    if not okR or type(raw) ~= "string" or raw == "" then return nil end
    local okJ, obj = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
    if not okJ or type(obj) ~= "table" or type(obj.scripts) ~= "table" then return nil end
    local byKey = {}
    for _, e in ipairs(obj.scripts) do
        if type(e) == "table" and type(e.k) == "string" and type(e.s) == "string" then byKey[e.k] = e end
    end
    return byKey
end

local function applySource(scr, src)
    local direct = pcall(function() scr.Source = src end)
    if not direct and type(setscriptable) == "function" then
        direct = pcall(function() setscriptable(scr, "Source", true); scr.Source = src end)
    end
    if not direct and type(sethiddenproperty) == "function" then
        direct = pcall(sethiddenproperty, scr, "Source", src)
    end
    if not direct then
        -- cadangan: salinan teks di dalam script (StringValue) supaya isinya tidak hilang
        local n, i = 1, 1
        repeat
            local sv = Instance.new("StringValue")
            sv.Name = (n == 1) and "MH_Source" or ("MH_Source_" .. n)
            pcall(function() sv.Value = string.sub(src, i, i + 149999) end)
            sv.Parent = scr
            n += 1
            i += 150000
        until i > #src
    end
    return direct
end

function ScriptKit.restore(list, byKey)
    local info = {total = #list, matched = 0, direct = 0}
    if not byKey then return info end
    local counter = {}
    for _, scr in ipairs(list) do
        local okN, fn = pcall(scr.GetFullName, scr)
        if okN then
            counter[fn] = (counter[fn] or 0) + 1
            local e = byKey[fn .. "#" .. counter[fn]]
            if e then
                info.matched += 1
                if applySource(scr, e.s) then info.direct += 1 end
            end
        end
    end
    return info
end

---------------------------------------------------------------------
-- IMPORTER UTAMA
---------------------------------------------------------------------
local function importRbx(data, opts, report)
    local head = data:sub(1, 8)
    if head == "<roblox " then
        error("Format XML (.rbxlx/.rbxmx) belum didukung, simpan sebagai .rbxl biner", 0)
    end
    if data:sub(1, 14) ~= "<roblox!\137\255\r\n\26\n" then
        error("Bukan file RBXL/RBXM biner", 0)
    end

    local total = #data
    local rd = newReader(data)
    rd.p = 21
    local totalInst = rd.u32()
    rd.p = 33

    local classes, objs, isSvc, deferred, pending = {}, {}, {}, {}, {}
    local parentData
    local stat = {created = 0, skipped = 0, meshFallback = 0, skippedClasses = {}}
    local lastYield = os.clock()
    local function tick()
        if os.clock() - lastYield > 0.03 then task.wait(); lastYield = os.clock() end
    end

    local function apply(ref, name, val)
        local d = deferred[ref]
        if d then d.props[name] = val return end
        local inst = objs[ref]
        if not inst then return end
        if isSvc[ref] and not opts.serviceProps then return end
        setValue(inst, name, val)
    end

    -- 1) baca chunk satu per satu
    while rd.p <= total - 15 do
        local cname = data:sub(rd.p, rd.p + 3)
        rd.p += 4
        local clen = rd.u32()
        local ulen = rd.u32()
        rd.p += 4
        local payload
        if clen == 0 then
            payload = data:sub(rd.p, rd.p + ulen - 1)
            rd.p += ulen
        else
            payload = decompress(data:sub(rd.p, rd.p + clen - 1), ulen)
            rd.p += clen
        end
        if cname == "END\0" then break end

        local cr = newReader(payload)
        if cname == "INST" then
            local id = cr.u32()
            local className = cr.str()
            local hasService = cr.u8()
            local n = cr.u32()
            local refs = cr.refs(n)
            classes[id] = {name = className, refs = refs}
            for _, ref in ipairs(refs) do
                if hasService == 1 then
                    local okS, svc = pcall(game.GetService, game, className)
                    isSvc[ref] = true
                    objs[ref] = (okS and svc and not UI.ImportSkipServices[className]) and svc or false
                elseif SKIP_CLASS[className] then
                    objs[ref] = false
                    stat.skipped += 1
                elseif className == "MeshPart" then
                    objs[ref] = false
                    deferred[ref] = {props = {}}
                else
                    local okI, inst = pcall(Instance.new, className)
                    if okI and inst then
                        objs[ref] = inst
                        stat.created += 1
                    else
                        objs[ref] = false
                        stat.skipped += 1
                        stat.skippedClasses[className] = (stat.skippedClasses[className] or 0) + 1
                    end
                end
            end
        elseif cname == "PROP" then
            local cls = classes[cr.u32()]
            local pname = cr.str()
            local tid = cr.u8()
            if cls then
                local n = #cls.refs
                if tid == 0x13 then
                    local okR, targets = pcall(cr.refs, n)
                    if okR then
                        for i = 1, n do pending[#pending + 1] = {cls.refs[i], pname, targets[i]} end
                    end
                elseif D[tid] then
                    local okD, vals = pcall(D[tid], cr, n)
                    if okD and vals then
                        for i = 1, n do apply(cls.refs[i], pname, vals[i]) end
                    end
                end
            end
        elseif cname == "PRNT" then
            cr.u8()
            local n = cr.u32()
            local childs = cr.refs(n)
            local parents = cr.refs(n)
            parentData = {childs, parents, n}
        end
        report(5 + 60 * (rd.p / total), "Membaca map...", "Memproses data (" .. fmt(totalInst) .. " instance di file)")
        tick()
    end
    if not parentData then error("Struktur file tidak lengkap (PRNT tidak ditemukan)", 0) end

    -- 2) bangun MeshPart yang tertunda
    local meshRefs = {}
    for ref in pairs(deferred) do meshRefs[#meshRefs + 1] = ref end
    for i, ref in ipairs(meshRefs) do
        local d = deferred[ref]
        local id = d.props.MeshId
        local inst
        if type(id) == "string" and id ~= "" then inst = makeMeshPart(id) end
        if inst then
            stat.created += 1
        else
            inst = Instance.new("Part")
            stat.meshFallback += 1
        end
        objs[ref] = inst
        for k, v in pairs(d.props) do
            if k ~= "MeshId" then setValue(inst, k, v) end
        end
        report(65 + 15 * (i / #meshRefs), "Memuat mesh...", i .. " / " .. #meshRefs)
        tick()
    end

    -- 3) properti referensi (Part0, Part1, PrimaryPart, dll)
    for _, pr in ipairs(pending) do
        local inst, target = objs[pr[1]], objs[pr[3]]
        if inst and target and not isSvc[pr[1]] then
            pcall(function() inst[pr[2]] = target end)
        end
    end

    -- 4) mode Studio Lite: anchor + simpan nilai asli di atribut SL_
    if opts.studioMode then
        for ref, inst in pairs(objs) do
            if inst and not isSvc[ref] and inst:IsA("BasePart") then
                pcall(function()
                    if inst:GetAttribute("SL_Anchored") == nil then
                        inst:SetAttribute("SL_Anchored", inst.Anchored)
                        inst:SetAttribute("SL_CanCollide", inst.CanCollide)
                    end
                    inst.Anchored = true
                end)
            end
        end
    end

    -- 5) susun hierarki: bagian dalam dulu, baru ditempel ke service
    local childs, parents, n = parentData[1], parentData[2], parentData[3]
    for i = 1, n do
        local cRef, pRef = childs[i], parents[i]
        local c = objs[cRef]
        if c and not isSvc[cRef] and pRef ~= -1 and not isSvc[pRef] then
            local p = objs[pRef]
            if p then pcall(function() c.Parent = p end) end
        end
        if i % 500 == 0 then
            report(80 + 10 * (i / n), "Menyusun hierarki...", fmt(i) .. " / " .. fmt(n))
            tick()
        end
    end
    local attached = 0
    local tops = {}
    for i = 1, n do
        local cRef, pRef = childs[i], parents[i]
        local c = objs[cRef]
        if c and not isSvc[cRef] and (pRef == -1 or isSvc[pRef]) then
            local p = (pRef == -1) and workspace or objs[pRef]
            if p and not UI.ImportSkipNames[c.Name] then
                if pcall(function() c.Parent = p end) then
                    attached += 1
                    tops[#tops + 1] = c
                end
            end
        end
        if i % 500 == 0 then
            report(90 + 10 * (i / n), "Menempel ke game...", fmt(i) .. " / " .. fmt(n))
            tick()
        end
    end
    stat.attached = attached
    local scriptList = {}
    for _, top in ipairs(tops) do
        if top:IsA("LuaSourceContainer") then scriptList[#scriptList + 1] = top end
        local okD, d = pcall(top.GetDescendants, top)
        for _, inst in ipairs(okD and d or {}) do
            if inst:IsA("LuaSourceContainer") then scriptList[#scriptList + 1] = inst end
        end
    end
    stat.scriptList = scriptList
    return stat
end

---------------------------------------------------------------------
-- IMPORT VIA GetObjects (cara utama; parser biner di atas jadi cadangan)
---------------------------------------------------------------------
local function assetCandidates(path)
    local c, seen = {}, {}
    local function add(x)
        if x and x ~= "" and not seen[x] then seen[x] = true; c[#c + 1] = x end
    end
    local p = path:gsub("\\", "/")
    add(p)
    for _, pre in ipairs({"workspace/", "Delta/workspace/", "delta/workspace/",
        "Android/Delta/workspace/", "/sdcard/Delta/workspace/", "/sdcard/Android/Delta/workspace/"}) do
        if p:sub(1, #pre):lower() == pre:lower() then add(p:sub(#pre + 1)) end
    end
    add(p:match("[^/]+$"))
    return c
end

local function importViaAsset(path, opts, report)
    local getAsset = getcustomasset or getsynasset
    if type(getAsset) ~= "function" then
        return nil, "getcustomasset tidak tersedia"
    end
    local lastErr = "GetObjects tidak mengembalikan apa-apa"
    local objects
    for _, cand in ipairs(assetCandidates(path)) do
        local okA, asset = pcall(getAsset, cand)
        if okA and asset then
            local okO, res = pcall(function() return game:GetObjects(asset) end)
            if okO and type(res) == "table" and #res > 0 then
                objects = res
                break
            end
            lastErr = okO and lastErr or tostring(res)
        else
            lastErr = tostring(asset)
        end
    end
    if not objects then return nil, lastErr end

    -- periksa isi sebelum menempel: harus ada part / script
    local nParts, nScripts, summary = 0, 0, {}
    local scriptList = {}
    for _, obj in ipairs(objects) do
        local okD, d = pcall(obj.GetDescendants, obj)
        d = okD and d or {}
        for _, inst in ipairs(d) do
            if inst:IsA("BasePart") then nParts += 1
            elseif inst:IsA("LuaSourceContainer") then
                nScripts += 1
                scriptList[#scriptList + 1] = inst
            end
        end
        summary[#summary + 1] = obj.ClassName .. "=" .. (#d + 1)
    end
    local summaryTxt = table.concat(summary, ", ")
    pcall(warn, ("[CopyMap] GetObjects: %d part, %d script | %s"):format(nParts, nScripts, summaryTxt))
    if nParts == 0 and nScripts == 0 then
        return nil, "GetObjects tanpa part/script (" .. summaryTxt .. ")"
    end

    local stat = {created = 0, skipped = 0, meshFallback = 0, attached = 0,
        parts = nParts, scripts = nScripts, scriptList = scriptList}
    report(40, "Menempelkan ke game...", fmt(#objects) .. " objek level atas")

    local function place(inst, parent)
        if UI.ImportSkipNames[inst.Name] then stat.skipped += 1 return end
        if pcall(function() inst.Parent = parent end) then stat.attached += 1 else stat.skipped += 1 end
    end

    local lastYield = os.clock()
    for i, obj in ipairs(objects) do
        -- hasil GetObjects dari .rbxl biasanya berupa kontainer bernama service
        local okS, svc = pcall(game.GetService, game, obj.ClassName)
        if okS and svc then
            if not UI.ImportSkipServices[obj.ClassName] then
                for _, ch in ipairs(obj:GetChildren()) do place(ch, svc) end
            end
        else
            place(obj, workspace)
        end
        if os.clock() - lastYield > 0.03 then
            report(40 + 50 * (i / #objects), "Menempelkan ke game...", fmt(i) .. " / " .. fmt(#objects))
            task.wait(); lastYield = os.clock()
        end
    end

    local count = 0
    for _, obj in ipairs(objects) do
        count += 1
        local okD, d = pcall(obj.GetDescendants, obj)
        if okD then count += #d end
    end
    stat.created = count

    if opts.studioMode then
        report(92, "Mode Studio Lite...", "Anchor part")
        for _, obj in ipairs(objects) do
            local okD, d = pcall(obj.GetDescendants, obj)
            for _, inst in ipairs(okD and d or {}) do
                if inst:IsA("BasePart") then
                    pcall(function()
                        if inst:GetAttribute("SL_Anchored") == nil then
                            inst:SetAttribute("SL_Anchored", inst.Anchored)
                            inst:SetAttribute("SL_CanCollide", inst.CanCollide)
                        end
                        inst.Anchored = true
                    end)
                end
            end
        end
    end
    return stat
end

---------------------------------------------------------------------
-- DAFTAR FILE + TOMBOL IMPORT
---------------------------------------------------------------------
local impBusy, impRunning, impT0 = false, false, 0
local selectedFile
local impCards = {}

local function fileBase(p)
    return ((p:gsub("\\", "/")):match("[^/]+$")) or p
end

local function impReport(pct, title, sub)
    pct = math.clamp(pct or 0, 0, 100)
    TweenService:Create(impBar, TweenInfo.new(0.2), {Size = UDim2.fromScale(pct / 100, 1)}):Play()
    impPct.Text = math.floor(pct) .. "%"
    if title then impTitle.Text = title end
    if sub then impSub.Text = sub end
    if pct >= 100 then
        impRunning = false
        impTime.Text = mmss(os.clock() - impT0)
    end
end

local function impBegin()
    impRunning, impT0 = true, os.clock()
    task.spawn(function()
        while impRunning and gui.Parent do
            impTime.Text = mmss(os.clock() - impT0)
            task.wait(0.25)
        end
    end)
end

local function findMapFiles()
    local seen, out = {}, {}
    if type(listfiles) ~= "function" then return out end
    for _, dir in ipairs({"", ".", "workspace"}) do
        local okL, files = pcall(listfiles, dir)
        if okL and type(files) == "table" then
            for _, p in ipairs(files) do
                local low = p:lower()
                local key = fileBase(low)
                if (low:match("%.rbxl$") or low:match("%.rbxm$")) and not seen[key] then
                    seen[key] = true
                    out[#out + 1] = p
                end
            end
        end
    end
    table.sort(out, function(a, b) return fileBase(a):lower() < fileBase(b):lower() end)
    return out
end

local function paintFiles()
    for _, c in ipairs(impCards) do
        if c.path then
            local on = c.path == selectedFile
            c.stroke.Color = on and T.Accent or T.Line
            c.stroke.Thickness = on and 1.6 or 1
            c.circle.BackgroundColor3 = on and T.Accent or T.Field
            c.dot.Visible = on
        end
    end
end

local function selectFile(p)
    selectedFile = p
    valFile.Text = fileBase(p)
    valSize.Text = "-"
    valInst.Text = "-"
    valStat.Text = "Siap import"
    paintFiles()
end

local function refreshFiles()
    for _, c in ipairs(impCards) do c.frame:Destroy() end
    impCards = {}
    local files = findMapFiles()
    lblFileCount.Text = #files .. " file"
    if #files == 0 then
        local lbl = label(impList, {
            Text = "Belum ada file .rbxl di folder workspace executor.\nCopy map dulu, lalu tekan MUAT ULANG.",
            TextSize = 9, TextColor3 = T.Muted, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 60),
        })
        impCards[1] = {frame = lbl}
        return
    end
    for idx, p in ipairs(files) do
        local card = new("Frame", {
            Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = idx,
        }, impList)
        corner(card, 12)
        local st = stroke(card, T.Line, 1)
        label(card, {Text = fileBase(p), Font = Enum.Font.GothamBold, TextSize = 11,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(16, 9), Size = UDim2.new(1, -66, 0, 18)})
        label(card, {Text = p:lower():match("%.rbxm$") and "Model biner (.rbxm)" or "Place biner (.rbxl)",
            TextSize = 9, TextColor3 = T.Muted,
            Position = UDim2.fromOffset(16, 28), Size = UDim2.new(1, -66, 0, 14)})
        local circle = new("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(28, 28), BackgroundColor3 = T.Field, BorderSizePixel = 0,
        }, card)
        corner(circle, 14)
        local dot = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(8, 8), BackgroundColor3 = T.Text, BorderSizePixel = 0, Visible = false,
        }, circle)
        corner(dot, 4)
        local hit = new("TextButton", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3,
        }, card)
        hit.MouseButton1Click:Connect(function() selectFile(p) end)
        impCards[#impCards + 1] = {frame = card, stroke = st, circle = circle, dot = dot, path = p}
    end
    -- pertahankan pilihan lama kalau filenya masih ada
    local still = false
    for _, p in ipairs(files) do if p == selectedFile then still = true end end
    if still then paintFiles() elseif #files == 1 then selectFile(files[1]) else selectedFile = nil end
end

UI.OnImport = function(path, opts)
    if impBusy then return end
    impBusy = true
    impBar.BackgroundColor3 = T.Accent

    local function fail(title, sub)
        impRunning = false
        impBar.BackgroundColor3 = T.Bad
        impReport(100, title, sub)
        impPct.Text = "GAGAL"
        valStat.Text = "Gagal"
        impBusy = false
    end

    if type(readfile) ~= "function" then
        return fail("Executor tidak didukung", "Fungsi readfile tidak ditemukan")
    end
    valStat.Text = "Membaca..."
    impReport(2, "Membaca file...", fileBase(path))
    local okR, data = pcall(readfile, path)
    if not okR or type(data) ~= "string" or #data == 0 then
        return fail("File tidak bisa dibaca", tostring(data):sub(1, 70))
    end
    valSize.Text = string.format("%.2f MB", #data / 1048576)

    impReport(10, "Mencoba import (GetObjects)...", fileBase(path))
    local res, assetErr = importViaAsset(path, opts or {}, impReport)
    if not res then
        pcall(warn, "[CopyMap] GetObjects gagal: " .. tostring(assetErr))
        impReport(12, "Cadangan: parser biner...", tostring(assetErr):sub(1, 60))
        local okI, r2 = pcall(importRbx, data, opts or {}, impReport)
        if not okI then
            pcall(warn, "[CopyMap] Parser biner gagal: " .. tostring(r2))
            return fail("Import gagal",
                "GetObjects: " .. tostring(assetErr):sub(1, 40) .. " | Parser: " .. (tostring(r2):gsub("^[^:]*:%d+: ", "")):sub(1, 70))
        end
        res = r2
    end

    valInst.Text = fmt(res.created)
    valStat.Text = "Selesai"
    local sub = fmt(res.created) .. " instance dibuat"
    if res.meshFallback > 0 then
        sub ..= ", " .. res.meshFallback .. " mesh jadi Part biasa"
    end
    if res.skipped > 0 then
        sub ..= ", " .. res.skipped .. " dilewati"
    end
    if res.parts then
        sub ..= " (" .. res.parts .. " part, " .. res.scripts .. " script)"
    end
    local nScr = res.scriptList and #res.scriptList or 0
    if nScr > 0 then
        impReport(96, "Memasang isi script...", nScr .. " script")
        local byKey = ScriptKit.load(path)
        if byKey then
            local ri = ScriptKit.restore(res.scriptList, byKey)
            sub ..= " | isi script: " .. ri.matched .. "/" .. ri.total .. " terpasang"
            if ri.matched > ri.direct then
                sub ..= " (" .. (ri.matched - ri.direct) .. " disalin ke MH_Source di dalam script)"
            end
        else
            sub ..= " | " .. nScr .. " script TANPA isi (file " .. fileBase(ScriptKit.sidecarPath(path)) ..
                " tidak ada; copy ulang map dengan versi ini)"
        end
    end
    impReport(100, "Import selesai", sub)
    impBusy = false
end

btnImport.MouseButton1Click:Connect(function()
    if impBusy then return end
    if not selectedFile then
        impTitle.Text = "Belum ada file dipilih"
        impSub.Text = "Pilih file di daftar sebelah kiri"
        return
    end
    if not UI.OnImport then return end
    impReport(0, "Memulai import...", fileBase(selectedFile))
    impBegin()
    task.spawn(UI.OnImport, selectedFile, {studioMode = getStudioMode(), serviceProps = getSvcProps()})
end)

btnRefresh.MouseButton1Click:Connect(refreshFiles)
tabImport.MouseButton1Click:Connect(refreshFiles)
pcall(refreshFiles)

---------------------------------------------------------------------
-- FITUR: OBSTACLE REPLACER (dari v2.1, disatukan + diperbaiki + fitur tambahan)
-- Semua perubahan terjadi di sisi client (hanya terlihat olehmu).
---------------------------------------------------------------------
local function buildReplacer()
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()
    local conns = {}
    table.insert(UI.Cleanups, function()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    end)

    local COL_OLD = Color3.fromRGB(255, 184, 28)
    local COL_NEW = Color3.fromRGB(60, 200, 110)
    local WARN = Color3.fromRGB(214, 140, 30)
    local MAX_SELECT, MAX_OUTLINE, MAX_UNDO = 3000, 60, 10
    local SIGNS = {-1, 1}

    local opt = {
        scale = 1,        -- 1 proporsional, 2 ukuran asli
        rot = 1,          -- 1 ikut objek lama, 2 rotasi asli
        hl = true,        -- outline
        scope = 1,        -- 1 seluruh map, 2 folder sama
        crit = 1,         -- 1 nama sama, 2 nama + ukuran
        tap = 1,          -- 1 otomatis (model induk), 2 part saja
        yaw = 0,          -- 0..3 (x90 derajat)
        folderCopy = 1,   -- 1 langsung, 2 salin dulu
        shift = 1,        -- 1 tidak, 2 +X, 3 +Z
        align = 1,        -- 1 tengah, 2 rata bawah, 3 rata atas
        anchor = 1,       -- 1 anchor hasil, 2 biarkan
        nameMode = 1,     -- 1 nama objek baru, 2 ikut nama lama
        scaleMul = 100,   -- persen tambahan
        offY = 0,         -- geser vertikal (stud)
    }

    local newObj, newBox = nil, nil
    local oldList, oldSet, oldBoxes = {}, {}, {}
    local undoStack = {}
    local pickMode = nil
    local oldSource = ""
    local busy = false

    ---------------------------------------------------------------
    -- KERANGKA UI: sidebar + halaman
    ---------------------------------------------------------------
    local root = replacerPage

    local side = new("Frame", {
        Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(112, 360),
        BackgroundColor3 = T.Panel, BorderSizePixel = 0,
    }, root)
    corner(side, 14)
    stroke(side, T.Line, 1)
    new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center}, side)
    new("UIPadding", {PaddingTop = UDim.new(0, 10)}, side)

    local panel = new("Frame", {
        Position = UDim2.fromOffset(134, 10), Size = UDim2.fromOffset(612, 360),
        BackgroundColor3 = T.Panel, BorderSizePixel = 0, ClipsDescendants = true,
    }, root)
    corner(panel, 14)
    stroke(panel, T.Line, 1)

    local tabs, pages = {}, {}
    local function setTab(name)
        for n, p in pairs(pages) do p.Visible = (n == name) end
        for n, b in pairs(tabs) do
            local on = n == name
            b.BackgroundColor3 = on and T.Accent or T.Field
            b.TextColor3 = on and T.Text or T.Muted
        end
    end
    local function makePage(name)
        local p = new("ScrollingFrame", {
            Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = T.AccentLn, CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
        }, panel)
        new("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 16),
            PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 16)}, p)
        new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, p)
        pages[name] = p
        return p
    end
    local function makeTab(name, text, order)
        local b = new("TextButton", {
            LayoutOrder = order, Size = UDim2.new(1, -16, 0, 32), BackgroundColor3 = T.Field,
            Text = text, TextColor3 = T.Muted, TextSize = 10, Font = Enum.Font.GothamBold,
            AutoButtonColor = false, BorderSizePixel = 0,
        }, side)
        corner(b, 10)
        tabs[name] = b
        b.MouseButton1Click:Connect(function() setTab(name) end)
        return b
    end

    -- widget kecil
    local function sec(parent, text, order)
        return label(parent, {
            LayoutOrder = order, Size = UDim2.new(1, 0, 0, 16), Text = text,
            Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = T.Title,
        })
    end
    local function card(parent, order, h)
        local f = new("Frame", {LayoutOrder = order, Size = UDim2.new(1, 0, 0, h),
            BackgroundColor3 = T.Card, BorderSizePixel = 0}, parent)
        corner(f, 12)
        stroke(f, T.Line, 1)
        new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}, f)
        return f
    end
    local function note(parent, order, text)
        local l = label(parent, {
            LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            Text = text, TextSize = 10, TextColor3 = T.Muted, TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top, Parent = parent,
        })
        return l
    end
    local function rbtn(parent, text, primary, size, pos)
        local b = button(parent, {
            Text = text, Size = size, Position = pos or UDim2.new(),
            BackgroundColor3 = primary and T.Accent or T.Field,
            TextColor3 = primary and Color3.fromRGB(40, 28, 6) or T.Text, TextSize = 10,
        })
        corner(b, 10)
        if not primary then stroke(b, T.Line, 1) end
        return b
    end
    local function choice(parent, order, prefix, options, init, onChange)
        local i = init or 1
        local b = button(parent, {Text = "", Size = UDim2.new(1, 0, 0, 32), LayoutOrder = order,
            BackgroundColor3 = T.Card, TextSize = 10})
        corner(b, 10)
        stroke(b, T.Line, 1)
        local function paint() b.Text = prefix .. options[i] .. "  ▸" end
        b.MouseButton1Click:Connect(function()
            i = i % #options + 1
            paint()
            onChange(i)
        end)
        paint()
        return b
    end
    local function numRow(parent, order, caption, init, lo, hi, onChange)
        local current = init
        local row = new("Frame", {LayoutOrder = order, Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = T.Card, BorderSizePixel = 0}, parent)
        corner(row, 10)
        stroke(row, T.Line, 1)
        label(row, {Text = caption, TextSize = 10, Font = Enum.Font.GothamBold,
            Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -110, 1, 0)})
        local box = new("TextBox", {
            Position = UDim2.new(1, -92, 0.5, -12), Size = UDim2.fromOffset(80, 24),
            BackgroundColor3 = T.Field, BorderSizePixel = 0, Text = tostring(init),
            TextColor3 = T.Text, TextSize = 11, Font = Enum.Font.GothamBold, ClearTextOnFocus = false,
        }, row)
        corner(box, 8)
        box.FocusLost:Connect(function()
            local v = tonumber(box.Text)
            if v then current = math.clamp(v, lo, hi) end
            box.Text = tostring(current)
            onChange(current)
        end)
    end

    ---------------------------------------------------------------
    -- TOAST
    ---------------------------------------------------------------
    local toastId = 0
    local toastLbl = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 44),
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 30),
        BackgroundColor3 = T.Window, TextColor3 = T.Text, TextSize = 11, Font = Enum.Font.GothamBold,
        Text = "", ZIndex = 40, BorderSizePixel = 0, TextTruncate = Enum.TextTruncate.AtEnd,
    }, root)
    corner(toastLbl, 15)
    local toastStroke = stroke(toastLbl, T.Accent, 1.5)
    new("UIPadding", {PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16)}, toastLbl)
    new("UISizeConstraint", {MaxSize = Vector2.new(640, 30)}, toastLbl)
    local function toast(text, color)
        toastId += 1
        local id = toastId
        toastLbl.Text = text
        toastLbl.TextColor3 = color or T.Text
        toastStroke.Color = color or T.Accent
        TweenService:Create(toastLbl, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Position = UDim2.new(0.5, 0, 1, -8)}):Play()
        task.delay(2.8, function()
            if id == toastId then
                TweenService:Create(toastLbl, TweenInfo.new(0.25), {Position = UDim2.new(0.5, 0, 1, 44)}):Play()
            end
        end)
        UI.FabNote(text, 3)
    end

    ---------------------------------------------------------------
    -- GEOMETRI (arah & kemiringan dibaca dari BENTUK objek, bukan pivot)
    ---------------------------------------------------------------
    local function allParts(obj)
        if obj:IsA("BasePart") then return {obj} end
        local t = {}
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("BasePart") and not d:IsA("Terrain") then table.insert(t, d) end
        end
        return t
    end

    local function getSize(obj)
        if obj:IsA("BasePart") then return obj.Size end
        local ok, s = pcall(function() return obj:GetExtentsSize() end)
        if ok and s then return s end
        return Vector3.new(1, 1, 1)
    end

    local function domSign(v)
        local ax, ay, az = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
        local m = math.max(ax, ay, az)
        local c = (m == ax and v.X) or (m == ay and v.Y) or v.Z
        if c >= 0 then return v else return -v end
    end

    local function getFrame(obj)
        local parts = allParts(obj)
        if #parts == 0 then return nil end
        local main, bv = parts[1], -1
        for _, p in ipairs(parts) do
            local v = p.Size.X * p.Size.Y * p.Size.Z
            if v > bv then main, bv = p, v end
        end
        local cf, msz = main.CFrame, main.Size
        local ax = {{msz.X, cf.RightVector}, {msz.Y, cf.UpVector}, {msz.Z, cf.LookVector}}
        table.sort(ax, function(a, b) return a[1] > b[1] end)
        local L = domSign(ax[1][2])
        local S = ax[3][2]
        if math.abs(S.Y) > .3 then
            if S.Y < 0 then S = -S end
        else
            S = domSign(S)
        end
        local M = S:Cross(L)
        local R = CFrame.fromMatrix(Vector3.new(), L, M, S)

        local INF = math.huge
        local mn, mx = Vector3.new(INF, INF, INF), Vector3.new(-INF, -INF, -INF)
        for i, p in ipairs(parts) do
            local pcf, h = p.CFrame, p.Size * .5
            for _, sx in ipairs(SIGNS) do for _, sy in ipairs(SIGNS) do for _, sz in ipairs(SIGNS) do
                local l = R:PointToObjectSpace(pcf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)))
                mn = Vector3.new(math.min(mn.X, l.X), math.min(mn.Y, l.Y), math.min(mn.Z, l.Z))
                mx = Vector3.new(math.max(mx.X, l.X), math.max(mx.Y, l.Y), math.max(mx.Z, l.Z))
            end end end
            if i % 3000 == 0 then RunService.Heartbeat:Wait() end
        end
        return {rot = R, size = mx - mn, center = R:PointToWorldSpace((mn + mx) * .5)}
    end

    -- batas Y dunia (untuk rata bawah / rata atas)
    local function worldYBounds(obj)
        local lo, hi = math.huge, -math.huge
        for _, p in ipairs(allParts(obj)) do
            local pcf, h = p.CFrame, p.Size * .5
            for _, sx in ipairs(SIGNS) do for _, sy in ipairs(SIGNS) do for _, sz in ipairs(SIGNS) do
                local y = pcf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)).Y
                if y < lo then lo = y end
                if y > hi then hi = y end
            end end end
        end
        return lo, hi
    end

    local function scaleUniform(obj, f)
        if obj:IsA("Model") then
            pcall(function() obj:ScaleTo(obj:GetScale() * f) end)
        elseif obj:IsA("BasePart") then
            obj.Size = obj.Size * f
        end
    end
    local function rotateAbout(obj, point, delta)
        local m = CFrame.new(point) * delta * CFrame.new(-point)
        if obj:IsA("Model") then obj:PivotTo(m * obj:GetPivot())
        elseif obj:IsA("BasePart") then obj.CFrame = m * obj.CFrame end
    end
    local function shiftBy(obj, v)
        if obj:IsA("Model") then obj:PivotTo(obj:GetPivot() + v)
        elseif obj:IsA("BasePart") then obj.CFrame = obj.CFrame + v end
    end

    ---------------------------------------------------------------
    -- SELEKSI & OUTLINE
    ---------------------------------------------------------------
    local function makeBox(obj, color)
        if not opt.hl then return nil end
        local ok, b = pcall(function()
            local s = Instance.new("SelectionBox")
            s.Adornee = obj
            s.Color3 = color
            s.LineThickness = .04
            s.SurfaceColor3 = color
            s.SurfaceTransparency = .82
            s.Parent = gui
            return s
        end)
        return ok and b or nil
    end

    local newName, oldCount, newHint, btnRep
    local function refreshInfo()
        newName.Text = newObj and ("📦  " .. newObj.Name) or "Belum dipilih"
        if #oldList == 0 then
            oldCount.Text = "Belum dipilih..."
            oldCount.TextColor3 = T.Muted
        else
            oldCount.Text = oldSource .. "  (" .. #oldList .. " objek)"
            oldCount.TextColor3 = T.Text
        end
        if btnRep and not busy then btnRep.Text = "REPLACE " .. #oldList .. " OBSTACLES" end
    end
    local function removeOld(obj, quiet)
        local i = table.find(oldList, obj)
        if i then table.remove(oldList, i) end
        oldSet[obj] = nil
        if oldBoxes[obj] then oldBoxes[obj]:Destroy(); oldBoxes[obj] = nil end
        if not quiet then refreshInfo() end
    end
    local function clearOld()
        for _, b in pairs(oldBoxes) do b:Destroy() end
        oldList, oldSet, oldBoxes = {}, {}, {}
        refreshInfo()
    end
    local function addOld(obj, noBox, quiet)
        if obj == newObj then toast("Itu objek baru, pilih yang lain", T.Bad) return end
        if oldSet[obj] then return end
        oldSet[obj] = true
        table.insert(oldList, obj)
        oldBoxes[obj] = (not noBox) and makeBox(obj, COL_OLD) or nil
        if not quiet then refreshInfo() end
    end
    local function setNew(obj)
        if newBox then newBox:Destroy(); newBox = nil end
        if oldSet[obj] then removeOld(obj) end
        newObj = obj
        newBox = makeBox(obj, COL_NEW)
        refreshInfo()
        toast("Objek baru: " .. obj.Name, T.Ok)
    end
    local function rebuildBoxes()
        if newBox then newBox:Destroy(); newBox = nil end
        for _, b in pairs(oldBoxes) do b:Destroy() end
        oldBoxes = {}
        if newObj and newObj.Parent then newBox = makeBox(newObj, COL_NEW) end
        if #oldList <= MAX_OUTLINE then
            for _, o in ipairs(oldList) do oldBoxes[o] = makeBox(o, COL_OLD) end
        end
    end

    local btnPick, btnAdd, btnFolder, btnName, btnBox, btnSearch, filterBox

    -- area kotak (2 tap)
    local boxFirst = nil
    local selRect = new("Frame", {Visible = false, BackgroundColor3 = COL_OLD, BackgroundTransparency = .75,
        BorderSizePixel = 0, ZIndex = 60}, gui)
    stroke(selRect, COL_OLD, 2)
    local selDot = new("Frame", {Visible = false, Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(.5, .5),
        BackgroundColor3 = COL_OLD, BorderSizePixel = 0, ZIndex = 60}, gui)
    corner(selDot, 8)
    local function boxReset()
        boxFirst = nil
        selRect.Visible = false
        selDot.Visible = false
    end

    local PICK_HINT = {
        new = "Tap objek BARU di dunia 3D",
        old = "Tap objek lama (tap lagi = batal). Tap ⚡ kalau selesai",
        folder = "Tap 1 objek di dalam folder",
        name = "Tap 1 obstacle: semua yang sama ikut terpilih. Tap ⚡ kalau selesai",
        box = "Tap 2 sudut area (jangan geser kamera). Tap ⚡ kalau selesai",
    }
    local function setPick(mode)
        pickMode = mode
        btnPick.Text = (mode == "new") and "BATAL" or "PILIH"
        btnAdd.Text = (mode == "old") and "SELESAI" or "TAMBAH"
        btnFolder.Text = (mode == "folder") and "BATAL" or "FOLDER"
        btnName.Text = (mode == "name") and "SELESAI" or "⚡ SAMA NAMA (SEKALIGUS)"
        btnBox.Text = (mode == "box") and "SELESAI" or "▭ KOTAK (2 TAP)"
        if mode ~= "box" then boxReset() end
        newHint.Text = (mode == "new") and "Tap objek baru di dunia 3D..." or "Tekan PILIH lalu tap objeknya"
    end
    -- mulai memilih: jendela diminimize supaya seluruh layar bebas untuk di-tap
    local function startPick(mode)
        if pickMode == mode then setPick(nil) return end
        setPick(mode)
        UI.Minimize()
        UI.FabNote(PICK_HINT[mode], 6)
    end
    local function endPick()
        setPick(nil)
        UI.Restore()
    end
    UI.OnRestore = function()
        if pickMode then setPick(nil) end
    end

    ---------------------------------------------------------------
    -- PILIH SEKALIGUS: nama sama / cari nama / kotak
    ---------------------------------------------------------------
    local function sizeSig(o)
        local v = getSize(o)
        local t = {v.X, v.Y, v.Z}
        table.sort(t)
        return t
    end
    local function sameSize(a, b)
        for i = 1, 3 do
            if math.abs(a[i] - b[i]) > math.max(.05, b[i] * .05) then return false end
        end
        return true
    end
    local playerChars = {}
    local function refreshChars()
        playerChars = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl.Character then table.insert(playerChars, pl.Character) end
        end
    end
    local function inCharacter(o)
        for _, ch in ipairs(playerChars) do
            if o == ch or o:IsDescendantOf(ch) then return true end
        end
        return false
    end

    -- buang objek yang berada di dalam objek lain yang juga terpilih
    local function dedupeNested(found)
        local set = {}
        for _, d in ipairs(found) do set[d] = true end
        local clean = {}
        for _, d in ipairs(found) do
            local nested, a = false, d.Parent
            while a and a ~= workspace do
                if set[a] then nested = true break end
                a = a.Parent
            end
            if not nested then table.insert(clean, d) end
        end
        return clean
    end

    local function commitFound(found, tag)
        found = dedupeNested(found)
        if #found == 0 then
            toast("Tidak ada yang cocok", WARN)
            return
        end
        if #found > MAX_SELECT then
            toast("Terlalu banyak (" .. #found .. "). Persempit filter/area", T.Bad)
            return
        end
        local noBox = #found > MAX_OUTLINE
        oldSource = (#oldList == 0) and tag or "campuran"
        local added = 0
        for i, d in ipairs(found) do
            if not oldSet[d] then addOld(d, noBox, true); added += 1 end
            if i % 500 == 0 then RunService.Heartbeat:Wait() end
        end
        refreshInfo()
        toast(tag .. " • " .. added .. " objek ditambahkan" .. (noBox and " • outline off" or ""),
            added > 0 and T.Ok or WARN)
        UI.FabNote(tag .. " +" .. added .. " • total " .. #oldList, 4)
    end

    local function addSimilar(ref)
        refreshChars()
        local rootInst = (opt.scope == 2 and ref.Parent) or workspace
        local generic = (ref.Name == ref.ClassName) or ref.Name == "Part" or ref.Name == "Model"
        local needSize = (opt.crit == 2) or generic
        local refSig = needSize and sizeSig(ref) or nil
        local found = {}
        for i, d in ipairs(rootInst:GetDescendants()) do
            if d ~= newObj and d.Name == ref.Name and d.ClassName == ref.ClassName
                and (d:IsA("Model") or d:IsA("BasePart")) and not d:IsA("Terrain")
                and not (newObj and d:IsDescendantOf(newObj)) and not inCharacter(d)
                and (not needSize or sameSize(sizeSig(d), refSig)) then
                table.insert(found, d)
            end
            if i % 4000 == 0 then RunService.Heartbeat:Wait() end
        end
        commitFound(found, "⚡ " .. ref.Name .. (generic and " (cocok ukuran)" or ""))
    end

    local function unitOf(part)
        if opt.tap == 1 and part.Parent and part.Parent ~= workspace and part.Parent:IsA("Model") then
            return part.Parent
        end
        return part
    end

    local function searchByName()
        local q = string.lower(filterBox.Text or "")
        if q == "" then toast("Ketik nama dulu di kolom filter", T.Bad) return end
        refreshChars()
        local found = {}
        for i, d in ipairs(workspace:GetDescendants()) do
            if (d:IsA("Model") or d:IsA("BasePart")) and not d:IsA("Terrain")
                and string.find(string.lower(d.Name), q, 1, true)
                and d ~= newObj and not (newObj and d:IsDescendantOf(newObj)) and not inCharacter(d) then
                table.insert(found, d)
            end
            if i % 4000 == 0 then RunService.Heartbeat:Wait() end
        end
        commitFound(found, "🔎 " .. filterBox.Text)
    end

    local function boxSelect(p1, p2)
        local cam = workspace.CurrentCamera
        if not cam then return end
        refreshChars()
        local x0, x1 = math.min(p1.X, p2.X), math.max(p1.X, p2.X)
        local y0, y1 = math.min(p1.Y, p2.Y), math.max(p1.Y, p2.Y)
        local q = string.lower(filterBox.Text or "")
        local seen, found = {}, {}
        for i, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") and not d:IsA("Terrain") then
                local v, on = cam:WorldToViewportPoint(d.Position)
                if on and v.X >= x0 and v.X <= x1 and v.Y >= y0 and v.Y <= y1 then
                    local u = unitOf(d)
                    if not seen[u] then
                        seen[u] = true
                        local sz = getSize(u)
                        if u ~= newObj and not (newObj and u:IsDescendantOf(newObj)) and not inCharacter(u)
                            and math.max(sz.X, sz.Y, sz.Z) <= 400
                            and (q == "" or string.find(string.lower(u.Name), q, 1, true)) then
                            table.insert(found, u)
                        end
                    end
                end
            end
            if i % 4000 == 0 then RunService.Heartbeat:Wait() end
        end
        commitFound(found, "▭ kotak")
    end

    local function boxTap()
        local pos = UserInputService:GetMouseLocation()
        if not boxFirst then
            boxFirst = pos
            selDot.Position = UDim2.fromOffset(pos.X, pos.Y)
            selDot.Visible = true
            UI.FabNote("▭ Sudut 1 ✔  tap sudut seberangnya", 5)
        else
            local p1 = boxFirst
            boxFirst = nil
            selDot.Visible = false
            selRect.Position = UDim2.fromOffset(math.min(p1.X, pos.X), math.min(p1.Y, pos.Y))
            selRect.Size = UDim2.fromOffset(math.abs(p1.X - pos.X), math.abs(p1.Y - pos.Y))
            selRect.Visible = true
            boxSelect(p1, pos)
            task.delay(.8, function() selRect.Visible = false end)
        end
    end

    -- salin folder (map asli tetap aman)
    local function copyContainer(src)
        local cp = src:Clone()
        if not cp then error("folder tidak bisa digandakan") end
        cp.Name = src.Name .. "_COPY"
        if opt.shift ~= 1 then
            local v = (opt.shift == 2) and Vector3.new(400, 0, 0) or Vector3.new(0, 0, 400)
            for _, ch in ipairs(cp:GetChildren()) do
                if ch:IsA("Model") or ch:IsA("BasePart") then shiftBy(ch, v) end
            end
        end
        cp.Parent = src.Parent
        return cp
    end

    -- tap di dunia 3D
    table.insert(conns, Mouse.Button1Down:Connect(function()
        if not pickMode then return end
        if UI.OverGui(UserInputService:GetMouseLocation()) then return end
        if pickMode == "box" then boxTap() return end
        local t = Mouse.Target
        if not t then toast("Tidak ada objek di situ", T.Bad) return end
        if t:IsA("Terrain") then toast("Terrain tidak bisa dipilih", T.Bad) return end
        local obj = unitOf(t)
        if pickMode == "new" then
            setNew(obj)
            endPick()
        elseif pickMode == "old" then
            if #oldList == 0 then oldSource = "✋ manual" elseif oldSource ~= "✋ manual" then oldSource = "campuran" end
            if oldSet[obj] then removeOld(obj) else addOld(obj) end
            UI.FabNote("Terpilih: " .. #oldList .. " objek", 2)
        elseif pickMode == "name" then
            addSimilar(obj)
        elseif pickMode == "folder" then
            local parent = obj.Parent
            clearOld()
            oldSource = "📂 " .. ((parent and parent ~= workspace) and parent.Name or obj.Name)
            if opt.folderCopy == 2 and parent and parent ~= workspace then
                local okc, cp = pcall(copyContainer, parent)
                if okc and cp then
                    parent = cp
                    oldSource = "📋 " .. cp.Name
                else
                    toast("Gagal menyalin folder", T.Bad)
                    return
                end
            end
            local n = 0
            if parent and parent ~= workspace then
                for _, ch in ipairs(parent:GetChildren()) do
                    if (ch:IsA("Model") or ch:IsA("BasePart")) and ch ~= newObj and not ch:IsA("Terrain") then
                        addOld(ch, #parent:GetChildren() > MAX_OUTLINE, true)
                        n += 1
                    end
                end
            else
                addOld(obj, false, true)
                n = 1
            end
            refreshInfo()
            toast(n .. " objek ditambahkan", T.Ok)
            endPick()
        end
    end))

    ---------------------------------------------------------------
    -- REPLACE / HAPUS / UNDO
    ---------------------------------------------------------------
    local function pushUndo(rec)
        if #rec == 0 then return end
        table.insert(undoStack, rec)
        if #undoStack > MAX_UNDO then table.remove(undoStack, 1) end
    end

    local function liveList()
        local list = {}
        for _, o in ipairs(oldList) do
            if o ~= newObj and o.Parent and o:IsDescendantOf(workspace) then table.insert(list, o) end
        end
        return list
    end

    local function doReplace(keep)
        if busy then return end
        if not newObj or not newObj.Parent then toast("Pilih objek baru dulu!", T.Bad) return end
        local list = liveList()
        if #list == 0 then toast("Pilih objek lama dulu!", T.Bad) return end
        busy = true
        setPick(nil)
        pcall(function() newObj.Archivable = true end)
        task.spawn(function()
            local ok, fail, rec = 0, 0, {}
            local firstErr
            for i, old in ipairs(list) do
                local c
                local success, err = pcall(function()
                    if not old.Parent or not old:IsDescendantOf(workspace) then error("objek lama sudah hilang") end
                    local parent = old.Parent
                    local fo = getFrame(old)
                    if not fo then error("objek lama tidak punya part") end
                    c = newObj:Clone()
                    if not c then error("objek baru tidak bisa digandakan") end
                    c.Parent = parent
                    local fn = getFrame(c)
                    if not fn then error("objek baru tidak punya part") end
                    if opt.scale == 1 and fn.size.X > .001 then
                        scaleUniform(c, fo.size.X / fn.size.X)
                        fn = getFrame(c)
                    end
                    if opt.scaleMul ~= 100 then
                        scaleUniform(c, opt.scaleMul / 100)
                        fn = getFrame(c)
                    end
                    if opt.rot == 1 then
                        local target = fo.rot * CFrame.Angles(0, 0, math.rad(90 * opt.yaw))
                        rotateAbout(c, fn.center, target * fn.rot:Inverse())
                        fn = getFrame(c)
                    end
                    shiftBy(c, fo.center - fn.center)
                    if opt.align ~= 1 then
                        local ol, oh = worldYBounds(old)
                        local nl, nh = worldYBounds(c)
                        shiftBy(c, Vector3.new(0, (opt.align == 2) and (ol - nl) or (oh - nh), 0))
                    end
                    if opt.offY ~= 0 then shiftBy(c, Vector3.new(0, opt.offY, 0)) end
                    if opt.nameMode == 2 then c.Name = old.Name end
                    if opt.anchor == 1 then
                        for _, p in ipairs(allParts(c)) do p.Anchored = true end
                    end
                    if keep then
                        table.insert(rec, {old = old, parent = parent, new = c})
                        old.Parent = nil
                    else
                        old:Destroy()
                    end
                end)
                if success then
                    ok += 1
                else
                    fail += 1
                    firstErr = firstErr or tostring(err)
                    warn("[CopyMap/Replacer] gagal:", err)
                    if c then pcall(function() c:Destroy() end) end
                end
                if i % 10 == 0 then
                    btnRep.Text = "MEMPROSES " .. i .. " / " .. #list
                    RunService.Heartbeat:Wait()
                end
            end
            if keep then pushUndo(rec) end
            busy = false
            clearOld()
            if fail == 0 then
                toast("Berhasil mengganti " .. ok .. " obstacle!", T.Ok)
            else
                toast(ok .. " berhasil, " .. fail .. " gagal: " .. string.sub(firstErr or "?", 1, 60), WARN)
            end
        end)
    end

    -- hapus objek terpilih (bisa di-UNDO)
    local function doRemove()
        if busy then return end
        local list = liveList()
        if #list == 0 then toast("Pilih objek yang mau dihapus dulu", T.Bad) return end
        local rec = {}
        for _, o in ipairs(list) do
            table.insert(rec, {old = o, parent = o.Parent})
            pcall(function() o.Parent = nil end)
        end
        pushUndo(rec)
        clearOld()
        toast(#rec .. " objek dihapus (bisa UNDO)", T.Ok)
    end

    local function doUndo()
        local rec = table.remove(undoStack)
        if not rec then toast("Tidak ada yang bisa di-undo", WARN) return end
        local n = 0
        for _, r in ipairs(rec) do
            pcall(function()
                if r.new and r.new.Parent then r.new:Destroy() end
                r.old.Parent = r.parent
                n += 1
            end)
        end
        toast("Undo: " .. n .. " objek dikembalikan  (sisa " .. #undoStack .. ")", T.Ok)
    end

    ---------------------------------------------------------------
    -- HALAMAN: REPLACER
    ---------------------------------------------------------------
    local PR = makePage("replacer")
    sec(PR, "1 • OBJEK BARU (pengganti)", 1)
    local cNew = card(PR, 2, 80)
    newName = label(cNew, {Size = UDim2.new(1, -100, 0, 18), Text = "Belum dipilih",
        Font = Enum.Font.GothamBold, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd})
    newHint = label(cNew, {Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -100, 0, 30),
        Text = "Tekan PILIH lalu tap objeknya", TextSize = 10, TextColor3 = T.Muted,
        TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
    btnPick = rbtn(cNew, "PILIH", true, UDim2.fromOffset(86, 34), UDim2.new(1, -86, 0.5, -17))

    sec(PR, "2 • OBJEK LAMA (yang diganti)", 3)
    local cOld = card(PR, 4, 218)
    oldCount = label(cOld, {Size = UDim2.new(1, 0, 0, 18), Text = "Belum dipilih...",
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Muted})
    label(cOld, {Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 14),
        Text = "Outline kuning = objek lama • hijau = objek baru", TextSize = 9, TextColor3 = T.Muted})
    filterBox = new("TextBox", {
        Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = T.Field,
        TextColor3 = T.Text, PlaceholderText = "Filter nama (contoh: tangga)", PlaceholderColor3 = T.Muted,
        Text = "", TextSize = 11, Font = Enum.Font.GothamMedium, ClearTextOnFocus = false, BorderSizePixel = 0,
    }, cOld)
    corner(filterBox, 8)
    stroke(filterBox, T.Line, 1)
    new("UIPadding", {PaddingLeft = UDim.new(0, 10)}, filterBox)

    local row2 = new("Frame", {Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1}, cOld)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)}, row2)
    btnBox = rbtn(row2, "▭ KOTAK (2 TAP)", false, UDim2.new(0.5, -3, 1, 0))
    btnSearch = rbtn(row2, "🔎 CARI NAMA", false, UDim2.new(0.5, -3, 1, 0))
    btnName = rbtn(cOld, "⚡ SAMA NAMA (SEKALIGUS)", true, UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 114))
    local row3 = new("Frame", {Position = UDim2.fromOffset(0, 156), Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1}, cOld)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)}, row3)
    btnAdd = rbtn(row3, "TAMBAH", false, UDim2.new(1 / 3, -4, 1, 0))
    btnFolder = rbtn(row3, "FOLDER", false, UDim2.new(1 / 3, -4, 1, 0))
    local btnReset = rbtn(row3, "RESET", false, UDim2.new(1 / 3, -4, 1, 0))

    sec(PR, "3 • EKSEKUSI", 5)
    btnRep = rbtn(PR, "REPLACE 0 OBSTACLES", true, UDim2.new(1, 0, 0, 42))
    btnRep.LayoutOrder = 6
    btnRep.TextSize = 12
    local btnBackup = rbtn(PR, "REPLACE (KEEP BACKUP)", false, UDim2.new(1, 0, 0, 38))
    btnBackup.LayoutOrder = 7
    local rowU = new("Frame", {LayoutOrder = 8, Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1}, PR)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)}, rowU)
    local btnUndo = rbtn(rowU, "↶  UNDO", false, UDim2.new(0.5, -3, 1, 0))
    local btnDelete = rbtn(rowU, "🗑  HAPUS TERPILIH", false, UDim2.new(0.5, -3, 1, 0))

    btnPick.MouseButton1Click:Connect(function() startPick("new") end)
    btnAdd.MouseButton1Click:Connect(function() startPick("old") end)
    btnFolder.MouseButton1Click:Connect(function() startPick("folder") end)
    btnName.MouseButton1Click:Connect(function() startPick("name") end)
    btnBox.MouseButton1Click:Connect(function() startPick("box") end)
    btnSearch.MouseButton1Click:Connect(function() task.spawn(searchByName) end)
    btnReset.MouseButton1Click:Connect(function()
        setPick(nil)
        clearOld()
        if newBox then newBox:Destroy(); newBox = nil end
        newObj = nil
        refreshInfo()
        toast("Pilihan direset", T.Muted)
    end)
    btnRep.MouseButton1Click:Connect(function() doReplace(false) end)
    btnBackup.MouseButton1Click:Connect(function() doReplace(true) end)
    btnUndo.MouseButton1Click:Connect(doUndo)
    btnDelete.MouseButton1Click:Connect(doRemove)

    ---------------------------------------------------------------
    -- HALAMAN: OPSI
    ---------------------------------------------------------------
    local PO = makePage("opsi")
    sec(PO, "HASIL PENGGANTIAN", 1)
    choice(PO, 2, "SKALA: ", {"PROPORSIONAL", "UKURAN ASLI"}, 1, function(i) opt.scale = i end)
    note(PO, 3, "PROPORSIONAL = objek baru disesuaikan ukurannya tanpa melar. UKURAN ASLI = ukuran objek baru tidak diubah.")
    numRow(PO, 4, "SKALA TAMBAHAN (%)", 100, 10, 500, function(v) opt.scaleMul = v end)
    choice(PO, 5, "ROTASI: ", {"IKUT OBJEK LAMA", "ROTASI ASLI"}, 1, function(i) opt.rot = i end)
    choice(PO, 6, "PUTAR: ", {"0°", "90°", "180°", "270°"}, 1, function(i) opt.yaw = i - 1 end)
    note(PO, 7, "IKUT OBJEK LAMA = arah dan kemiringan disamakan (dibaca dari bentuk objek, bukan pivot). Kalau objek baru terputar 90°, ubah PUTAR; putarannya terhadap sumbu tegak lurus permukaan.")
    choice(PO, 8, "POSISI VERTIKAL: ", {"TENGAH", "RATA BAWAH", "RATA ATAS"}, 1, function(i) opt.align = i end)
    numRow(PO, 9, "GESER NAIK/TURUN (STUD)", 0, -500, 500, function(v) opt.offY = v end)
    note(PO, 10, "RATA BAWAH = dasar objek baru disamakan dengan dasar objek lama (cocok kalau tingginya beda). Geser dipakai untuk koreksi halus.")
    choice(PO, 11, "ANCHOR HASIL: ", {"YA", "TIDAK"}, 1, function(i) opt.anchor = i end)
    choice(PO, 12, "NAMA HASIL: ", {"NAMA OBJEK BARU", "IKUT NAMA LAMA"}, 1, function(i) opt.nameMode = i end)
    sec(PO, "PILIH SEKALIGUS", 13)
    choice(PO, 14, "LINGKUP: ", {"SELURUH MAP", "FOLDER SAMA"}, 1, function(i) opt.scope = i end)
    choice(PO, 15, "KRITERIA: ", {"NAMA SAMA", "NAMA + UKURAN SAMA"}, 1, function(i) opt.crit = i end)
    note(PO, 16, "Nama umum seperti Part otomatis dicocokkan juga lewat ukuran, supaya tidak ikut mengambil semua part di map. Batas pilihan " .. MAX_SELECT .. " objek.")
    choice(PO, 17, "TAP MEMILIH: ", {"OTOMATIS", "PART SAJA"}, 1, function(i) opt.tap = i end)
    note(PO, 18, "OTOMATIS = kalau part ada di dalam Model, yang dipilih Model-nya.")
    choice(PO, 19, "OUTLINE: ", {"NYALA", "MATI"}, 1, function(i) opt.hl = (i == 1); rebuildBoxes() end)
    sec(PO, "SALINAN (MAP ASLI AMAN)", 20)
    choice(PO, 21, "FOLDER: ", {"LANGSUNG", "SALIN DULU"}, 1, function(i) opt.folderCopy = i end)
    choice(PO, 22, "GESER SALINAN: ", {"TIDAK", "+X 400 STUD", "+Z 400 STUD"}, 1, function(i) opt.shift = i end)
    note(PO, 23, "SALIN DULU = tombol FOLDER menggandakan foldernya lebih dulu, lalu yang diganti adalah salinannya.")

    ---------------------------------------------------------------
    -- HALAMAN: INFO
    ---------------------------------------------------------------
    local PI = makePage("info")
    sec(PI, "CARA PAKAI", 1)
    note(PI, 2, "1. PILIH → jendela mengecil, tap objek BARU di dunia 3D.\n2. Pilih objek LAMA: ⚡ SAMA NAMA (tap 1, semua yang sama ikut), TAMBAH (satu per satu), FOLDER (isi folder), 🔎 CARI NAMA (ketik di filter), atau ▭ KOTAK (tap 2 sudut area). Tap tombol ⚡ melayang untuk kembali.\n3. REPLACE OBSTACLES mengganti. KEEP BACKUP menyimpan objek lama sehingga bisa di-UNDO (sampai " .. MAX_UNDO .. " langkah).")
    sec(PI, "TIPS", 3)
    note(PI, 4, "• Atur SKALA, ROTASI, PUTAR, POSISI VERTIKAL di tab OPSI.\n• SALIN DULU di OPSI menjaga folder asli tetap aman.\n• 🗑 HAPUS TERPILIH juga bisa di-UNDO.\n• Tombol ⚡ melayang bisa digeser. RightCtrl membuka/menutup jendela.\n• Semua perubahan hanya terjadi di sisi client (terlihat olehmu).")

    makeTab("replacer", "REPLACER", 1)
    makeTab("opsi", "OPSI", 2)
    makeTab("info", "INFO", 3)
    setTab("replacer")
    refreshInfo()
end

buildReplacer()

task.spawn(scan)

UI.Gui = gui
openWindow()
return UI
