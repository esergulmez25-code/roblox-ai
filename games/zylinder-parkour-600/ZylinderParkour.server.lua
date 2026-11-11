--[[
	ZYLINDER-PARKOUR · 600 LEVEL
	============================

	Ein schweres Obby mit 600 Leveln in 12 Welten. Jede Welt ist ein eigener
	Zylinder mit eigenen Wänden (Hecke, Sandstein, Lava-Gestein, Eis, Holz,
	Zuckerstange, Neon ...). Die Strecke windet sich als Spirale an der
	Innenseite nach oben. Oben in jeder Welt wartet ein PORTAL, das dich in
	die nächste Welt bringt. Schon Level 1 ist kein Spaziergang.

	Einbau: Diesen Script in ServerScriptService legen (als normales "Script")
	und auf Spielen drücken. Alles andere (Welten, Level, Checkpoints, Portale,
	GUI, Speichern) baut der Script beim Start selbst.

	Chat-Befehle:
	  /neustart       – zurück zu Level 0 (Lobby)
	  /level 250      – direkt zu Level 250 springen (nur in Studio oder für
	                    den Besitzer des Spiels, zum Testen)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")

-------------------------------------------------------------------------------
-- EINSTELLUNGEN
-------------------------------------------------------------------------------
local CONFIG = {
	LEVELS = 600, -- Anzahl Level
	LEVELS_PER_WORLD = 50, -- alle 50 Level eine neue Welt (neuer Zylinder)
	SEED = 600, -- gleicher Seed = gleiche Strecke bei jedem Start

	PATH_RADIUS = 40, -- Radius, auf dem die Strecke läuft
	PILLAR_RADIUS = 14, -- Mittelsäule
	WALL_RADIUS = 62, -- Wand des Zylinders
	WALL_SEGMENTS = 48, -- Anzahl Wandplatten im Kreis
	WORLD_SPACING = 400, -- Abstand zwischen den Welt-Zylindern

	SLOPE = 0.1, -- Höhe pro Stud Strecke -> ca. 25 Studs Abstand pro Runde
	FALL_LIMIT = 12, -- so tief gefallen (seit höchstem Punkt) -> zurück zum Checkpoint
	ACTIVE_RANGE = 2, -- Hindernisse werden nur um Spieler herum animiert

	-- Schwierigkeit (0 = leicht, 1 = maximal). Startet schon bei START_DIFF.
	START_DIFF = 0.35,
	MAX_GAP = 6.2, -- größte Lücke (mehr schafft man mit normalem Sprung kaum)
	MIN_SIZE = 3, -- kleinste Plattform

	RESPAWN_TIME = 1,
	DATASTORE_NAME = "ZylinderParkour600_v1",
}

-- 12 Welten à 50 Level. wall = Material der Zylinderwand, wall2 = zweite
-- Farbe für Streifen (jede zweite Platte).
local M = Enum.Material
local WORLDS = {
	{ name = "Grasland", main = Color3.fromRGB(106, 190, 48), accent = Color3.fromRGB(255, 255, 255),
		wallMat = M.LeafyGrass, wall = Color3.fromRGB(60, 130, 40), wall2 = Color3.fromRGB(50, 115, 35), pillarMat = M.Brick },
	{ name = "Wüste", main = Color3.fromRGB(226, 190, 112), accent = Color3.fromRGB(196, 120, 52),
		wallMat = M.Sandstone, wall = Color3.fromRGB(215, 175, 110), wall2 = Color3.fromRGB(195, 150, 90), pillarMat = M.Sandstone },
	{ name = "Ozean", main = Color3.fromRGB(40, 140, 220), accent = Color3.fromRGB(150, 230, 255),
		wallMat = M.Pebble, wall = Color3.fromRGB(30, 110, 140), wall2 = Color3.fromRGB(240, 220, 170), pillarMat = M.Pebble },
	{ name = "Vulkan", main = Color3.fromRGB(90, 60, 55), accent = Color3.fromRGB(255, 120, 30),
		wallMat = M.Basalt, wall = Color3.fromRGB(45, 35, 35), wall2 = Color3.fromRGB(60, 40, 35), pillarMat = M.CrackedLava },
	{ name = "Eiswelt", main = Color3.fromRGB(190, 230, 255), accent = Color3.fromRGB(90, 160, 230),
		wallMat = M.Ice, wall = Color3.fromRGB(170, 215, 245), wall2 = Color3.fromRGB(200, 235, 255), pillarMat = M.Glacier },
	{ name = "Dschungel", main = Color3.fromRGB(40, 110, 60), accent = Color3.fromRGB(240, 210, 60),
		wallMat = M.Wood, wall = Color3.fromRGB(105, 70, 40), wall2 = Color3.fromRGB(85, 55, 30), pillarMat = M.Wood },
	{ name = "Süßigkeiten", main = Color3.fromRGB(255, 150, 200), accent = Color3.fromRGB(130, 220, 255),
		wallMat = M.SmoothPlastic, wall = Color3.fromRGB(255, 80, 110), wall2 = Color3.fromRGB(255, 255, 255), pillarMat = M.SmoothPlastic },
	{ name = "Neon-Stadt", main = Color3.fromRGB(40, 30, 70), accent = Color3.fromRGB(0, 255, 220),
		wallMat = M.Metal, wall = Color3.fromRGB(25, 25, 35), wall2 = Color3.fromRGB(0, 200, 255), wall2Mat = M.Neon, pillarMat = M.DiamondPlate },
	{ name = "Weltall", main = Color3.fromRGB(30, 30, 50), accent = Color3.fromRGB(180, 120, 255),
		wallMat = M.Slate, wall = Color3.fromRGB(15, 12, 30), wall2 = Color3.fromRGB(35, 20, 60), pillarMat = M.Foil },
	{ name = "Giftsumpf", main = Color3.fromRGB(70, 90, 40), accent = Color3.fromRGB(170, 255, 0),
		wallMat = M.Mud, wall = Color3.fromRGB(60, 70, 35), wall2 = Color3.fromRGB(45, 55, 25), pillarMat = M.Mud },
	{ name = "Goldtempel", main = Color3.fromRGB(240, 190, 50), accent = Color3.fromRGB(255, 250, 200),
		wallMat = M.Marble, wall = Color3.fromRGB(240, 235, 220), wall2 = Color3.fromRGB(230, 180, 40), wall2Mat = M.Foil, pillarMat = M.Marble },
	{ name = "Regenbogen", main = Color3.fromRGB(255, 255, 255), accent = Color3.fromRGB(255, 80, 80),
		wallMat = M.SmoothPlastic, rainbowWall = true, pillarMat = M.Neon },
}

-- Hindernis-Arten und ab welchem Level sie vorkommen.
-- "Mix" mischt in einem Level alle schon freigeschalteten Arten.
local OBSTACLES = {
	{ id = "Sprung", from = 1 },
	{ id = "Lava", from = 3 },
	{ id = "Verschwinden", from = 8 },
	{ id = "Mini", from = 14 },
	{ id = "Bewegt", from = 20 },
	{ id = "Förderband", from = 30 },
	{ id = "Spinner", from = 40 },
	{ id = "Mix", from = 100 },
}

local LAVA_COLOR = Color3.fromRGB(255, 60, 30)

-------------------------------------------------------------------------------
-- HILFSFUNKTIONEN
-------------------------------------------------------------------------------
local rng = Random.new(CONFIG.SEED)
local TAU = math.pi * 2

local root = Instance.new("Folder")
root.Name = "ZylinderParkour"
root.Parent = workspace

local function newPart(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function worldIndex(level)
	return math.clamp(math.ceil(level / CONFIG.LEVELS_PER_WORLD), 1, #WORLDS)
end

local function worldCenter(w)
	return Vector3.new((w - 1) * CONFIG.WORLD_SPACING, 0, 0)
end

local currentCenter = worldCenter(1)

-- CFrame auf der Spirale der aktuellen Welt: -Z zeigt in Laufrichtung,
-- X zeigt nach außen.
local function pathCFrame(angle, y, radialOffset)
	local r = CONFIG.PATH_RADIUS + (radialOffset or 0)
	local pos = currentCenter + Vector3.new(math.cos(angle) * r, y, math.sin(angle) * r)
	local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
	return CFrame.lookAt(pos, pos + tangent)
end

local function rainbow(n)
	return Color3.fromHSV((n * 0.07) % 1, 0.75, 1)
end

local function getHumanoid(hit)
	local model = hit and hit:FindFirstAncestorOfClass("Model")
	return model and model:FindFirstChildOfClass("Humanoid")
end

local function makeKill(part)
	part.Touched:Connect(function(hit)
		local hum = getHumanoid(hit)
		if hum and hum.Health > 0 then
			hum.Health = 0
		end
	end)
end

local function addLabel(part, text, face, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = part
	return gui
end

-------------------------------------------------------------------------------
-- ANIMATIONEN (nur Level in der Nähe von Spielern laufen)
-------------------------------------------------------------------------------
local animsByLevel = {} -- [level] = { {step = fn(t), stop = fn()} , ... }

local function addAnim(level, anim)
	animsByLevel[level] = animsByLevel[level] or {}
	table.insert(animsByLevel[level], anim)
end

-------------------------------------------------------------------------------
-- HINDERNIS-BAUSTEINE
-- Jeder Baustein bekommt: cf (Mitte, Laufrichtung -Z), ctx (Level-Infos),
-- len (Länge in Laufrichtung, vorher über ELEMENT_LENGTH bestimmt).
-------------------------------------------------------------------------------
local function platformColor(ctx)
	if ctx.world == #WORLDS then
		return rainbow(ctx.level + ctx.index)
	end
	return ctx.index % 2 == 0 and ctx.colors.main or ctx.colors.main:Lerp(ctx.colors.accent, 0.35)
end

local ELEMENT_LENGTH = {
	Sprung = function(ctx) return ctx.size end,
	Mini = function(ctx) return math.max(2, ctx.size * 0.6) end,
	Verschwinden = function(ctx) return ctx.size end,
	Bewegt = function(ctx) return ctx.size end,
	Lava = function(ctx) return ctx.size * 2 + 3 end,
	["Förderband"] = function(ctx) return ctx.size * 2 + 3 end,
	Spinner = function(ctx) return ctx.size + 3 end,
}

-- Abzug von der Lücke, damit die fiesen Arten noch schaffbar bleiben
local GAP_BONUS = {
	Sprung = 0, Mini = -0.5, Verschwinden = 0, Bewegt = -1.2,
	Lava = -0.5, ["Förderband"] = -1, Spinner = -1,
}

local BUILD = {}

function BUILD.Sprung(cf, ctx, len)
	newPart({
		Name = "Sprung",
		Size = Vector3.new(ctx.size, 1, len),
		CFrame = cf,
		Color = platformColor(ctx),
	}, ctx.folder)
end

function BUILD.Mini(cf, ctx, len)
	newPart({
		Name = "Mini",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, len, len),
		CFrame = cf * CFrame.Angles(0, 0, math.pi / 2),
		Color = platformColor(ctx),
	}, ctx.folder)
end

function BUILD.Verschwinden(cf, ctx, len)
	local p = newPart({
		Name = "Verschwinden",
		Size = Vector3.new(ctx.size, 1, len),
		CFrame = cf,
		Color = ctx.colors.accent,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	}, ctx.folder)
	local delayTime = math.max(0.3, 0.6 - 0.3 * ctx.diff)
	local busy = false
	p.Touched:Connect(function(hit)
		if busy or not getHumanoid(hit) then
			return
		end
		busy = true
		TweenService:Create(p, TweenInfo.new(delayTime), { Transparency = 0.85 }):Play()
		task.wait(delayTime)
		p.CanCollide = false
		task.wait(2)
		p.CanCollide = true
		p.Transparency = 0.15
		busy = false
	end)
end

function BUILD.Bewegt(cf, ctx, len)
	local p = newPart({
		Name = "Bewegt",
		Size = Vector3.new(ctx.size, 1, len),
		CFrame = cf,
		Color = ctx.colors.accent,
		Material = Enum.Material.Metal,
	}, ctx.folder)
	-- Bewegt sich nach innen/außen (lokale X-Achse), damit der Abstand fair bleibt
	local axis = cf.RightVector
	local amp = 2.5 + 3 * ctx.diff
	local speed = 1.5 + 1.5 * ctx.diff
	local phase = rng:NextNumber(0, TAU)
	addAnim(ctx.level, {
		step = function(t)
			local s = math.sin(t * speed + phase)
			local c = math.cos(t * speed + phase)
			p.CFrame = cf + axis * (amp * s)
			-- Geschwindigkeit setzen, damit Spieler mitgenommen werden
			p.AssemblyLinearVelocity = axis * (amp * speed * c)
		end,
		stop = function()
			p.AssemblyLinearVelocity = Vector3.zero
		end,
	})
end

function BUILD.Lava(cf, ctx, len)
	newPart({
		Name = "LavaWeg",
		Size = Vector3.new(ctx.size, 1, len),
		CFrame = cf,
		Color = platformColor(ctx),
	}, ctx.folder)
	local width = 2 + 2.5 * ctx.diff
	local lava = newPart({
		Name = "Lava",
		Size = Vector3.new(ctx.size + 0.2, 0.3, width),
		CFrame = cf * CFrame.new(0, 0.6, 0),
		Color = LAVA_COLOR,
		Material = Enum.Material.Neon,
	}, ctx.folder)
	makeKill(lava)
end

BUILD["Förderband"] = function(cf, ctx, len)
	local p = newPart({
		Name = "Förderband",
		Size = Vector3.new(ctx.size, 1, len),
		CFrame = cf,
		Color = Color3.fromRGB(60, 60, 60),
		Material = Enum.Material.DiamondPlate,
	}, ctx.folder)
	-- Schiebt rückwärts (gegen die Laufrichtung). Läuft immer, kostet nichts.
	local speed = 7 + 5 * ctx.diff
	p.AssemblyLinearVelocity = -cf.LookVector * speed
	addLabel(p, "<<<", Enum.NormalId.Top, Color3.fromRGB(255, 220, 0))
end

function BUILD.Spinner(cf, ctx, len)
	newPart({
		Name = "SpinnerBasis",
		Size = Vector3.new(ctx.size + 3, 1, len),
		CFrame = cf,
		Color = platformColor(ctx),
	}, ctx.folder)
	local barLen = math.max(ctx.size + 3, len) + 1
	local center = cf * CFrame.new(0, 1.6, 0)
	local bars = {}
	-- Ab mittlerer Schwierigkeit: Kreuz aus zwei Balken
	for i = 1, (ctx.diff > 0.7 and 2 or 1) do
		local bar = newPart({
			Name = "Spinner",
			Size = Vector3.new(barLen, 0.8, 0.8),
			CFrame = center,
			Color = LAVA_COLOR,
			Material = Enum.Material.Neon,
			CanQuery = false,
		}, ctx.folder)
		makeKill(bar)
		bars[i] = bar
	end
	local speed = 2 + 2.5 * ctx.diff
	local phase = rng:NextNumber(0, TAU)
	addAnim(ctx.level, {
		step = function(t)
			for i, bar in ipairs(bars) do
				bar.CFrame = center * CFrame.Angles(0, t * speed + phase + (i - 1) * math.pi / 2, 0)
			end
		end,
		stop = function() end,
	})
end

-------------------------------------------------------------------------------
-- STRECKE GENERIEREN
-------------------------------------------------------------------------------
local checkpoints = {} -- [level] = Part (601 = Ziel)
local checkpointsFolder = Instance.new("Folder")
checkpointsFolder.Name = "Checkpoints"
checkpointsFolder.Parent = root

local levelsFolder = Instance.new("Folder")
levelsFolder.Name = "Level"
levelsFolder.Parent = root

local CHECKPOINT_SIZE = 8
local START_ANGLE = 0
local FLOOR_Y = 0

local angle = START_ANGLE
local pathY = FLOOR_Y + 0.5
local prevHalf = 0

-- Bewegt den "Stift" entlang der Spirale weiter
local function advance(dist)
	angle += dist / CONFIG.PATH_RADIUS
	pathY += dist * CONFIG.SLOPE
end

local onCheckpointTouched -- wird weiter unten gesetzt
local buildCylinder -- wird weiter unten gesetzt

local function buildCheckpoint(level, kind)
	-- kind: nil = normaler Checkpoint, "portal" = Portal in die nächste Welt,
	-- "finish" = Ziel ganz oben in der letzten Welt
	local w = worldIndex(math.min(level, CONFIG.LEVELS))
	local colors = WORLDS[w]
	local size = kind and 14 or CHECKPOINT_SIZE
	local cf = pathCFrame(angle, pathY)
	local pad = newPart({
		Name = kind == "finish" and "Ziel" or kind == "portal" and ("Portal_Welt" .. w) or ("Checkpoint" .. level),
		Size = Vector3.new(size, 1, size),
		CFrame = cf,
		Color = kind == "finish" and Color3.fromRGB(255, 215, 0) or colors.accent,
		Material = Enum.Material.Neon,
	}, checkpointsFolder)
	pad:SetAttribute("Level", level)

	local touchParts = { pad }
	if kind == "finish" then
		addLabel(pad, "🏆 ZIEL 🏆", Enum.NormalId.Top, Color3.fromRGB(80, 50, 0))
	elseif kind == "portal" then
		local nextWorld = WORLDS[w + 1]
		local portal = newPart({
			Name = "Portal",
			Size = Vector3.new(10, 12, 1),
			CFrame = cf * CFrame.new(0, 6.5, -3), -- steht quer zur Laufrichtung
			Color = nextWorld.accent,
			Material = Enum.Material.ForceField,
			CanCollide = false,
		}, checkpointsFolder)
		addLabel(portal, "Welt " .. (w + 1) .. "\n" .. nextWorld.name, Enum.NormalId.Front, Color3.new(1, 1, 1))
		addLabel(portal, "Welt " .. (w + 1) .. "\n" .. nextWorld.name, Enum.NormalId.Back, Color3.new(1, 1, 1))
		addLabel(pad, "PORTAL ➜", Enum.NormalId.Top, Color3.new(0, 0, 0))
		table.insert(touchParts, portal)
	elseif level % CONFIG.LEVELS_PER_WORLD == 1 then
		addLabel(pad, "Welt " .. w .. "\n" .. colors.name, Enum.NormalId.Top, Color3.new(0, 0, 0))
	else
		addLabel(pad, tostring(level), Enum.NormalId.Top, Color3.new(0, 0, 0))
	end

	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 1.2
	light.Color = pad.Color
	light.Parent = pad

	for _, part in ipairs(touchParts) do
		part.Touched:Connect(function(hit)
			onCheckpointTouched(pad, level, kind, hit)
		end)
	end
	if kind ~= "portal" then
		checkpoints[level] = pad
	end
	return pad
end

local function unlocked(level)
	local pool = {}
	for _, o in ipairs(OBSTACLES) do
		if level >= o.from and o.id ~= "Mix" then
			table.insert(pool, o.id)
		end
	end
	return pool
end

local function pickObstacle(level, last)
	if level % CONFIG.LEVELS_PER_WORLD == 0 and level >= 50 then
		return "Mix" -- letztes Level jeder Welt: Endgegner-Level mit allem
	end
	local pool = unlocked(level)
	if level >= 100 then
		table.insert(pool, "Mix")
		table.insert(pool, "Mix")
	end
	local choice = pool[rng:NextInteger(1, #pool)]
	if choice == last and #pool > 1 then
		choice = pool[rng:NextInteger(1, #pool)]
	end
	return choice
end

local function difficulty(level)
	local global = (level - 1) / math.max(CONFIG.LEVELS - 1, 1)
	local inWorld = ((level - 1) % CONFIG.LEVELS_PER_WORLD) / (CONFIG.LEVELS_PER_WORLD - 1)
	local d = CONFIG.START_DIFF + (1 - CONFIG.START_DIFF) * (0.75 * global + 0.25 * inWorld)
	return math.clamp(d, 0, 1)
end

local function generate()
	local lastType = nil
	for level = 1, CONFIG.LEVELS do
		local w = worldIndex(level)
		local worldStart = (level - 1) % CONFIG.LEVELS_PER_WORLD == 0

		if worldStart then
			-- Neue Welt = neuer Zylinder, Strecke beginnt wieder unten
			currentCenter = worldCenter(w)
			angle = START_ANGLE
			pathY = FLOOR_Y + 0.5
		else
			advance(prevHalf + 3 + CHECKPOINT_SIZE / 2)
		end
		buildCheckpoint(level, nil)
		prevHalf = CHECKPOINT_SIZE / 2

		local diff = difficulty(level)
		local kind = pickObstacle(level, lastType)
		lastType = kind

		local folder = Instance.new("Folder")
		folder.Name = string.format("Level%03d_%s", level, kind)
		folder.Parent = levelsFolder

		local ctx = {
			level = level,
			world = w,
			colors = WORLDS[w],
			diff = diff,
			size = math.max(CONFIG.MIN_SIZE, 5.5 - 3 * diff), -- Plattformen werden kleiner
			folder = folder,
			index = 0,
		}
		local count = 4 + math.floor(diff * 4) -- 5 bis 8 Sprünge pro Level
		local pool = unlocked(level)

		for i = 1, count do
			ctx.index = i
			local k = kind == "Mix" and pool[rng:NextInteger(1, #pool)] or kind
			local gap = math.clamp(2.5 + 4.5 * diff + GAP_BONUS[k], 2, CONFIG.MAX_GAP)
			local len = ELEMENT_LENGTH[k](ctx)
			advance(prevHalf + gap + len / 2)
			local jitter = rng:NextNumber(-1, 1) * diff
			BUILD[k](pathCFrame(angle, pathY, jitter), ctx, len)
			prevHalf = len / 2
		end

		-- Ende der Welt: Portal (oder Ziel in der letzten Welt) + Zylinder drumherum
		if level % CONFIG.LEVELS_PER_WORLD == 0 or level == CONFIG.LEVELS then
			advance(prevHalf + 3 + 7)
			local last = level == CONFIG.LEVELS
			buildCheckpoint(last and CONFIG.LEVELS + 1 or level, last and "finish" or "portal")
			buildCylinder(w, currentCenter, pathY + 30)
		end

		if level % 10 == 0 then
			task.wait() -- Server nicht einfrieren lassen
		end
	end
end

-------------------------------------------------------------------------------
-- ZYLINDER BAUEN (Boden, Säule, Wand, Deckel) – jede Welt anders
-------------------------------------------------------------------------------
local function verticalCylinder(name, center, radius, bottomY, topY, props, parent)
	local height = topY - bottomY
	props.Name = name
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, radius * 2, radius * 2)
	props.CFrame = CFrame.new(center + Vector3.new(0, bottomY + height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	return newPart(props, parent)
end

buildCylinder = function(w, center, topY)
	local theme = WORLDS[w]
	local folder = Instance.new("Folder")
	folder.Name = "Welt" .. w .. "_" .. theme.name
	folder.Parent = root

	verticalCylinder("Boden", center, CONFIG.WALL_RADIUS + 2, FLOOR_Y - 2, FLOOR_Y, {
		Color = theme.wall2 or theme.main, Material = theme.wallMat,
	}, folder)

	-- Mittelsäule (Parts dürfen max. 2048 lang sein)
	local y = FLOOR_Y
	while y < topY do
		local seg = math.min(topY - y, 2000)
		verticalCylinder("Säule", center, CONFIG.PILLAR_RADIUS, y, y + seg, {
			Color = theme.main:Lerp(Color3.new(0, 0, 0), 0.25), Material = theme.pillarMat, CastShadow = false,
		}, folder)
		y += seg
	end

	-- Wand aus Platten, abwechselnd in zwei Farben (Streifen)
	local panelWidth = TAU * CONFIG.WALL_RADIUS / CONFIG.WALL_SEGMENTS + 0.6
	y = FLOOR_Y
	while y < topY do
		local seg = math.min(topY - y, 2000)
		for i = 0, CONFIG.WALL_SEGMENTS - 1 do
			local a = i / CONFIG.WALL_SEGMENTS * TAU
			local pos = center + Vector3.new(math.cos(a) * CONFIG.WALL_RADIUS, y + seg / 2, math.sin(a) * CONFIG.WALL_RADIUS)
			local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
			local even = i % 2 == 0
			local color, mat
			if theme.rainbowWall then
				color, mat = Color3.fromHSV(i / CONFIG.WALL_SEGMENTS, 0.7, 1), theme.wallMat
			else
				color = even and theme.wall or theme.wall2
				mat = (not even and theme.wall2Mat) or theme.wallMat
			end
			newPart({
				Name = "Wand",
				Size = Vector3.new(2, seg, panelWidth),
				CFrame = CFrame.lookAt(pos, pos + tangent),
				Color = color,
				Material = mat,
				CastShadow = false, -- damit es innen nicht stockdunkel ist
			}, folder)
		end
		y += seg
	end

	-- Deckel (wirft keinen Schatten, Licht kommt trotzdem rein)
	verticalCylinder("Deckel", center, CONFIG.WALL_RADIUS + 2, topY, topY + 2, {
		Color = theme.accent, Material = Enum.Material.Neon, Transparency = 0.4, CastShadow = false,
	}, folder)

	if w == 1 then
		-- Lobby-Spawn auf dem Boden, kurz vor Checkpoint 1
		local saved = currentCenter
		currentCenter = center
		local spawnCf = pathCFrame(START_ANGLE - 18 / CONFIG.PATH_RADIUS, FLOOR_Y + 0.5)
		currentCenter = saved
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "LobbySpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(12, 1, 12)
		spawn.CFrame = spawnCf
		spawn.Color = Color3.fromRGB(255, 255, 255)
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Duration = 0
		spawn.Parent = folder

		local sign = newPart({
			Name = "Schild",
			Size = Vector3.new(14, 6, 0.5),
			CFrame = spawnCf * CFrame.new(0, 6, 8),
			Color = Color3.fromRGB(30, 30, 40),
		}, folder)
		addLabel(sign, "ZYLINDER-PARKOUR\n600 LEVEL · 12 WELTEN", Enum.NormalId.Front, Color3.fromRGB(255, 220, 0))
	end
end

-------------------------------------------------------------------------------
-- SPIELER: Level, Speichern, Respawn, GUI
-------------------------------------------------------------------------------
local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(CONFIG.DATASTORE_NAME)
end)

local stageOf = {} -- [player] = höchster erreichter Checkpoint (0 = Lobby)
local maxYOf = {} -- [player] = höchster Punkt seit dem letzten Checkpoint

local function checkpointCFrame(level)
	local pad = checkpoints[level]
	if not pad then
		return nil
	end
	return pad.CFrame * CFrame.new(0, 3.5, 0)
end

local function makeGui(player)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ParkourGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local frame = Instance.new("Frame")
	frame.Name = "Box"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 8)
	frame.Size = UDim2.fromOffset(320, 58)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.25
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(10, 4)
	label.Size = UDim2.new(1, -20, 0, 30)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = frame

	local barBack = Instance.new("Frame")
	barBack.Name = "BarBack"
	barBack.Position = UDim2.fromOffset(10, 38)
	barBack.Size = UDim2.new(1, -20, 0, 12)
	barBack.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	barBack.Parent = frame
	Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = Color3.fromRGB(255, 210, 0)
	bar.Parent = barBack
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)
	banner.Size = UDim2.fromOffset(600, 80)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.FredokaOne
	banner.TextScaled = true
	banner.TextColor3 = Color3.fromRGB(255, 220, 0)
	banner.TextStrokeTransparency = 0
	banner.Text = ""
	banner.Visible = false
	banner.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

local function showBanner(player, text, seconds)
	local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("ParkourGui")
	if not gui then
		return
	end
	local banner = gui.Banner
	banner.Text = text
	banner.Visible = true
	local token = os.clock()
	banner:SetAttribute("Token", token)
	task.delay(seconds or 2.5, function()
		if banner:GetAttribute("Token") == token then
			banner.Visible = false
		end
	end)
end

local function refresh(player)
	local stage = stageOf[player] or 0
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Level.Value = stage
	end
	local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("ParkourGui")
	if gui then
		local worldName = stage == 0 and "Lobby" or WORLDS[worldIndex(stage)].name
		gui.Box.Text.Text = string.format("Level %d / %d  •  %s", stage, CONFIG.LEVELS, worldName)
		gui.Box.BarBack.Bar.Size = UDim2.fromScale(stage / CONFIG.LEVELS, 1)
	end
end

local function teleportToStage(player)
	local char = player.Character
	local stage = stageOf[player] or 0
	local cf = stage > 0 and checkpointCFrame(stage)
	if char and cf then
		char:PivotTo(cf)
		maxYOf[player] = cf.Position.Y
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function setStage(player, stage)
	stageOf[player] = math.clamp(stage, 0, CONFIG.LEVELS)
	player:SetAttribute("Finished", false)
	refresh(player)
end

onCheckpointTouched = function(pad, level, kind, hit)
	local hum = getHumanoid(hit)
	if not hum or hum.Health <= 0 then
		return
	end
	local player = Players:GetPlayerFromCharacter(hum.Parent)
	if not player or not stageOf[player] then
		return
	end
	local stage = stageOf[player]

	if kind == "portal" then
		-- Welt geschafft -> ab in die nächste Welt
		if stage == level then
			stageOf[player] = level + 1
			refresh(player)
			teleportToStage(player)
			local w = worldIndex(level + 1)
			showBanner(player, "🌀 Welt " .. w .. ": " .. WORLDS[w].name .. " 🌀", 3)
		end
		return
	end

	if kind == "finish" then
		if stage == CONFIG.LEVELS and not player:GetAttribute("Finished") then
			player:SetAttribute("Finished", true)
			player.leaderstats.Siege.Value += 1
			showBanner(player, "🏆 GESCHAFFT! Alle 600 Level! 🏆", 6)
		end
		return
	end

	-- Nur der nächste Checkpoint zählt (kein Überspringen)
	if level == stage + 1 then
		stageOf[player] = level
		maxYOf[player] = nil
		refresh(player)
		if level % 100 == 0 then
			showBanner(player, "Level " .. level .. "!", 2)
		end
		-- kleiner Effekt am Checkpoint
		local old = pad.Color
		pad.Color = Color3.new(1, 1, 1)
		task.delay(0.25, function()
			pad.Color = old
		end)
	end
end

local function loadData(player)
	if not store then
		return 0, 0
	end
	local ok, data = pcall(function()
		return store:GetAsync("u_" .. player.UserId)
	end)
	if ok and type(data) == "table" then
		return tonumber(data.stage) or 0, tonumber(data.wins) or 0
	end
	return 0, 0
end

local function saveData(player)
	if not store or stageOf[player] == nil then
		return
	end
	local ls = player:FindFirstChild("leaderstats")
	local data = { stage = stageOf[player], wins = ls and ls.Siege.Value or 0 }
	pcall(function()
		store:SetAsync("u_" .. player.UserId, data)
	end)
end

local function handleCommand(player, msg)
	local lower = string.lower(msg)
	if lower == "/neustart" then
		setStage(player, 0)
		if player.Character then
			player:LoadCharacter()
		end
		return
	end
	local n = string.match(lower, "^/level%s+(%d+)$")
	if n and (RunService:IsStudio() or player.UserId == game.CreatorId) then
		setStage(player, tonumber(n))
		teleportToStage(player)
	end
end

local function onPlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local lvl = Instance.new("IntValue")
	lvl.Name = "Level"
	lvl.Parent = ls
	local wins = Instance.new("IntValue")
	wins.Name = "Siege"
	wins.Parent = ls
	ls.Parent = player

	local stage, savedWins = loadData(player)
	wins.Value = savedWins
	stageOf[player] = math.clamp(stage, 0, CONFIG.LEVELS)

	makeGui(player)
	refresh(player)

	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart")
		task.wait() -- Roblox setzt den Charakter zuerst an den SpawnLocation
		teleportToStage(player)
	end)
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		player.Chatted:Connect(function(msg)
			handleCommand(player, msg)
		end)
	end

	if player.Character then
		teleportToStage(player)
	end
end

-------------------------------------------------------------------------------
-- HAUPTSCHLEIFEN
-------------------------------------------------------------------------------
local function activeLevels()
	local set = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local s = stageOf[player]
		if s then
			for l = s - CONFIG.ACTIVE_RANGE + 1, s + CONFIG.ACTIVE_RANGE do
				if animsByLevel[l] then
					set[l] = true
				end
			end
		end
	end
	return set
end

local function startLoops()
	local active = {}
	local nextScan = 0

	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		if t >= nextScan then
			nextScan = t + 0.5
			local newSet = activeLevels()
			for l in pairs(active) do
				if not newSet[l] then
					for _, a in ipairs(animsByLevel[l]) do
						a.stop()
					end
				end
			end
			active = newSet
		end
		for l in pairs(active) do
			for _, a in ipairs(animsByLevel[l]) do
				a.step(t)
			end
		end
	end)

	-- Wer runterfällt, wird zum letzten Checkpoint zurückgesetzt
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in ipairs(Players:GetPlayers()) do
				local stage = stageOf[player]
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp and stage and stage > 0 then
					-- Die Spirale liegt ca. 25 Studs über sich selbst: wer 12 Studs
					-- unter seinen höchsten Punkt fällt, ist von der Strecke gefallen.
					local y = hrp.Position.Y
					local maxY = math.max(maxYOf[player] or y, y)
					maxYOf[player] = maxY
					if y < maxY - CONFIG.FALL_LIMIT then
						teleportToStage(player)
					end
				end
			end
		end
	end)
end

-------------------------------------------------------------------------------
-- START
-------------------------------------------------------------------------------
Players.RespawnTime = CONFIG.RESPAWN_TIME

local t0 = os.clock()
-- Etwas helleres Umgebungslicht, damit es in den Zylindern nicht zu dunkel ist
Lighting.Ambient = Color3.fromRGB(120, 120, 130)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)

generate()
print(string.format("[ZylinderParkour] %d Level in %d Welten gebaut (%.1fs)",
	CONFIG.LEVELS, #WORLDS, os.clock() - t0))

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	stageOf[player] = nil
	maxYOf[player] = nil
end)

-- Chat-Befehle für das neue Chat-System (TextChatService)
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	local cmdFolder = Instance.new("Folder")
	cmdFolder.Name = "ParkourBefehle"
	cmdFolder.Parent = TextChatService
	for _, alias in ipairs({ "/neustart", "/level" }) do
		local cmd = Instance.new("TextChatCommand")
		cmd.Name = alias
		cmd.PrimaryAlias = alias
		cmd.Parent = cmdFolder
		cmd.Triggered:Connect(function(source, text)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				handleCommand(player, text)
			end
		end)
	end
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)

startLoops()
