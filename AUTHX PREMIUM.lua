-- ████████████████████████████████████████████████████████████
-- //  AuthX Suite v3.5  —  KEYAUTH GATED | PREMIUM BUILD
-- //  Paste into Solara / Synapse / Delta, hit Execute
-- //  INSERT = Toggle Menu | DEL = Panic Unload
-- ████████████████████████████████████████████████████████████

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

local KA = {
    name    = "AuthX",
    ownerid = "nydmC2rmel",
    secret  = "cb8c08cd6b956e51d9563b02db523bceec21363cb0cc24228f49bbd3eaebd3c7",
    version = "1.0",
}

local CFG = {
    AimEnabled=true, AimKey=Enum.UserInputType.MouseButton2,
    AimPart="Head", FOVRadius=180, Smoothness=0.20, Prediction=0.13,
    WallCheck=true, TeamCheck=false, FOVVisible=true,
    FOVColor=Color3.fromRGB(255,255,255),
    NoRecoil=true, NoSpread=true, RecoilStrength=0.85,
    SilentEnabled=true, SilentFOV=45, SilentChance=100,
    TrigEnabled=true, TrigDelay=0.065, TrigBurst=0, TrigQuickScope=true,
    ESPEnabled=true, ESPBoxes=true, ESPNames=true, ESPHealth=true,
    ESPDist=true, ESPTracers=false, ESPMaxDist=900, ESPHeadDot=true,
    BoxColor=Color3.fromRGB(255,255,255), NameColor=Color3.fromRGB(255,255,255),
    TracerColor=Color3.fromRGB(255,255,255),
    HitboxEnabled=false, HitboxHead=1.0, HitboxBody=1.0, HitboxLimbs=1.0,
    SpeedEnabled=false, SpeedMult=1.0,
    FlyEnabled=false, FlySpeed=50,
    NoclipEnabled=false,
    InfJumpEnabled=false, JumpCount=99, JumpHeight=1.0,
    BhopEnabled=false,
    StreamProof=true,
    RagebotEnabled=false, RagebotDelay=0.12, RagebotShots=3,
}

local PAL = {
    bg0=Color3.fromRGB(4,4,4),     bg1=Color3.fromRGB(9,9,9),
    bg2=Color3.fromRGB(14,14,14),  bg3=Color3.fromRGB(22,22,22),
    bg4=Color3.fromRGB(30,30,30),
    border=Color3.fromRGB(32,32,32), borderHi=Color3.fromRGB(60,60,60),
    accent=Color3.fromRGB(255,255,255), accentD=Color3.fromRGB(130,130,130),
    textP=Color3.fromRGB(245,245,245), textS=Color3.fromRGB(110,110,110),
    textM=Color3.fromRGB(55,55,55),
    red=Color3.fromRGB(220,55,55), green=Color3.fromRGB(55,215,95),
    gold=Color3.fromRGB(255,210,60),
}

local function inst(cls, props, parent)
    local o = Instance.new(cls)
    for k,v in pairs(props) do pcall(function() o[k]=v end) end
    if parent then o.Parent=parent end
    return o
end
local function corner(p,r) local c=Instance.new("UICorner",p) c.CornerRadius=UDim.new(0,r or 8) return c end
local function stroke(p,c,t) local s=Instance.new("UIStroke",p) s.Color=c or PAL.border s.Thickness=t or 1 return s end
local function lbl(parent, props)
    local l=inst("TextLabel",{BackgroundTransparency=1,Font=Enum.Font.GothamBold,
        TextSize=12,TextColor3=PAL.textP,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center})
    for k,v in pairs(props) do pcall(function() l[k]=v end) end
    l.Parent=parent return l
end
local function screenCenter() return Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2) end
local function toScreen(pos) local v,vis=Camera:WorldToViewportPoint(pos) return Vector2.new(v.X,v.Y),vis,v.Z end
local function inFOV(sp,r) return (sp-screenCenter()).Magnitude<=(r or CFG.FOVRadius) end
local rayParams=RaycastParams.new() rayParams.FilterType=Enum.RaycastFilterType.Exclude
local function isVisible(origin,target,char)
    if not CFG.WallCheck then return true end
    local lc=LocalPlayer.Character
    rayParams.FilterDescendantsInstances=lc and {lc} or {}
    local hit=workspace:Raycast(origin,target-origin,rayParams)
    if not hit then return true end
    return hit.Instance and hit.Instance:IsDescendantOf(char)
end
local function getCharParts(char)
    local head=char:FindFirstChild("Head")
    local torso=char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    local root=char:FindFirstChild("HumanoidRootPart")
    local hum=char:FindFirstChildOfClass("Humanoid")
    return head,torso,root,hum
end
local function getBestTarget(fovRadius)
    local best,bd=nil,math.huge local center=screenCenter()
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr==LocalPlayer then continue end
        if CFG.TeamCheck and plr.Team==LocalPlayer.Team then continue end
        local char=plr.Character if not char then continue end
        local head,torso,root,hum=getCharParts(char)
        if not root or not hum or hum.Health<=0 then continue end
        local aimPart=(CFG.AimPart=="Head" and head) or (CFG.AimPart=="UpperTorso" and torso) or root
        if not aimPart then continue end
        local sp,onScreen,depth=toScreen(aimPart.Position)
        if not onScreen or depth<0 then continue end
        if not inFOV(sp,fovRadius) then continue end
        local d=(sp-center).Magnitude
        if d<bd and isVisible(Camera.CFrame.Position,aimPart.Position,char) then
            bd=d best={aimPart=aimPart,root=root,head=head,char=char,plr=plr,hum=hum,sp=sp,depth=depth}
        end
    end
    return best
end
local function getAllTargets()
    local list={}
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr==LocalPlayer then continue end
        if CFG.TeamCheck and plr.Team==LocalPlayer.Team then continue end
        local char=plr.Character if not char then continue end
        local _,_,root,hum=getCharParts(char)
        if root and hum and hum.Health>0 then table.insert(list,{plr=plr,char=char,root=root,hum=hum}) end
    end
    return list
end

pcall(function() CoreGui:FindFirstChild("AuthX_Gate"):Destroy() end)
pcall(function() CoreGui:FindFirstChild("AuthX_v35"):Destroy() end)

local RootGui=inst("ScreenGui",{Name="AuthX_Gate",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
RootGui.Parent=CoreGui

-- ── GATE FRAME ───────────────────────────────────────────────
local GateFrame=inst("Frame",{
    Name="GateFrame", Size=UDim2.new(0,460,0,300),
    Position=UDim2.new(0.5,-230,0.5,-150),
    BackgroundColor3=PAL.bg0, BorderSizePixel=0,
},RootGui)
corner(GateFrame,14)
stroke(GateFrame,PAL.border,1)
inst("UIGradient",{
    Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(10,10,10)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(4,4,4))
    }), Rotation=135,
},GateFrame)

-- top glow
local gGlow=inst("Frame",{Size=UDim2.new(1,0,0,1.5),BackgroundColor3=PAL.accent,BorderSizePixel=0,ZIndex=2},GateFrame)
corner(gGlow,2)
inst("UIGradient",{Transparency=NumberSequence.new({
    NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.25,0),
    NumberSequenceKeypoint.new(0.75,0),NumberSequenceKeypoint.new(1,1)
})},gGlow)

-- ── LOGO: AuthX then v1.0 BELOW it, no overlap ───────────────
lbl(GateFrame,{
    Text="AuthX", Font=Enum.Font.GothamBold, TextSize=30,
    TextColor3=PAL.textP, Size=UDim2.new(1,0,0,38),
    Position=UDim2.new(0,0,0,24),
    TextXAlignment=Enum.TextXAlignment.Center, ZIndex=3,
})
lbl(GateFrame,{
    Text="v1.0", Font=Enum.Font.Gotham, TextSize=9,
    TextColor3=PAL.textM, Size=UDim2.new(1,0,0,14),
    Position=UDim2.new(0,0,0,62),
    TextXAlignment=Enum.TextXAlignment.Center, ZIndex=3,
})
lbl(GateFrame,{
    Text="KEY VERIFICATION REQUIRED", Font=Enum.Font.GothamBold, TextSize=8,
    TextColor3=PAL.textM, Size=UDim2.new(1,0,0,14),
    Position=UDim2.new(0,0,0,78),
    TextXAlignment=Enum.TextXAlignment.Center, ZIndex=3,
})

-- divider
inst("Frame",{Size=UDim2.new(0,320,0,1),AnchorPoint=Vector2.new(0.5,0),
    Position=UDim2.new(0.5,0,0,100),BackgroundColor3=PAL.border,BorderSizePixel=0,ZIndex=3},GateFrame)

-- key input
local inputBg=inst("Frame",{
    Size=UDim2.new(0,360,0,42), AnchorPoint=Vector2.new(0.5,0),
    Position=UDim2.new(0.5,0,0,112),
    BackgroundColor3=PAL.bg2, BorderSizePixel=0, ZIndex=3,
},GateFrame)
corner(inputBg,8) stroke(inputBg,PAL.border,1)
lbl(inputBg,{Text="🔑",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=PAL.textM,
    Size=UDim2.new(0,32,1,0),Position=UDim2.new(0,10,0,0),
    TextXAlignment=Enum.TextXAlignment.Center,ZIndex=4})
local keyInput=inst("TextBox",{
    Size=UDim2.new(1,-52,1,-2), Position=UDim2.new(0,42,0,1),
    BackgroundTransparency=1, BorderSizePixel=0,
    PlaceholderText="Enter your license key...",
    PlaceholderColor3=PAL.textM, Text="",
    Font=Enum.Font.Gotham, TextSize=13, TextColor3=PAL.textP,
    TextXAlignment=Enum.TextXAlignment.Left,
    ClearTextOnFocus=false, ZIndex=4,
},inputBg)

keyInput.Focused:Connect(function()
    TweenService:Create(inputBg,TweenInfo.new(0.15),{BackgroundColor3=PAL.bg3}):Play()
    stroke(inputBg,PAL.borderHi,1)
end)
keyInput.FocusLost:Connect(function()
    TweenService:Create(inputBg,TweenInfo.new(0.15),{BackgroundColor3=PAL.bg2}):Play()
    stroke(inputBg,PAL.border,1)
end)

local statusLbl=lbl(GateFrame,{
    Text="", Font=Enum.Font.Gotham, TextSize=10,
    TextColor3=PAL.textM, Size=UDim2.new(0,360,0,16),
    AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0,0,162),
    TextXAlignment=Enum.TextXAlignment.Center, ZIndex=3,
})

local verifyBtn=inst("TextButton",{
    Size=UDim2.new(0,180,0,40), AnchorPoint=Vector2.new(0.5,0),
    Position=UDim2.new(0.5,0,0,184),
    BackgroundColor3=PAL.accent, BorderSizePixel=0,
    Text="VERIFY KEY", Font=Enum.Font.GothamBold, TextSize=12,
    TextColor3=PAL.bg0, ZIndex=4, AutoButtonColor=false,
},GateFrame)
corner(verifyBtn,8)
verifyBtn.MouseEnter:Connect(function()
    TweenService:Create(verifyBtn,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(200,200,200)}):Play()
end)
verifyBtn.MouseLeave:Connect(function()
    TweenService:Create(verifyBtn,TweenInfo.new(0.12),{BackgroundColor3=PAL.accent}):Play()
end)

-- ── LOAD OVERLAY ─────────────────────────────────────────────
local LoadOverlay=inst("Frame",{
    Size=UDim2.new(1,0,1,0), BackgroundColor3=PAL.bg0,
    BorderSizePixel=0, ZIndex=20, Visible=false,
},GateFrame)
lbl(LoadOverlay,{
    Text="AuthX", Font=Enum.Font.GothamBold, TextSize=32,
    TextColor3=PAL.textP, Size=UDim2.new(1,0,0,40),
    Position=UDim2.new(0,0,0.25,0), TextXAlignment=Enum.TextXAlignment.Center, ZIndex=21,
})
local loadSub=lbl(LoadOverlay,{
    Text="LOADING SUITE...", Font=Enum.Font.Gotham, TextSize=9,
    TextColor3=PAL.textM, Size=UDim2.new(1,0,0,16),
    Position=UDim2.new(0,0,0.25,46), TextXAlignment=Enum.TextXAlignment.Center, ZIndex=21,
})
local pBarBg=inst("Frame",{
    Size=UDim2.new(0,280,0,3), AnchorPoint=Vector2.new(0.5,0),
    Position=UDim2.new(0.5,0,0.25,72), BackgroundColor3=PAL.bg3,
    BorderSizePixel=0, ZIndex=21,
},LoadOverlay)
corner(pBarBg,4)
local pBarFill=inst("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=PAL.accent,BorderSizePixel=0,ZIndex=22},pBarBg)
corner(pBarFill,4)
inst("UIGradient",{Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(160,160,160)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(255,255,255))
}),Rotation=90},pBarFill)
local shimmer=inst("Frame",{
    Size=UDim2.new(0,60,1,0), Position=UDim2.new(-0.3,0,0,0),
    BackgroundColor3=Color3.fromRGB(255,255,255),
    BackgroundTransparency=0.7, BorderSizePixel=0, ZIndex=23,
},pBarFill)
corner(shimmer,4)
inst("UIGradient",{Transparency=NumberSequence.new({
    NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.4),NumberSequenceKeypoint.new(1,1)
}),Rotation=0},shimmer)
local stepLbl=lbl(LoadOverlay,{
    Text="Initializing...", Font=Enum.Font.Gotham, TextSize=9,
    TextColor3=PAL.textM, Size=UDim2.new(1,0,0,14),
    Position=UDim2.new(0,0,0.25,82), TextXAlignment=Enum.TextXAlignment.Center, ZIndex=21,
})

-- Spinning dots
local spinFrame=inst("Frame",{
    Size=UDim2.new(0,40,0,40), AnchorPoint=Vector2.new(0.5,0),
    Position=UDim2.new(0.5,0,0.25,106),
    BackgroundTransparency=1, ZIndex=21,
},LoadOverlay)
local spinDots={}
for i=1,3 do
    local dot=inst("Frame",{Size=UDim2.new(0,5,0,5),AnchorPoint=Vector2.new(0.5,0.5),
        BackgroundColor3=PAL.textM,BorderSizePixel=0,ZIndex=22},spinFrame)
    corner(dot,4) spinDots[i]=dot
end
local spinAngle=0
local spinConn=RunService.Heartbeat:Connect(function(dt)
    spinAngle=spinAngle+dt*3.5
    for i,dot in ipairs(spinDots) do
        local a=spinAngle+(i-1)*(math.pi*2/3)
        dot.Position=UDim2.new(0.5+math.cos(a)*0.45,0,0.5+math.sin(a)*0.45,0)
        local b=0.4+0.6*math.abs(math.sin(a))
        dot.BackgroundColor3=Color3.fromRGB(math.floor(b*255),math.floor(b*255),math.floor(b*255))
    end
end)

local LOAD_STEPS={
    {t="Connecting to AuthX servers...",    p=0.10},
    {t="Validating license signature...",   p=0.28},
    {t="Decrypting module payloads...",     p=0.45},
    {t="Injecting render hooks...",         p=0.60},
    {t="Loading ESP engine...",             p=0.72},
    {t="Wiring aimbot systems...",          p=0.83},
    {t="Calibrating ragebot...",            p=0.91},
    {t="Suite ready.",                      p=1.00},
}
local function runLoadSequence(onComplete)
    LoadOverlay.Visible=true
    local function stepTo(idx)
        if idx>#LOAD_STEPS then task.delay(0.4,onComplete) return end
        local s=LOAD_STEPS[idx]
        stepLbl.Text=s.t
        TweenService:Create(pBarFill,TweenInfo.new(0.32,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
            {Size=UDim2.new(s.p,0,1,0)}):Play()
        shimmer.Position=UDim2.new(-0.3,0,0,0)
        TweenService:Create(shimmer,TweenInfo.new(0.32),{Position=UDim2.new(1.3,0,0,0)}):Play()
        task.delay(0.36,function() stepTo(idx+1) end)
    end
    stepTo(1)
end

-- ── KEYAUTH: INIT → LICENSE (two-step, session ID fixed) ─────
local function httpRequest(url, method)
    method = method or "GET"
    local fn = (syn and syn.request)
             or (http_request)
             or (request)
             or (http and http.request)
    if fn then
        local ok,res=pcall(fn,{Url=url,Method=method})
        if ok and res then return res.Body end
    end
    -- fallback
    local ok2,res2=pcall(function() return game:GetService("HttpService"):GetAsync(url) end)
    if ok2 then return res2 end
    return nil
end

local function verifyKey(key, onSuccess, onFail)
    task.spawn(function()
        -- STEP 1: init — get a session ID
        local initUrl = ("https://keyauth.win/api/1.2/?type=init&ver=%s&name=%s&ownerid=%s"):format(
            KA.version, KA.name, KA.ownerid)
        local initBody = httpRequest(initUrl)
        if not initBody then
            onFail("Could not reach KeyAuth servers.") return
        end
        local initOk, initData = pcall(function()
            return HttpService:JSONDecode(initBody)
        end)
        if not initOk or type(initData)~="table" then
            onFail("Init response parse error.") return
        end
        if not initData.sessionid then
            -- some builds return message on failure
            local msg = initData.message or "Init failed — check app credentials."
            onFail(msg) return
        end
        local sessionId = initData.sessionid

        -- STEP 2: license check with session ID
        local licUrl = ("https://keyauth.win/api/1.2/?type=license&key=%s&sessionid=%s&name=%s&ownerid=%s"):format(
            key, sessionId, KA.name, KA.ownerid)
        local licBody = httpRequest(licUrl)
        if not licBody then
            onFail("License check request failed.") return
        end
        local licOk, licData = pcall(function()
            return HttpService:JSONDecode(licBody)
        end)
        if not licOk or type(licData)~="table" then
            onFail("License response parse error.") return
        end
        if licData.success==true or licData.message=="succeeded" then
            onSuccess(licData)
        else
            onFail(licData.message or "Invalid license key.")
        end
    end)
end

-- ── VERIFY LOGIC ─────────────────────────────────────────────
local verifying=false
local function attemptVerify()
    if verifying then return end
    local key=keyInput.Text:match("^%s*(.-)%s*$")
    if #key<4 then
        statusLbl.Text="⚠  Please enter a valid key."
        statusLbl.TextColor3=PAL.gold return
    end
    verifying=true
    verifyBtn.Text="VERIFYING..."
    verifyBtn.BackgroundColor3=PAL.bg3
    verifyBtn.TextColor3=PAL.textM
    statusLbl.Text="Initializing session..."
    statusLbl.TextColor3=PAL.textM

    verifyKey(key,
        function()
            statusLbl.Text="✓  License accepted."
            statusLbl.TextColor3=PAL.green
            task.delay(0.4,function()
                TweenService:Create(GateFrame,TweenInfo.new(0.35,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
                    {BackgroundTransparency=0.5}):Play()
                task.delay(0.15,function()
                    runLoadSequence(function()
                        spinConn:Disconnect()
                        GateFrame:Destroy()
                        loadMainUI()
                    end)
                end)
            end)
        end,
        function(msg)
            verifying=false
            statusLbl.Text="✗  "..msg
            statusLbl.TextColor3=PAL.red
            verifyBtn.Text="VERIFY KEY"
            verifyBtn.BackgroundColor3=PAL.accent
            verifyBtn.TextColor3=PAL.bg0
            -- shake
            local orig=GateFrame.Position
            for i=1,6 do
                task.delay(i*0.05,function()
                    local sh=i%2==0 and -5 or 5
                    GateFrame.Position=UDim2.new(orig.X.Scale,orig.X.Offset+sh,orig.Y.Scale,orig.Y.Offset)
                end)
            end
            task.delay(0.36,function() GateFrame.Position=orig end)
        end
    )
end
verifyBtn.MouseButton1Click:Connect(attemptVerify)
keyInput.FocusLost:Connect(function(enter) if enter then attemptVerify() end end)

-- Gate drag
do
    local drag,ds,sp2=false,nil,nil
    GateFrame.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true ds=i.Position sp2=GateFrame.Position end
    end)
    GateFrame.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds
            GateFrame.Position=UDim2.new(sp2.X.Scale,sp2.X.Offset+d.X,sp2.Y.Scale,sp2.Y.Offset+d.Y)
        end
    end)
end

-- ████████████████████████████████████████████████████████████
-- ── MAIN UI ──────────────────────────────────────────────────
-- ████████████████████████████████████████████████████████████
function loadMainUI()
    local ScreenGui=inst("ScreenGui",{Name="AuthX_v35",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    ScreenGui.Parent=CoreGui

    local origSizes={}
    local function applyHitboxes()
        if not CFG.HitboxEnabled then return end
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr==LocalPlayer then continue end
            local char=plr.Character if not char then continue end
            for _,part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    if not origSizes[part] then origSizes[part]=part.Size end
                    local n=part.Name:lower()
                    local scale=CFG.HitboxLimbs
                    if n:find("head") then scale=CFG.HitboxHead
                    elseif n:find("torso") or n:find("chest") then scale=CFG.HitboxBody end
                    part.Size=origSizes[part]*scale
                end
            end
        end
    end
    local function restoreHitboxes()
        for part,sz in pairs(origSizes) do pcall(function() part.Size=sz end) end origSizes={}
    end
    local recoilConn
    local function enableNoRecoil()
        if recoilConn then recoilConn:Disconnect() end
        recoilConn=RunService.RenderStepped:Connect(function()
            if not CFG.NoRecoil then return end
            local cf=Camera.CFrame
            local _,_,_,_,rx,_=cf:ToEulerAnglesYXZ()
            if math.abs(rx)>0.001 then
                Camera.CFrame=CFrame.new(cf.Position)*CFrame.Angles(rx*(1-CFG.RecoilStrength),0,0)
                    *CFrame.Angles(0,select(2,cf:ToEulerAnglesYXZ()),0)
            end
        end)
    end
    enableNoRecoil()
    local noclipConn
    local function setNoclip(state)
        if noclipConn then noclipConn:Disconnect() noclipConn=nil end
        if state then
            noclipConn=RunService.Stepped:Connect(function()
                local char=LocalPlayer.Character if not char then return end
                for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
            end)
        else
            local char=LocalPlayer.Character
            if char then for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=true end end end
        end
    end
    local flyConn,flyBV
    local function setFly(state)
        if flyConn then flyConn:Disconnect() flyConn=nil end
        local char=LocalPlayer.Character if not char then return end
        local root=char:FindFirstChild("HumanoidRootPart") if not root then return end
        if flyBV then pcall(function() flyBV:Destroy() end) flyBV=nil end
        if state then
            local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.PlatformStand=true end
            flyBV=Instance.new("BodyVelocity",root)
            flyBV.MaxForce=Vector3.new(1e5,1e5,1e5) flyBV.Velocity=Vector3.zero
            flyConn=RunService.RenderStepped:Connect(function()
                local mv=Vector3.zero local cf=Camera.CFrame
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv=mv-Vector3.new(0,1,0) end
                if flyBV then flyBV.Velocity=mv*CFG.FlySpeed end
            end)
        else
            local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.PlatformStand=false end
        end
    end
    local infJumpConn,jumpCounter=nil,0
    local function setupInfJump()
        if infJumpConn then infJumpConn:Disconnect() infJumpConn=nil end
        if not CFG.InfJumpEnabled then return end
        infJumpConn=UserInputService.JumpRequest:Connect(function()
            local char=LocalPlayer.Character if not char then return end
            local hum=char:FindFirstChildOfClass("Humanoid")
            local root=char:FindFirstChild("HumanoidRootPart")
            if not hum or not root then return end
            local limit=CFG.JumpCount>=99 and math.huge or CFG.JumpCount
            if jumpCounter<limit then
                jumpCounter=jumpCounter+1
                local bv=Instance.new("BodyVelocity",root)
                bv.MaxForce=Vector3.new(0,1e5,0) bv.Velocity=Vector3.new(0,50*CFG.JumpHeight,0)
                game:GetService("Debris"):AddItem(bv,0.12)
            end
        end)
        local char=LocalPlayer.Character
        if char then
            local hum=char:FindFirstChildOfClass("Humanoid")
            if hum then hum.StateChanged:Connect(function(_,new) if new==Enum.HumanoidStateType.Landed then jumpCounter=0 end end) end
        end
    end

    -- Ragebot
    local rbRunning=false
    local function stopRagebot() rbRunning=false end
    local function startRagebot()
        if rbRunning then return end rbRunning=true
        task.spawn(function()
            while rbRunning and CFG.RagebotEnabled do
                local targets=getAllTargets()
                if #targets==0 then task.wait(0.2) continue end
                for _,t in ipairs(targets) do
                    if not rbRunning or not CFG.RagebotEnabled then break end
                    local char=LocalPlayer.Character if not char then break end
                    local root=char:FindFirstChild("HumanoidRootPart") if not root then break end
                    local offset=t.root.CFrame.LookVector*-3
                    root.CFrame=CFrame.new(t.root.Position+offset)*CFrame.Angles(0,math.pi,0)
                    task.wait(0.08)
                    local head=getCharParts(t.char)
                    Camera.CFrame=CFrame.new(Camera.CFrame.Position,(head or t.root).Position)
                    local m2=LocalPlayer:GetMouse()
                    for s=1,CFG.RagebotShots do
                        pcall(function() m2:Button1Down() end) task.wait(0.04)
                        pcall(function() m2:Button1Up() end) task.wait(CFG.RagebotDelay)
                        if not rbRunning then break end
                    end
                    local waited=0
                    while rbRunning and t.hum and t.hum.Health>0 and waited<3 do task.wait(0.1) waited=waited+0.1 end
                    task.wait(0.1)
                end
                task.wait(0.1)
            end
        end)
    end

    -- FOV
    local fovCircle=Drawing.new("Circle")
    fovCircle.Radius=CFG.FOVRadius fovCircle.Color=Color3.fromRGB(255,255,255)
    fovCircle.Thickness=1 fovCircle.NumSides=80 fovCircle.Filled=false fovCircle.Visible=CFG.FOVVisible

    -- ESP
    local function newDraw(t,p) local d=Drawing.new(t) for k,v in pairs(p) do d[k]=v end return d end
    local espPool={}
    local function getESP(plr)
        if not espPool[plr] then
            espPool[plr]={
                box=newDraw("Square",{Thickness=0.8,Color=CFG.BoxColor,Filled=false,Visible=false}),
                cTL=newDraw("Line",{Thickness=2,Color=CFG.BoxColor,Visible=false}),
                cTR=newDraw("Line",{Thickness=2,Color=CFG.BoxColor,Visible=false}),
                cBL=newDraw("Line",{Thickness=2,Color=CFG.BoxColor,Visible=false}),
                cBR=newDraw("Line",{Thickness=2,Color=CFG.BoxColor,Visible=false}),
                name=newDraw("Text",{Size=13,Color=CFG.NameColor,Center=true,Outline=true,Visible=false}),
                dist=newDraw("Text",{Size=11,Color=Color3.fromRGB(160,160,160),Center=true,Outline=true,Visible=false}),
                hpBg=newDraw("Square",{Thickness=1,Color=Color3.fromRGB(20,20,20),Filled=true,Visible=false}),
                hp=newDraw("Square",{Thickness=1,Color=Color3.fromRGB(80,255,100),Filled=true,Visible=false}),
                tracer=newDraw("Line",{Thickness=1,Color=CFG.TracerColor,Visible=false}),
                head=newDraw("Circle",{Radius=5,Thickness=1,Color=CFG.BoxColor,Filled=false,NumSides=20,Visible=false}),
                rbMarker=newDraw("Text",{Size=13,Color=Color3.fromRGB(220,60,60),Center=true,Outline=true,Text="[RAGE]",Visible=false}),
            }
        end
        return espPool[plr]
    end
    local function hideESP(e) for _,d in pairs(e) do d.Visible=false end end
    Players.PlayerRemoving:Connect(function(plr)
        if espPool[plr] then for _,d in pairs(espPool[plr]) do pcall(function() d:Remove() end) end espPool[plr]=nil end
    end)
    local function cleanStale()
        for plr in pairs(espPool) do
            if not Players:FindFirstChild(plr.Name) then
                for _,d in pairs(espPool[plr]) do pcall(function() d:Remove() end) end espPool[plr]=nil
            end
        end
    end
    local function drawCorners(e,x,y,w,h)
        local cL=math.floor(math.min(w,h)*0.25) local c=CFG.BoxColor
        e.cTL.From=Vector2.new(x,y+cL)     e.cTL.To=Vector2.new(x,y)       e.cTL.Color=c e.cTL.Visible=true
        e.cTR.From=Vector2.new(x+w-cL,y)   e.cTR.To=Vector2.new(x+w,y)     e.cTR.Color=c e.cTR.Visible=true
        e.cBL.From=Vector2.new(x,y+h-cL)   e.cBL.To=Vector2.new(x,y+h)     e.cBL.Color=c e.cBL.Visible=true
        e.cBR.From=Vector2.new(x+w,y+h-cL) e.cBR.To=Vector2.new(x+w,y+h)   e.cBR.Color=c e.cBR.Visible=true
    end
    local function updateESPColors()
        for _,e in pairs(espPool) do
            for _,k in ipairs({"cTL","cTR","cBL","cBR","box","head"}) do if e[k] then e[k].Color=CFG.BoxColor end end
            if e.tracer then e.tracer.Color=CFG.TracerColor end
            if e.name   then e.name.Color=CFG.NameColor end
        end
    end

    -- ── MAIN FRAME ───────────────────────────────────────────
    local Main=inst("Frame",{
        Name="Main", Size=UDim2.new(0,720,0,500),
        Position=UDim2.new(0.5,-360,0.5,-250),
        BackgroundColor3=PAL.bg0, BorderSizePixel=0,
    },ScreenGui)
    corner(Main,14) stroke(Main,PAL.border,1)
    inst("UIGradient",{Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(10,10,10)),
        ColorSequenceKeypoint.new(1,PAL.bg0)
    }),Rotation=150},Main)
    local topGlow2=inst("Frame",{Size=UDim2.new(1,0,0,1.5),BackgroundColor3=PAL.accent,BorderSizePixel=0,ZIndex=3},Main)
    corner(topGlow2,2)
    inst("UIGradient",{Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.2,0),
        NumberSequenceKeypoint.new(0.8,0),NumberSequenceKeypoint.new(1,1)
    })},topGlow2)
    local drag2,ds2,sp3=false,nil,nil
    Main.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag2=true ds2=i.Position sp3=Main.Position end
    end)
    Main.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag2=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag2 and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds2
            Main.Position=UDim2.new(sp3.X.Scale,sp3.X.Offset+d.X,sp3.Y.Scale,sp3.Y.Offset+d.Y)
        end
    end)

    -- Topbar
    local Topbar=inst("Frame",{Size=UDim2.new(1,0,0,46),BackgroundColor3=PAL.bg1,BorderSizePixel=0,ZIndex=2},Main)
    corner(Topbar,14) inst("UIStroke",{Color=PAL.border,Thickness=1},Topbar)
    lbl(Topbar,{Text="AuthX",Font=Enum.Font.GothamBold,TextSize=16,TextColor3=PAL.textP,
        Size=UDim2.new(0,60,1,0),Position=UDim2.new(0,18,0,0),ZIndex=3})
    lbl(Topbar,{Text="v3.5",Font=Enum.Font.Gotham,TextSize=9,TextColor3=PAL.textM,
        Size=UDim2.new(0,40,0,14),Position=UDim2.new(0,62,0.5,-2),ZIndex=3})
    local sDot=inst("Frame",{Size=UDim2.new(0,7,0,7),AnchorPoint=Vector2.new(0,0.5),
        Position=UDim2.new(0,112,0.5,0),BackgroundColor3=PAL.green,BorderSizePixel=0,ZIndex=3},Topbar)
    corner(sDot,8)
    lbl(Topbar,{Text="AUTHENTICATED",Font=Enum.Font.GothamBold,TextSize=9,
        TextColor3=Color3.fromRGB(55,215,95),
        Size=UDim2.new(0,110,0,20),Position=UDim2.new(0,124,0.5,-10),ZIndex=3})
    local closeBtn=inst("TextButton",{Text="×",Size=UDim2.new(0,28,0,28),
        Position=UDim2.new(1,-38,0.5,-14),BackgroundColor3=PAL.bg3,BorderSizePixel=0,
        TextColor3=PAL.textS,Font=Enum.Font.GothamBold,TextSize=18,ZIndex=3,AutoButtonColor=false},Topbar)
    corner(closeBtn,6)
    closeBtn.MouseButton1Click:Connect(function() Main.Visible=false end)
    closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3=PAL.red end)
    closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3=PAL.textS end)

    -- Nav + content
    local tabNames={"AIMBOT","TRIGGERBOT","ESP","MOVEMENT","RAGEBOT","MISC"}
    local tabPages={} local tabBtns={}
    local NavBar=inst("Frame",{Size=UDim2.new(0,126,1,-54),Position=UDim2.new(0,0,0,54),
        BackgroundColor3=PAL.bg1,BorderSizePixel=0},Main)
    inst("UIStroke",{Color=PAL.border,Thickness=1},NavBar)
    inst("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2)},NavBar)
    inst("UIPadding",{PaddingTop=UDim.new(0,10),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},NavBar)
    local ContentArea=inst("Frame",{Size=UDim2.new(1,-126,1,-54),Position=UDim2.new(0,126,0,54),
        BackgroundColor3=PAL.bg0,BorderSizePixel=0},Main)
    inst("UIStroke",{Color=PAL.border,Thickness=1},ContentArea)
    local QuickPanel=inst("Frame",{Size=UDim2.new(0,162,1,0),Position=UDim2.new(1,-162,0,0),
        BackgroundColor3=PAL.bg1,BorderSizePixel=0},ContentArea)
    inst("UIStroke",{Color=PAL.border,Thickness=1},QuickPanel)
    lbl(QuickPanel,{Text="QUICK STATUS",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,
        Size=UDim2.new(1,-16,0,16),Position=UDim2.new(0,8,0,12)})
    inst("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,3)},QuickPanel)
    inst("UIPadding",{PaddingTop=UDim.new(0,36),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},QuickPanel)
    local quickPills={}
    local function makeQuickPill(label,cfgKey)
        local pill=inst("TextButton",{Size=UDim2.new(1,0,0,28),BackgroundColor3=PAL.bg2,
            BorderSizePixel=0,Text="",AutoButtonColor=false})
        corner(pill,6) stroke(pill,PAL.border)
        local pl2=lbl(pill,{Text=label,Font=Enum.Font.Gotham,TextSize=11,
            TextColor3=CFG[cfgKey] and PAL.textP or PAL.textM,
            Size=UDim2.new(1,-30,1,0),Position=UDim2.new(0,10,0,0)})
        local dot2=inst("Frame",{Size=UDim2.new(0,7,0,7),AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(1,-14,0.5,0),
            BackgroundColor3=CFG[cfgKey] and PAL.accent or PAL.textM,BorderSizePixel=0},pill)
        corner(dot2,8)
        local function sync()
            local on=CFG[cfgKey]
            TweenService:Create(dot2,TweenInfo.new(0.12),{BackgroundColor3=on and PAL.accent or PAL.textM}):Play()
            pl2.TextColor3=on and PAL.textP or PAL.textM
            pill.BackgroundColor3=on and PAL.bg3 or PAL.bg2
        end
        pill.MouseButton1Click:Connect(function()
            CFG[cfgKey]=not CFG[cfgKey] sync()
            if cfgKey=="RagebotEnabled" then if CFG.RagebotEnabled then startRagebot() else stopRagebot() end end
        end)
        pill.Parent=QuickPanel quickPills[cfgKey]=sync
    end
    makeQuickPill("Aimbot","AimEnabled") makeQuickPill("Silent Aim","SilentEnabled")
    makeQuickPill("Triggerbot","TrigEnabled") makeQuickPill("ESP","ESPEnabled")
    makeQuickPill("Wallhack","ESPBoxes") makeQuickPill("No Recoil","NoRecoil")
    makeQuickPill("Ragebot","RagebotEnabled") makeQuickPill("Speed Hack","SpeedEnabled")
    makeQuickPill("Fly Hack","FlyEnabled") makeQuickPill("No Clip","NoclipEnabled")
    makeQuickPill("Inf. Jump","InfJumpEnabled") makeQuickPill("Hitbox Ext.","HitboxEnabled")

    local PanelArea=inst("Frame",{Size=UDim2.new(1,-162,1,0),BackgroundTransparency=1,BorderSizePixel=0},ContentArea)
    local function makePage()
        local sf=Instance.new("ScrollingFrame")
        sf.Size=UDim2.new(1,0,1,0) sf.BackgroundTransparency=1 sf.BorderSizePixel=0
        sf.ScrollBarThickness=2 sf.ScrollBarImageColor3=PAL.bg4
        sf.CanvasSize=UDim2.new(0,0,0,0) sf.AutomaticCanvasSize=Enum.AutomaticSize.Y
        sf.Visible=false sf.Parent=PanelArea
        inst("UIPadding",{PaddingTop=UDim.new(0,12),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},sf)
        inst("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8)},sf)
        return sf
    end
    local function mkCard(parent,order)
        local card=inst("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundColor3=PAL.bg2,BorderSizePixel=0,LayoutOrder=order or 0},parent)
        corner(card,8) stroke(card,PAL.border)
        inst("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,0)},card)
        inst("UIPadding",{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,10),
            PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},card)
        return card
    end
    local function mkCardHdr(parent,text,order)
        local f=inst("Frame",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=order or 0},parent)
        lbl(f,{Text=text,Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textM,Size=UDim2.new(1,0,1,0)})
        return f
    end
    local function mkRow(parent,order)
        return inst("Frame",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=order or 0},parent)
    end
    local function mkToggleRow(parent,labelText,cfgKey,order,onChange)
        local row=mkRow(parent,order)
        lbl(row,{Text=labelText,Font=Enum.Font.Gotham,TextSize=12,TextColor3=PAL.textS,Size=UDim2.new(1,-52,1,0)})
        local track=inst("Frame",{Size=UDim2.new(0,34,0,18),Position=UDim2.new(1,-34,0.5,-9),
            BackgroundColor3=CFG[cfgKey] and PAL.accent or PAL.bg4,BorderSizePixel=0},row)
        corner(track,10)
        local thumb=inst("Frame",{Size=UDim2.new(0,12,0,12),
            Position=CFG[cfgKey] and UDim2.new(0,19,0,3) or UDim2.new(0,3,0,3),
            BackgroundColor3=CFG[cfgKey] and PAL.bg0 or PAL.textM,BorderSizePixel=0},track)
        corner(thumb,8)
        local ti2=TweenInfo.new(0.14)
        local btn2=inst("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""},row)
        btn2.MouseButton1Click:Connect(function()
            CFG[cfgKey]=not CFG[cfgKey] local on=CFG[cfgKey]
            TweenService:Create(track,ti2,{BackgroundColor3=on and PAL.accent or PAL.bg4}):Play()
            TweenService:Create(thumb,ti2,{Position=on and UDim2.new(0,19,0,3) or UDim2.new(0,3,0,3),
                BackgroundColor3=on and PAL.bg0 or PAL.textM}):Play()
            if quickPills[cfgKey] then quickPills[cfgKey]() end
            if onChange then onChange(on) end
        end)
    end
    local function mkSliderRow(parent,labelText,cfgKey,minV,maxV,fmt,order,onChange)
        local row=inst("Frame",{Size=UDim2.new(1,0,0,48),BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=order or 0},parent)
        lbl(row,{Text=labelText,Font=Enum.Font.Gotham,TextSize=12,TextColor3=PAL.textS,Size=UDim2.new(0.6,0,0,20),Position=UDim2.new(0,0,0,2)})
        local valLbl2=lbl(row,{Text=fmt(CFG[cfgKey]),Font=Enum.Font.GothamBold,TextSize=11,
            TextColor3=PAL.accentD,Size=UDim2.new(0.4,0,0,20),Position=UDim2.new(0.6,0,0,2),TextXAlignment=Enum.TextXAlignment.Right})
        local tBg3=inst("Frame",{Size=UDim2.new(1,0,0,3),Position=UDim2.new(0,0,0,28),BackgroundColor3=PAL.bg4,BorderSizePixel=0},row)
        corner(tBg3,4)
        local pct3=math.clamp((CFG[cfgKey]-minV)/(maxV-minV),0,1)
        local fl3=inst("Frame",{Size=UDim2.new(pct3,0,1,0),BackgroundColor3=PAL.accent,BorderSizePixel=0},tBg3)
        corner(fl3,4)
        inst("UIGradient",{Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(140,140,140)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,255,255))
        }),Rotation=90},fl3)
        local th3=inst("Frame",{Size=UDim2.new(0,13,0,13),AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(pct3,0,0.5,0),BackgroundColor3=PAL.accent,BorderSizePixel=0,ZIndex=3},tBg3)
        corner(th3,8)
        local drag3=false
        local function upd3(pos)
            local r=math.clamp((pos.X-tBg3.AbsolutePosition.X)/math.max(tBg3.AbsoluteSize.X,1),0,1)
            local cur=minV+(maxV-minV)*r
            if minV==math.floor(minV) and maxV==math.floor(maxV) then cur=math.floor(cur) end
            CFG[cfgKey]=cur fl3.Size=UDim2.new(r,0,1,0) th3.Position=UDim2.new(r,0,0.5,0)
            valLbl2.Text=fmt(cur) if onChange then onChange(cur) end
        end
        local sb3=inst("TextButton",{Size=UDim2.new(1,0,0,20),Position=UDim2.new(0,0,0,20),
            BackgroundTransparency=1,Text="",ZIndex=4},row)
        sb3.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag3=true upd3(i.Position) end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag3=false end end)
        UserInputService.InputChanged:Connect(function(i) if drag3 and i.UserInputType==Enum.UserInputType.MouseMovement then upd3(i.Position) end end)
    end
    local function mkDropRow(parent,labelText,options,cfgKey,order,onChange)
        local row=mkRow(parent,order) row.Size=UDim2.new(1,0,0,30)
        lbl(row,{Text=labelText,Font=Enum.Font.Gotham,TextSize=12,TextColor3=PAL.textS,Size=UDim2.new(0.55,0,1,0)})
        local sel2=inst("TextButton",{Size=UDim2.new(0.42,0,0,22),Position=UDim2.new(0.57,0,0.5,-11),
            BackgroundColor3=PAL.bg4,BorderSizePixel=0,Text=CFG[cfgKey],Font=Enum.Font.Gotham,TextSize=10,TextColor3=PAL.textP},row)
        corner(sel2,5) stroke(sel2,PAL.border)
        local open2=false local dd2
        sel2.MouseButton1Click:Connect(function()
            open2=not open2 if dd2 then dd2:Destroy() dd2=nil end
            if not open2 then return end
            dd2=inst("Frame",{Size=UDim2.new(0.42,0,0,#options*24+4),Position=UDim2.new(0.57,0,0.5,12),
                BackgroundColor3=PAL.bg3,BorderSizePixel=0,ZIndex=10},row)
            corner(dd2,6) stroke(dd2,PAL.border)
            for idx2,opt2 in ipairs(options) do
                local ob2=inst("TextButton",{Size=UDim2.new(1,-8,0,22),Position=UDim2.new(0,4,0,(idx2-1)*24+2),
                    BackgroundTransparency=1,Text=opt2,Font=Enum.Font.Gotham,TextSize=10,
                    TextColor3=opt2==CFG[cfgKey] and PAL.textP or PAL.textS,ZIndex=11},dd2)
                ob2.MouseButton1Click:Connect(function()
                    CFG[cfgKey]=opt2 sel2.Text=opt2 open2=false dd2:Destroy() dd2=nil
                    if onChange then onChange(opt2) end
                end)
            end
        end)
    end

    -- Pages
    local p1=makePage() tabPages[1]=p1
    local c1a=mkCard(p1,1) mkCardHdr(c1a,"AIMBOT",0)
    mkToggleRow(c1a,"Enable Aimbot","AimEnabled",1)
    mkToggleRow(c1a,"Wall Check","WallCheck",2)
    mkToggleRow(c1a,"Team Check","TeamCheck",3)
    mkToggleRow(c1a,"Show FOV Circle","FOVVisible",4,function(v) fovCircle.Visible=v end)
    mkDropRow(c1a,"Bone Target",{"Head","UpperTorso","Torso","HumanoidRootPart"},"AimPart",5)
    mkSliderRow(c1a,"FOV Radius","FOVRadius",30,500,function(v) return math.floor(v).."px" end,6)
    mkSliderRow(c1a,"Smoothness","Smoothness",0.01,1.0,function(v) return math.floor(v*100).."%" end,7)
    mkSliderRow(c1a,"Prediction","Prediction",0,0.5,function(v) return ("%.2f"):format(v) end,8)
    local c1b=mkCard(p1,2) mkCardHdr(c1b,"SILENT AIM",0)
    mkToggleRow(c1b,"Enable Silent Aim","SilentEnabled",1)
    mkSliderRow(c1b,"Silent FOV","SilentFOV",5,180,function(v) return math.floor(v).."px" end,2)
    mkSliderRow(c1b,"Hit Chance","SilentChance",1,100,function(v) return math.floor(v).."%" end,3)
    local c1c=mkCard(p1,3) mkCardHdr(c1c,"RECOIL & SPREAD",0)
    mkToggleRow(c1c,"No Recoil","NoRecoil",1,function(v) if not v and recoilConn then recoilConn:Disconnect() recoilConn=nil else enableNoRecoil() end end)
    mkToggleRow(c1c,"No Spread","NoSpread",2)
    mkSliderRow(c1c,"Recoil Strength","RecoilStrength",0.1,1.0,function(v) return math.floor(v*100).."%" end,3)
    local c1d=mkCard(p1,4) mkCardHdr(c1d,"HITBOX EXTENDER",0)
    mkToggleRow(c1d,"Enable Hitbox","HitboxEnabled",1,function(v) if not v then restoreHitboxes() end end)
    mkSliderRow(c1d,"Head Scale","HitboxHead",1.0,5.0,function(v) return ("%.1fx"):format(v) end,2)
    mkSliderRow(c1d,"Body Scale","HitboxBody",1.0,5.0,function(v) return ("%.1fx"):format(v) end,3)
    mkSliderRow(c1d,"Limb Scale","HitboxLimbs",1.0,5.0,function(v) return ("%.1fx"):format(v) end,4)

    local p2=makePage() tabPages[2]=p2
    local c2a=mkCard(p2,1) mkCardHdr(c2a,"TRIGGERBOT",0)
    mkToggleRow(c2a,"Enable Triggerbot","TrigEnabled",1)
    mkToggleRow(c2a,"Quick Scope","TrigQuickScope",2)
    mkSliderRow(c2a,"Reaction Delay","TrigDelay",0,0.3,function(v) return math.floor(v*1000).."ms" end,3)
    mkSliderRow(c2a,"Burst Time","TrigBurst",0,0.5,function(v) return math.floor(v*1000).."ms" end,4)

    local p3=makePage() tabPages[3]=p3
    local c3a=mkCard(p3,1) mkCardHdr(c3a,"PLAYER ESP",0)
    mkToggleRow(c3a,"Enable ESP","ESPEnabled",1)
    mkToggleRow(c3a,"Corner Boxes","ESPBoxes",2)
    mkToggleRow(c3a,"Name Tags","ESPNames",3)
    mkToggleRow(c3a,"Health Bars","ESPHealth",4)
    mkToggleRow(c3a,"Distance","ESPDist",5)
    mkToggleRow(c3a,"Tracers","ESPTracers",6)
    mkToggleRow(c3a,"Head Dot","ESPHeadDot",7)
    mkSliderRow(c3a,"Max Distance","ESPMaxDist",50,2000,function(v) return math.floor(v).."m" end,8)

    local p4=makePage() tabPages[4]=p4
    local c4a=mkCard(p4,1) mkCardHdr(c4a,"SPEED HACK",0)
    mkToggleRow(c4a,"Enable Speed","SpeedEnabled",1,function(v)
        local char=LocalPlayer.Character
        if char then local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.WalkSpeed=v and 16*CFG.SpeedMult or 16 end end
    end)
    mkSliderRow(c4a,"Speed Multiplier","SpeedMult",1.0,10.0,function(v) return ("%.1fx"):format(v) end,2,function(v)
        if CFG.SpeedEnabled then
            local char=LocalPlayer.Character
            if char then local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.WalkSpeed=16*v end end
        end
    end)
    local c4b=mkCard(p4,2) mkCardHdr(c4b,"FLY HACK",0)
    mkToggleRow(c4b,"Enable Fly","FlyEnabled",1,function(v) setFly(v) end)
    mkToggleRow(c4b,"Noclip Mode","NoclipEnabled",2,function(v) setNoclip(v) end)
    mkSliderRow(c4b,"Fly Speed","FlySpeed",5,200,function(v) return math.floor(v).." wu/s" end,3)
    local c4c=mkCard(p4,3) mkCardHdr(c4c,"JUMP",0)
    mkToggleRow(c4c,"Infinite Jump","InfJumpEnabled",1,function() setupInfJump() end)
    mkToggleRow(c4c,"Bunny Hop","BhopEnabled",2)
    mkSliderRow(c4c,"Jump Count","JumpCount",1,99,function(v) return v>=99 and "INF" or tostring(math.floor(v)) end,3)
    mkSliderRow(c4c,"Jump Height","JumpHeight",1.0,5.0,function(v) return ("%.1fx"):format(v) end,4)

    local p5=makePage() tabPages[5]=p5
    local c5a=mkCard(p5,1) mkCardHdr(c5a,"RAGEBOT",0)
    local warnRow=inst("Frame",{Size=UDim2.new(1,0,0,28),BackgroundColor3=Color3.fromRGB(35,10,10),
        BorderSizePixel=0,LayoutOrder=1},c5a)
    corner(warnRow,6) inst("UIStroke",{Color=Color3.fromRGB(80,20,20),Thickness=1},warnRow)
    lbl(warnRow,{Text="⚠  Teleports to each target and executes.",Font=Enum.Font.Gotham,TextSize=9,
        TextColor3=Color3.fromRGB(200,80,80),Size=UDim2.new(1,-16,1,0),Position=UDim2.new(0,8,0,0)})
    mkToggleRow(c5a,"Enable Ragebot","RagebotEnabled",2,function(v) if v then startRagebot() else stopRagebot() end end)
    mkToggleRow(c5a,"Team Check","TeamCheck",3)
    mkSliderRow(c5a,"Shot Delay","RagebotDelay",0.05,1.0,function(v) return math.floor(v*1000).."ms" end,4)
    mkSliderRow(c5a,"Shots Per Target","RagebotShots",1,10,function(v) return tostring(math.floor(v)) end,5)

    local p6=makePage() tabPages[6]=p6
    local c6a=mkCard(p6,1) mkCardHdr(c6a,"SYSTEM",0)
    mkToggleRow(c6a,"Stream Proof","StreamProof",1)
    local function mkKeyRow(parent,lText,kStr,order)
        local row=mkRow(parent,order)
        lbl(row,{Text=lText,Font=Enum.Font.Gotham,TextSize=12,TextColor3=PAL.textS,Size=UDim2.new(0.6,0,1,0)})
        local kb2=inst("TextButton",{Size=UDim2.new(0,80,0,20),Position=UDim2.new(1,-80,0.5,-10),
            BackgroundColor3=PAL.bg4,BorderSizePixel=0,Text=kStr,Font=Enum.Font.GothamBold,TextSize=9,TextColor3=PAL.textP},row)
        corner(kb2,4) stroke(kb2,PAL.border)
    end
    mkKeyRow(c6a,"Toggle Menu","INSERT",2) mkKeyRow(c6a,"Panic Unload","DEL",3)
    mkKeyRow(c6a,"Toggle Aimbot","RSHIFT",4) mkKeyRow(c6a,"Toggle ESP","F1",5)
    mkKeyRow(c6a,"Toggle Triggerbot","F2",6) mkKeyRow(c6a,"Toggle Silent Aim","F3",7)
    mkKeyRow(c6a,"Toggle Ragebot","F4",8)

    -- Nav
    local function switchTab(idx)
        for i,pg in ipairs(tabPages) do pg.Visible=(i==idx) end
        for i,btn3 in ipairs(tabBtns) do
            btn3.BackgroundColor3=i==idx and PAL.bg3 or Color3.fromRGB(0,0,0)
            btn3.BackgroundTransparency=i==idx and 0 or 1
            btn3.TextColor3=i==idx and PAL.textP or PAL.textM
        end
    end
    for i,name in ipairs(tabNames) do
        local isRage=(name=="RAGEBOT")
        local btn3=inst("TextButton",{
            Size=UDim2.new(1,0,0,32),
            BackgroundColor3=i==1 and PAL.bg3 or Color3.fromRGB(0,0,0),
            BackgroundTransparency=i==1 and 0 or 1, BorderSizePixel=0,
            Text=name, Font=Enum.Font.GothamBold, TextSize=9,
            TextColor3=i==1 and PAL.textP or (isRage and Color3.fromRGB(180,60,60) or PAL.textM),
            AutoButtonColor=false, LayoutOrder=i,
        },NavBar)
        corner(btn3,6)
        btn3.MouseButton1Click:Connect(function() switchTab(i) end)
        tabBtns[i]=btn3
    end
    tabPages[1].Visible=true

    local trigCD=false local mouse3=LocalPlayer:GetMouse()

    RunService:BindToRenderStep("AuthX_v35",Enum.RenderPriority.Camera.Value+1,function()
        local center=screenCenter()
        fovCircle.Position=center fovCircle.Visible=CFG.FOVVisible and CFG.AimEnabled
        fovCircle.Radius=CFG.FOVRadius
        if CFG.AimEnabled and UserInputService:IsMouseButtonPressed(CFG.AimKey) then
            local t=getBestTarget(CFG.FOVRadius)
            if t then
                local vel=t.aimPart.AssemblyLinearVelocity or Vector3.zero
                Camera.CFrame=Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position,t.aimPart.Position+vel*CFG.Prediction),CFG.Smoothness)
            end
        end
        if CFG.SilentEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            if math.random(1,100)<=CFG.SilentChance then
                local t=getBestTarget(CFG.SilentFOV)
                if t then local s=Camera.CFrame Camera.CFrame=CFrame.new(Camera.CFrame.Position,t.aimPart.Position) task.defer(function() Camera.CFrame=s end) end
            end
        end
        if CFG.TrigEnabled and not trigCD then
            local ur=Camera:ScreenPointToRay(center.X,center.Y)
            local rp3=RaycastParams.new() rp3.FilterType=Enum.RaycastFilterType.Exclude
            local lc=LocalPlayer.Character rp3.FilterDescendantsInstances=lc and {lc} or {}
            local hit3=workspace:Raycast(ur.Origin,ur.Direction*1200,rp3)
            if hit3 and hit3.Instance then
                local hp3=Players:GetPlayerFromCharacter(hit3.Instance.Parent) or Players:GetPlayerFromCharacter(hit3.Instance.Parent and hit3.Instance.Parent.Parent)
                if hp3 and hp3~=LocalPlayer and not (CFG.TeamCheck and hp3.Team==LocalPlayer.Team) then
                    trigCD=true
                    task.delay(CFG.TrigDelay,function()
                        mouse3:Button1Down()
                        task.delay(CFG.TrigBurst>0 and CFG.TrigBurst or 0.04,function()
                            mouse3:Button1Up() task.delay(0.06,function() trigCD=false end)
                        end)
                    end)
                end
            end
        end
        if CFG.HitboxEnabled then applyHitboxes() end
        if CFG.SpeedEnabled then
            local char=LocalPlayer.Character
            if char then local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.WalkSpeed=16*CFG.SpeedMult end end
        end
        if CFG.BhopEnabled then
            local char=LocalPlayer.Character
            if char then
                local hum=char:FindFirstChildOfClass("Humanoid")
                if hum and hum:GetState()==Enum.HumanoidStateType.Landed and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end
        cleanStale()
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr==LocalPlayer then continue end
            local e=getESP(plr)
            if not CFG.ESPEnabled then hideESP(e) continue end
            local char=plr.Character if not char then hideESP(e) continue end
            local head,_,root,hum=getCharParts(char)
            if not root or not hum or hum.Health<=0 then hideESP(e) continue end
            local sp,onScr,depth=toScreen(root.Position)
            if not onScr or depth<0 or depth>CFG.ESPMaxDist then hideESP(e) continue end
            local headPos=head and head.Position or root.Position+Vector3.new(0,3,0)
            local topSP=select(1,toScreen(headPos+Vector3.new(0,0.65,0)))
            local bH=math.max(28,sp.Y-topSP.Y) local bW=bH*0.58 local bX=sp.X-bW/2 local bY=topSP.Y
            if CFG.RagebotEnabled and e.rbMarker then e.rbMarker.Position=Vector2.new(sp.X,bY-28) e.rbMarker.Visible=true
            elseif e.rbMarker then e.rbMarker.Visible=false end
            if CFG.ESPBoxes then
                drawCorners(e,bX,bY,bW,bH)
                e.box.Size=Vector2.new(bW,bH) e.box.Position=Vector2.new(bX,bY) e.box.Color=CFG.BoxColor e.box.Visible=true
            else e.box.Visible=false e.cTL.Visible=false e.cTR.Visible=false e.cBL.Visible=false e.cBR.Visible=false end
            if CFG.ESPHeadDot and head then
                local hsp=select(1,toScreen(head.Position))
                e.head.Position=hsp e.head.Color=CFG.BoxColor e.head.Radius=math.max(4,bW*0.12) e.head.Visible=true
            else e.head.Visible=false end
            if CFG.ESPNames then e.name.Text=plr.DisplayName e.name.Position=Vector2.new(sp.X,bY-15) e.name.Color=CFG.NameColor e.name.Visible=true else e.name.Visible=false end
            if CFG.ESPDist then
                local d3=math.floor((root.Position-Camera.CFrame.Position).Magnitude)
                e.dist.Text=d3.."m" e.dist.Position=Vector2.new(sp.X,bY+bH+3) e.dist.Visible=true
            else e.dist.Visible=false end
            if CFG.ESPHealth then
                local ratio=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
                e.hpBg.Size=Vector2.new(3,bH) e.hpBg.Position=Vector2.new(bX-6,bY) e.hpBg.Visible=true
                local fH=math.floor(bH*ratio)
                e.hp.Size=Vector2.new(3,fH) e.hp.Position=Vector2.new(bX-6,bY+bH-fH)
                e.hp.Color=Color3.fromRGB(math.floor(255*(1-ratio)),math.floor(220*ratio),50) e.hp.Visible=true
            else e.hpBg.Visible=false e.hp.Visible=false end
            if CFG.ESPTracers then
                e.tracer.From=Vector2.new(center.X,Camera.ViewportSize.Y) e.tracer.To=sp e.tracer.Color=CFG.TracerColor e.tracer.Visible=true
            else e.tracer.Visible=false end
        end
    end)

    UserInputService.InputBegan:Connect(function(i,gp)
        if gp then return end
        if i.KeyCode==Enum.KeyCode.Insert then Main.Visible=not Main.Visible end
        if i.KeyCode==Enum.KeyCode.RightShift then CFG.AimEnabled=not CFG.AimEnabled if quickPills["AimEnabled"] then quickPills["AimEnabled"]() end end
        if i.KeyCode==Enum.KeyCode.F1 then CFG.ESPEnabled=not CFG.ESPEnabled if quickPills["ESPEnabled"] then quickPills["ESPEnabled"]() end end
        if i.KeyCode==Enum.KeyCode.F2 then CFG.TrigEnabled=not CFG.TrigEnabled if quickPills["TrigEnabled"] then quickPills["TrigEnabled"]() end end
        if i.KeyCode==Enum.KeyCode.F3 then CFG.SilentEnabled=not CFG.SilentEnabled if quickPills["SilentEnabled"] then quickPills["SilentEnabled"]() end end
        if i.KeyCode==Enum.KeyCode.F4 then
            CFG.RagebotEnabled=not CFG.RagebotEnabled
            if quickPills["RagebotEnabled"] then quickPills["RagebotEnabled"]() end
            if CFG.RagebotEnabled then startRagebot() else stopRagebot() end
        end
        if i.KeyCode==Enum.KeyCode.Delete then
            stopRagebot() setFly(false) setNoclip(false)
            if infJumpConn then infJumpConn:Disconnect() end
            if recoilConn then recoilConn:Disconnect() end
            restoreHitboxes()
            local char=LocalPlayer.Character
            if char then local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.WalkSpeed=16 hum.PlatformStand=false end end
            for _,e in pairs(espPool) do for _,d in pairs(e) do pcall(function() d:Remove() end) end end
            fovCircle:Remove()
            pcall(function() ScreenGui:Destroy() end)
            pcall(function() RootGui:Destroy() end)
            RunService:UnbindFromRenderStep("AuthX_v35")
            print("[AuthX v3.5] Unloaded.")
        end
    end)
    print("[AuthX v3.5] Active — INSERT=Menu | RSHIFT=Aim | F1=ESP | F2=Trig | F3=Silent | F4=Rage | DEL=Panic")
end
