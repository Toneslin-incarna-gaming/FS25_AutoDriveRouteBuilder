--
-- AutoDrive Route Builder - parameter dialog
-- left: settings of the selected build type, right: help panel with what can be done and the keys
--

ADRouteBuilderGui = {}
local ADRouteBuilderGui_mt = Class(ADRouteBuilderGui, DialogElement)

function ADRouteBuilderGui.new(target)
    local self = DialogElement.new(target, ADRouteBuilderGui_mt)
    return self
end

function ADRouteBuilderGui:getInput(key)
    return self["input_" .. key]
end

-------------------------------------------------------------------------------------------------
-- selection boxes: value letter stored in ADRouteBuilder.values <-> text key
-------------------------------------------------------------------------------------------------
ADRouteBuilderGui.OPTIONS = {
    approachSide = {{"R", "adrb_optRight"}, {"L", "adrb_optLeft"}, {"-", "adrb_optNoneApproach"}},
    exitSide = {{"L", "adrb_optLeft"}, {"R", "adrb_optRight"}, {"-", "adrb_optNoneExit"}},
    curveSide = {{"R", "adrb_optRight"}, {"L", "adrb_optLeft"}},
    curveConnection = {{"V", "adrb_optForward"}, {"B", "adrb_optDual"}, {"R", "adrb_optReverse"}},
    branchMode = {{"A", "adrb_optBranchOff"}, {"E", "adrb_optMerge"}},
    branchConnection = {{"V", "adrb_optOneWay"}, {"B", "adrb_optDual"}},
    lineConnection = {{"V", "adrb_optForward"}, {"B", "adrb_optDual"}, {"R", "adrb_optReverse"}},
}

-- which parts of the dialog belong to which build type
local SECTIONS = {
    S = {"rowS0", "rowS1", "rowS2", "rowS3", "rowS4", "rowS5", "lbl_name", "input_name", "lbl_startNumber", "input_startNumber", "rowDiagram"},
    K = {"rowK0", "rowK1", "rowK2", "lbl_curveSide", "option_curveSide", "lbl_curveAngle", "input_curveAngle", "lbl_curveRadius",
        "input_curveRadius", "rowDiagram"},
    B = {"rowK0", "rowK1", "rowK2", "rowDiagram"},
    L = {"rowL0", "rowL", "rowDiagram"},
    Y = {"rowY0", "rowY1", "rowY2", "rowY3", "rowY4", "rowY5", "rowY6", "rowDiagram"},
    Z = {"rowY0", "rowY1", "rowY2", "rowY3", "rowY4", "rowY5", "rowY6", "rowDiagram"},
    G = {"rowG0", "rowG1", "rowG2", "rowDiagram"},
    M = {"rowM0", "rowM"}
}
local DIAGRAMS = {S = "gui/diagram.dds", K = "gui/curve.dds", B = "gui/arc.dds", L = "gui/guide.dds", Y = "gui/branch.dds",
    Z = "gui/merge.dds", G = "gui/line.dds"}
-- labels of the branch rows that mean something else for the merge (Z)
local BRANCH_LABELS = {
    rowY0Text = {"adrb_sectionBranch", "adrb_sectionMerge"},
    lbl_branchIn = {"adrb_branchIn", "adrb_mergeOut"},
    lbl_branchStraight = {"adrb_branchStraight", "adrb_mergeStraight"},
    lbl_branchOut = {"adrb_branchOut", "adrb_mergeIn"},
    lbl_branchAtL = {"adrb_branchAt", "adrb_mergeAt"},
    lbl_branchAtR = {"adrb_branchAt", "adrb_mergeAt"},
}
local ALL = {}
for _, list in pairs(SECTIONS) do
    for _, id in ipairs(list) do
        ALL[id] = true
    end
end
local REF_HEIGHT_PX = 1010   -- height of the dialog in the xml
local EXTRA_PX = 150         -- title area, button bar and margins
local HELP_LINES = 14

-------------------------------------------------------------------------------------------------
-- help texts (German / English)
-------------------------------------------------------------------------------------------------
local HELP = {
    de = {
        S = {
            "Baut eine oder mehrere Rückfahr-Buchten nebeneinander, z. B. für Silos oder Parkplätze.",
            "Mausposition = Ziel (Ende der Bucht), Drehrichtung = aus der Bucht heraus.",
            "Num9 mit der Maus im Fahrsilo nahe der Einfahrt = Buchten automatisch einpassen (Richtung, Mitte, Abstand). Num3 = Bezugspunkt erste Bucht / Mitte.",
            "Ablauf: vorwärts bis zum Wendestück, rückwärts ins Ziel, vorwärts zur Abfahrt.",
            "Zielname + Startnummer ergeben die AD-Ziele (z. B. P 1, P 2 ...), die Nummer zählt weiter.",
            "LStrg + Mausrad = Radius, LAlt + Mausrad = Punkte. LStrg + Seitentaste / Linksklick auf Zu- / Abfahrt, dann auf eine Hilfslinie = tangential daran. LAlt + Klick darauf = andere Seite.",
            "Weiterfahrt nie vom Punkt abzweigen lassen, an dem das Rückwärtsfahren beginnt.",
        },
        K = {
            "Baut eine freie Kurve, beginnend an der Mausposition in Drehrichtung.",
            "LStrg + Mausrad = Radius (mit LUmschalt fein), LAlt + Mausrad = Punkte.",
            "Num3 = Fahrtrichtung umdrehen, Num, = Verbindungsart wechseln.",
        },
        B = {
            "Baut einen Bogen, der die letzten zwei Hilfslinien berührt (Linie 1 orange, Linie 2 türkis).",
            "Vorher zwei Hilfslinien setzen (Bauart Hilfslinie / Kreuz).",
            "Die Maus wählt Ecke und Größe, LStrg + Mausrad = Radius, LAlt + Mausrad = Punkte.",
            "Num3 = Fahrtrichtung umdrehen, Num, = Verbindungsart wechseln.",
        },
        L = {
            "Setzt eine Hilfslinie mit Querlinie zum Ausrichten. Nur du siehst sie, AutoDrive baut nichts.",
            "LStrg + Mausrad = Länge je Seite ±5 m (mit LUmschalt ±1 m).",
            "Lineal an der Linie: Striche jeden Meter, alle 5 m länger, alle 10 m mit Meterzahl; die Enden zeigen die Länge.",
            "Zwei Hilfslinien sind die Grundlage für die Bauart Bogen. LStrg + Seitentaste / LStrg + Linksklick an einer Hilfslinie, Fahrsilo-Wand oder einem Gebäude = neue Linie parallel dazu.",
            "Einzelne Hilfslinie entfernen: Maus in die Nähe (bis 15 m), Entf. Zurückholen: LUmschalt + Entf. Alle entfernen: LStrg + LAlt + L.",
        },
        Y = {
            "Baut eine Verzweigung: Zulauf, Abzweige nach links und/oder rechts, wahlweise geradeaus.",
            "Mausposition = Verzweigungspunkt, Drehrichtung = Richtung des Zulaufs.",
            "Die Abzweige können an verschiedenen Stellen beginnen (Meter nach dem Verzweigungspunkt).",
            "LStrg + Mausrad = beide Radien, LAlt + Mausrad = Punkte, Num0 = Start auf nächsten AD-Punkt legen (wird verbunden), dann darum drehen.",
            "Zusammenführen: Bauart 7 Zuführung. Num, = Einbahn / beidseitig. Winkel 0 = kein Abzweig, LAlt + Linksklick auf eine Seite = Abzweig weg / zurück.",
            "An Hilfslinie ausrichten: LStrg + Maustaste (Nr. unten) erst auf den Abzweig, dann auf die Hilfslinie. Der 1. Abzweig verschiebt die Verzweigung, der 2. seinen Beginn.",
        },
        Z = {
            "Baut eine Zuführung: Strecken von links und/oder rechts hinten laufen auf eine Linie zusammen.",
            "Mausposition = Zusammenführungspunkt, Drehrichtung = Richtung des Ablaufs (nach dem Zusammenführen).",
            "Die Einmündungen können an verschiedenen Stellen liegen (Meter vor dem Zusammenführungspunkt).",
            "LStrg + Mausrad = beide Radien, LAlt + Mausrad = Punkte, Num0 = Ende des Ablaufs auf nächsten AD-Punkt (wird verbunden), dann darum drehen.",
            "Num, = Einbahn / beidseitig. Winkel 0 = keine Einmündung, LAlt + Linksklick auf eine Seite = Einmündung weg / zurück.",
            "An Hilfslinie ausrichten: LStrg + Maustaste (Nr. unten) erst auf die Einmündung, dann auf die Hilfslinie. Die 1. verschiebt die Zuführung, die 2. ihren Beginn.",
        },
        G = {
            "Baut eine gerade Strecke genau auf einer Hilfslinie (vorher mit Bauart Hilfslinie setzen).",
            "1. Linksklick nahe der Hilfslinie = Start, 2. Linksklick = Ende; beide werden auf die Linie gesetzt.",
            "Die Punkte werden gleichmäßig verteilt, kein Abstand größer als 'max. Punktabstand'.",
            "LAlt + Mausrad = Punktabstand, Num, = Verbindungsart, Num0 = Start verwerfen.",
            "Schnell hin und zurück: LAlt + Num1.",
        },
        M = {
            "Wählt AutoDrive-Punkte aus und bearbeitet sie - am besten in der Draufsicht (Num+). Num5 bei einem Punkt = AD-Ziel setzen / umbenennen / löschen.",
            "Linke Maustaste ziehen = Kasten aufziehen und alle Punkte darin wählen (LUmschalt = dazu, LStrg = abwählen).",
            "Klick auf einen Punkt = nur diesen wählen (LUmschalt dazu / weg), Num0 = aufheben. LAlt + Mausrad = Punktzahl einer gewählten Kurve ändern, Num/ bei 2 Punkten = Gerade dazwischen, Linksklick oder Num Enter = übernehmen.",
            "Ausgewählten Punkt ziehen = ganze Auswahl verschieben. Num3 = frei / entlang / quer zur Hilfslinie (bei der Maus, sonst die letzte).",
            "Num8/2/4/6 = um 0,1 m schieben. Num7 = Auswahl genau auf ihre Hilfslinie legen (Gerade), Num9 = dazu gleichmäßig verteilen. LStrg + LAlt + Z = zurück.",
            "Num, = Verbindungen der Auswahl: Einbahn / beidseitig / rückwärts, LStrg + Num, = Richtung umdrehen, LAlt + Num, = Haupt- / Nebenstrecke. Entf, innerhalb 3 s nochmal Entf = Auswahl samt Zielen löschen (nicht rückgängig!).",
            "LStrg + C oder Einfg = Auswahl kopieren: die Kopie hängt an der Maus, Linksklick fügt sie ein (mehrmals möglich), Num3 = frei / entlang / quer zur Hilfslinie, LUmschalt + Mausrad = drehen, Num0 = fertig. Ziele werden nicht mitkopiert.",
        },
        common = {
            "Linksklick = bauen (bleibt aktiv), kurzer Rechtsklick oder Num Enter = AutoDrive bearbeiten / zurück, Ende = beenden.",
            "Mausrad = Kamera zoomen, mittlere Maustaste halten oder Num/ = frei umsehen.",
            "LUmschalt + Mausrad oder , / . = drehen, LUmschalt + LAlt + Mausrad = fein drehen 0,1° (mit LStrg 0,01°).",
            "Num8/2/4/6 = fein verschieben, Num5 = Position festhalten, Num1 = Bauart-Menü (Zahl oder Klick).",
            "H = Hilfskreise an/aus, LStrg + LAlt + Z = rückgängig. LStrg + LAlt + B startet mit der Hilfslinie, beim Bauen öffnet es dieses Fenster.",
            "Num+ = Draufsicht (drehen: Leertaste + Maus), LStrg + Num+ = zur Person / zum Fahrzeug, Num* = AD-Netz anzeigen.",
        },
        title = "So geht's",
    },
    en = {
        S = {
            "Builds one or more reverse bays side by side, e.g. for silos or parking spots.",
            "Mouse position = target (end of the bay), rotation = out of the bay.",
            "Num9 with the mouse in a bunker silo near the entrance = fit the bays automatically (direction, centre, spacing). Num3 = reference first bay / middle.",
            "Sequence: forward to the turning piece, reverse into the target, forward to the exit.",
            "Name + start number give the AD targets (e.g. P 1, P 2 ...), the number counts on.",
            "LCtrl + wheel = radius, LAlt + wheel = points. LCtrl + side button / left click on approach / exit, then on a guide line = tangent to it. LAlt + click on it = other side.",
            "Never let a road continue from the point where reversing starts.",
        },
        K = {
            "Builds a free curve starting at the mouse position in the set direction.",
            "LCtrl + wheel = radius (LShift = fine), LAlt + wheel = points.",
            "Num3 = swap driving direction, Num, = change connection type.",
        },
        B = {
            "Builds an arc touching the last two guide lines (line 1 orange, line 2 cyan).",
            "Set two guide lines first (type guide line / cross).",
            "The mouse chooses corner and size, LCtrl + wheel = radius, LAlt + wheel = points.",
            "Num3 = swap driving direction, Num, = change connection type.",
        },
        L = {
            "Sets a guide line with a cross line for alignment. Only you see it, nothing is built.",
            "LCtrl + wheel = length per side ±5 m (LShift = ±1 m).",
            "Ruler on the line: tick every metre, longer every 5 m, distance every 10 m; the ends show the length.",
            "Two guide lines are the base for the type arc. LCtrl + side button / LCtrl + left click at a guide line, bunker silo wall or building = new line parallel to it.",
            "Remove one guide line: mouse near it (up to 15 m), Del. Bring back: LShift + Del. Remove all: LCtrl + LAlt + L.",
        },
        Y = {
            "Builds a branch: feed line, branches to the left and/or right, optionally straight on.",
            "Mouse position = branch point, rotation = direction of the feed line.",
            "The branches can start at different places (metres after the branch point).",
            "LCtrl + wheel = both radii, LAlt + wheel = points, Num0 = put the start onto the nearest AD point (gets connected), then rotate around it.",
            "Merging: build type 7 merge. Num, = one-way / both ways. Angle 0 = no branch, LAlt + left click on a side = branch off / back.",
            "Align to a guide line: LCtrl + mouse button (no. below) first on the branch, then on the guide line. The 1st branch moves the whole branch, the 2nd its start.",
        },
        Z = {
            "Builds a merge: lines from behind left and/or right join into one line.",
            "Mouse position = merge point, rotation = direction of the outgoing line (after merging).",
            "The joins can be at different places (metres before the merge point).",
            "LCtrl + wheel = both radii, LAlt + wheel = points, Num0 = end of the outgoing line onto the nearest AD point (gets connected), then rotate.",
            "Num, = one-way / both ways. Angle 0 = no join, LAlt + left click on a side = join off / back.",
            "Align to a guide line: LCtrl + mouse button (no. below) first on the join, then on the guide line. The 1st moves the merge, the 2nd its start.",
        },
        G = {
            "Builds a straight line exactly on a guide line (set it first with type guide line).",
            "1st left click near the guide line = start, 2nd left click = end; both are put onto the line.",
            "The points are spread evenly, no spacing larger than 'max. point spacing'.",
            "LAlt + wheel = point spacing, Num, = connection type, Num0 = discard start.",
            "Quick there and back: LAlt + Num1.",
        },
        M = {
            "Selects AutoDrive points and edits them - best in the top view (Num+). Num5 on one point = set / rename / remove an AD target.",
            "Drag the left mouse button = box, selects all points in it (LShift = add, LCtrl = remove).",
            "Click on a point = select only it (LShift add / remove), Num0 = clear. LAlt + wheel = change the point count of a selected curve, Num/ with 2 points = straight between them, left click or Num Enter = apply.",
            "Drag a selected point = move the whole selection. Num3 = free / along / across the guide line (near the mouse, else the last).",
            "Num8/2/4/6 = move 0.1 m. Num7 = put the selection exactly onto its guide line (straight), Num9 = and spread evenly. LCtrl + LAlt + Z = undo.",
            "Num, = connections of the selection: one-way / both ways / reverse, LCtrl + Num, = turn the direction around, LAlt + Num, = main / sub route. Del, again within 3 s = delete the selection with its targets (no undo!).",
            "LCtrl + C or Ins = copy the selection: the copy hangs on the mouse, left click pastes it (several times), Num3 = free / along / across the guide line, LShift + wheel = rotate, Num0 = done. Targets are not copied.",
        },
        common = {
            "Left click = build (stays active), short right click or Num Enter = edit AutoDrive / back, End = finish.",
            "Wheel = camera zoom, hold middle mouse button or Num/ = look around.",
            "LShift + wheel or , / . = rotate, LShift + LAlt + wheel = fine rotation 0.1° (with LCtrl 0.01°).",
            "Num8/2/4/6 = fine move, Num5 = lock position, Num1 = build type menu (number or click).",
            "H = helper circles on/off, LCtrl + LAlt + Z = undo. LCtrl + LAlt + B starts with the guide line, while building it opens this window.",
            "Num+ = top view (rotate: Space + mouse), LCtrl + Num+ = to the person / vehicle, Num* = show AD network.",
        },
        title = "How it works",
    }
}

local function getHelp()
    return (g_languageShort == "de") and HELP.de or HELP.en
end

local function loadImage(element, filename)
    if element == nil then
        return
    end
    local ok, err = pcall(function()
        element:setImageFilename(ADRouteBuilder.MOD_DIR .. filename)
        if GuiUtils ~= nil and GuiUtils.getUVs ~= nil then
            element:setImageUVs(nil, unpack(GuiUtils.getUVs("0px 0px 1024px 350px", {1024, 512})))
        end
        if element.setImageColor ~= nil then
            element:setImageColor(nil, 1, 1, 1, 1)
        end
    end)
    if not ok then
        Logging.warning("[AD Route Builder] could not load image %s: %s", filename, tostring(err))
    end
end

function ADRouteBuilderGui:onOpen()
    ADRouteBuilderGui:superClass().onOpen(self)
    local getText = ADRouteBuilder.getText
    -- selection box for the build type
    if self.option_buildType ~= nil then
        local texts = {}
        local state = 1
        for i, bt in ipairs(ADRouteBuilder.BUILD_TYPES) do
            texts[i] = getText(ADRouteBuilder.BUILD_TYPE_TEXTS[bt] .. "Long", bt)
            if bt == string.upper(tostring(ADRouteBuilder.values.buildType or "S")) then
                state = i
            end
        end
        self.option_buildType:setTexts(texts)
        self.option_buildType:setState(state)
    end
    -- other selection boxes
    for key, options in pairs(ADRouteBuilderGui.OPTIONS) do
        local element = self["option_" .. key]
        if element ~= nil then
            local texts, state = {}, 1
            local current = string.upper(tostring(ADRouteBuilder.values[key] or ""))
            if current == "" or current == "0" then
                current = "-"
            end
            for i, o in ipairs(options) do
                texts[i] = getText(o[2], o[1])
                if o[1] == current then
                    state = i
                end
            end
            element:setTexts(texts)
            element:setState(state)
        end
    end
    for _, key in ipairs(ADRouteBuilder.FIELDS) do
        local element = self:getInput(key)
        if element ~= nil then
            element:setText(tostring(ADRouteBuilder.values[key] or ""))
        end
    end
    self.lastDiagram = nil
    self:updateVisibility()
end

function ADRouteBuilderGui:getSelectedBuildType()
    if self.option_buildType ~= nil then
        return ADRouteBuilder.BUILD_TYPES[self.option_buildType:getState()] or "S"
    end
    return string.upper(tostring(ADRouteBuilder.values.buildType or "S"))
end

local function visibleHeight(box, spacingPx, px)
    local height, count = 0, 0
    for _, element in ipairs(box.elements or {}) do
        if element.visible ~= false and element.size ~= nil then
            height = height + element.size[2]
            count = count + 1
        end
    end
    return height + math.max(0, count - 1) * spacingPx * px
end

--- shows only the settings of the selected build type, fills the help panel and fits the dialog height
function ADRouteBuilderGui:updateVisibility()
    local bt = self:getSelectedBuildType()
    local getText = ADRouteBuilder.getText
    local show = {}
    for _, id in ipairs(SECTIONS[bt] or SECTIONS.S) do
        show[id] = true
    end
    for id, _ in pairs(ALL) do
        local element = self[id]
        if element ~= nil and element.setVisible ~= nil then
            element:setVisible(show[id] == true)
        end
    end
    if self.rowK0Text ~= nil and self.rowK0Text.setText ~= nil then
        self.rowK0Text:setText(getText(bt == "B" and "adrb_sectionArc" or "adrb_sectionCurve", ""))
    end
    for id, keys in pairs(BRANCH_LABELS) do
        local element = self[id]
        if element ~= nil and element.setText ~= nil then
            element:setText(getText(bt == "Z" and keys[2] or keys[1], ""))
        end
    end
    -- diagram of the build type
    if self.lastDiagram ~= bt and DIAGRAMS[bt] ~= nil then
        self.lastDiagram = bt
        -- the diagrams have German and English text
        local file = DIAGRAMS[bt]
        if g_languageShort ~= "de" then
            file = string.gsub(file, "%.dds$", "_en.dds")
        end
        loadImage(self.diagramElement, file)
    end
    -- help panel
    local help = getHelp()
    local lines = {}
    for _, l in ipairs(help[bt] or {}) do
        table.insert(lines, "- " .. l)
    end
    table.insert(lines, "")
    for _, l in ipairs(help.common) do
        table.insert(lines, "- " .. l)
    end
    if self.helpTitle ~= nil and self.helpTitle.setText ~= nil then
        self.helpTitle:setText(help.title)
    end
    for i = 1, HELP_LINES do
        local element = self["help" .. i]
        if element ~= nil then
            local text = lines[i]
            element:setVisible(text ~= nil)
            if text ~= nil and element.setText ~= nil then
                element:setText(text)
            end
        end
    end
    for _, id in ipairs({"rowTop", "rowK1", "rowK2", "rowY5", "rowG1", "rowDiagram", "colLeft", "colHelp"}) do
        local element = self[id]
        if element ~= nil and element.invalidateLayout ~= nil then
            element:invalidateLayout()
        end
    end
    -- heights: columns -> main row -> dialog
    local ok, err = pcall(function()
        local bg, box = self.dialogBg, self.contentBox
        if bg == nil or box == nil or bg.size == nil then
            return
        end
        if self.fullHeight == nil then
            self.fullHeight = bg.size[2]
        end
        local px = self.fullHeight / REF_HEIGHT_PX
        if self.colLeft ~= nil and self.colHelp ~= nil and self.rowMain ~= nil then
            local hLeft = visibleHeight(self.colLeft, 10, px)
            local hHelp = visibleHeight(self.colHelp, 2, px) + 16 * px
            local h = math.max(hLeft, hHelp)
            self.colLeft:setSize(nil, h)
            self.colHelp:setSize(nil, h)
            self.rowMain:setSize(nil, h)
            self.colLeft:invalidateLayout()
            self.colHelp:invalidateLayout()
            self.rowMain:invalidateLayout()
        end
        box:invalidateLayout()
        local newHeight = math.min(self.fullHeight, visibleHeight(box, 10, px) + EXTRA_PX * px)
        bg:setSize(nil, newHeight)
        box:invalidateLayout()
    end)
    if not ok then
        Logging.warning("[AD Route Builder] could not resize the dialog: %s", tostring(err))
    end
end

function ADRouteBuilderGui:onBuildTypeChanged(state)
    self:updateVisibility()
end

function ADRouteBuilderGui:readValues()
    local values = {}
    for _, key in ipairs(ADRouteBuilder.FIELDS) do
        local element = self:getInput(key)
        if element ~= nil then
            values[key] = element.text or ""
        else
            values[key] = ADRouteBuilder.values[key]
        end
    end
    for key, options in pairs(ADRouteBuilderGui.OPTIONS) do
        local element = self["option_" .. key]
        if element ~= nil then
            local o = options[element:getState()]
            if o ~= nil then
                values[key] = o[1]
            end
        end
    end
    if self.option_buildType ~= nil then
        values.buildType = ADRouteBuilder.BUILD_TYPES[self.option_buildType:getState()] or "S"
    end
    return values
end

function ADRouteBuilderGui:onClickOk()
    local values = self:readValues()
    local params, err = ADRouteBuilder.getParams(values)
    if params == nil then
        g_currentMission:showBlinkingWarning(string.format(ADRouteBuilder.getText("adrb_invalid", "invalid: %s"), err), 4000)
        return
    end
    ADRouteBuilder.values = values
    ADRouteBuilder.saveSettings()
    self.okPressed = true
    self:onClickBack()
    ADRouteBuilder.startPlacing(params)
    ADRouteBuilder.afterDialogStart()
end

--- "back" / Esc: close and continue placing where it was (if the dialog was opened while placing)
function ADRouteBuilderGui:onClickBack(...)
    local result = ADRouteBuilderGui:superClass().onClickBack(self, ...)
    if not self.okPressed then
        ADRouteBuilder.resumePlacing()
    end
    self.okPressed = false
    return result
end

function ADRouteBuilderGui:onEscPressed()
    self:onClickBack()
end
