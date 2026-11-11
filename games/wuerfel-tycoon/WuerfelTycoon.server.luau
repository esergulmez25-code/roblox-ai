--!strict
--[[
	Würfel-Tycoon
	=============
	Ein komplettes kleines Tycoon-Spiel in EINEM Server-Script.

	So funktioniert es:
	  * Die Maschine (Dropper) spuckt ständig kleine Würfel aus.
	  * Die Würfel fallen auf ein Förderband und werden zum Ende transportiert.
	  * Am Ende fallen sie in einen Kasten und werden dort zu Geld.
	  * Mit dem Geld kaufst du Upgrades: mehr Dropper, schnelleres Droppen,
	    wertvollere Würfel und ein schnelleres Förderband.

	Einbau in Roblox Studio:
	  1. Neues Projekt mit der Vorlage "Baseplate" öffnen.
	  2. In ServerScriptService ein neues "Script" einfügen.
	  3. Den kompletten Inhalt dieser Datei hineinkopieren.
	  4. Auf "Play" drücken, zu einem freien Tycoon laufen und auf das
	     grüne Feld "Tycoon beanspruchen" treten.

	Es werden 4 Tycoons gebaut, damit mehrere Spieler gleichzeitig spielen können.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

---------------------------------------------------------------------------
-- Einstellungen
---------------------------------------------------------------------------

local CONFIG = {
	StartGeld = 10,
	WuerfelGroesse = 1, -- Kantenlänge der Würfel in Studs
	WuerfelLebensdauer = 30, -- Sekunden, bevor festhängende Würfel verschwinden
	MaxWuerfelProTycoon = 120, -- Schutz gegen Lag
	BasisIntervall = 2, -- Sekunden zwischen zwei Würfeln pro Dropper
	BasisBandTempo = 8, -- Studs pro Sekunde
	BandTempoProStufe = 4,
}

-- Positionen der Tycoons (die Mitte bleibt frei für den Spawn)
local PLOT_POSITIONEN = {
	Vector3.new(-70, 0, -30),
	Vector3.new(-70, 0, 30),
	Vector3.new(70, 0, -30),
	Vector3.new(70, 0, 30),
}

type Upgrade = {
	id: string,
	name: string,
	preis: number,
	faktor: number,
	maxStufe: number,
	x: number,
	benoetigt: string?,
}

-- Kauf-Buttons. Preis steigt pro Stufe: preis * faktor ^ stufe
local UPGRADES: { Upgrade } = {
	{ id = "Dropper2", name = "Dropper 2", preis = 25, faktor = 1, maxStufe = 1, x = -20 },
	{ id = "Dropper3", name = "Dropper 3", preis = 150, faktor = 1, maxStufe = 1, x = -10, benoetigt = "Dropper2" },
	{ id = "Tempo", name = "Schneller droppen", preis = 40, faktor = 1.8, maxStufe = 5, x = 0 },
	{ id = "Wert", name = "Wertvollere Würfel", preis = 75, faktor = 2, maxStufe = 5, x = 10 },
	{ id = "Band", name = "Förderband schneller", preis = 60, faktor = 1.7, maxStufe = 3, x = 20 },
}

-- Farbe der Würfel je nach "Wert"-Stufe
local WUERFEL_FARBEN = {
	Color3.fromRGB(200, 60, 60), -- Stufe 0: rot      ($1)
	Color3.fromRGB(235, 140, 40), -- Stufe 1: orange   ($2)
	Color3.fromRGB(245, 215, 50), -- Stufe 2: gelb     ($4)
	Color3.fromRGB(80, 210, 90), -- Stufe 3: grün     ($8)
	Color3.fromRGB(60, 200, 235), -- Stufe 4: türkis   ($16)
	Color3.fromRGB(200, 90, 240), -- Stufe 5: lila     ($32)
}

local FARBE_GRUEN = Color3.fromRGB(70, 200, 90)
local FARBE_ROT = Color3.fromRGB(210, 60, 60)
local FARBE_GRAU = Color3.fromRGB(120, 120, 130)

---------------------------------------------------------------------------
-- Kollisionsgruppen: Würfel kollidieren nicht mit Spielern
---------------------------------------------------------------------------

pcall(function()
	PhysicsService:RegisterCollisionGroup("Wuerfel")
end)
pcall(function()
	PhysicsService:RegisterCollisionGroup("Spieler")
end)
PhysicsService:CollisionGroupSetCollidable("Wuerfel", "Spieler", false)

---------------------------------------------------------------------------
-- Hilfsfunktionen zum Bauen
---------------------------------------------------------------------------

local function teil(eltern: Instance, name: string, groesse: Vector3, position: Vector3, farbe: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = groesse
	p.Position = position
	p.Color = farbe
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = eltern
	return p
end

local function schild(adornee: BasePart, text: string, hoehe: number, breite: number, groesseY: number): TextLabel
	local bb = Instance.new("BillboardGui")
	bb.Name = "Schild"
	bb.Size = UDim2.new(breite, 0, groesseY, 0) -- in Studs, skaliert mit der Entfernung
	bb.StudsOffset = Vector3.new(0, hoehe, 0)
	bb.MaxDistance = 120
	bb.Adornee = adornee
	bb.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = bb
	return label
end

-- Merkt sich das Original-Aussehen, damit Teile versteckt und wieder gezeigt werden können
local function merkeAussehen(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetAttribute("OrigTransparenz", d.Transparency)
			d:SetAttribute("OrigKollision", d.CanCollide)
		end
	end
end

local function setzeSichtbar(model: Instance, sichtbar: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = if sichtbar then (d:GetAttribute("OrigTransparenz") :: number? or 0) else 1
			d.CanCollide = sichtbar and (d:GetAttribute("OrigKollision") :: boolean? or false)
			d.CanTouch = sichtbar
		elseif d:IsA("BillboardGui") then
			d.Enabled = sichtbar
		end
	end
end

local function spielerVonTreffer(treffer: BasePart): Player?
	local charakter = treffer:FindFirstAncestorOfClass("Model")
	if not charakter then
		return nil
	end
	local humanoid = charakter:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return Players:GetPlayerFromCharacter(charakter)
end

local function geldWert(spieler: Player): IntValue?
	local stats = spieler:FindFirstChild("leaderstats")
	return if stats then stats:FindFirstChild("Geld") :: IntValue? else nil
end

local function preisVon(up: Upgrade, stufe: number): number
	return math.floor(up.preis * up.faktor ^ stufe)
end

---------------------------------------------------------------------------
-- Tycoon
---------------------------------------------------------------------------

type Button = { model: Model, pad: Part, label: TextLabel, cooldown: boolean, meldung: boolean }
type Dropper = { model: Model, spawnPunkt: Vector3, duese: Part }

type Tycoon = {
	model: Model,
	besitzer: Player?,
	stufen: { [string]: number },
	wuerfelOrdner: Folder,
	wuerfelAnzahl: number,
	droppers: { Dropper },
	buttons: { [string]: Button },
	band: Part,
	kasten: Part,
	claimPad: Part,
	claimLabel: TextLabel,
	geldVerbindung: RBXScriptConnection?,
}

local spielerTycoon: { [Player]: Tycoon } = {}

local function baueDropper(t: Tycoon, o: Vector3, x: number, nummer: number): Dropper
	local m = Instance.new("Model")
	m.Name = "Dropper" .. nummer
	m.Parent = t.model

	local metall = Color3.fromRGB(90, 95, 110)
	-- Säule hinter dem Band
	teil(m, "Saeule", Vector3.new(1.2, 10, 1.2), o + Vector3.new(x, 6, -11), metall, Enum.Material.Metal)
	-- Arm zur Maschine
	teil(m, "Arm", Vector3.new(1, 1, 4), o + Vector3.new(x, 10.5, -9), metall, Enum.Material.Metal)
	-- Gehäuse der Maschine
	local gehaeuse = teil(m, "Gehaeuse", Vector3.new(4, 4, 4), o + Vector3.new(x, 10, -6), Color3.fromRGB(60, 70, 90), Enum.Material.DiamondPlate)
	-- Leuchtstreifen
	teil(m, "Streifen", Vector3.new(4.1, 0.4, 4.1), o + Vector3.new(x, 11, -6), Color3.fromRGB(0, 200, 255), Enum.Material.Neon)
	-- Trichter / Düse unten
	local duese = teil(m, "Duese", Vector3.new(1.8, 1, 1.8), o + Vector3.new(x, 7.5, -6), Color3.fromRGB(35, 35, 40), Enum.Material.Metal)

	schild(gehaeuse, "Dropper " .. nummer, 3.5, 6, 1.5)
	merkeAussehen(m)

	return {
		model = m,
		spawnPunkt = o + Vector3.new(x, 6.3, -6),
		duese = duese,
	}
end

local function baueButton(t: Tycoon, o: Vector3, up: Upgrade): Button
	local m = Instance.new("Model")
	m.Name = "Button_" .. up.id
	m.Parent = t.model

	teil(m, "Sockel", Vector3.new(5, 0.6, 5), o + Vector3.new(up.x, 1.3, 9), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
	local pad = teil(m, "Pad", Vector3.new(4, 0.4, 4), o + Vector3.new(up.x, 1.7, 9), FARBE_ROT, Enum.Material.Neon)
	local label = schild(pad, up.name, 3, 8, 2.5)
	merkeAussehen(m)

	return { model = m, pad = pad, label = label, cooldown = false, meldung = false }
end

local function updateButtons(t: Tycoon)
	local geld = 0
	if t.besitzer then
		local g = geldWert(t.besitzer)
		geld = if g then g.Value else 0
	end

	for _, up in UPGRADES do
		local b = t.buttons[up.id]
		local stufe = t.stufen[up.id]
		local sichtbar = t.besitzer ~= nil
			and stufe < up.maxStufe
			and (up.benoetigt == nil or t.stufen[up.benoetigt :: string] >= 1)

		setzeSichtbar(b.model, sichtbar)
		if sichtbar and not b.meldung then
			local preis = preisVon(up, stufe)
			b.pad.Color = if geld >= preis then FARBE_GRUEN else FARBE_ROT
			local stufenText = if up.maxStufe > 1 then string.format(" (%d/%d)", stufe + 1, up.maxStufe) else ""
			b.label.Text = string.format("%s%s\n$%d", up.name, stufenText, preis)
		end
	end
end

-- Wendet die gekauften Stufen auf die Welt an
local function wendeUpgradesAn(t: Tycoon)
	for i, d in t.droppers do
		local aktiv = i == 1 or t.stufen["Dropper" .. i] >= 1
		setzeSichtbar(d.model, aktiv)
	end
	local tempo = CONFIG.BasisBandTempo + t.stufen.Band * CONFIG.BandTempoProStufe
	t.band.AssemblyLinearVelocity = Vector3.new(tempo, 0, 0)
end

local function geldPopup(t: Tycoon, betrag: number)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(4, 0, 1.5, 0)
	bb.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 80
	bb.Adornee = t.kasten
	bb.Parent = t.kasten

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(120, 255, 120)
	label.TextStrokeTransparency = 0.3
	label.Text = "+$" .. betrag
	label.Parent = bb

	local info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bb, info, { StudsOffset = bb.StudsOffset + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(bb, 1.1)
end

local function spawneWuerfel(t: Tycoon, d: Dropper)
	if t.wuerfelAnzahl >= CONFIG.MaxWuerfelProTycoon then
		return
	end

	local stufe = t.stufen.Wert
	local wert = 2 ^ stufe -- 1, 2, 4, 8, 16, 32

	local w = Instance.new("Part")
	w.Name = "Wuerfel"
	w.Size = Vector3.one * CONFIG.WuerfelGroesse
	w.Color = WUERFEL_FARBEN[stufe + 1]
	w.Material = if stufe >= 3 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.CollisionGroup = "Wuerfel"
	w.CustomPhysicalProperties = PhysicalProperties.new(1, 0.8, 0.05, 1, 1)
	w.Position = d.spawnPunkt + Vector3.new(math.random(-2, 2) / 10, 0, math.random(-2, 2) / 10)
	w:SetAttribute("Wert", wert)
	w.Parent = t.wuerfelOrdner
	w:SetNetworkOwner(nil) -- Server berechnet die Physik, damit alles flüssig und fair bleibt

	t.wuerfelAnzahl += 1
	w.Destroying:Connect(function()
		t.wuerfelAnzahl -= 1
	end)
	Debris:AddItem(w, CONFIG.WuerfelLebensdauer)

	-- kleiner "Puff"-Effekt an der Düse
	d.duese.Color = Color3.fromRGB(255, 220, 80)
	task.delay(0.15, function()
		d.duese.Color = Color3.fromRGB(35, 35, 40)
	end)
end

local function setzeZurueck(t: Tycoon)
	if t.geldVerbindung then
		t.geldVerbindung:Disconnect()
		t.geldVerbindung = nil
	end
	if t.besitzer then
		spielerTycoon[t.besitzer] = nil
	end
	t.besitzer = nil
	for _, up in UPGRADES do
		t.stufen[up.id] = 0
	end
	t.wuerfelOrdner:ClearAllChildren()

	t.claimPad.Color = FARBE_GRUEN
	t.claimLabel.Text = "Tycoon frei!\nDrauftreten zum Beanspruchen"

	wendeUpgradesAn(t)
	updateButtons(t)
end

local function beanspruche(t: Tycoon, spieler: Player)
	if t.besitzer or spielerTycoon[spieler] then
		return
	end
	local geld = geldWert(spieler)
	if not geld then
		return
	end

	t.besitzer = spieler
	spielerTycoon[spieler] = t
	t.claimPad.Color = FARBE_GRAU
	t.claimLabel.Text = spieler.DisplayName .. "s Tycoon"
	t.geldVerbindung = geld.Changed:Connect(function()
		updateButtons(t)
	end)
	updateButtons(t)
end

local function kaufe(t: Tycoon, up: Upgrade, spieler: Player)
	if spieler ~= t.besitzer then
		return
	end
	local stufe = t.stufen[up.id]
	if stufe >= up.maxStufe then
		return
	end
	if up.benoetigt and t.stufen[up.benoetigt] < 1 then
		return
	end

	local geld = geldWert(spieler)
	if not geld then
		return
	end

	local b = t.buttons[up.id]
	local preis = preisVon(up, stufe)
	if geld.Value < preis then
		if not b.meldung then
			b.meldung = true
			b.label.Text = "Zu wenig Geld!\n$" .. preis
			task.delay(1, function()
				b.meldung = false
				updateButtons(t)
			end)
		end
		return
	end

	geld.Value -= preis
	t.stufen[up.id] = stufe + 1
	wendeUpgradesAn(t)
	updateButtons(t)
end

local function baueTycoon(nummer: number, o: Vector3): Tycoon
	local model = Instance.new("Model")
	model.Name = "Tycoon" .. nummer
	model.Parent = workspace

	local wuerfelOrdner = Instance.new("Folder")
	wuerfelOrdner.Name = "Wuerfel"
	wuerfelOrdner.Parent = model

	-- Boden (Oberkante auf Höhe 1)
	teil(model, "Boden", Vector3.new(60, 1, 40), o + Vector3.new(0, 0.5, 0), Color3.fromRGB(75, 150, 75), Enum.Material.Grass)

	-- Förderband (Oberkante auf Höhe 4), von x = -22 bis x = 12
	local band = teil(model, "Foerderband", Vector3.new(34, 1, 6), o + Vector3.new(-5, 3.5, -6), Color3.fromRGB(45, 45, 50), Enum.Material.DiamondPlate)
	-- Seitengeländer, damit keine Würfel herunterfallen
	local gelb = Color3.fromRGB(240, 190, 40)
	teil(model, "GelaenderLinks", Vector3.new(34, 1, 0.5), o + Vector3.new(-5, 4.5, -9.25), gelb, Enum.Material.Metal)
	teil(model, "GelaenderRechts", Vector3.new(34, 1, 0.5), o + Vector3.new(-5, 4.5, -2.75), gelb, Enum.Material.Metal)
	teil(model, "Endstueck", Vector3.new(0.5, 1, 6), o + Vector3.new(-21.75, 4.5, -6), gelb, Enum.Material.Metal)
	-- Beine
	for _, x in { -20, -10, 0, 10 } do
		for _, z in { -8.5, -3.5 } do
			teil(model, "Bein", Vector3.new(1, 2, 1), o + Vector3.new(x, 2, z), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
		end
	end
	-- Geld-Kasten am Ende des Bandes (x = 12 bis 19.5)
	local kastenModel = Instance.new("Model")
	kastenModel.Name = "GeldKasten"
	kastenModel.Parent = model
	local holz = Color3.fromRGB(150, 105, 60)
	local kasten = teil(kastenModel, "Boden", Vector3.new(7.5, 0.5, 8), o + Vector3.new(15.75, 1.25, -6), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
	-- vordere Wand ist niedriger als das Band, damit die Würfel hineinfallen
	teil(kastenModel, "WandVorne", Vector3.new(0.5, 2.5, 8), o + Vector3.new(12.25, 2.25, -6), holz, Enum.Material.WoodPlanks)
	teil(kastenModel, "WandHinten", Vector3.new(0.5, 7, 8), o + Vector3.new(19.75, 4.5, -6), holz, Enum.Material.WoodPlanks)
	teil(kastenModel, "WandLinks", Vector3.new(8, 4, 0.5), o + Vector3.new(16, 3, -10.25), holz, Enum.Material.WoodPlanks)
	teil(kastenModel, "WandRechts", Vector3.new(8, 4, 0.5), o + Vector3.new(16, 3, -1.75), holz, Enum.Material.WoodPlanks)
	schild(kasten, "💰 Geld-Kasten 💰", 8, 10, 2)

	-- Feld zum Beanspruchen
	local claimPad = teil(model, "TycoonBeanspruchen", Vector3.new(6, 0.4, 6), o + Vector3.new(0, 1.2, 16), FARBE_GRUEN, Enum.Material.Neon)
	local claimLabel = schild(claimPad, "", 4, 12, 3)

	local t: Tycoon = {
		model = model,
		besitzer = nil,
		stufen = {},
		wuerfelOrdner = wuerfelOrdner,
		wuerfelAnzahl = 0,
		droppers = {},
		buttons = {},
		band = band,
		kasten = kasten,
		claimPad = claimPad,
		claimLabel = claimLabel,
		geldVerbindung = nil,
	}

	-- Dropper (Nummer 2 und 3 werden erst nach dem Kauf sichtbar)
	for i, x in { -18, -11, -4 } do
		t.droppers[i] = baueDropper(t, o, x, i)
	end

	-- Kauf-Buttons
	for _, up in UPGRADES do
		local b = baueButton(t, o, up)
		t.buttons[up.id] = b
		b.pad.Touched:Connect(function(treffer)
			if b.cooldown then
				return
			end
			local spieler = spielerVonTreffer(treffer)
			if not spieler then
				return
			end
			b.cooldown = true
			kaufe(t, up, spieler)
			task.delay(0.5, function()
				b.cooldown = false
			end)
		end)
	end

	-- Beanspruchen
	claimPad.Touched:Connect(function(treffer)
		local spieler = spielerVonTreffer(treffer)
		if spieler then
			beanspruche(t, spieler)
		end
	end)

	-- Würfel landen im Kasten -> Geld
	kasten.Touched:Connect(function(treffer)
		if treffer.Parent ~= wuerfelOrdner or treffer:GetAttribute("Bezahlt") then
			return
		end
		treffer:SetAttribute("Bezahlt", true)
		local wert = treffer:GetAttribute("Wert") :: number? or 0
		treffer:Destroy()

		local besitzer = t.besitzer
		if besitzer then
			local geld = geldWert(besitzer)
			if geld then
				geld.Value += wert
				geldPopup(t, wert)
			end
		end
	end)

	setzeZurueck(t)

	-- Die Maschinen laufen, solange jemand den Tycoon besitzt
	task.spawn(function()
		while model.Parent do
			if t.besitzer then
				for i, d in t.droppers do
					if i == 1 or t.stufen["Dropper" .. i] >= 1 then
						spawneWuerfel(t, d)
					end
				end
			end
			task.wait(CONFIG.BasisIntervall * 0.75 ^ t.stufen.Tempo)
		end
	end)

	return t
end

---------------------------------------------------------------------------
-- Spieler
---------------------------------------------------------------------------

local function charakterHinzugefuegt(charakter: Model)
	local function setzeGruppe(d: Instance)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Spieler"
		end
	end
	for _, d in charakter:GetDescendants() do
		setzeGruppe(d)
	end
	charakter.DescendantAdded:Connect(setzeGruppe)
end

local function spielerBeigetreten(spieler: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local geld = Instance.new("IntValue")
	geld.Name = "Geld"
	geld.Value = CONFIG.StartGeld
	geld.Parent = stats
	stats.Parent = spieler

	if spieler.Character then
		charakterHinzugefuegt(spieler.Character)
	end
	spieler.CharacterAdded:Connect(charakterHinzugefuegt)
end

Players.PlayerAdded:Connect(spielerBeigetreten)
for _, spieler in Players:GetPlayers() do
	spielerBeigetreten(spieler)
end

Players.PlayerRemoving:Connect(function(spieler)
	local t = spielerTycoon[spieler]
	if t then
		setzeZurueck(t)
	end
end)

for i, position in PLOT_POSITIONEN do
	baueTycoon(i, position)
end
