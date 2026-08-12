-- ████████████████████████████████████████████████████
-- //  AuthX Suite v3 — PREMIUM FULL BUILD
-- //  Paste into Solara / Synapse, hit Execute
-- //  RCTRL = Toggle Menu | DEL = Panic Unload
-- ████████████████████████████████████████████████████

-- ── SERVICES ─────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

-- ── CFG ──────────────────────────────────────────────
local CFG = {
    -- Aimbot
    AimEnabled        = true,
    AimKey            = Enum.UserInputType.MouseButton2,
    AimPart           = "Head",
    FOVRadius         = 180,
    Smoothness        = 0.20,
    Prediction        = 0.13,
    WallCheck         = true,
    TeamCheck         = false,
    FOVVisible        = true,
    FOVColor          = Color3.fromRGB(255,255,255),
    -- Recoil / Spread
    NoRecoil          = true,
    NoSpread          = true,
    RecoilStrength    = 0.85,
    -- Silent Aim
    SilentEnabled     = true,
    SilentFOV         = 45,
    SilentChance      = 100,
    -- Triggerbot
    TrigEnabled       = true,
    TrigDelay         = 0.065,
    TrigBurst         = 0,
    TrigQuickScope    = true,
    -- ESP / Visuals
    ESPEnabled        = true,
    ESPBoxes          = true,
    ESPNames          = true,
    ESPHealth         = true,
    ESPDist           = true,
    ESPTracers        = false,
    ESPMaxDist        = 900,
    ESPHeadDot        = true,
    BoxColor          = Color3.fromRGB(255,255,255),
    NameColor         = Color3.fromRGB(255,255,255),
    TracerColor       = Color3.fromRGB(255,255,255),
    -- Hitbox Extender
    HitboxEnabled     = false,
    HitboxHead        = 1.0,
    HitboxBody        = 1.0,
    HitboxLimbs       = 1.0,
    -- Movement
    SpeedEnabled      = false,
    SpeedMult         = 1.0,
    FlyEnabled        = false,
    FlySpeed          = 50,
    NoclipEnabled     = false,
    InfJumpEnabled    = false,
    JumpCount         = 99,
    JumpHeight        = 1.0,
    BhopEnabled       = false,
    -- Misc
    StreamProof       = true,
    PanicKey          = Enum.KeyCode.Delete,
}

-- ── UTILS ─────────────────────────────────────────────
local function screenCenter()
    return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
end
local function toScreen(pos)
    local v,vis = Camera:WorldToViewportPoint(pos)
    return Vector2.new(v.X,v.Y), vis, v.Z
end
local function inFOV(sp, radius)
    return (sp - screenCenter()).Magnitude <= (radius or CFG.FOVRadius)
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function isVisible(origin, target, char)
    if not CFG.WallCheck then return true end
    local lc = LocalPlayer.Character
    rayParams.FilterDescendantsInstances = lc and {lc} or {}
    local hit = workspace:Raycast(origin, target - origin, rayParams)
    if not hit then return true end
    return hit.Instance and hit.Instance:IsDescendantOf(char)
end
local function getCharParts(char)
    local head  = char:FindFirstChild("Head")
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    local root  = char:FindFirstChild("HumanoidRootPart")
    local hum   = char:FindFirstChildOfClass("Humanoid")
    if not root then
        for _,v in ipairs(char:GetChildren()) do
            if v:IsA("BasePart") and v.Name:lower():find("root") then root=v break end
        end
    end
    if not head then
        for _,v in ipairs(char:GetChildren()) do
            if v:IsA("BasePart") and v.Name:lower():find("head") then head=v break end
        end
    end
    return head, torso, root, hum
end
local function getBestTarget(fovRadius)
    local best, bd = nil, math.huge
    local center = screenCenter()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if CFG.TeamCheck and plr.Team == LocalPlayer.Team then continue end
        local char = plr.Character
        if not char then continue end
        local head, torso, root, hum = getCharParts(char)
        if not root or not hum or hum.Health <= 0 then continue end
        local aimPart = (CFG.AimPart=="Head" and head) or (CFG.AimPart=="UpperTorso" and torso) or root
        if not aimPart then continue end
        local sp, onScreen, depth = toScreen(aimPart.Position)
        if not onScreen or depth < 0 then continue end
        if not inFOV(sp, fovRadius) then continue end
        local d = (sp - center).Magnitude
        if d < bd and isVisible(Camera.CFrame.Position, aimPart.Position, char) then
            bd = d
            best = {aimPart=aimPart, root=root, head=head, char=char, plr=plr, hum=hum, sp=sp, depth=depth}
        end
    end
    return best
end

-- ── HITBOX EXTENDER ───────────────────────────────────
local origSizes = {}
local function applyHitboxes()
    if not CFG.HitboxEnabled then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if not origSizes[part] then origSizes[part] = part.Size end
                local n = part.Name:lower()
                local scale = CFG.HitboxLimbs
                if n:find("head") then scale = CFG.HitboxHead
                elseif n:find("torso") or n:find("chest") then scale = CFG.HitboxBody end
                part.Size = origSizes[part] * scale
            end
        end
    end
end
local function restoreHitboxes()
    for part, sz in pairs(origSizes) do
        pcall(function() part.Size = sz end)
    end
    origSizes = {}
end

-- ── NO RECOIL / SPREAD ────────────────────────────────
local recoilConn
local function enableNoRecoil()
    if recoilConn then recoilConn:Disconnect() end
    recoilConn = RunService.RenderStepped:Connect(function()
        if not CFG.NoRecoil then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        -- Counteract camera kick via CFrame nudge
        local cf = Camera.CFrame
        local _, _, _, _, rx, _ = cf:ToEulerAnglesYXZ()
        if math.abs(rx) > 0.001 then
            Camera.CFrame = CFrame.new(cf.Position) * CFrame.Angles(rx * (1 - CFG.RecoilStrength), 0, 0) * CFrame.Angles(0, select(2, cf:ToEulerAnglesYXZ()), 0)
        end
    end)
end
enableNoRecoil()

-- ── MOVEMENT SYSTEMS ──────────────────────────────────
local noclipConn
local function setNoclip(state)
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if state then
        noclipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end)
    else
        local char = LocalPlayer.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end
end

local flyConn, flyBV
local function setFly(state)
    if flyConn then flyConn:Disconnect() flyConn = nil end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if flyBV then pcall(function() flyBV:Destroy() end) flyBV = nil end
    if state then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = true end
        flyBV = Instance.new("BodyVelocity", root)
        flyBV.MaxForce = Vector3.new(1e5,1e5,1e5)
        flyBV.Velocity = Vector3.zero
        flyConn = RunService.RenderStepped:Connect(function()
            local mv = Vector3.zero
            local cf = Camera.CFrame
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv - Vector3.new(0,1,0) end
            if flyBV then flyBV.Velocity = mv * CFG.FlySpeed end
        end)
    else
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end

local infJumpConn
local jumpCounter = 0
local function setupInfJump()
    if infJumpConn then infJumpConn:Disconnect() infJumpConn = nil end
    if not CFG.InfJumpEnabled then return end
    infJumpConn = UserInputService.JumpRequest:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return end
        local limit = CFG.JumpCount >= 99 and math.huge or CFG.JumpCount
        if jumpCounter < limit then
            jumpCounter = jumpCounter + 1
            local bv = Instance.new("BodyVelocity", root)
            bv.MaxForce = Vector3.new(0, 1e5, 0)
            bv.Velocity = Vector3.new(0, 50 * CFG.JumpHeight, 0)
            game:GetService("Debris"):AddItem(bv, 0.12)
        end
    end)
    -- Reset on land
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.StateChanged:Connect(function(_, new)
                if new == Enum.HumanoidStateType.Landed then jumpCounter = 0 end
            end)
        end
    end
end

-- ── FOV CIRCLE ────────────────────────────────────────
local fovCircle = Drawing.new("Circle")
fovCircle.Radius    = CFG.FOVRadius
fovCircle.Color     = Color3.fromRGB(255,255,255)
fovCircle.Thickness = 1.2
fovCircle.NumSides  = 80
fovCircle.Filled    = false
fovCircle.Visible   = CFG.FOVVisible

-- ── ESP POOL ──────────────────────────────────────────
local function newDraw(t, p)
    local d = Drawing.new(t)
    for k,v in pairs(p) do d[k]=v end
    return d
end
local espPool = {}
local function getESP(plr)
    if not espPool[plr] then
        espPool[plr] = {
            box    = newDraw("Square", {Thickness=0.8, Color=CFG.BoxColor, Filled=false, Visible=false}),
            cTL    = newDraw("Line",   {Thickness=2, Color=CFG.BoxColor, Visible=false}),
            cTR    = newDraw("Line",   {Thickness=2, Color=CFG.BoxColor, Visible=false}),
            cBL    = newDraw("Line",   {Thickness=2, Color=CFG.BoxColor, Visible=false}),
            cBR    = newDraw("Line",   {Thickness=2, Color=CFG.BoxColor, Visible=false}),
            name   = newDraw("Text",   {Size=13, Color=CFG.NameColor, Center=true, Outline=true, Visible=false}),
            dist   = newDraw("Text",   {Size=11, Color=Color3.fromRGB(180,180,180), Center=true, Outline=true, Visible=false}),
            hpBg   = newDraw("Square", {Thickness=1, Color=Color3.fromRGB(20,20,20), Filled=true, Visible=false}),
            hp     = newDraw("Square", {Thickness=1, Color=Color3.fromRGB(80,255,100), Filled=true, Visible=false}),
            tracer = newDraw("Line",   {Thickness=1, Color=CFG.TracerColor, Visible=false}),
            head   = newDraw("Circle", {Radius=5, Thickness=1, Color=CFG.BoxColor, Filled=false, NumSides=20, Visible=false}),
        }
    end
    return espPool[plr]
end
local function hideESP(e)
    for _, d in pairs(e) do d.Visible = false end
end
Players.PlayerRemoving:Connect(function(plr)
    if espPool[plr] then
        for _,d in pairs(espPool[plr]) do pcall(function() d:Remove() end) end
        espPool[plr] = nil
    end
end)
local function cleanStale()
    for plr in pairs(espPool) do
        if not Players:FindFirstChild(plr.Name) then
            for _,d in pairs(espPool[plr]) do pcall(function() d:Remove() end) end
            espPool[plr] = nil
        end
    end
end
local function drawCorners(e,x,y,w,h)
    local cL = math.floor(math.min(w,h)*0.25)
    local c = CFG.BoxColor
    e.cTL.From=Vector2.new(x,y+cL)   e.cTL.To=Vector2.new(x,y)     e.cTL.Color=c e.cTL.Visible=true
    e.cTR.From=Vector2.new(x+w-cL,y) e.cTR.To=Vector2.new(x+w,y)   e.cTR.Color=c e.cTR.Visible=true
    e.cBL.From=Vector2.new(x,y+h-cL) e.cBL.To=Vector2.new(x,y+h)   e.cBL.Color=c e.cBL.Visible=true
    e.cBR.From=Vector2.new(x+w,y+h-cL) e.cBR.To=Vector2.new(x+w,y+h) e.cBR.Color=c e.cBR.Visible=true
end
local function updateESPColors()
    for _, e in pairs(espPool) do
        for _, key in ipairs({"cTL","cTR","cBL","cBR","box","head"}) do
            if e[key] then e[key].Color = CFG.BoxColor end
        end
        if e.tracer then e.tracer.Color = CFG.TracerColor end
        if e.name   then e.name.Color   = CFG.NameColor   end
    end
end

-- ── GUI BUILD ────────────────────────────────────────
pcall(function() CoreGui:FindFirstChild("AuthX_v3"):Destroy() end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AuthX_v3"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if CFG.StreamProof then ScreenGui.Parent = CoreGui else ScreenGui.Parent = LocalPlayer.PlayerGui end
ScreenGui.Parent = CoreGui

-- ── PALETTE ──────────────────────────────────────────
local PAL = {
    bg0     = Color3.fromRGB(6,6,6),
    bg1     = Color3.fromRGB(11,11,11),
    bg2     = Color3.fromRGB(17,17,17),
    bg3     = Color3.fromRGB(24,24,24),
    border  = Color3.fromRGB(35,35,35),
    accent  = Color3.fromRGB(255,255,255),
    accentD = Color3.fromRGB(140,140,140),
    textP   = Color3.fromRGB(240,240,240),
    textS   = Color3.fromRGB(120,120,120),
    textM   = Color3.fromRGB(60,60,60),
    red     = Color3.fromRGB(220,60,60),
    green   = Color3.fromRGB(60,210,100),
}

-- ── HELPERS ───────────────────────────────────────────
local function inst(cls, props)
    local o = Instance.new(cls)
    for k,v in pairs(props) do o[k]=v end
    return o
end
local function corner(parent, rad)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, rad or 8)
    return c
end
local function stroke(parent, col, th)
    local s = Instance.new("UIStroke", parent)
    s.Color = col or PAL.border
    s.Thickness = th or 1
    return s
end
local function lbl(parent, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamBold
    l.TextSize = 12
    l.TextColor3 = PAL.textP
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Center
    for k,v in pairs(props) do l[k]=v end
    l.Parent = parent
    return l
end

-- ── ROOT FRAME ───────────────────────────────────────
local Main = inst("Frame",{
    Name="Main",
    Size=UDim2.new(0,700,0,480),
    Position=UDim2.new(0.5,-350,0.5,-240),
    BackgroundColor3=PAL.bg0,
    BorderSizePixel=0,
    Parent=ScreenGui,
})
corner(Main,12)
stroke(Main,PAL.border,1)

-- white glow at top
local glow = inst("Frame",{
    Size=UDim2.new(1,0,0,2),
    BackgroundColor3=PAL.accent,
    BorderSizePixel=0,
    ZIndex=2,
    Parent=Main,
})
corner(glow,2)
inst("UIGradient",{
    Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,1),
        NumberSequenceKeypoint.new(0.3,0),
        NumberSequenceKeypoint.new(0.7,0),
        NumberSequenceKeypoint.new(1,1),
    }),
    Parent=glow,
})

-- Drag logic
local drag,dragStart,startPos=false,nil,nil
Main.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=true dragStart=i.Position startPos=Main.Position
    end
end)
Main.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
end)
UserInputService.InputChanged:Connect(function(i)
    if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-dragStart
        Main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)

-- ── TOPBAR ───────────────────────────────────────────
local Topbar = inst("Frame",{
    Size=UDim2.new(1,0,0,44),
    BackgroundColor3=PAL.bg1,
    BorderSizePixel=0,
    Parent=Main, ZIndex=2,
})
corner(Topbar,12)

-- Logo area
local logoFrame = inst("Frame",{
    Size=UDim2.new(0,120,1,0),
    BackgroundTransparency=1,
    Parent=Topbar,
})
lbl(logoFrame,{Text="AuthX",Font=Enum.Font.GothamBold,TextSize=15,
    TextColor3=PAL.textP,Size=UDim2.new(0,80,1,0),Position=UDim2.new(0,16,0,0),
    TextXAlignment=Enum.TextXAlignment.Left,
})
-- version sub
lbl(logoFrame,{Text="v3.0",Font=Enum.Font.Gotham,TextSize=10,
    TextColor3=PAL.textM,Size=UDim2.new(0,40,0,14),
    Position=UDim2.new(0,60,0,16), ZIndex=3,
})

-- Status dot + text
local statusDot = inst("Frame",{
    Size=UDim2.new(0,7,0,7), AnchorPoint=Vector2.new(0,0.5),
    Position=UDim2.new(0,130,0.5,0),
    BackgroundColor3=PAL.green, BorderSizePixel=0,
    Parent=Topbar, ZIndex=3,
})
corner(statusDot,8)
lbl(Topbar,{Text="INJECTED",Font=Enum.Font.GothamBold,TextSize=10,
    TextColor3=PAL.textM,Size=UDim2.new(0,80,0,20),
    Position=UDim2.new(0,143,0.5,-10), ZIndex=3,
})

-- Close btn
local closeBtn = inst("TextButton",{
    Text="×", Size=UDim2.new(0,28,0,28),
    Position=UDim2.new(1,-36,0.5,-14),
    BackgroundColor3=PAL.bg3, BorderSizePixel=0,
    TextColor3=PAL.textS, Font=Enum.Font.GothamBold, TextSize=18,
    ZIndex=3, Parent=Topbar,
})
corner(closeBtn,6)
closeBtn.MouseButton1Click:Connect(function() Main.Visible=false end)
closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3=PAL.red end)
closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3=PAL.textS end)

-- ── LEFT NAV (tabs) ───────────────────────────────────
local NavBar = inst("Frame",{
    Size=UDim2.new(0,120,1,-52),
    Position=UDim2.new(0,0,0,52),
    BackgroundColor3=PAL.bg1,
    BorderSizePixel=0,
    Parent=Main,
})
inst("UIStroke",{Color=PAL.border,Thickness=1,Parent=NavBar})

local tabNames = {"AIMBOT","TRIGGERBOT","ESP","MOVEMENT","MISC"}
local tabPages = {}
local tabBtns = {}

local navLayout = inst("UIListLayout",{
    SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,2),
    Parent=NavBar,
})
inst("UIPadding",{
    PaddingTop=UDim.new(0,10),
    PaddingLeft=UDim.new(0,8),
    PaddingRight=UDim.new(0,8),
    Parent=NavBar,
})

-- ── CONTENT AREA ─────────────────────────────────────
local ContentArea = inst("Frame",{
    Size=UDim2.new(1,-120,1,-52),
    Position=UDim2.new(0,120,0,52),
    BackgroundColor3=PAL.bg0,
    BorderSizePixel=0,
    Parent=Main,
})
inst("UIStroke",{Color=PAL.border,Thickness=1,Parent=ContentArea})

-- ── RIGHT QUICK PANEL ─────────────────────────────────
local QuickPanel = inst("Frame",{
    Size=UDim2.new(0,160,1,0),
    Position=UDim2.new(1,-160,0,0),
    BackgroundColor3=PAL.bg1,
    BorderSizePixel=0,
    Parent=ContentArea,
})
inst("UIStroke",{Color=PAL.border,Thickness=1,Parent=QuickPanel})

lbl(QuickPanel,{
    Text="QUICK STATUS",Font=Enum.Font.GothamBold,TextSize=9,
    TextColor3=PAL.textM,Size=UDim2.new(1,-16,0,16),
    Position=UDim2.new(0,8,0,12),
    TextXAlignment=Enum.TextXAlignment.Left,
})

local qLayout = inst("UIListLayout",{
    SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,4),
    Parent=QuickPanel,
})
inst("UIPadding",{
    PaddingTop=UDim.new(0,36),
    PaddingLeft=UDim.new(0,8),
    PaddingRight=UDim.new(0,8),
    Parent=QuickPanel,
})

-- Quick pill factory
local quickPills = {}
local function makeQuickPill(label, cfgKey, subKeys)
    local pill = inst("TextButton",{
        Size=UDim2.new(1,0,0,30),
        BackgroundColor3=PAL.bg2,
        BorderSizePixel=0,
        Text="",
        AutoButtonColor=false,
    })
    corner(pill,6)
    stroke(pill,PAL.border)
    local pillLabel = lbl(pill,{
        Text=label,Font=Enum.Font.Gotham,TextSize=11,
        TextColor3=CFG[cfgKey] and PAL.textP or PAL.textM,
        Size=UDim2.new(1,-30,1,0),Position=UDim2.new(0,10,0,0),
    })
    local dot = inst("Frame",{
        Size=UDim2.new(0,7,0,7), AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.new(1,-12,0.5,0),
        BackgroundColor3=CFG[cfgKey] and PAL.accent or PAL.textM,
        BorderSizePixel=0, Parent=pill,
    })
    corner(dot,8)
    local function syncPill()
        local on = CFG[cfgKey]
        TweenService:Create(dot,TweenInfo.new(0.12),{BackgroundColor3=on and PAL.accent or PAL.textM}):Play()
        pillLabel.TextColor3 = on and PAL.textP or PAL.textM
        pill.BackgroundColor3 = on and PAL.bg3 or PAL.bg2
    end
    pill.MouseButton1Click:Connect(function()
        CFG[cfgKey] = not CFG[cfgKey]
        if subKeys then for _, sk in ipairs(subKeys) do CFG[sk]=CFG[cfgKey] end end
        syncPill()
    end)
    pill.Parent = QuickPanel
    quickPills[cfgKey] = syncPill
    return pill
end

makeQuickPill("Aimbot",       "AimEnabled")
makeQuickPill("Silent Aim",   "SilentEnabled")
makeQuickPill("Triggerbot",   "TrigEnabled")
makeQuickPill("ESP",          "ESPEnabled")
makeQuickPill("Wallhack",     "ESPBoxes")
makeQuickPill("No Recoil",    "NoRecoil")
makeQuickPill("Speed Hack",   "SpeedEnabled")
makeQuickPill("Fly Hack",     "FlyEnabled")
makeQuickPill("No Clip",      "NoclipEnabled")
makeQuickPill("Inf. Jump",    "InfJumpEnabled")
makeQuickPill("Hitbox Ext.",  "HitboxEnabled")

-- ── SCROLL / PANEL AREA ───────────────────────────────
local PanelArea = inst("Frame",{
    Size=UDim2.new(1,-160,1,0),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    Parent=ContentArea,
})

local function makePage()
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1,0,1,0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 2
    sf.ScrollBarImageColor3 = PAL.border
    sf.CanvasSize = UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Visible = false
    sf.Parent = PanelArea
    inst("UIPadding",{PaddingTop=UDim.new(0,12),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),Parent=sf})
    local layout = inst("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8),Parent=sf})
    return sf, layout
end

-- ── COMPONENT BUILDERS ────────────────────────────────
local function mkSectionLabel(parent, text, order)
    local f = inst("Frame",{
        Size=UDim2.new(1,0,0,20),
        BackgroundTransparency=1,
        BorderSizePixel=0,
        LayoutOrder=order or 0,
        Parent=parent,
    })
    lbl(f,{Text=text,Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,
        Size=UDim2.new(1,0,1,0),
        TextXAlignment=Enum.TextXAlignment.Left,
    })
    return f
end

local function mkCard(parent, order)
    local card = inst("Frame",{
        Size=UDim2.new(1,0,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=PAL.bg2,
        BorderSizePixel=0,
        LayoutOrder=order or 0,
        Parent=parent,
    })
    corner(card,8)
    stroke(card,PAL.border)
    local layout = inst("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,0),Parent=card})
    inst("UIPadding",{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,10),
        PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),Parent=card})
    return card, layout
end

local function mkRow(parent, order)
    local row = inst("Frame",{
        Size=UDim2.new(1,0,0,32),
        BackgroundTransparency=1,
        BorderSizePixel=0,
        LayoutOrder=order or 0,
        Parent=parent,
    })
    return row
end

local function mkToggleRow(parent, labelText, cfgKey, order, onChange)
    local row = mkRow(parent, order)
    lbl(row,{Text=labelText,Font=Enum.Font.Gotham,TextSize=12,TextColor3=PAL.textS,
        Size=UDim2.new(1,-52,1,0),Position=UDim2.new(0,0,0,0),
    })
    local track = inst("Frame",{
        Size=UDim2.new(0,34,0,18),
        Position=UDim2.new(1,-34,0.5,-9),
        BackgroundColor3=CFG[cfgKey] and PAL.accent or PAL.bg3,
        BorderSizePixel=0, Parent=row,
    })
    corner(track,10)
    local thumb = inst("Frame",{
        Size=UDim2.new(0,12,0,12),
        Position=CFG[cfgKey] and UDim2.new(0,19,0,3) or UDim2.new(0,3,0,3),
        BackgroundColor3=CFG[cfgKey] and PAL.bg0 or PAL.textM,
        BorderSizePixel=0, Parent=track,
    })
    corner(thumb,8)
    local ti = TweenInfo.new(0.14)
    local btn = inst("TextButton",{
        Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=row,
    })
    btn.MouseButton1Click:Connect(function()
        CFG[cfgKey] = not CFG[cfgKey]
        local on = CFG[cfgKey]
        TweenService:Create(track,ti,{BackgroundColor3=on and PAL.accent or PAL.bg3}):Play()
        TweenService:Create(thumb,ti,{Position=on and UDim2.new(0,19,0,3) or UDim2.new(0,3,0,3),
            BackgroundColor3=on and PAL.bg0 or PAL.textM}):Play()
        if quickPills[cfgKey] then quickPills[cfgKey]() end
        if onChange then onChange(on) end
    end)
end

local function mkSliderRow(parent, labelText, cfgKey, minV, maxV, fmt, order, onChange)
    local row = inst("Frame",{
        Size=UDim2.new(1,0,0,48),
        BackgroundTransparency=1,
        BorderSizePixel=0,
        LayoutOrder=order or 0,
        Parent=parent,
    })
    lbl(row,{Text=labelText,Font=Enum.Font.Gotham,TextSize=12,TextColor3=PAL.textS,
        Size=UDim2.new(0.6,0,0,20),Position=UDim2.new(0,0,0,2),
    })
    local valLbl = lbl(row,{Text=fmt(CFG[cfgKey]),Font=Enum.Font.GothamBold,TextSize=11,
        TextColor3=PAL.accentD,Size=UDim2.new(0.4,0,0,20),Position=UDim2.new(0.6,0,0,2),
        TextXAlignment=Enum.TextXAlignment.Right,
    })
    local trackBg = inst("Frame",{
        Size=UDim2.new(1,0,0,3),Position=UDim2.new(0,0,0,28),
        BackgroundColor3=PAL.bg3,BorderSizePixel=0,Parent=row,
    })
    corner(trackBg,4)
    local pct = math.clamp((CFG[cfgKey]-minV)/(maxV-minV),0,1)
    local fill = inst("Frame",{
        Size=UDim2.new(pct,0,1,0),
        BackgroundColor3=PAL.accent,BorderSizePixel=0,Parent=trackBg,
    })
    corner(fill,4)
    local thumb = inst("Frame",{
        Size=UDim2.new(0,13,0,13),AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.new(pct,0,0.5,0),
        BackgroundColor3=PAL.accent,BorderSizePixel=0,ZIndex=3,Parent=trackBg,
    })
    corner(thumb,8)
    local dragging=false
    local function upd(pos)
        local r=math.clamp((pos.X-trackBg.AbsolutePosition.X)/math.max(trackBg.AbsoluteSize.X,1),0,1)
        local cur=minV+(maxV-minV)*r
        -- round to int if both bounds are ints
        if minV==math.floor(minV) and maxV==math.floor(maxV) then cur=math.floor(cur) end
        CFG[cfgKey]=cur
        fill.Size=UDim2.new(r,0,1,0) thumb.Position=UDim2.new(r,0,0.5,0)
        valLbl.Text=fmt(cur)
        if onChange then onChange(cur) end
        if quickPills[cfgKey] then quickPills[cfgKey]() end
    end
    local slBtn=inst("TextButton",{Size=UDim2.new(1,0,0,20),Position=UDim2.new(0,0,0,20),
        BackgroundTransparency=1,Text="",ZIndex=4,Parent=row})
    slBtn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true upd(i.Position) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then upd(i.Position) end
    end)
    return row
end

-- Color picker row (RGB sliders)
local function mkColorRow(parent, labelText, cfgKey, order, onChange)
    local wrapper = inst("Frame",{
        Size=UDim2.new(1,0,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,
        BorderSizePixel=0,
        LayoutOrder=order or 0,
        Parent=parent,
    })
    local header = mkRow(wrapper, 0)
    lbl(header,{Text=labelText,Font=Enum.Font.Gotham,TextSize=12,TextColor3=PAL.textS,
        Size=UDim2.new(0.7,0,1,0),
    })
    local preview = inst("Frame",{
        Size=UDim2.new(0,28,0,14),AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,0,0.5,0),
        BackgroundColor3=CFG[cfgKey],BorderSizePixel=0,Parent=header,
    })
    corner(preview,4) stroke(preview,PAL.border)

    local r0,g0,b0 = math.floor(CFG[cfgKey].R*255), math.floor(CFG[cfgKey].G*255), math.floor(CFG[cfgKey].B*255)
    local function rebuild(r,g,b)
        CFG[cfgKey]=Color3.fromRGB(r,g,b)
        preview.BackgroundColor3=CFG[cfgKey]
        if onChange then onChange(CFG[cfgKey]) end
    end

    -- R/G/B sub-sliders
    for i, ch in ipairs({"R","G","B"}) do
        local initV = i==1 and r0 or i==2 and g0 or b0
        local sub = inst("Frame",{
            Size=UDim2.new(1,0,0,32),BackgroundTransparency=1,
            BorderSizePixel=0,LayoutOrder=i,Parent=wrapper,
        })
        local chLbl = lbl(sub,{Text=ch,Font=Enum.Font.GothamBold,TextSize=10,TextColor3=PAL.textM,
            Size=UDim2.new(0,16,1,0),TextXAlignment=Enum.TextXAlignment.Center,
        })
        local vLbl = lbl(sub,{Text=tostring(initV),Font=Enum.Font.Gotham,TextSize=10,TextColor3=PAL.textM,
            Size=UDim2.new(0,28,1,0),Position=UDim2.new(1,-28,0,0),TextXAlignment=Enum.TextXAlignment.Right,
        })
        local tBg = inst("Frame",{
            Size=UDim2.new(1,-48,0,3),Position=UDim2.new(0,20,0.5,0),
            BackgroundColor3=PAL.bg3,BorderSizePixel=0,Parent=sub,
        })
        corner(tBg,4)
        local pct2=(initV)/255
        local fl2=inst("Frame",{Size=UDim2.new(pct2,0,1,0),BackgroundColor3=PAL.accent,BorderSizePixel=0,Parent=tBg})
        corner(fl2,4)
        local th2=inst("Frame",{
            Size=UDim2.new(0,11,0,11),AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(pct2,0,0.5,0),
            BackgroundColor3=PAL.accent,BorderSizePixel=0,ZIndex=3,Parent=tBg,
        })
        corner(th2,8)
        local cur=initV
        local dragging2=false
        local function upd2(pos)
            local ratio=math.clamp((pos.X-tBg.AbsolutePosition.X)/math.max(tBg.AbsoluteSize.X,1),0,1)
            cur=math.floor(ratio*255)
            fl2.Size=UDim2.new(ratio,0,1,0) th2.Position=UDim2.new(ratio,0,0.5,0)
            vLbl.Text=tostring(cur)
            local c=CFG[cfgKey]
            local rv=i==1 and cur or math.floor(c.R*255)
            local gv=i==2 and cur or math.floor(c.G*255)
            local bv=i==3 and cur or math.floor(c.B*255)
            rebuild(rv,gv,bv)
        end
        local sb2=inst("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=4,Parent=sub})
        sb2.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging2=true upd2(inp.Position) end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging2=false end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if dragging2 and inp.UserInputType==Enum.UserInputType.MouseMovement then upd2(inp.Position) end
        end)
    end
end

-- Dropdown row
local function mkDropRow(parent, labelText, options, cfgKey, order, onChange)
    local row = mkRow(parent, order)
    row.Size = UDim2.new(1,0,0,30)
    lbl(row,{Text=labelText,Font=Enum.Font.Gotham,TextSize=12,TextColor3=PAL.textS,
        Size=UDim2.new(0.55,0,1,0),
    })
    local sel = inst("TextButton",{
        Size=UDim2.new(0.42,0,0,22),Position=UDim2.new(0.57,0,0.5,-11),
        BackgroundColor3=PAL.bg3,BorderSizePixel=0,
        Text=CFG[cfgKey],Font=Enum.Font.Gotham,TextSize=10,TextColor3=PAL.textP,
        Parent=row,
    })
    corner(sel,5) stroke(sel,PAL.border)
    local open=false
    local dropdown
    sel.MouseButton1Click:Connect(function()
        open=not open
        if dropdown then dropdown:Destroy() dropdown=nil end
        if not open then return end
        dropdown=inst("Frame",{
            Size=UDim2.new(0.42,0,0,#options*24+4),
            Position=UDim2.new(0.57,0,0.5,12),
            BackgroundColor3=PAL.bg3,BorderSizePixel=0,ZIndex=10,Parent=row,
        })
        corner(dropdown,6) stroke(dropdown,PAL.border)
        for idx,opt in ipairs(options) do
            local ob=inst("TextButton",{
                Size=UDim2.new(1,-8,0,22),Position=UDim2.new(0,4,0,(idx-1)*24+2),
                BackgroundTransparency=1,Text=opt,Font=Enum.Font.Gotham,TextSize=10,
                TextColor3=opt==CFG[cfgKey] and PAL.textP or PAL.textS,ZIndex=11,Parent=dropdown,
            })
            ob.MouseButton1Click:Connect(function()
                CFG[cfgKey]=opt sel.Text=opt
                open=false dropdown:Destroy() dropdown=nil
                if onChange then onChange(opt) end
            end)
        end
    end)
end

-- ── PAGE 1: AIMBOT ────────────────────────────────────
local p1,_ = makePage()
tabPages[1]=p1

local c1a,_ = mkCard(p1,1)
lbl(c1a,{Text="AIMBOT",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,
    Size=UDim2.new(1,0,0,16),LayoutOrder=0})
mkToggleRow(c1a,"Enable Aimbot","AimEnabled",1)
mkToggleRow(c1a,"Wall Check","WallCheck",2)
mkToggleRow(c1a,"Team Check","TeamCheck",3)
mkToggleRow(c1a,"Show FOV Circle","FOVVisible",4,function(v) fovCircle.Visible=v end)
mkDropRow(c1a,"Bone Target",{"Head","UpperTorso","Torso","HumanoidRootPart"},"AimPart",5)
mkSliderRow(c1a,"FOV Radius","FOVRadius",30,500,function(v) return math.floor(v).."px" end,6)
mkSliderRow(c1a,"Smoothness","Smoothness",0.01,1.0,function(v) return math.floor(v*100).."%" end,7)
mkSliderRow(c1a,"Prediction","Prediction",0,0.5,function(v) return ("%.2f"):format(v) end,8)

local c1b,_ = mkCard(p1,2)
lbl(c1b,{Text="SILENT AIM",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,
    Size=UDim2.new(1,0,0,16),LayoutOrder=0})
mkToggleRow(c1b,"Enable Silent Aim","SilentEnabled",1)
mkSliderRow(c1b,"Silent FOV","SilentFOV",5,180,function(v) return math.floor(v).."px" end,2)
mkSliderRow(c1b,"Hit Chance","SilentChance",1,100,function(v) return math.floor(v).."%" end,3)
mkDropRow(c1b,"Silent Bone",{"Head","UpperTorso","Torso"},"AimPart",4)

local c1c,_ = mkCard(p1,3)
lbl(c1c,{Text="RECOIL & SPREAD",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,
    Size=UDim2.new(1,0,0,16),LayoutOrder=0})
mkToggleRow(c1c,"No Recoil","NoRecoil",1,function(v) if not v and recoilConn then recoilConn:Disconnect() recoilConn=nil else enableNoRecoil() end end)
mkToggleRow(c1c,"No Spread","NoSpread",2)
mkSliderRow(c1c,"Recoil Strength","RecoilStrength",0.1,1.0,function(v) return math.floor(v*100).."%" end,3)

local c1d,_ = mkCard(p1,4)
lbl(c1d,{Text="HITBOX EXTENDER",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,
    Size=UDim2.new(1,0,0,16),LayoutOrder=0})
mkToggleRow(c1d,"Enable Hitbox","HitboxEnabled",1,function(v) if not v then restoreHitboxes() end end)
mkSliderRow(c1d,"Head Scale","HitboxHead",1.0,5.0,function(v) return ("%.1fx"):format(v) end,2)
mkSliderRow(c1d,"Body Scale","HitboxBody",1.0,5.0,function(v) return ("%.1fx"):format(v) end,3)
mkSliderRow(c1d,"Limb Scale","HitboxLimbs",1.0,5.0,function(v) return ("%.1fx"):format(v) end,4)

-- ── PAGE 2: TRIGGERBOT ────────────────────────────────
local p2,_ = makePage()
tabPages[2]=p2

local c2a,_ = mkCard(p2,1)
lbl(c2a,{Text="TRIGGERBOT",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,
    Size=UDim2.new(1,0,0,16),LayoutOrder=0})
mkToggleRow(c2a,"Enable Triggerbot","TrigEnabled",1)
mkToggleRow(c2a,"Quick Scope","TrigQuickScope",2)
mkSliderRow(c2a,"Reaction Delay","TrigDelay",0,0.3,function(v) return math.floor(v*1000).."ms" end,3)
mkSliderRow(c2a,"Burst Time","TrigBurst",0,0.5,function(v) return math.floor(v*1000).."ms" end,4)

-- ── PAGE 3: ESP ───────────────────────────────────────
local p3,_ = makePage()
tabPages[3]=p3

local c3a,_ = mkCard(p3,1)
lbl(c3a,{Text="PLAYER ESP",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,
    Size=UDim2.new(1,0,0,16),LayoutOrder=0})
mkToggleRow(c3a,"Enable ESP","ESPEnabled",1)
mkToggleRow(c3a,"Corner Boxes","ESPBoxes",2)
mkToggleRow(c3a,"Name Tags","ESPNames",3)
mkToggleRow(c3a,"Health Bars","ESPHealth",4)
mkToggleRow(c3a,"Distance","ESPDist",5)
mkToggleRow(c3a,"Tracers","ESPTracers",6)
mkToggleRow(c3a,"Head Dot","ESPHeadDot",7)
mkSliderRow(c3a,"Max Distance","ESPMaxDist",50,2000,function(v) return math.floor(v).."m" end,8)

local c3b,_ = mkCard(p3,2)
lbl(c3b,{Text="ESP COLORS",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,
    Size=UDim2.new(1,0,0,16),LayoutOrder=0})
mkColorRow(c3b,"Box / Corner Color","BoxColor",1,function() updateESPColors() end)
mkColorRow(c3b,"Name Color","NameColor",2,function() updateESPColors() end)
mkColorRow(c3b,"Tracer Color","TracerColor",3,function() updateESPColors() end)

-- ── PAGE 4: MOVEMENT ──────────────────────────────────
local p4,_ = makePage()
tabPages[4]=p4

local c4a,_ = mkCard(p4,1)
lbl(c4a,{Text="SPEED HACK",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,
    Size=UDim2.new(1,0,0,16),LayoutOrder=0})
mkToggleRow(c4a,"Enable Speed","SpeedEnabled",1,function(v)
    local char=LocalPlayer.Character
    if char then
        local hum=char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed=v and 16*CFG.SpeedMult or 16 end
    end
end)
mkSliderRow(c4a,"Speed Multiplier","SpeedMult",1.0,10.0,function(v) return ("%.1fx"):format(v) end,2,function(v)
    if CFG.SpeedEnabled then
        local char=LocalPlayer.Character
        if char then
            local hum=char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed=16*v end
        end
    end
end)

local c4b,_ = mkCard(p4,2)
lbl(c4b,{Text="FLY HACK",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,
    Size=UDim2.new(1,0,0,16),LayoutOrder=0})
mkToggleRow(c4b,"Enable Fly","FlyEnabled",1,function(v) setFly(v) end)
mkToggleRow(c4b,"Noclip Mode","NoclipEnabled",2,function(v) setNoclip(v) end)
mkSliderRow(c4b,"Fly Speed","FlySpeed",5,200,function(v) return math.floor(v).." wu/s" end,3)

local c4c,_ = mkCard(p4,3)
lbl(c4c,{Text="JUMP",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,
    Size=UDim2.new(1,0,0,16),LayoutOrder=0})
mkToggleRow(c4c,"Infinite Jump","InfJumpEnabled",1,function(v) setupInfJump() end)
mkToggleRow(c4c,"Bunny Hop","BhopEnabled",2)
mkSliderRow(c4c,"Jump Count","JumpCount",1,99,function(v) return v>=99 and "INF" or tostring(math.floor(v)) end,3)
mkSliderRow(c4c,"Jump Height","JumpHeight",1.0,5.0,function(v) return ("%.1fx"):format(v) end,4)

-- ── PAGE 5: MISC ──────────────────────────────────────
local p5,_ = makePage()
tabPages[5]=p5

local c5a,_ = mkCard(p5,1)
lbl(c5a,{Text="SYSTEM",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,
    Size=UDim2.new(1,0,0,16),LayoutOrder=0})
mkToggleRow(c5a,"Stream Proof","StreamProof",1)

-- Keybind display
local function mkKeybindRow(parent, labelText, keyStr, order)
    local row = mkRow(parent,order)
    lbl(row,{Text=labelText,Font=Enum.Font.Gotham,TextSize=12,TextColor3=PAL.textS,
        Size=UDim2.new(0.6,0,1,0),})
    local kb = inst("TextButton",{
        Size=UDim2.new(0,80,0,20),Position=UDim2.new(1,-80,0.5,-10),
        BackgroundColor3=PAL.bg3,BorderSizePixel=0,
        Text=keyStr,Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textP,
        Parent=row,
    })
    corner(kb,4) stroke(kb,PAL.border)
end
mkKeybindRow(c5a,"Toggle Menu","RCTRL",2)
mkKeybindRow(c5a,"Unload / Panic","DEL",3)
mkKeybindRow(c5a,"Toggle Aimbot","RSHIFT",4)
mkKeybindRow(c5a,"Toggle ESP","F1",5)
mkKeybindRow(c5a,"Toggle Triggerbot","F2",6)
mkKeybindRow(c5a,"Toggle Silent Aim","F3",7)

-- ── NAV BUTTONS ───────────────────────────────────────
local function switchTab(idx)
    for i, pg in ipairs(tabPages) do pg.Visible=(i==idx) end
    for i, btn in ipairs(tabBtns) do
        btn.BackgroundColor3 = i==idx and PAL.bg3 or Color3.fromRGB(0,0,0)
        btn.BackgroundTransparency = i==idx and 0 or 1
        btn.TextColor3 = i==idx and PAL.textP or PAL.textM
    end
end

for i, name in ipairs(tabNames) do
    local btn = inst("TextButton",{
        Size=UDim2.new(1,0,0,32),
        BackgroundColor3=i==1 and PAL.bg3 or Color3.fromRGB(0,0,0),
        BackgroundTransparency=i==1 and 0 or 1,
        BorderSizePixel=0,
        Text=name,
        Font=Enum.Font.GothamBold,
        TextSize=9,
        TextColor3=i==1 and PAL.textP or PAL.textM,
        AutoButtonColor=false,
        LayoutOrder=i,
        Parent=NavBar,
    })
    corner(btn,6)
    btn.MouseButton1Click:Connect(function() switchTab(i) end)
    btn.MouseEnter:Connect(function() if tabPages[i] and not tabPages[i].Visible then btn.TextColor3=PAL.textS end end)
    btn.MouseLeave:Connect(function() if tabPages[i] and not tabPages[i].Visible then btn.TextColor3=PAL.textM end end)
    tabBtns[i]=btn
end
tabPages[1].Visible=true

-- ── TRIGGERBOT STATE ──────────────────────────────────
local trigCD = false
local mouse  = LocalPlayer:GetMouse()

-- ── MAIN LOOP ─────────────────────────────────────────
RunService:BindToRenderStep("AuthX_v3", Enum.RenderPriority.Camera.Value+1, function()
    local center = screenCenter()

    -- FOV circle
    fovCircle.Position = center
    fovCircle.Visible  = CFG.FOVVisible and CFG.AimEnabled
    fovCircle.Radius   = CFG.FOVRadius
    fovCircle.Color    = CFG.FOVColor

    -- Aimbot
    if CFG.AimEnabled and UserInputService:IsMouseButtonPressed(CFG.AimKey) then
        local t = getBestTarget(CFG.FOVRadius)
        if t then
            local vel  = t.aimPart.AssemblyLinearVelocity or Vector3.zero
            local pred = t.aimPart.Position + vel * CFG.Prediction
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, pred), CFG.Smoothness)
        end
    end

    -- Silent Aim (deflect bullet raycast target on fire)
    -- Hooks into mouse button: on LMB down we redirect the camera briefly
    -- Implemented via a lighter approach: override CFrame on LMB for one frame
    if CFG.SilentEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        local chance = math.random(1,100)
        if chance <= CFG.SilentChance then
            local t = getBestTarget(CFG.SilentFOV)
            if t then
                local savedCF = Camera.CFrame
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, t.aimPart.Position)
                task.defer(function() Camera.CFrame = savedCF end)
            end
        end
    end

    -- Triggerbot
    if CFG.TrigEnabled and not trigCD then
        local ur = Camera:ScreenPointToRay(center.X, center.Y)
        local rp2 = RaycastParams.new()
        rp2.FilterType = Enum.RaycastFilterType.Exclude
        local lc = LocalPlayer.Character
        rp2.FilterDescendantsInstances = lc and {lc} or {}
        local hit = workspace:Raycast(ur.Origin, ur.Direction*1200, rp2)
        if hit and hit.Instance then
            local hp = Players:GetPlayerFromCharacter(hit.Instance.Parent)
                    or Players:GetPlayerFromCharacter(hit.Instance.Parent and hit.Instance.Parent.Parent)
            if hp and hp ~= LocalPlayer then
                if CFG.TeamCheck and hp.Team == LocalPlayer.Team then
                    -- skip
                else
                    trigCD = true
                    task.delay(CFG.TrigDelay, function()
                        mouse:Button1Down()
                        task.delay(CFG.TrigBurst > 0 and CFG.TrigBurst or 0.04, function()
                            mouse:Button1Up()
                            task.delay(0.06, function() trigCD = false end)
                        end)
                    end)
                end
            end
        end
    end

    -- Hitbox extender
    if CFG.HitboxEnabled then applyHitboxes() end

    -- Speed hack (continuous)
    if CFG.SpeedEnabled then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 * CFG.SpeedMult end
        end
    end

    -- Bhop
    if CFG.BhopEnabled then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum:GetState()==Enum.HumanoidStateType.Landed then
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end
    end

    -- ESP
    cleanStale()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local e = getESP(plr)
        if not CFG.ESPEnabled then hideESP(e) continue end
        local char = plr.Character
        if not char then hideESP(e) continue end
        local head,_,root,hum = getCharParts(char)
        if not root or not hum or hum.Health <= 0 then hideESP(e) continue end
        local rootPos = root.Position
        local sp,onScreen,depth = toScreen(rootPos)
        if not onScreen or depth < 0 or depth > CFG.ESPMaxDist then hideESP(e) continue end
        local headPos = head and head.Position or rootPos + Vector3.new(0,3,0)
        local topSP   = select(1, toScreen(headPos + Vector3.new(0,0.65,0)))
        local bH = math.max(28, sp.Y - topSP.Y)
        local bW = bH * 0.58
        local bX = sp.X - bW/2
        local bY = topSP.Y

        -- Boxes
        if CFG.ESPBoxes then
            drawCorners(e, bX, bY, bW, bH)
            e.box.Size=Vector2.new(bW,bH) e.box.Position=Vector2.new(bX,bY)
            e.box.Color=CFG.BoxColor e.box.Visible=true
        else
            e.box.Visible=false e.cTL.Visible=false e.cTR.Visible=false e.cBL.Visible=false e.cBR.Visible=false
        end

        -- Head dot
        if CFG.ESPHeadDot and head then
            local hsp = select(1,toScreen(head.Position))
            e.head.Position=hsp e.head.Color=CFG.BoxColor
            e.head.Radius=math.max(4, bW*0.12) e.head.Visible=true
        else e.head.Visible=false end

        -- Name
        if CFG.ESPNames then
            e.name.Text=plr.DisplayName e.name.Position=Vector2.new(sp.X,bY-15)
            e.name.Color=CFG.NameColor e.name.Visible=true
        else e.name.Visible=false end

        -- Distance
        if CFG.ESPDist then
            local d3=math.floor((rootPos-Camera.CFrame.Position).Magnitude)
            e.dist.Text=d3.."m" e.dist.Position=Vector2.new(sp.X,bY+bH+3) e.dist.Visible=true
        else e.dist.Visible=false end

        -- Health bar
        if CFG.ESPHealth then
            local ratio=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
            local barX=bX-6
            e.hpBg.Size=Vector2.new(3,bH) e.hpBg.Position=Vector2.new(barX,bY) e.hpBg.Visible=true
            local fH=math.floor(bH*ratio)
            e.hp.Size=Vector2.new(3,fH) e.hp.Position=Vector2.new(barX,bY+bH-fH)
            e.hp.Color=Color3.fromRGB(math.floor(255*(1-ratio)),math.floor(220*ratio),50)
            e.hp.Visible=true
        else e.hpBg.Visible=false e.hp.Visible=false end

        -- Tracers
        if CFG.ESPTracers then
            e.tracer.From=Vector2.new(center.X,Camera.ViewportSize.Y)
            e.tracer.To=sp e.tracer.Color=CFG.TracerColor e.tracer.Visible=true
        else e.tracer.Visible=false end
    end
end)

-- ── KEYBINDS ─────────────────────────────────────────
UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightControl then Main.Visible = not Main.Visible end
    if i.KeyCode == Enum.KeyCode.RightShift    then CFG.AimEnabled = not CFG.AimEnabled if quickPills["AimEnabled"] then quickPills["AimEnabled"]() end end
    if i.KeyCode == Enum.KeyCode.F1            then CFG.ESPEnabled = not CFG.ESPEnabled if quickPills["ESPEnabled"] then quickPills["ESPEnabled"]() end end
    if i.KeyCode == Enum.KeyCode.F2            then CFG.TrigEnabled = not CFG.TrigEnabled if quickPills["TrigEnabled"] then quickPills["TrigEnabled"]() end end
    if i.KeyCode == Enum.KeyCode.F3            then CFG.SilentEnabled = not CFG.SilentEnabled if quickPills["SilentEnabled"] then quickPills["SilentEnabled"]() end end
    if i.KeyCode == Enum.KeyCode.Delete then
        -- PANIC: full unload
        setFly(false) setNoclip(false)
        if infJumpConn then infJumpConn:Disconnect() end
        if recoilConn  then recoilConn:Disconnect()  end
        restoreHitboxes()
        local char=LocalPlayer.Character
        if char then
            local hum=char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed=16 hum.PlatformStand=false end
        end
        for _,e in pairs(espPool) do for _,d in pairs(e) do pcall(function() d:Remove() end) end end
        fovCircle:Remove()
        pcall(function() ScreenGui:Destroy() end)
        RunService:UnbindFromRenderStep("AuthX_v3")
        print("[AuthX v3] Unloaded cleanly.")
    end
end)

print("[AuthX v3] Loaded — RCTRL=Menu | RSHIFT=Aim | F1=ESP | F2=Trig | F3=Silent | DEL=Panic")