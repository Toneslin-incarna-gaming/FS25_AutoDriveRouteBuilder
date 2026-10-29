--
-- AutoDrive Route Builder
-- Builds "reverse bays" for AutoDrive from parameters and places them freely with the mouse.
--
-- Layout of one bay: dual lane from the target outwards, approach and exit curves on the lane,
-- turning piece at the outer end (forward line beside a reverse line), see buildBayLocal.
--

ADRouteBuilder = {}
ADRouteBuilder.MOD_NAME = g_currentModName
ADRouteBuilder.MOD_DIR = g_currentModDirectory

-- connection types used in the route description
ADRouteBuilder.CON_FORWARD = 1
ADRouteBuilder.CON_DUAL = 3
ADRouteBuilder.CON_REVERSE = 4
ADRouteBuilder.CON_FORWARD_AND_REVERSE_BACK = 5
ADRouteBuilder.TURN_OFFSET = 0.5 -- side offset of the middle point of the turning piece
ADRouteBuilder.TURN_BACK = 1.5   -- distance of that point before the end

ADRouteBuilder.DEFAULTS = {
    name = "Silo 1 -",
    startNumber = "1",
    count = "1",
    spacing = "5",
    lengthTarget = "30",
    totalLength = "50",
    endLength = "6",
    turnOffset = "0.5",
    buildType = "S",
    curveSide = "R",
    curveAngle = "90",
    curveRadius = "10",
    curveCount = "8",
    curveConnection = "V",
    exitAt = "35",
    pointSpacing = "3",
    approachSide = "R",
    approachAngle = "90",
    approachRadius = "10",
    exitSide = "L",
    exitAngle = "90",
    exitRadius = "10",
    curvePoints = "8",
    exitPoints = "8",
    branchIn = "10",
    branchStraight = "10",
    branchOut = "10",
    branchPoints = "8",
    branchLeftAngle = "45",
    branchLeftRadius = "15",
    branchRightAngle = "45",
    branchRightRadius = "15",
    branchLeftAt = "0",
    branchRightAt = "0",
    branchMode = "A",
    branchConnection = "V",
    lineSpacing = "5",
    lineConnection = "V",
    subRoute = "0",
    bayAnchor = "E",
    alignButton = "6"
}

-- build types in the order of the selection box and of Num1
ADRouteBuilder.BUILD_TYPES = {"S", "K", "L", "G", "B", "Y", "Z", "M"}
ADRouteBuilder.BUILD_TYPE_TEXTS = {S = "adrb_typeS", K = "adrb_typeK", L = "adrb_typeL", G = "adrb_typeG", B = "adrb_typeB",
    Y = "adrb_typeY", Z = "adrb_typeZ", M = "adrb_typeM"}

ADRouteBuilder.FIELDS = {"name", "startNumber", "count", "spacing", "lengthTarget", "totalLength", "exitAt",
    "pointSpacing", "approachSide", "approachAngle", "approachRadius", "exitSide", "exitAngle", "exitRadius", "curvePoints", "endLength",
    "buildType", "curveSide", "curveAngle", "curveRadius", "curveCount", "curveConnection", "exitPoints", "turnOffset",
    "branchIn", "branchStraight", "branchOut", "branchPoints", "branchLeftAngle", "branchLeftRadius", "branchRightAngle",
    "branchRightRadius", "branchMode", "branchConnection", "branchLeftAt", "branchRightAt", "lineSpacing", "lineConnection", "alignButton", "bayAnchor", "subRoute"}

ADRouteBuilder.values = {}
ADRouteBuilder.isPlacing = false
ADRouteBuilder.showHelpers = true
ADRouteBuilder.guides = {}
ADRouteBuilder.guideLength = 50
ADRouteBuilder.rotation = 0
ADRouteBuilder.buildStack = {}

local function getText(key, fallback)
    if g_i18n ~= nil and g_i18n:hasText(key) then
        return g_i18n:getText(key)
    end
    return fallback or key
end
ADRouteBuilder.getText = getText

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-------------------------------------------------------------------------------------------------
-- access to AutoDrive: every mod runs in its own script environment, so the AutoDrive classes are
-- not visible directly. They are taken from AutoDrive's environment (global table named like the mod).
-------------------------------------------------------------------------------------------------

function ADRouteBuilder.resolveAutoDrive()
    if ADGraphManager ~= nil and AutoDrive ~= nil then
        return true
    end
    local globalEnv = getfenv(0)
    local candidates = {"FS25_AutoDrive"}
    if g_modManager ~= nil and g_modManager.getActiveMods ~= nil then
        for _, mod in ipairs(g_modManager:getActiveMods()) do
            table.insert(candidates, mod.modName)
        end
    end
    for _, modName in ipairs(candidates) do
        local env = globalEnv[modName]
        if type(env) == "table" and env.ADGraphManager ~= nil and env.AutoDrive ~= nil then
            ADGraphManager = env.ADGraphManager
            AutoDrive = env.AutoDrive
            AutoDriveDeleteWayPointsEvent = env.AutoDriveDeleteWayPointsEvent
            Logging.info("[AD Route Builder] AutoDrive found in '%s'", modName)
            return true
        end
    end
    Logging.warning("[AD Route Builder] AutoDrive not found")
    return false
end

-------------------------------------------------------------------------------------------------
-- settings persistence (local per player)
-------------------------------------------------------------------------------------------------

function ADRouteBuilder.getSettingsPath()
    return getUserProfileAppPath() .. "modSettings/FS25_AutoDriveRouteBuilder.xml"
end

--- guide lines are kept per map and savegame
function ADRouteBuilder.getGuideKey()
    local mi = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    if mi == nil then
        return ""
    end
    return tostring(mi.mapId or "") .. "#" .. tostring(mi.savegameIndex or "")
end

function ADRouteBuilder.loadSettings()
    for k, v in pairs(ADRouteBuilder.DEFAULTS) do
        ADRouteBuilder.values[k] = v
    end
    local path = ADRouteBuilder.getSettingsPath()
    if fileExists(path) then
        local xml = loadXMLFile("adrbSettings", path)
        if xml ~= nil and xml ~= 0 then
            for _, key in ipairs(ADRouteBuilder.FIELDS) do
                local v = getXMLString(xml, "routeBuilder.values#" .. key)
                if v ~= nil then
                    ADRouteBuilder.values[key] = v
                end
            end
            local rot = getXMLFloat(xml, "routeBuilder.values#rotation")
            if rot ~= nil then
                ADRouteBuilder.savedRotation = math.rad(rot)
            end
            local len = getXMLFloat(xml, "routeBuilder.values#guideLength")
            if len ~= nil then
                ADRouteBuilder.guideLength = math.max(5, math.min(500, len))
            end
            -- guide lines of this map / savegame
            if getXMLString(xml, "routeBuilder.guides#key") == ADRouteBuilder.getGuideKey() then
                ADRouteBuilder.guides = {}
                local i = 0
                while true do
                    local base = string.format("routeBuilder.guides.guide(%d)", i)
                    local gx = getXMLFloat(xml, base .. "#x")
                    if gx == nil then
                        break
                    end
                    table.insert(ADRouteBuilder.guides, {x = gx, z = getXMLFloat(xml, base .. "#z") or 0,
                        rot = math.rad(getXMLFloat(xml, base .. "#rot") or 0), length = getXMLFloat(xml, base .. "#length") or 50})
                    i = i + 1
                end
            end
            delete(xml)
        end
    end
end

function ADRouteBuilder.saveSettings()
    createFolder(getUserProfileAppPath() .. "modSettings/")
    local xml = createXMLFile("adrbSettings", ADRouteBuilder.getSettingsPath(), "routeBuilder")
    if xml ~= nil and xml ~= 0 then
        for _, key in ipairs(ADRouteBuilder.FIELDS) do
            setXMLString(xml, "routeBuilder.values#" .. key, tostring(ADRouteBuilder.values[key] or ""))
        end
        if ADRouteBuilder.savedRotation ~= nil then
            setXMLFloat(xml, "routeBuilder.values#rotation", math.deg(ADRouteBuilder.savedRotation))
        end
        setXMLFloat(xml, "routeBuilder.values#guideLength", ADRouteBuilder.guideLength)
        -- guide lines (only for this map / savegame)
        setXMLString(xml, "routeBuilder.guides#key", ADRouteBuilder.getGuideKey())
        for i, g in ipairs(ADRouteBuilder.guides) do
            local base = string.format("routeBuilder.guides.guide(%d)", i - 1)
            setXMLFloat(xml, base .. "#x", g.x)
            setXMLFloat(xml, base .. "#z", g.z)
            setXMLFloat(xml, base .. "#rot", math.deg(g.rot))
            setXMLFloat(xml, base .. "#length", g.length)
        end
        saveXMLFile(xml)
        delete(xml)
    end
end

-------------------------------------------------------------------------------------------------
-- parameter parsing
-------------------------------------------------------------------------------------------------

local function parseNumber(values, key, minValue, maxValue, errors)
    local s = trim(values[key]):gsub(",", ".")
    local n = tonumber(s)
    if n == nil or n < minValue or n > maxValue then
        table.insert(errors, getText("adrb_" .. key, key))
        return nil
    end
    return n
end

local function parseSide(values, key, errors)
    local s = string.upper(trim(values[key]))
    if s == "" or s == "-" or s == "0" then
        return 0
    elseif s == "L" or s == "LINKS" or s == "LEFT" then
        return -1
    elseif s == "R" or s == "RECHTS" or s == "RIGHT" then
        return 1
    end
    table.insert(errors, getText("adrb_" .. key, key))
    return nil
end

--- Converts the text values of the dialog into numbers. Returns params or nil and an error text.
function ADRouteBuilder.getParams(values)
    local errors = {}
    local p = {}
    p.name = trim(values.name)
    if p.name == "" then
        table.insert(errors, getText("adrb_name", "name"))
    end
    local sn = trim(values.startNumber)
    if sn == "" then
        p.startNumber = nil
    else
        p.startNumber = tonumber(sn)
        if p.startNumber == nil then
            table.insert(errors, getText("adrb_startNumber", "startNumber"))
        end
    end
    p.count = parseNumber(values, "count", 1, 50, errors)
    p.spacing = parseNumber(values, "spacing", -200, 200, errors)
    p.lengthTarget = parseNumber(values, "lengthTarget", 1, 500, errors)
    p.totalLength = parseNumber(values, "totalLength", 3, 700, errors)
    p.endLength = parseNumber(values, "endLength", 1, 50, errors)
    p.turnOffset = parseNumber(values, "turnOffset", 0.1, 10, errors)
    local bt = string.upper(trim(values.buildType))
    if bt == "S" or bt == "" then
        p.buildType = "S"
    elseif bt == "K" or bt == "C" then
        p.buildType = "K"
    elseif bt == "L" or bt == "H" then
        p.buildType = "L"
    elseif bt == "B" or bt == "T" then
        p.buildType = "B"
    elseif bt == "Y" or bt == "V" then
        p.buildType = "Y"
    elseif bt == "M" then
        p.buildType = "M"
    elseif bt == "Z" then
        p.buildType = "Z"
    elseif bt == "G" then
        p.buildType = "G"
    else
        table.insert(errors, getText("adrb_buildType", "buildType"))
    end
    p.curveSide = parseSide(values, "curveSide", errors)
    if p.curveSide == 0 then
        table.insert(errors, getText("adrb_curveSide", "curveSide"))
    end
    p.curveAngle = parseNumber(values, "curveAngle", 1, 360, errors)
    p.curveRadius = parseNumber(values, "curveRadius", 1, 300, errors)
    p.curveCount = parseNumber(values, "curveCount", 1, 100, errors)
    local cc = string.upper(trim(values.curveConnection))
    if cc == "V" or cc == "" then
        p.curveConnection = ADRouteBuilder.CON_FORWARD
    elseif cc == "B" then
        p.curveConnection = ADRouteBuilder.CON_DUAL
    elseif cc == "R" then
        p.curveConnection = ADRouteBuilder.CON_REVERSE
    else
        table.insert(errors, getText("adrb_curveConnection", "curveConnection"))
    end
    if p.totalLength ~= nil and p.lengthTarget ~= nil and p.endLength ~= nil and p.buildType == "S"
        and p.totalLength < p.lengthTarget + p.endLength + 1 then
        table.insert(errors, getText("adrb_totalLength", "totalLength"))
    end
    p.exitAt = parseNumber(values, "exitAt", 0, 700, errors)
    p.pointSpacing = parseNumber(values, "pointSpacing", 0.5, 50, errors)
    p.approachSide = parseSide(values, "approachSide", errors)
    p.approachAngle = parseNumber(values, "approachAngle", 1, 180, errors)
    p.approachRadius = parseNumber(values, "approachRadius", 1, 200, errors)
    p.exitSide = parseSide(values, "exitSide", errors)
    p.exitAngle = parseNumber(values, "exitAngle", 1, 180, errors)
    p.exitRadius = parseNumber(values, "exitRadius", 1, 200, errors)
    p.curvePoints = parseNumber(values, "curvePoints", 2, 60, errors)
    p.exitPoints = parseNumber(values, "exitPoints", 2, 60, errors)
    -- branch (Y)
    p.branchIn = parseNumber(values, "branchIn", 0, 500, errors)
    p.branchStraight = parseNumber(values, "branchStraight", 0, 500, errors)
    p.branchOut = parseNumber(values, "branchOut", 0, 500, errors)
    p.branchPoints = parseNumber(values, "branchPoints", 1, 60, errors)
    p.branchLeftAngle = parseNumber(values, "branchLeftAngle", 0, 180, errors)
    p.branchLeftRadius = parseNumber(values, "branchLeftRadius", 1, 300, errors)
    p.branchRightAngle = parseNumber(values, "branchRightAngle", 0, 180, errors)
    p.branchRightRadius = parseNumber(values, "branchRightRadius", 1, 300, errors)
    p.branchLeftAt = parseNumber(values, "branchLeftAt", 0, 500, errors)
    p.branchRightAt = parseNumber(values, "branchRightAt", 0, 500, errors)
    -- straight line on a guide line (G)
    p.lineSpacing = parseNumber(values, "lineSpacing", 0.5, 100, errors)
    if values.alignButton ~= nil and trim(values.alignButton) ~= "" then
        p.alignButton = parseNumber(values, "alignButton", 2, 30, errors)
    end
    local lc = string.upper(trim(values.lineConnection or ""))
    if lc == "V" or lc == "" then
        p.lineConnection = ADRouteBuilder.CON_FORWARD
    elseif lc == "B" then
        p.lineConnection = ADRouteBuilder.CON_DUAL
    elseif lc == "R" then
        p.lineConnection = ADRouteBuilder.CON_REVERSE
    else
        table.insert(errors, getText("adrb_lineConnection", "lineConnection"))
    end
    -- the branch always branches off; merging in is the build type "merge" (Z).
    -- (an old saved value "E" = merge in is ignored)
    p.branchMerge = false
    local bc = string.upper(trim(values.branchConnection))
    if bc == "V" or bc == "" then
        p.branchConnection = ADRouteBuilder.CON_FORWARD
    elseif bc == "B" then
        p.branchConnection = ADRouteBuilder.CON_DUAL
    else
        table.insert(errors, getText("adrb_branchConnection", "branchConnection"))
    end
    if (p.buildType == "Y" or p.buildType == "Z") and p.branchLeftAngle ~= nil and p.branchRightAngle ~= nil and p.branchStraight ~= nil
        and p.branchLeftAngle < 1 and p.branchRightAngle < 1 and p.branchStraight <= 0 then
        table.insert(errors, getText("adrb_branchNothing", "no branch"))
    end
    if #errors > 0 then
        return nil, table.concat(errors, ", ")
    end
    p.count = math.floor(p.count)
    p.curvePoints = math.floor(p.curvePoints)
    p.exitPoints = math.floor(p.exitPoints)
    p.branchPoints = math.floor(p.branchPoints)
    return p
end

-------------------------------------------------------------------------------------------------
-- geometry (local frame: x = right, z = outwards; target at 0/0)
-------------------------------------------------------------------------------------------------

--- Builds the route of one bay in local coordinates.
--- Layout (u = distance from the target outwards):
---   T (u=0) ==dual== J (approach joins) ==dual== K (exit branches) ==dual== P
---   turning piece at P: forward P -> M (1 m to the side) -> E, reverse E -> P
---   AutoDrive does not allow turns > 80 degree on normal connections, so a vehicle coming in at J
---   has to drive on to E, reverses E -> P and then reverses on the dual lane into T.
---@return table points {{x, z}, ...}, connections {{a, b, type}}, markerIndex, info
function ADRouteBuilder.buildBayLocal(p)
    local points, connections, helpers = {}, {}, {}
    local function addPoint(x, z)
        table.insert(points, {x, z})
        return #points
    end
    local function connect(a, b, t)
        if a ~= nil and b ~= nil and a ~= b then
            table.insert(connections, {a, b, t})
        end
    end

    local uE = p.totalLength
    local endLength = math.min(p.endLength, uE - 1)
    local uP = uE - endLength

    -- dual lane T .. P
    local numB = math.max(1, math.ceil(uP / p.pointSpacing - 0.001))
    local us = {}
    for i = 0, numB do
        us[i] = uP * i / numB
    end
    -- curves aligned to a guide line join the lane at an exact position: extra lane point there
    local exact = {}
    if p.exactApproach and p.approachSide ~= 0 then
        table.insert(exact, p.lengthTarget)
    end
    if p.exactExit and p.exitSide ~= 0 then
        table.insert(exact, p.exitAt)
    end
    if #exact > 0 then
        local list = {}
        for i = 0, numB do
            local keep = true
            for _, u in ipairs(exact) do
                if i > 0 and i < numB and math.abs(us[i] - u) < p.pointSpacing * 0.4 then
                    keep = false
                end
            end
            if keep then
                table.insert(list, us[i])
            end
        end
        for _, u in ipairs(exact) do
            local dup = false
            for _, v in ipairs(list) do
                if math.abs(v - u) < 0.05 then
                    dup = true
                end
            end
            if not dup then
                table.insert(list, math.max(0.1, math.min(uP, u)))
            end
        end
        table.sort(list)
        us = {}
        for i, u in ipairs(list) do
            us[i - 1] = u
        end
        numB = #list - 1
    end
    local lane = {}
    for i = 0, numB do
        lane[i] = addPoint(0, us[i])
    end
    for i = 1, numB do
        connect(lane[i - 1], lane[i], ADRouteBuilder.CON_DUAL)
    end
    local function laneIndexAt(u)
        local idx, best = 1, nil
        for i = 1, numB do
            local d = math.abs(us[i] - u)
            if best == nil or d < best then
                idx, best = i, d
            end
        end
        return idx
    end
    local pointP = lane[numB]

    -- turning piece: forward P -> M -> E, M lies just beside the reverse line shortly before E
    local pointM = addPoint(-p.turnOffset, uE - math.min(ADRouteBuilder.TURN_BACK, endLength * 0.3))
    local pointE = addPoint(0, uE)
    connect(pointP, pointM, ADRouteBuilder.CON_FORWARD)
    connect(pointM, pointE, ADRouteBuilder.CON_FORWARD)
    connect(pointE, pointP, ADRouteBuilder.CON_REVERSE)

    -- approach curve ending at J on the lane, tangent outwards, lying on the given side
    local approachStart, pointJ = nil, nil
    if p.approachSide ~= 0 then
        local jIndex = laneIndexAt(p.lengthTarget)
        pointJ = lane[jIndex]
        local uJ = us[jIndex]
        local r, a, s = p.approachRadius, math.rad(p.approachAngle), p.approachSide
        ADRouteBuilder.addCurveHelpers(helpers, {s * r, uJ}, r,
            {s * r * (1 - math.cos(a)), uJ - r * math.sin(a)}, {-s * math.sin(a), math.cos(a)}, {0, uJ})
        local prev = nil
        for k = p.curvePoints, 1, -1 do
            local phi = a * k / p.curvePoints
            local idx = addPoint(s * r * (1 - math.cos(phi)), uJ - r * math.sin(phi))
            if k == p.curvePoints then
                approachStart = idx
            end
            connect(prev, idx, ADRouteBuilder.CON_FORWARD)
            prev = idx
        end
        connect(prev, pointJ, ADRouteBuilder.CON_FORWARD)
    end

    -- exit curve starting at K on the lane
    local exitEnd, pointK = nil, nil
    if p.exitSide ~= 0 then
        local kIndex = laneIndexAt(p.exitAt)
        pointK = lane[kIndex]
        local uK = us[kIndex]
        local r, a, s = p.exitRadius, math.rad(p.exitAngle), p.exitSide
        ADRouteBuilder.addCurveHelpers(helpers, {s * r, uK}, r,
            {s * r * (1 - math.cos(a)), uK + r * math.sin(a)}, {s * math.sin(a), math.cos(a)}, {0, uK})
        local prev = pointK
        for k = 1, p.exitPoints do
            local phi = a * k / p.exitPoints
            local idx = addPoint(s * r * (1 - math.cos(phi)), uK + r * math.sin(phi))
            connect(prev, idx, ADRouteBuilder.CON_FORWARD)
            prev = idx
            exitEnd = idx
        end
    end

    -- helper line: axis of the lane, extended on both sides
    table.insert(helpers, {0, -ADRouteBuilder.HELPER_LENGTH, 0, uE + ADRouteBuilder.HELPER_LENGTH, "axis"})
    local info = {target = lane[0], pointJ = pointJ, pointK = pointK, pointP = pointP, pointE = pointE,
        approachStart = approachStart, exitEnd = exitEnd, helpers = helpers}
    return points, connections, lane[0], info
end

--- Builds the complete route (all bays) in world coordinates.
--- With several bays the approach start points and the exit end points are joined by straight
--- one-way lines (collector roads) in driving direction of the curves.
-------------------------------------------------------------------------------------------------
-- helper lines for the preview (local coordinates: {x1, z1, x2, z2, kind})
--   kind "axis"    : extended straight lines / tangents (white, dashed)
--   kind "circle"  : full circle of a curve (grey)
--   kind "radius"  : radius lines from the centre (yellow)
-------------------------------------------------------------------------------------------------
ADRouteBuilder.HELPER_LENGTH = 60
-- dark colours of the main guide lines (normal, arc line 1, arc line 2) and of the ruler
ADRouteBuilder.GUIDE_COLORS = {guide = {0.35, 0.0, 0.4}, guideArc1 = {0.55, 0.22, 0.0}, guideArc2 = {0.0, 0.3, 0.45}}

--- center c, radius r, free end point e with its tangent direction d, fixed end point f
function ADRouteBuilder.addCurveHelpers(helpers, c, r, e, d, f)
    local L = ADRouteBuilder.HELPER_LENGTH
    -- tangent through the free end of the curve, extended in both directions
    table.insert(helpers, {e[1] - d[1] * L, e[2] - d[2] * L, e[1] + d[1] * L, e[2] + d[2] * L, "axis"})
    -- full circle
    local n = 48
    for i = 0, n - 1 do
        local a1, a2 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        table.insert(helpers, {c[1] + r * math.cos(a1), c[2] + r * math.sin(a1), c[1] + r * math.cos(a2), c[2] + r * math.sin(a2), "circle"})
    end
    -- radius lines and centre cross
    table.insert(helpers, {c[1], c[2], e[1], e[2], "radius"})
    table.insert(helpers, {c[1], c[2], f[1], f[2], "radius"})
    table.insert(helpers, {c[1] - 0.8, c[2], c[1] + 0.8, c[2], "radius"})
    table.insert(helpers, {c[1], c[2] - 0.8, c[1], c[2] + 0.8, "radius"})
end

function ADRouteBuilder.transformHelpers(localHelpers, tx, tz, dirX, dirZ, rightX, rightZ)
    local result = {}
    for _, h in ipairs(localHelpers or {}) do
        local x1 = tx + rightX * h[1] + dirX * h[2]
        local z1 = tz + rightZ * h[1] + dirZ * h[2]
        local x2 = tx + rightX * h[3] + dirX * h[4]
        local z2 = tz + rightZ * h[3] + dirZ * h[4]
        table.insert(result, {x1, z1, x2, z2, h[5]})
    end
    return result
end

-------------------------------------------------------------------------------------------------
-- arc (B): circle tangent to the last two guide lines. The mouse chooses the quadrant and the
-- tangent point on line 1, the tangent point on line 2 has the same distance to the intersection.
-------------------------------------------------------------------------------------------------

function ADRouteBuilder.computeArc(tx, tz)
    local n = #ADRouteBuilder.guides
    if n < 2 then
        return {error = "adrb_arcNeedGuides"}
    end
    local g1, g2 = ADRouteBuilder.guides[n - 1], ADRouteBuilder.guides[n]
    local d1x, d1z = math.sin(g1.rot), math.cos(g1.rot)
    local d2x, d2z = math.sin(g2.rot), math.cos(g2.rot)
    local cross = d1x * d2z - d1z * d2x
    if math.abs(cross) < 0.01 then
        return {error = "adrb_arcParallel"}
    end
    -- intersection I = g1 + t * d1
    local t = ((g2.x - g1.x) * d2z - (g2.z - g1.z) * d2x) / cross
    local ix, iz = g1.x + d1x * t, g1.z + d1z * t
    local mx, mz = tx - ix, tz - iz
    -- ray on line 1 towards the mouse, distance = projection of the mouse
    local p1 = mx * d1x + mz * d1z
    local s1 = p1 >= 0 and 1 or -1
    local u1x, u1z = d1x * s1, d1z * s1
    local tangent = math.abs(p1)
    -- ray on line 2 on the same side of line 1 as the mouse
    local sideMouse = d1x * mz - d1z * mx
    local side2 = d1x * d2z - d1z * d2x
    local s2 = (sideMouse * side2 >= 0) and 1 or -1
    local u2x, u2z = d2x * s2, d2z * s2
    local cosPhi = math.max(-1, math.min(1, u1x * u2x + u1z * u2z))
    local phi = math.acos(cosPhi)
    if tangent < 0.2 or phi < math.rad(1) or phi > math.rad(179) then
        return {error = "adrb_arcTooSmall"}
    end
    local radius = tangent * math.tan(phi * 0.5)
    local bx, bz = u1x + u2x, u1z + u2z
    local bl = MathUtil.vector2Length(bx, bz)
    local cDist = tangent / math.cos(phi * 0.5)
    local cx, cz = ix + bx / bl * cDist, iz + bz / bl * cDist
    local sx, sz = ix + u1x * tangent, iz + u1z * tangent
    local ex, ez = ix + u2x * tangent, iz + u2z * tangent
    return {ix = ix, iz = iz, u1x = u1x, u1z = u1z, u2x = u2x, u2z = u2z, tangent = tangent, radius = radius,
        angle = math.deg(phi), cx = cx, cz = cz, sx = sx, sz = sz, ex = ex, ez = ez,
        -- offset of the mouse point from the tangent point (kept when the radius is changed)
        offX = tx - sx, offZ = tz - sz}
end

function ADRouteBuilder.buildArcWorld(p, tx, tz, precise)
    local a = ADRouteBuilder.computeArc(tx, tz)
    ADRouteBuilder.lastArc = a
    local route = {points = {}, connections = {}, markers = {}, preview = {}, helpers = {}}
    if a.error ~= nil then
        return route
    end
    local a1 = math.atan2(a.sz - a.cz, a.sx - a.cx)
    local a2 = math.atan2(a.ez - a.cz, a.ex - a.cx)
    local diff = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
    local n = math.max(1, math.floor(p.curveCount))
    for k = 0, n do
        local ang = a1 + diff * k / n
        local x, z = a.cx + a.radius * math.cos(ang), a.cz + a.radius * math.sin(ang)
        local y
        if precise then
            y = ADRouteBuilder.getHeight(x, z)
        else
            y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
        end
        table.insert(route.points, {x, y, z})
    end
    for k = 1, n do
        if ADRouteBuilder.arcReverseDir then
            table.insert(route.connections, {k + 1, k, p.curveConnection})
        else
            table.insert(route.connections, {k, k + 1, p.curveConnection})
        end
    end
    route.startIndex = ADRouteBuilder.arcReverseDir and (n + 1) or 1
    -- helpers: full circle, radius lines, centre
    ADRouteBuilder.addCurveHelpers(route.helpers, {a.cx, a.cz}, a.radius, {a.sx, a.sz}, {a.u1x, a.u1z}, {a.ex, a.ez})
    return route
end

--- A single free curve: starts at the mouse position, start direction = rotation.
function ADRouteBuilder.buildCurveLocal(p)
    local points, connections = {}, {}
    local r, a, s, n = p.curveRadius, math.rad(p.curveAngle), p.curveSide, math.floor(p.curveCount)
    for k = 0, n do
        local phi = a * k / n
        table.insert(points, {s * r * (1 - math.cos(phi)), r * math.sin(phi)})
        if k > 0 then
            if ADRouteBuilder.arcReverseDir then
                table.insert(connections, {k + 1, k, p.curveConnection})
            else
                table.insert(connections, {k, k + 1, p.curveConnection})
            end
        end
    end
    local helpers = {}
    -- start tangent (extended backwards and forwards)
    table.insert(helpers, {0, -ADRouteBuilder.HELPER_LENGTH, 0, ADRouteBuilder.HELPER_LENGTH * 0.4, "axis"})
    ADRouteBuilder.addCurveHelpers(helpers, {s * r, 0}, r, {s * r * (1 - math.cos(a)), r * math.sin(a)},
        {s * math.sin(a), math.cos(a)}, {0, 0})
    return points, connections, helpers
end

function ADRouteBuilder.buildCurveWorld(p, tx, tz, rotY, precise)
    local dirX, dirZ = math.sin(rotY), math.cos(rotY)
    local rightX, rightZ = dirZ, -dirX
    local localPoints, localConnections, localHelpers = ADRouteBuilder.buildCurveLocal(p)
    local route = {points = {}, connections = localConnections, markers = {}, preview = {}}
    route.helpers = ADRouteBuilder.transformHelpers(localHelpers, tx, tz, dirX, dirZ, rightX, rightZ)
    for _, lp in ipairs(localPoints) do
        local x = tx + rightX * lp[1] + dirX * lp[2]
        local z = tz + rightZ * lp[1] + dirZ * lp[2]
        local y
        if precise then
            y = ADRouteBuilder.getHeight(x, z)
        else
            y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
        end
        table.insert(route.points, {x, y, z})
    end
    route.startIndex = 1
    return route
end

-------------------------------------------------------------------------------------------------
-- branch (Y): straight feed line, at the branch point (= mouse position) curves to the left and/or
-- right and optionally a straight continuation. Local frame: x = right, z = forward.
-- Direction "A" (Abzweig): feed line -> branches, "E" (Einmuendung): branches -> feed line.
-------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------
-- straight line on a guide line (G): 1st click = start, 2nd click = end, both are put onto the
-- same guide line; the points are spread evenly with a spacing of at most "lineSpacing"
-------------------------------------------------------------------------------------------------
ADRouteBuilder.GUIDE_SNAP_DISTANCE = 15

--- A "target" is one line of a guide cross: +i = main line of guide i (with the ruler), -i = its cross line.
function ADRouteBuilder.getGuideTarget(target)
    if target == nil then
        return nil
    end
    local g = ADRouteBuilder.guides[math.abs(target)]
    if g == nil then
        return nil
    end
    if target < 0 then
        return {x = g.x, z = g.z, rot = g.rot + math.pi * 0.5, length = g.length * 0.5}
    end
    return g
end

--- text for a target: "2" or "2 (cross line)"
function ADRouteBuilder.getTargetName(target)
    if target == nil then
        return "-"
    end
    if target < 0 then
        return string.format(getText("adrb_targetCross", "%d (cross line)"), -target)
    end
    return tostring(target)
end

--- target number after guide line "index" was removed (nil = it was this guide line)
function ADRouteBuilder.targetAfterRemove(target, index)
    if target == nil or math.abs(target) == index then
        return nil
    end
    if math.abs(target) > index then
        return target > 0 and target - 1 or target + 1
    end
    return target
end

--- target number after a guide line was put back at "index"
function ADRouteBuilder.targetAfterInsert(target, index)
    if target ~= nil and math.abs(target) >= index then
        return target > 0 and target + 1 or target - 1
    end
    return target
end

--- nearest guide line to x/z: projected point, guide index, target (see above), distance.
--- target = only this line; withCross = the cross lines count too
function ADRouteBuilder.projectOnGuide(x, z, target, withCross)
    local best = nil
    local function test(id)
        local g = ADRouteBuilder.getGuideTarget(id)
        if g == nil then
            return
        end
        local dx, dz = math.sin(g.rot), math.cos(g.rot)
        local t = (x - g.x) * dx + (z - g.z) * dz
        if target == nil and g.length ~= nil and math.abs(t) > g.length + ADRouteBuilder.GUIDE_SNAP_DISTANCE then
            -- when searching, only near the drawn part of the line (the cross lines are short)
            return
        end
        local px, pz = g.x + dx * t, g.z + dz * t
        local d = MathUtil.vector2Length(x - px, z - pz)
        if best == nil or d < best.d then
            best = {x = px, z = pz, index = math.abs(id), target = id, d = d}
        end
    end
    if target ~= nil then
        test(target)
        return best
    end
    for i, _ in ipairs(ADRouteBuilder.guides) do
        test(i)
        if withCross then
            test(-i)
        end
    end
    return best
end

--- number of segments for a line of length len: equal parts, none longer than spacing
function ADRouteBuilder.getLineSegments(len, spacing)
    return math.max(1, math.ceil(len / spacing - 0.001))
end

function ADRouteBuilder.buildLineWorld(p, tx, tz, precise)
    local route = {points = {}, connections = {}, markers = {}, preview = {}, extraCrosses = {}}
    local function addPoint(x, z)
        local y
        if precise then
            y = ADRouteBuilder.getHeight(x, z)
        else
            y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
        end
        table.insert(route.points, {x, y, z})
    end
    route.startIndex = 1
    local s = ADRouteBuilder.lineStart
    if s == nil or MathUtil.vector2Length(tx - s.x, tz - s.z) < 0.2 then
        -- no start yet (or end = start): only the snapped point is shown
        if s ~= nil then
            tx, tz = s.x, s.z
        end
        addPoint(tx, tz)
        route.noBuild = true
        return route
    end
    local len = MathUtil.vector2Length(tx - s.x, tz - s.z)
    local n = ADRouteBuilder.getLineSegments(len, p.lineSpacing)
    for i = 0, n do
        addPoint(s.x + (tx - s.x) * i / n, s.z + (tz - s.z) * i / n)
        if i > 0 then
            if ADRouteBuilder.arcReverseDir then
                table.insert(route.connections, {i + 1, i, p.lineConnection})
            else
                table.insert(route.connections, {i, i + 1, p.lineConnection})
            end
        end
    end
    table.insert(route.extraCrosses, {n + 1, 1, 0.5, 0})
    route.lineLength = len
    route.lineSpacingUsed = len / n
    return route
end

-------------------------------------------------------------------------------------------------
-- branch / merge tangent to a guide line (LCtrl + align mouse button: 1st click = side, 2nd click =
-- guide line): the angle of the side is set to the direction of the guide line and the whole branch
-- is moved along its main axis until the end of that side lies exactly on the guide line.
-- A 2nd side aligned the same way keeps the position and moves where its curve starts instead. With a start on an AD point (Num0) the start stays
-- there and the feed line (merge: outgoing line) gets as long as needed instead.
-------------------------------------------------------------------------------------------------
function ADRouteBuilder.computeTangentAlign(p, tx, tz, rotY, anchored, list)
    local dirX, dirZ = math.sin(rotY), math.cos(rotY)
    local rightX, rightZ = dirZ, -dirX
    local mirror = p.buildType == "Z" and -1 or 1
    local function toLocal(wx, wz)
        return wx * rightX + wz * rightZ, (wx * dirX + wz * dirZ) * mirror
    end
    local sides = {
        [-1] = {angle = p.branchLeftAngle, r = p.branchLeftRadius, at = p.branchLeftAt, angleField = "branchLeftAngle", atField = "branchLeftAt"},
        [1] = {angle = p.branchRightAngle, r = p.branchRightRadius, at = p.branchRightAt, angleField = "branchRightAngle", atField = "branchRightAt"}
    }
    --- guide in the local frame, direction pointing to side s; nil if parallel to the main line
    local function localGuide(g, s)
        local ux, uz = toLocal(math.sin(g.rot), math.cos(g.rot))
        if s * ux < 0 then
            ux, uz = -ux, -uz
        end
        if math.abs(ux) <= 0.02 then
            return nil
        end
        local px, pz = toLocal(g.x - tx, g.z - tz)
        local a = math.atan2(math.abs(ux), uz)
        if math.deg(a) < 1 or math.deg(a) > 179 then
            return nil
        end
        return ux, uz, px, pz, a
    end
    -- 1st guide line: angle of side s, the whole branch moves by t along its axis
    local function solveMove(g, s)
        local side = sides[s]
        if side.angle < 1 then
            return nil
        end
        local ux, uz, px, pz, a = localGuide(g, s)
        if ux == nil then
            return nil
        end
        local r = side.r
        local ex, ez = s * r * (1 - math.cos(a)), side.at + r * math.sin(a)
        -- cross(u, E + (0, t) - P) = 0
        local t = -(ux * (ez - pz) - uz * (ex - px)) / ux
        if anchored and p.branchIn + t < 0 then
            return nil
        end
        return {t = t, angle = math.deg(a)}
    end
    -- 2nd guide line: angle of side s and where it starts on the main line ("starts after" = z0)
    local function solveStart(g, s, t)
        local side = sides[s]
        if side.angle < 1 then
            return nil
        end
        local ux, uz, px, pz, a = localGuide(g, s)
        if ux == nil then
            return nil
        end
        local r = side.r
        pz = pz - t
        local ex = s * r * (1 - math.cos(a))
        local z0 = pz - r * math.sin(a) + uz * (ex - px) / ux
        if z0 < 0 then
            return nil
        end
        return {at = z0, angle = math.deg(a)}
    end

    -- list = {{side = -1 / 1, target = guide line}, ...}: the 1st entry moves the whole branch,
    -- the 2nd (other side) moves where its curve starts on the main line
    local first, second = list ~= nil and list[1] or nil, list ~= nil and list[2] or nil
    local g = first ~= nil and ADRouteBuilder.getGuideTarget(first.target) or nil
    if g == nil then
        return nil
    end
    local m = solveMove(g, first.side)
    if m == nil then
        return nil
    end
    local best = {t = m.t, angle = m.angle, side = first.side, guide = first.target}
    if second ~= nil and second.side == -first.side then
        local g2 = ADRouteBuilder.getGuideTarget(second.target)
        best.second = g2 ~= nil and solveStart(g2, second.side, m.t) or nil
        best.secondGuide = second.target
        best.secondFailed = best.second == nil
    end
    if best == nil then
        return nil
    end
    local override = {[sides[best.side].angleField] = best.angle}
    if best.second ~= nil then
        override[sides[-best.side].angleField] = best.second.angle
        override[sides[-best.side].atField] = best.second.at
    end
    if anchored then
        override.branchIn = p.branchIn + best.t
    end
    best.params = setmetatable(override, {__index = p})
    best.x = tx + dirX * best.t * mirror
    best.z = tz + dirZ * best.t * mirror
    return best
end

--- mouse button for aligning (together with LCtrl), set in the dialog or learned with LCtrl + LAlt + N
function ADRouteBuilder.getAlignButton()
    return tonumber(ADRouteBuilder.values.alignButton or "") or tonumber(ADRouteBuilder.DEFAULTS.alignButton)
end

--- guide line (L): LCtrl + align button near an existing guide line = the new line becomes parallel to it
--- (main or cross line); of the two possible directions the one nearer to the current rotation is kept
function ADRouteBuilder.alignGuideParallel()
    local mx, mz = ADRouteBuilder.getMouseTerrainPos()
    if mx == nil then
        return
    end
    -- of the two directions of a line the one nearer to the current rotation is kept
    local function keepSide(rot)
        local diff = (ADRouteBuilder.rotation - rot) % (2 * math.pi)
        if diff > math.pi * 0.5 and diff < math.pi * 1.5 then
            rot = rot + math.pi
        end
        return rot
    end
    -- 1. a guide line near the mouse
    local pr = ADRouteBuilder.projectOnGuide(mx, mz, nil, true)
    if pr ~= nil and pr.d <= ADRouteBuilder.GUIDE_SNAP_DISTANCE then
        local g = ADRouteBuilder.getGuideTarget(pr.target)
        ADRouteBuilder.rotation = keepSide(g.rot)
        ADRouteBuilder.parallelRef = {x = g.x, z = g.z, rot = g.rot, guide = g}
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
            string.format(getText("adrb_guideParallel", "parallel to guide line %s"), ADRouteBuilder.getTargetName(pr.target)))
        return
    end
    -- 2. the outline nearest to the mouse: bunker silo walls and the areas of buildings
    --    (clear / leveling / placement test areas), parallel to the edge you click at
    local bestEdge, bestD, bestKind, bestName, bestPoint = nil, nil, nil, nil, nil
    local function testQuad(corners, kind, name)
        for i = 1, 4 do
            local p1, p2 = corners[i], corners[i % 4 + 1]
            local ex, ez = p2[1] - p1[1], p2[2] - p1[2]
            local len2 = ex * ex + ez * ez
            if len2 > 0.25 then
                local t = math.max(0, math.min(1, ((mx - p1[1]) * ex + (mz - p1[2]) * ez) / len2))
                local d = MathUtil.vector2Length(mx - (p1[1] + ex * t), mz - (p1[2] + ez * t))
                if bestD == nil or d < bestD then
                    bestEdge, bestD, bestKind, bestName = math.atan2(ex, ez), d, kind, name
                    bestPoint = {p1[1], p1[2]}
                end
            end
        end
    end
    local function testArea(sx, sz, wx, wz, hx, hz, kind, name)
        local w = {wx - sx, wz - sz}
        local h = {hx - sx, hz - sz}
        testQuad({{sx, sz}, {sx + w[1], sz + w[2]}, {sx + w[1] + h[1], sz + w[2] + h[2]}, {sx + h[1], sz + h[2]}}, kind, name)
    end
    for _, a in ipairs(ADRouteBuilder.getBunkerSiloAreas()) do
        testArea(a.sx, a.sz, a.wx, a.wz, a.hx, a.hz, "silo")
    end
    pcall(function()
        local ps = g_currentMission.placeableSystem
        for _, placeable in ipairs(ps ~= nil and ps.placeables or {}) do
            local name = placeable.getName ~= nil and placeable:getName() or nil
            local lists = {}
            if placeable.spec_clearAreas ~= nil then
                table.insert(lists, placeable.spec_clearAreas.areas)
            end
            if placeable.spec_leveling ~= nil then
                table.insert(lists, placeable.spec_leveling.levelAreas)
            end
            for _, list in ipairs(lists) do
                for _, area in ipairs(list or {}) do
                    if area.start ~= nil and area.width ~= nil and area.height ~= nil then
                        local sx, _, sz = getWorldTranslation(area.start)
                        local wx, _, wz = getWorldTranslation(area.width)
                        local hx, _, hz = getWorldTranslation(area.height)
                        testArea(sx, sz, wx, wz, hx, hz, "building", name)
                    end
                end
            end
            if placeable.spec_placement ~= nil then
                for _, area in ipairs(placeable.spec_placement.testAreas or {}) do
                    if area.startNode ~= nil and area.endNode ~= nil then
                        local ox, _, oz = localToLocal(area.endNode, area.startNode, 0, 0, 0)
                        local c = {}
                        for _, q in ipairs({{0, 0}, {ox, 0}, {ox, oz}, {0, oz}}) do
                            local x, _, z = localToWorld(area.startNode, q[1], 0, q[2])
                            table.insert(c, {x, z})
                        end
                        testQuad(c, "building", name)
                    end
                end
            end
        end
    end)
    if bestEdge ~= nil and bestD <= ADRouteBuilder.GUIDE_SNAP_DISTANCE then
        ADRouteBuilder.rotation = keepSide(bestEdge)
        ADRouteBuilder.parallelRef = {x = bestPoint[1], z = bestPoint[2], rot = bestEdge}
        if bestKind == "silo" then
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, getText("adrb_guideParallelSilo", "parallel to the bunker silo"))
        else
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
                string.format(getText("adrb_guideParallelEdge", "parallel to the edge of %s"), tostring(bestName or "")))
        end
        return
    end
    -- 3. a building (placeable): its own axes, the one nearer to the current rotation
    local bestRot, bestName, bestPD = nil, nil, nil
    pcall(function()
        local ps = g_currentMission.placeableSystem
        for _, placeable in ipairs(ps ~= nil and ps.placeables or {}) do
            local node = placeable.rootNode
            if node ~= nil and node ~= 0 then
                local px, _, pz = getWorldTranslation(node)
                local d = MathUtil.vector2Length(px - mx, pz - mz)
                if d <= 40 and (bestPD == nil or d < bestPD) then
                    local dx, _, dz = localDirectionToWorld(node, 0, 0, 1)
                    bestRot, bestPD = math.atan2(dx, dz), d
                    bestName = placeable.getName ~= nil and placeable:getName() or nil
                end
            end
        end
    end)
    if bestRot ~= nil then
        -- nearest of the four axis directions (along / across the building)
        local best, bestDiff = bestRot, nil
        for k = 0, 3 do
            local r = bestRot + k * math.pi * 0.5
            local diff = math.abs(((ADRouteBuilder.rotation - r + math.pi) % (2 * math.pi)) - math.pi)
            if bestDiff == nil or diff < bestDiff then
                best, bestDiff = r, diff
            end
        end
        ADRouteBuilder.rotation = best
        ADRouteBuilder.parallelRef = nil
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
            string.format(getText("adrb_guideParallelBuilding", "aligned to the building %s"), tostring(bestName or "")))
        return
    end
    g_currentMission:showBlinkingWarning(getText("adrb_guideNothingNear", "no guide line, bunker silo or building near the mouse"), 2500)
end

--- distance of the new guide line to the line it was made parallel to (nil if it is not parallel any more)
function ADRouteBuilder.getParallelDistance()
    local r = ADRouteBuilder.parallelRef
    if r == nil or ADRouteBuilder.lastX == nil then
        return nil
    end
    -- the reference guide line was removed (Del / LCtrl + LAlt + L): no distance any more
    if r.guide ~= nil then
        local exists = false
        for _, g in ipairs(ADRouteBuilder.guides) do
            if g == r.guide then
                exists = true
            end
        end
        if not exists then
            -- then the last guide line that is still there is the reference (if the new line is parallel to it)
            local last = ADRouteBuilder.guides[#ADRouteBuilder.guides]
            if last == nil then
                return nil
            end
            r = {x = last.x, z = last.z, rot = last.rot, guide = last}
            ADRouteBuilder.parallelRef = r
        end
    end
    local diff = math.abs(((ADRouteBuilder.rotation - r.rot) % math.pi + math.pi * 0.5) % math.pi - math.pi * 0.5)
    if diff > math.rad(0.05) then
        return nil
    end
    local dx, dz = math.sin(r.rot), math.cos(r.rot)
    local t = (ADRouteBuilder.lastX - r.x) * dx + (ADRouteBuilder.lastZ - r.z) * dz
    local fx, fz = r.x + dx * t, r.z + dz * t
    return MathUtil.vector2Length(ADRouteBuilder.lastX - fx, ADRouteBuilder.lastZ - fz), fx, fz
end

--- LCtrl + align button: 1st click near a side of the branch = choose that side,
--- 2nd click near a guide line (main or cross line) = align the chosen side to it
ADRouteBuilder.alignList = {}
function ADRouteBuilder.alignClick()
    local p = ADRouteBuilder.params
    local mx, mz = ADRouteBuilder.getMouseTerrainPos()
    if mx == nil or p == nil then
        return
    end
    if ADRouteBuilder.alignPending == nil then
        if #ADRouteBuilder.guides == 0 then
            g_currentMission:showBlinkingWarning(getText("adrb_lineNeedGuide", "set a guide line first"), 3000)
            return
        end
        -- which side of the main line was clicked
        local _, ex, ez = ADRouteBuilder.getEffective()
        if ex == nil then
            return
        end
        local dirX, dirZ = math.sin(ADRouteBuilder.rotation), math.cos(ADRouteBuilder.rotation)
        local lx = (mx - ex) * dirZ + (mz - ez) * (-dirX)
        local side = lx < 0 and -1 or 1
        local angle = side < 0 and p.branchLeftAngle or p.branchRightAngle
        if angle == nil or angle < 1 then
            g_currentMission:showBlinkingWarning(getText(side < 0 and "adrb_alignNoLeft" or "adrb_alignNoRight", "no branch on this side (angle 0)"), 3000)
            return
        end
        ADRouteBuilder.alignPending = side
        ADRouteBuilder.posLocked = true
        return
    end
    local side = ADRouteBuilder.alignPending
    ADRouteBuilder.alignPending = nil
    local pr = ADRouteBuilder.projectOnGuide(mx, mz, nil, true)
    local position = nil
    local list = {}
    for i, e in ipairs(ADRouteBuilder.alignList) do
        if e.side == side then
            position = i
        else
            table.insert(list, e)
        end
    end
    if pr ~= nil and pr.d <= ADRouteBuilder.GUIDE_SNAP_DISTANCE then
        -- the side keeps its place in the order (1st = moves the branch, 2nd = moves its start)
        table.insert(list, math.min(position or (#list + 1), #list + 1), {side = side, target = pr.target})
    else
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
            getText(side < 0 and "adrb_alignOffLeft" or "adrb_alignOffRight", "alignment of this side off"))
    end
    ADRouteBuilder.alignList = list
end

-------------------------------------------------------------------------------------------------
-- reverse bays: fit to the bunker silo at the mouse (Num9). The game knows the area of every bunker
-- silo (start / width / height node, BunkerSilo.bunkerSiloArea). Width -> spacing = width / number of
-- bays, the bays are centred, the direction runs along the silo out of the end nearer to the mouse,
-- the targets lie in front of the other end.
-------------------------------------------------------------------------------------------------
ADRouteBuilder.SILO_TARGET_MARGIN = 2      -- m between the back end of the silo and the targets

--- all bunker silo areas: {sx, sz, wx, wz, hx, hz} (inner area if the silo has one)
function ADRouteBuilder.getBunkerSiloAreas()
    local areas = {}
    local function add(silo)
        local a = silo ~= nil and silo.bunkerSiloArea or nil
        if a == nil or a.sx == nil then
            return
        end
        local i = a.inner
        if i ~= nil and i.sx ~= nil and i.wx ~= nil and i.hx ~= nil then
            table.insert(areas, {sx = i.sx, sz = i.sz, wx = i.wx, wz = i.wz, hx = i.hx, hz = i.hz})
        else
            table.insert(areas, {sx = a.sx, sz = a.sz, wx = a.wx, wz = a.wz, hx = a.hx, hz = a.hz})
        end
    end
    pcall(function()
        local ps = g_currentMission.placeableSystem
        for _, placeable in ipairs(ps ~= nil and ps.bunkerSilos or {}) do
            if placeable.spec_bunkerSilo ~= nil then
                add(placeable.spec_bunkerSilo.bunkerSilo)
            end
            if placeable.spec_multiBunkerSilo ~= nil then
                for _, silo in ipairs(placeable.spec_multiBunkerSilo.bunkerSilos or {}) do
                    add(silo)
                end
            end
        end
    end)
    return areas
end

function ADRouteBuilder.fitBaysToSilo()
    local p = ADRouteBuilder.params
    local mx, mz = ADRouteBuilder.getMouseTerrainPos()
    if p == nil or mx == nil then
        return
    end
    -- silo containing the mouse, otherwise the nearest one (centre) up to 30 m
    local best, bestD = nil, nil
    for _, a in ipairs(ADRouteBuilder.getBunkerSiloAreas()) do
        local dwx, dwz, dhx, dhz = a.wx - a.sx, a.wz - a.sz, a.hx - a.sx, a.hz - a.sz
        local w2, h2 = dwx * dwx + dwz * dwz, dhx * dhx + dhz * dhz
        if w2 > 0.01 and h2 > 0.01 then
            local u = ((mx - a.sx) * dwx + (mz - a.sz) * dwz) / w2
            local v = ((mx - a.sx) * dhx + (mz - a.sz) * dhz) / h2
            local cu, cv = math.max(0, math.min(1, u)), math.max(0, math.min(1, v))
            local px, pz = a.sx + dwx * cu + dhx * cv, a.sz + dwz * cu + dhz * cv
            local d = MathUtil.vector2Length(mx - px, mz - pz)
            if bestD == nil or d < bestD then
                best, bestD = {a = a, v = v, dwx = dwx, dwz = dwz, dhx = dhx, dhz = dhz, w = math.sqrt(w2), h = math.sqrt(h2)}, d
            end
        end
    end
    if best == nil or bestD > 30 then
        g_currentMission:showBlinkingWarning(getText("adrb_siloNone", "no bunker silo at the mouse"), 3000)
        return
    end
    local a = best.a
    -- opening = the end nearer to the mouse (v < 0.5: the start end)
    local openAtStart = best.v < 0.5
    local hx, hz = best.dhx / best.h, best.dhz / best.h
    local dirX, dirZ = hx, hz
    local backX, backZ = a.sx + best.dhx, a.sz + best.dhz
    if openAtStart then
        dirX, dirZ = -hx, -hz
    else
        backX, backZ = a.sx, a.sz
    end
    -- middle of the back end, a bit inside
    local cx = backX + best.dwx * 0.5 + dirX * ADRouteBuilder.SILO_TARGET_MARGIN
    local cz = backZ + best.dwz * 0.5 + dirZ * ADRouteBuilder.SILO_TARGET_MARGIN
    local spacing = best.w / math.max(1, p.count)
    p.spacing = spacing
    ADRouteBuilder.values.spacing = string.format("%.2f", spacing)
    ADRouteBuilder.values.bayAnchor = "M"
    ADRouteBuilder.rotation = math.atan2(dirX, dirZ)
    ADRouteBuilder.lastX, ADRouteBuilder.lastZ = cx, cz
    ADRouteBuilder.posLocked = true
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format(getText("adrb_siloFitted", "silo %.1f m wide, %.1f m long: %d bays every %.2f m"), best.w, best.h, p.count, spacing))
end

-------------------------------------------------------------------------------------------------
-- reverse bays: approach / exit curve tangent to a guide line (LCtrl + align mouse button: 1st click
-- near the approach or the exit curve, 2nd click on the guide line). The angle follows the guide line,
-- the radius is computed for every bay so that the free end of the curve lies on the line.
-------------------------------------------------------------------------------------------------
ADRouteBuilder.bayAlign = {}

function ADRouteBuilder.hasBayAlign()
    return ADRouteBuilder.bayAlign.approach ~= nil or ADRouteBuilder.bayAlign.exit ~= nil
end

--- parameters of bay b with angle / radius from the guide lines; failures are noted in bayAlignFail
function ADRouteBuilder.computeBayAlign(p, info, localPoints, ox, oz, dirX, dirZ, rightX, rightZ, b)
    local override = {}
    if b == 0 then
        ADRouteBuilder.bayAlignFail = {}
        ADRouteBuilder.bayAlignResult = {}
    end
    local function toLocal(wx, wz)
        return (wx - ox) * rightX + (wz - oz) * rightZ, (wx - ox) * dirX + (wz - oz) * dirZ
    end
    local uE = p.totalLength
    local uP = uE - math.min(p.endLength, uE - 1)
    -- the radius stays as set (LCtrl + wheel), the point where the curve joins the lane is computed
    -- so that the free end of the curve lies on the guide line (an extra lane point is set there)
    local function solve(kind, target, side, radius, sign)
        local g = ADRouteBuilder.getGuideTarget(target)
        if g == nil or side == 0 then
            return
        end
        local gx, gz = math.sin(g.rot), math.cos(g.rot)
        local ux, uz = gx * rightX + gz * rightZ, gx * dirX + gz * dirZ
        -- travel direction at the free end: approach (-s sin a, cos a), exit (s sin a, cos a)
        if ux * side * sign > 0 then
            ux, uz = -ux, -uz
        end
        if math.abs(ux) < 0.02 then
            ADRouteBuilder.bayAlignFail[kind] = "parallel"
            return
        end
        local a = math.atan2(math.abs(ux), uz)
        if math.deg(a) < 1 or math.deg(a) > 179 then
            ADRouteBuilder.bayAlignFail[kind] = "parallel"
            return
        end
        local px, pz = toLocal(g.x, g.z)
        -- free end relative to the attach point: approach (s r (1-cos a), -r sin a), exit (.., +r sin a)
        local ex, ez = side * (1 - math.cos(a)), -sign * math.sin(a)
        local function attachFor(r)
            local fx = ex * r
            return pz + uz * (fx - px) / ux - ez * r
        end
        local u = attachFor(radius)
        if u < 0.5 or u > uP then
            ADRouteBuilder.bayAlignFail[kind] = "outside"
            return
        end
        local res = ADRouteBuilder.bayAlignResult[kind] or {angle = math.deg(a), rMin = radius, rMax = radius, uMin = u, uMax = u, target = target}
        res.rMin, res.rMax = math.min(res.rMin, radius), math.max(res.rMax, radius)
        res.uMin, res.uMax = math.min(res.uMin, u), math.max(res.uMax, u)
        ADRouteBuilder.bayAlignResult[kind] = res
        return math.deg(a), radius, u
    end
    local ba = ADRouteBuilder.bayAlign
    if ba.approach ~= nil then
        local angle, r, u = solve("approach", ba.approach, p.approachSide, p.approachRadius, 1)
        if angle ~= nil then
            override.approachAngle, override.approachRadius, override.lengthTarget, override.exactApproach = angle, r, u, true
        end
    end
    if ba.exit ~= nil then
        local angle, r, u = solve("exit", ba.exit, p.exitSide, p.exitRadius, -1)
        if angle ~= nil then
            override.exitAngle, override.exitRadius, override.exitAt, override.exactExit = angle, r, u, true
        end
    end
    return setmetatable(override, {__index = p})
end

--- curve of the bays (approach / exit) nearest to the mouse
function ADRouteBuilder.getBayCurveAtMouse()
    local mx, mz = ADRouteBuilder.getMouseTerrainPos()
    local r = ADRouteBuilder.previewRoute
    if mx == nil or r == nil then
        return nil
    end
    local best, bestD = nil, nil
    for _, pv in ipairs(r.preview or {}) do
        for kind, idx in pairs({approach = pv.approachStart, exit = pv.exitEnd}) do
            local q = idx ~= nil and r.points[idx] or nil
            if q ~= nil then
                local d = MathUtil.vector2Length(q[1] - mx, q[3] - mz)
                if bestD == nil or d < bestD then
                    best, bestD = kind, d
                end
            end
        end
    end
    return best
end

--- LAlt + left click: approach / exit to the other side of the bay
function ADRouteBuilder.toggleBaySideAtMouse()
    local p = ADRouteBuilder.params
    local kind = ADRouteBuilder.getBayCurveAtMouse()
    if p == nil or kind == nil then
        return
    end
    local field = kind == "approach" and "approachSide" or "exitSide"
    if p[field] == 0 then
        return
    end
    p[field] = -p[field]
    ADRouteBuilder.values[field] = p[field] > 0 and "R" or "L"
    ADRouteBuilder.posLocked = true
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
        getText(kind == "approach" and "adrb_baySideApproach" or "adrb_baySideExit", "side changed"))
end

--- LCtrl + align button in the bay type: choose approach / exit, then the guide line
function ADRouteBuilder.bayAlignClick()
    local mx, mz = ADRouteBuilder.getMouseTerrainPos()
    local p = ADRouteBuilder.params
    if mx == nil or p == nil then
        return
    end
    if ADRouteBuilder.alignPending == nil then
        if #ADRouteBuilder.guides == 0 then
            g_currentMission:showBlinkingWarning(getText("adrb_lineNeedGuide", "set a guide line first"), 3000)
            return
        end
        -- the curve nearest to the mouse (all points of approach / exit of all bays)
        local r = ADRouteBuilder.previewRoute
        local best, bestD = nil, nil
        for _, pv in ipairs(r ~= nil and r.preview or {}) do
            for kind, idx in pairs({approach = pv.approachStart, exit = pv.exitEnd}) do
                local q = idx ~= nil and r.points[idx] or nil
                if q ~= nil then
                    local d = MathUtil.vector2Length(q[1] - mx, q[3] - mz)
                    if bestD == nil or d < bestD then
                        best, bestD = kind, d
                    end
                end
            end
        end
        if best == nil then
            return
        end
        ADRouteBuilder.alignPending = best
        ADRouteBuilder.posLocked = true
        return
    end
    local kind = ADRouteBuilder.alignPending
    ADRouteBuilder.alignPending = nil
    local pr = ADRouteBuilder.projectOnGuide(mx, mz, nil, true)
    if pr ~= nil and pr.d <= ADRouteBuilder.GUIDE_SNAP_DISTANCE then
        ADRouteBuilder.bayAlign[kind] = pr.target
    else
        ADRouteBuilder.bayAlign[kind] = nil
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
            getText(kind == "approach" and "adrb_bayAlignOffA" or "adrb_bayAlignOffX", "alignment off"))
    end
end

function ADRouteBuilder.getBayAlignText()
    local parts = {}
    if ADRouteBuilder.alignPending == "approach" or ADRouteBuilder.alignPending == "exit" then
        table.insert(parts, string.format(getText("adrb_bayAlignPick", "%s chosen: now LCtrl + mouse button %d or LCtrl + left click on the guide line"),
            getText(ADRouteBuilder.alignPending == "approach" and "adrb_approach" or "adrb_exit", ""), ADRouteBuilder.getAlignButton()))
    end
    for _, kind in ipairs({"approach", "exit"}) do
        if ADRouteBuilder.bayAlign[kind] ~= nil then
            local name = getText(kind == "approach" and "adrb_approach" or "adrb_exit", kind)
            local res = ADRouteBuilder.bayAlignResult ~= nil and ADRouteBuilder.bayAlignResult[kind] or nil
            local fail = ADRouteBuilder.bayAlignFail ~= nil and ADRouteBuilder.bayAlignFail[kind] or nil
            if fail == "parallel" then
                table.insert(parts, string.format(getText("adrb_bayAlignFail", "%s: guide line runs along the bay"), name))
            elseif fail ~= nil then
                table.insert(parts, string.format(getText("adrb_bayAlignOut", "%s: guide line too far away - the curve would join outside the lane"), name))
            elseif res ~= nil then
                local radius = math.abs(res.rMax - res.rMin) < 0.05 and string.format("%.1f m", res.rMin) or string.format("%.1f-%.1f m", res.rMin, res.rMax)
                local at = math.abs(res.uMax - res.uMin) < 0.05 and string.format("%.1f m", res.uMin) or string.format("%.1f-%.1f m", res.uMin, res.uMax)
                table.insert(parts, string.format(getText("adrb_bayAlignInfo", "%s tangent to guide %s: %.1f deg, radius %s, joins at %s"), name,
                    ADRouteBuilder.getTargetName(ADRouteBuilder.bayAlign[kind]), res.angle, radius, at))
            end
        end
    end
    return table.concat(parts, " - ")
end

--- LAlt + left click: removes the branch on the clicked side (angle 0), a 2nd click there brings it back
ADRouteBuilder.removedArms = {}
function ADRouteBuilder.toggleArmAtMouse()
    local p = ADRouteBuilder.params
    local mx, mz = ADRouteBuilder.getMouseTerrainPos()
    local _, ex, ez = ADRouteBuilder.getEffective()
    if p == nil or mx == nil or ex == nil then
        return
    end
    local dirX, dirZ = math.sin(ADRouteBuilder.rotation), math.cos(ADRouteBuilder.rotation)
    local side = ((mx - ex) * dirZ - (mz - ez) * dirX) < 0 and -1 or 1
    local field = side < 0 and "branchLeftAngle" or "branchRightAngle"
    local otherField = side < 0 and "branchRightAngle" or "branchLeftAngle"
    local sideText = getText(side < 0 and "adrb_optLeft" or "adrb_optRight", "")
    if p[field] >= 1 then
        if p[otherField] < 1 and p.branchStraight <= 0 then
            g_currentMission:showBlinkingWarning(getText("adrb_armLast", "this is the last branch - nothing would be left"), 3000)
            return
        end
        ADRouteBuilder.removedArms[side] = p[field]
        p[field] = 0
        -- an alignment of this side makes no sense any more
        local list = {}
        for _, e in ipairs(ADRouteBuilder.alignList) do
            if e.side ~= side then
                table.insert(list, e)
            end
        end
        ADRouteBuilder.alignList = list
        if ADRouteBuilder.alignPending == side then
            ADRouteBuilder.alignPending = nil
        end
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
            string.format(getText("adrb_armRemoved", "%s branch removed (LAlt + click there again = back)"), sideText))
    else
        p[field] = ADRouteBuilder.removedArms[side] or 45
        ADRouteBuilder.removedArms[side] = nil
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
            string.format(getText("adrb_armBack", "%s branch back"), sideText))
    end
    ADRouteBuilder.values[field] = string.format("%g", p[field])
    -- keep the branch where it is (Num5 releases it, building too)
    ADRouteBuilder.posLocked = true
end

--- parameters and position that are really built (with the tangent alignment applied)
function ADRouteBuilder.getEffective()
    local a = ADRouteBuilder.align
    if a ~= nil then
        return a.params, a.x, a.z
    end
    return ADRouteBuilder.params, ADRouteBuilder.lastX, ADRouteBuilder.lastZ
end

function ADRouteBuilder.buildBranchLocal(p)
    local points, connections, helpers = {}, {}, {}
    local function addPoint(x, z)
        table.insert(points, {x, z})
        return #points
    end
    local function connect(a, b)
        if a == nil or b == nil or a == b then
            return
        end
        if p.branchMerge then
            a, b = b, a
        end
        table.insert(connections, {a, b, p.branchConnection})
    end
    local sp = p.pointSpacing
    -- straight line from (x, z) in direction (dx, dz), length len; first point is "fromIndex"
    local function straight(fromIndex, x, z, dx, dz, len)
        local prev = fromIndex
        if len <= 0 then
            return prev
        end
        local n = math.max(1, math.ceil(len / sp - 0.001))
        for i = 1, n do
            local idx = addPoint(x + dx * len * i / n, z + dz * len * i / n)
            connect(prev, idx)
            prev = idx
        end
        return prev
    end

    -- feed line ending in the branch point
    local startIndex
    local split
    if p.branchIn > 0 then
        startIndex = addPoint(0, -p.branchIn)
        local n = math.max(1, math.ceil(p.branchIn / sp - 0.001))
        local prev = startIndex
        for i = 1, n do
            local idx = addPoint(0, -p.branchIn + p.branchIn * i / n)
            connect(prev, idx)
            prev = idx
        end
        split = prev
    else
        split = addPoint(0, 0)
        startIndex = split
    end
    table.insert(helpers, {0, -p.branchIn - ADRouteBuilder.HELPER_LENGTH * 0.5, 0, ADRouteBuilder.HELPER_LENGTH, "axis"})

    -- main line from the branch point: it runs through every branch position and then on by
    -- "straight on" (without "straight on" it ends in the last branch)
    local ends = {}
    local sides = {{-1, p.branchLeftAngle, p.branchLeftRadius, p.branchLeftAt}, {1, p.branchRightAngle, p.branchRightRadius, p.branchRightAt}}
    local stops, lastBranch = {0}, 0
    for _, side in ipairs(sides) do
        if side[2] >= 1 then
            table.insert(stops, side[4])
            lastBranch = math.max(lastBranch, side[4])
        end
    end
    local zEnd = lastBranch + p.branchStraight
    table.insert(stops, zEnd)
    table.sort(stops)
    local nodeAt = {[0] = split}
    local function key(z)
        return math.floor(z * 100 + 0.5)
    end
    nodeAt[key(0)] = split
    local prevZ, prevIndex = 0, split
    for _, z in ipairs(stops) do
        if z > prevZ + 0.01 then
            local len = z - prevZ
            local n = math.max(1, math.ceil(len / sp - 0.001))
            for i = 1, n do
                local idx = addPoint(0, prevZ + len * i / n)
                connect(prevIndex, idx)
                prevIndex = idx
            end
            prevZ = z
            nodeAt[key(z)] = prevIndex
        end
    end
    if p.branchStraight > 0 then
        table.insert(ends, prevIndex)
    end

    -- curves, s = -1 left, +1 right, starting on the main line at their own position
    for _, side in ipairs(sides) do
        local s, angle, r, z0 = side[1], side[2], side[3], side[4]
        if angle >= 1 then
            local a = math.rad(angle)
            local n = p.branchPoints
            local prev = nodeAt[key(z0)] or split
            for k = 1, n do
                local phi = a * k / n
                local idx = addPoint(s * r * (1 - math.cos(phi)), z0 + r * math.sin(phi))
                connect(prev, idx)
                prev = idx
            end
            local ex, ez = s * r * (1 - math.cos(a)), z0 + r * math.sin(a)
            local dx, dz = s * math.sin(a), math.cos(a)
            ADRouteBuilder.addCurveHelpers(helpers, {s * r, z0}, r, {ex, ez}, {dx, dz}, {0, z0})
            table.insert(ends, straight(prev, ex, ez, dx, dz, p.branchOut))
        end
    end
    return points, connections, helpers, startIndex, split, ends
end

function ADRouteBuilder.buildBranchWorld(p, tx, tz, rotY, precise)
    local dirX, dirZ = math.sin(rotY), math.cos(rotY)
    local rightX, rightZ = dirZ, -dirX
    local bp = p
    local isMerge = p.buildType == "Z"
    if isMerge then
        -- merge (Zufuehrung): the branch mirrored backwards with all arrows turned round. The lines come
        -- from behind left / right, join at the mouse position and leave forward in the set direction.
        bp = setmetatable({branchMerge = true}, {__index = p})
    end
    local localPoints, localConnections, localHelpers, startIndex, split, ends = ADRouteBuilder.buildBranchLocal(bp)
    if isMerge then
        for _, lp in ipairs(localPoints) do
            lp[2] = -lp[2]
        end
        for _, h in ipairs(localHelpers) do
            h[2], h[4] = -h[2], -h[4]
        end
    end
    local route = {points = {}, connections = localConnections, markers = {}, preview = {}}
    route.helpers = ADRouteBuilder.transformHelpers(localHelpers, tx, tz, dirX, dirZ, rightX, rightZ)
    for _, lp in ipairs(localPoints) do
        local x = tx + rightX * lp[1] + dirX * lp[2]
        local z = tz + rightZ * lp[1] + dirZ * lp[2]
        local y
        if precise then
            y = ADRouteBuilder.getHeight(x, z)
        else
            y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
        end
        table.insert(route.points, {x, y, z})
    end
    route.startIndex = split
    route.branchStart = startIndex
    route.extraCrosses = {}
    table.insert(route.extraCrosses, {startIndex, 0, 1, 0})
    for _, e in ipairs(ends) do
        table.insert(route.extraCrosses, {e, 1, 0.5, 0})
    end
    return route
end

function ADRouteBuilder.buildRouteWorld(p, tx, tz, rotY, precise)
    if p.buildType == "M" then
        return {points = {}, connections = {}, markers = {}, preview = {}}
    elseif p.buildType == "G" then
        return ADRouteBuilder.buildLineWorld(p, tx, tz, precise)
    elseif p.buildType == "Y" or p.buildType == "Z" then
        return ADRouteBuilder.buildBranchWorld(p, tx, tz, rotY, precise)
    elseif p.buildType == "K" then
        return ADRouteBuilder.buildCurveWorld(p, tx, tz, rotY, precise)
    elseif p.buildType == "L" then
        return {points = {}, connections = {}, markers = {}, preview = {}, isGuide = true,
            helpers = ADRouteBuilder.getGuideLines({x = tx, z = tz, rot = rotY, length = ADRouteBuilder.guideLength})}
    elseif p.buildType == "B" then
        return ADRouteBuilder.buildArcWorld(p, tx, tz, precise)
    end
    local dirX, dirZ = math.sin(rotY), math.cos(rotY)
    local rightX, rightZ = dirZ, -dirX
    local localPoints, localConnections, markerLocal, info = ADRouteBuilder.buildBayLocal(p)

    local route = {points = {}, connections = {}, markers = {}, preview = {}}
    route.helpers = ADRouteBuilder.transformHelpers(info.helpers, tx, tz, dirX, dirZ, rightX, rightZ)
    local approachStarts, exitEnds = {}, {}
    for b = 0, p.count - 1 do
        local offset = #route.points
        -- bays side by side; "centre" = the mouse is the middle of all bays (e.g. centred in a silo)
        local shift = b
        if ADRouteBuilder.values.bayAnchor == "M" then
            shift = b - (p.count - 1) * 0.5
        end
        local ox, oz = tx + rightX * p.spacing * shift, tz + rightZ * p.spacing * shift
        if ADRouteBuilder.hasBayAlign() then
            -- approach / exit tangent to guide lines: own radius for every bay
            local pb = ADRouteBuilder.computeBayAlign(p, info, localPoints, ox, oz, dirX, dirZ, rightX, rightZ, b)
            localPoints, localConnections, markerLocal, info = ADRouteBuilder.buildBayLocal(pb)
        end
        for _, lp in ipairs(localPoints) do
            local x = ox + rightX * lp[1] + dirX * lp[2]
            local z = oz + rightZ * lp[1] + dirZ * lp[2]
            local y
            if precise then
                y = ADRouteBuilder.getHeight(x, z)
            else
                y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
            end
            table.insert(route.points, {x, y, z})
        end
        for _, c in ipairs(localConnections) do
            table.insert(route.connections, {c[1] + offset, c[2] + offset, c[3]})
        end
        local name = p.name
        if p.startNumber ~= nil then
            name = string.format("%s %d", p.name, p.startNumber + b)
        end
        table.insert(route.markers, {markerLocal + offset, name})
        local function off(i)
            return i ~= nil and i + offset or nil
        end
        approachStarts[b] = off(info.approachStart)
        exitEnds[b] = off(info.exitEnd)
        table.insert(route.preview, {
            target = off(info.target), approachStart = off(info.approachStart), exitEnd = off(info.exitEnd),
            pointE = off(info.pointE), name = name
        })
    end

    -- collector roads (only with more than one bay)
    if p.count > 1 then
        local function collect(list, ascending)
            local first, last, step = 0, p.count - 1, 1
            if not ascending then
                first, last, step = p.count - 1, 0, -1
            end
            local prev = nil
            for b = first, last, step do
                if list[b] ~= nil then
                    if prev ~= nil then
                        table.insert(route.connections, {prev, list[b], ADRouteBuilder.CON_FORWARD})
                    end
                    prev = list[b]
                end
            end
        end
        -- vehicles enter the approach curve moving towards -side, leave the exit curve moving towards +side
        if p.approachSide ~= 0 then
            collect(approachStarts, p.approachSide * p.spacing < 0)
        end
        if p.exitSide ~= 0 then
            collect(exitEnds, p.exitSide * p.spacing > 0)
        end
    end
    return route
end

function ADRouteBuilder.getHeight(x, z)
    if AutoDrive ~= nil and AutoDrive.getTerrainHeightAtWorldPos ~= nil then
        local ok, y = pcall(AutoDrive.getTerrainHeightAtWorldPos, AutoDrive, x, z)
        if ok and y ~= nil then
            return y
        end
    end
    return getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
end

-------------------------------------------------------------------------------------------------
-- creating the route in the AutoDrive graph (runs on server and every client)
-------------------------------------------------------------------------------------------------

function ADRouteBuilder.applyRoute(route)
    if not ADRouteBuilder.resolveAutoDrive() then
        Logging.warning("[AD Route Builder] AutoDrive not loaded")
        return
    end
    local base = ADGraphManager:getWayPointsCount()
    for i, p in ipairs(route.points) do
        local flags = route.flags ~= nil and route.flags[i] or 0
        if flags == 0 then
            flags = AutoDrive.FLAG_NONE or 0
        end
        ADGraphManager:createWayPointWithConnections(p[1], p[2], p[3], {}, {}, flags, false, false, false, 0, false)
    end
    local function node(i)
        if i < 0 then
            -- existing AutoDrive waypoint (e.g. start of a branch snapped with Num0)
            return ADGraphManager:getWayPointById(-i)
        end
        return ADGraphManager:getWayPointById(base + i)
    end
    for _, c in ipairs(route.connections) do
        local a, b, t = node(c[1]), node(c[2]), c[3]
        if a ~= nil and b ~= nil then
            if t == ADRouteBuilder.CON_FORWARD_AND_REVERSE_BACK then
                ADGraphManager:setConnectionBetween(a, b, ADRouteBuilder.CON_FORWARD, false)
                -- add the reverse connection b -> a (b.out only, a.incoming stays without b)
                if not table.contains(b.out, a.id) then
                    table.insert(b.out, a.id)
                end
            else
                ADGraphManager:setConnectionBetween(a, b, t, false)
            end
        end
    end
    for _, m in ipairs(route.markers) do
        ADGraphManager:createMapMarker(base + m[1], m[2], false)
    end
    ADGraphManager:markChanges()
    if #route.points > 0 then
        table.insert(ADRouteBuilder.buildStack, {first = base + 1, last = base + #route.points})
    end
    Logging.info("[AD Route Builder] route created: waypoints %d to %d, %d targets", base + 1, base + #route.points, #route.markers)
end

function ADRouteBuilder.undoLast()
    -- the global key and the key handler of the builder can both fire for the same key press
    if ADRouteBuilder.lastUndoTime ~= nil and g_time - ADRouteBuilder.lastUndoTime < 300 then
        return
    end
    ADRouteBuilder.lastUndoTime = g_time
    if ADRouteBuilder.lastActionWasMove and ADRouteBuilder.undoLastMove ~= nil and ADRouteBuilder.undoLastMove() then
        return
    end
    local lb = ADRouteBuilder.buildStack[#ADRouteBuilder.buildStack]
    if not ADRouteBuilder.resolveAutoDrive() or lb == nil or ADGraphManager:getWayPointsCount() ~= lb.last then
        g_currentMission:showBlinkingWarning(getText("adrb_undoNotPossible", "undo not possible"), 4000)
        return
    end
    local ids = {}
    for id = lb.last, lb.first, -1 do
        table.insert(ids, id)
    end
    AutoDriveDeleteWayPointsEvent.sendEvent(ids)
    table.remove(ADRouteBuilder.buildStack)
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, getText("adrb_undone", "removed"))
end

-------------------------------------------------------------------------------------------------
-- placement mode
-------------------------------------------------------------------------------------------------

function ADRouteBuilder.startPlacing(params, keepView)
    ADRouteBuilder.params = params
    ADRouteBuilder.isPlacing = true
    ADRouteBuilder.posLocked = false
    ADRouteBuilder.lastArc = nil
    ADRouteBuilder.alignList = {}
    ADRouteBuilder.alignPending = nil
    ADRouteBuilder.bayAlign = {}
    ADRouteBuilder.lineStart = nil
    ADRouteBuilder.copyData = nil
    ADRouteBuilder.typeMenu = false
    if params.buildType == "B" and #ADRouteBuilder.guides >= 2 then
        -- fine moving with the numpad goes along line 1
        ADRouteBuilder.rotation = ADRouteBuilder.guides[#ADRouteBuilder.guides - 1].rot
    end
    ADRouteBuilder.mouseX, ADRouteBuilder.mouseY = 0.5, 0.5
    ADRouteBuilder.editMode = false
    ADRouteBuilder.syncAdEditor()
    ADRouteBuilder.cursorWasShown = g_inputBinding:getShowMouseCursor()
    g_inputBinding:setShowMouseCursor(true)
    -- start rotation: the last used one (also stored in the settings file), otherwise the camera direction
    if ADRouteBuilder.savedRotation ~= nil then
        ADRouteBuilder.rotation = ADRouteBuilder.savedRotation
    else
        local cam = getCamera()
        if cam ~= nil and cam ~= 0 then
            local dx, _, dz = localDirectionToWorld(cam, 0, 0, 1)
            ADRouteBuilder.rotation = math.atan2(dx, dz)
        end
    end
    ADRouteBuilder.previewRoute = nil
    -- placing starts in the top view (Num+ switches it off); keepView = the caller decides
    if not keepView then
        ADRouteBuilder.enterTopView(true)
    end
end

-------------------------------------------------------------------------------------------------
-- top view (camera from above like in the construction menu), Num+ = on / off
-- Uses the game's own GuiTopDownCamera in an own input context, so the vehicle / player does not
-- move while the camera is moved with W A S D.
-------------------------------------------------------------------------------------------------
ADRouteBuilder.TOPVIEW_CONTEXT = "ADRB_TOPVIEW"

--- position and view direction of the player: the vehicle if one is driven, otherwise the active camera
function ADRouteBuilder.getPlayerView()
    local x, z, heading
    pcall(function()
        local cam = getCamera()
        if cam ~= nil and cam ~= 0 then
            local cx, _, cz = getWorldTranslation(cam)
            x, z = cx, cz
            local dx, _, dz = localDirectionToWorld(cam, 0, 0, -1)
            if math.abs(dx) + math.abs(dz) > 0.001 then
                heading = math.atan2(dx, dz)
            end
        end
        local vehicle = g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil and g_localPlayer:getCurrentVehicle() or nil
        if vehicle ~= nil and vehicle.rootNode ~= nil then
            local vx, _, vz = getWorldTranslation(vehicle.rootNode)
            x, z = vx, vz
        end
    end)
    return x, z, heading
end

--- turns the top view camera so that it looks in direction "heading" (works for every rotation
--- convention of the camera: the real view direction of the camera node is measured and corrected)
function ADRouteBuilder.setTopViewHeading(cam, heading)
    if heading == nil or cam.camera == nil or cam.cameraRotY == nil then
        return
    end
    for _ = 1, 2 do
        cam.cameraRotY = cam.cameraRotY or 0
        cam:updatePosition()
        local dx, _, dz = localDirectionToWorld(cam.camera, 0, 0, -1)
        if math.abs(dx) + math.abs(dz) < 0.001 then
            return
        end
        local diff = heading - math.atan2(dx, dz)
        cam.cameraRotY = cam.cameraRotY + diff
        cam.targetRotation = cam.cameraRotY
    end
    cam:updatePosition()
end

function ADRouteBuilder.centerTopView()
    if not ADRouteBuilder.topView or ADRouteBuilder.topCamera == nil then
        ADRouteBuilder.enterTopView(true)
        return
    end
    local cam = ADRouteBuilder.topCamera
    local x, z, heading = ADRouteBuilder.getPlayerView()
    if x ~= nil then
        pcall(function()
            cam:setCameraPosition(x, z)
        end)
    end
    pcall(ADRouteBuilder.setTopViewHeading, cam, heading)
end

function ADRouteBuilder.enterTopView(atPlayer)
    if ADRouteBuilder.topView or GuiTopDownCamera == nil then
        return
    end
    local ok, err = pcall(function()
        if ADRouteBuilder.topCamera == nil then
            ADRouteBuilder.topCamera = GuiTopDownCamera.new()
        end
        local cam = ADRouteBuilder.topCamera
        cam:setTerrainRootNode(g_terrainNode or g_currentMission.terrainRootNode)
        g_inputBinding:setContext(ADRouteBuilder.TOPVIEW_CONTEXT, true, false)
        ADRouteBuilder.topViewContext = true
        cam:activate()
        -- start: above the tractor / the person, looking in their view direction;
        -- switched on again while placing (Num+): above the place where you are building
        local x, z = ADRouteBuilder.lastX, ADRouteBuilder.lastZ
        local px, pz, heading = ADRouteBuilder.getPlayerView()
        if atPlayer or x == nil then
            x, z = px, pz
        else
            heading = nil
        end
        if x ~= nil then
            cam:setCameraPosition(x, z)
        end
        pcall(ADRouteBuilder.setTopViewHeading, cam, heading)
        g_inputBinding:setShowMouseCursor(true)
        ADRouteBuilder.topView = true
        ADRouteBuilder.isLooking = false
    end)
    if not ok then
        Logging.warning("[AD Route Builder] top view not possible: %s", tostring(err))
        ADRouteBuilder.exitTopView()
    end
end

function ADRouteBuilder.exitTopView()
    local cam = ADRouteBuilder.topCamera
    if ADRouteBuilder.topView and cam ~= nil then
        pcall(cam.deactivate, cam)
    end
    if ADRouteBuilder.topViewContext then
        pcall(function()
            g_inputBinding:revertContext(true)
        end)
        ADRouteBuilder.topViewContext = false
    end
    if ADRouteBuilder.topView then
        ADRouteBuilder.topView = false
        if ADRouteBuilder.isPlacing then
            g_inputBinding:setShowMouseCursor(true)
        end
    end
end

--- AutoDrive network around a point, drawn by the route builder itself (also on foot)
ADRouteBuilder.NETWORK_RADIUS = 120
function ADRouteBuilder.isNetworkShown()
    if ADRouteBuilder.showNetwork ~= nil then
        return ADRouteBuilder.showNetwork
    end
    -- default: on foot and in the top view yes, in a vehicle AutoDrive shows its own network
    local inVehicle = g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil and g_localPlayer:getCurrentVehicle() ~= nil
    return ADRouteBuilder.topView or not inVehicle
end

function ADRouteBuilder.drawNetwork(cx, cz)
    if cx == nil or not ADRouteBuilder.resolveAutoDrive() then
        return
    end
    local wps = ADGraphManager:getWayPoints()
    local r = ADRouteBuilder.NETWORK_RADIUS
    local r2 = r * r
    local function near(wp)
        local dx, dz = wp.x - cx, wp.z - cz
        return dx * dx + dz * dz < r2
    end
    local subPrio = AutoDrive.FLAG_SUBPRIO or 1
    for _, wp in pairs(wps) do
        if near(wp) then
            local y1 = wp.y + 0.35
            local isSub = bit32.band(wp.flags or 0, subPrio) > 0
            for _, outId in ipairs(wp.out or {}) do
                local other = wps[outId]
                if other ~= nil then
                    local dual = table.contains(other.out or {}, wp.id) and table.contains(wp.incoming or {}, other.id)
                    local reverse = not table.contains(other.incoming or {}, wp.id)
                    if not dual or wp.id < other.id then
                        local cr, cg, cb = 0, 1, 0
                        if reverse then
                            cr, cg, cb = 0, 0.57, 0.84
                        elseif dual then
                            cr, cg, cb = 0, 0, 1
                        end
                        if isSub then
                            cr, cg, cb = 1, 0.53, 0.14
                            if dual then
                                cr, cg, cb = 0.39, 0.18, 0
                            end
                        end
                        local a, b = {wp.x, wp.y, wp.z}, {other.x, other.y, other.z}
                        DebugUtil.drawDebugLine(wp.x, y1, wp.z, other.x, other.y + 0.35, other.z, cr, cg, cb)
                        if not dual then
                            ADRouteBuilder.drawArrow(a, b, cr, cg, cb)
                        end
                    end
                end
            end
            DebugUtil.drawDebugLine(wp.x, wp.y + 0.1, wp.z, wp.x, wp.y + 0.6, wp.z, 1, 0.2, 0.2)
        end
    end
    if Utils.renderTextAtWorldPosition ~= nil then
        local size = getCorrectTextSize ~= nil and getCorrectTextSize(0.014) or 0.014
        for _, marker in pairs(ADGraphManager:getMapMarkers()) do
            local wp = wps[marker.id]
            if wp ~= nil and near(wp) then
                Utils.renderTextAtWorldPosition(wp.x, wp.y + 2.2, wp.z, marker.name, size, 0)
            end
        end
    end
end

function ADRouteBuilder.stopPlacing()
    if ADRouteBuilder.isPlacing then
        -- also keep the rotation (and guide length) when placing was cancelled
        ADRouteBuilder.savedRotation = ADRouteBuilder.rotation
        pcall(ADRouteBuilder.saveSettings)
    end
    ADRouteBuilder.exitTopView()
    ADRouteBuilder.editMode = false
    ADRouteBuilder.isLooking = false
    ADRouteBuilder.isPlacing = false
    ADRouteBuilder.syncAdEditor()
    ADRouteBuilder.previewRoute = nil
    if not ADRouteBuilder.cursorWasShown then
        g_inputBinding:setShowMouseCursor(false)
    end
end

--- Terrain point under the mouse cursor (ray march along the camera ray).
function ADRouteBuilder.getMouseTerrainPos()
    local mx, my = ADRouteBuilder.mouseX, ADRouteBuilder.mouseY
    if mx == nil then
        return nil
    end
    local x1, y1, z1 = unProject(mx, my, 0)
    local x2, y2, z2 = unProject(mx, my, 1)
    if x1 == nil or x2 == nil then
        return nil
    end
    local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
    local len = MathUtil.vector3Length(dx, dy, dz)
    if len < 0.001 then
        return nil
    end
    dx, dy, dz = dx / len, dy / len, dz / len
    local maxDist = math.min(len, 600)
    local step = 1.0
    local prevT = 0
    local t = step
    while t <= maxDist do
        local x, y, z = x1 + dx * t, y1 + dy * t, z1 + dz * t
        local h = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
        if y <= h then
            -- refine between prevT and t
            local lo, hi = prevT, t
            for _ = 1, 12 do
                local mid = (lo + hi) * 0.5
                local mxp, myp, mzp = x1 + dx * mid, y1 + dy * mid, z1 + dz * mid
                local mh = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, mxp, 0, mzp)
                if myp <= mh then
                    hi = mid
                else
                    lo = mid
                end
            end
            return x1 + dx * hi, z1 + dz * hi
        end
        prevT = t
        step = math.min(5, step * 1.05)
        t = t + step
    end
    return nil
end

function ADRouteBuilder.build()
    if ADRouteBuilder.previewRoute == nil or ADRouteBuilder.lastX == nil or ADRouteBuilder.params.buildType == "M" then
        return
    end
    if ADRouteBuilder.params.buildType == "L" then
        -- guide line / cross: only local, nothing is created in AutoDrive
        local newGuide = {x = ADRouteBuilder.lastX, z = ADRouteBuilder.lastZ,
            rot = ADRouteBuilder.rotation, length = ADRouteBuilder.guideLength}
        table.insert(ADRouteBuilder.guides, newGuide)
        -- the next line is measured against this one (distance display, LAlt + wheel)
        ADRouteBuilder.parallelRef = {x = ADRouteBuilder.lastX, z = ADRouteBuilder.lastZ, rot = ADRouteBuilder.rotation, guide = newGuide}
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
            string.format(getText("adrb_guideSet", "guide set (%d)"), #ADRouteBuilder.guides))
        -- stay in placing mode: the next guide can be set right away
        ADRouteBuilder.posLocked = false
        ADRouteBuilder.savedRotation = ADRouteBuilder.rotation
        ADRouteBuilder.saveSettings()
        return
    end
    if ADRouteBuilder.params.buildType == "G" then
        if #ADRouteBuilder.guides == 0 then
            g_currentMission:showBlinkingWarning(getText("adrb_lineNeedGuide", "set a guide line first"), 3000)
            return
        end
        if ADRouteBuilder.lineStart == nil then
            local snap = ADRouteBuilder.lineSnap
            if snap == nil then
                g_currentMission:showBlinkingWarning(getText("adrb_lineTooFar", "click closer to a guide line"), 3000)
                return
            end
            -- 1st click: remember the start, nothing is built yet
            ADRouteBuilder.lineStart = {x = ADRouteBuilder.lastX, z = ADRouteBuilder.lastZ, target = snap.target}
            return
        end
        if ADRouteBuilder.previewRoute.noBuild then
            return
        end
    end
    -- final heights with AutoDrive's raycast (also hits silo floors, roads, ...)
    if ADRouteBuilder.params.buildType == "S" and ADRouteBuilder.hasBayAlign() and ADRouteBuilder.bayAlignFail ~= nil
        and (ADRouteBuilder.bayAlignFail.approach or ADRouteBuilder.bayAlignFail.exit) then
        g_currentMission:showBlinkingWarning(getText("adrb_bayAlignNoBuild", "a curve does not fit its guide line - nothing built"), 3000)
        return
    end
    if #ADRouteBuilder.alignList > 0 and ADRouteBuilder.align == nil
        and (ADRouteBuilder.params.buildType == "Y" or ADRouteBuilder.params.buildType == "Z") then
        g_currentMission:showBlinkingWarning(getText("adrb_alignNone", "no fitting guide line"), 3000)
        return
    end
    local ep, ex, ez = ADRouteBuilder.getEffective()
    local route = ADRouteBuilder.buildRouteWorld(ep, ex, ez, ADRouteBuilder.rotation, true)
    local anchor = ADRouteBuilder.anchor
    if anchor ~= nil and anchor.id ~= nil and route.branchStart ~= nil
        and (ADRouteBuilder.params.buildType == "Y" or ADRouteBuilder.params.buildType == "Z") then
        route = ADRouteBuilder.mergeIntoWayPoint(route, route.branchStart, anchor.id)
    end
    local sendRoute = {points = route.points, connections = route.connections, markers = route.markers}
    local btSub = ADRouteBuilder.params.buildType
    if ADRouteBuilder.isSubRoute() and (btSub == "K" or btSub == "B" or btSub == "G") then
        -- sub route (curve, arc, straight line): AutoDrive's flag on every new point (LAlt + Num,)
        local sub = AutoDrive ~= nil and AutoDrive.FLAG_SUBPRIO or 1
        sendRoute.flags = {}
        for i = 1, #route.points do
            sendRoute.flags[i] = sub
        end
    end
    ADRBRouteEvent.sendEvent(sendRoute)
    ADRouteBuilder.lastActionWasMove = false
    ADRouteBuilder.savedRotation = ADRouteBuilder.rotation
    ADRouteBuilder.saveSettings()
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format(getText("adrb_built", "built %d %d"), #route.points, #route.markers))
    -- stay in placing mode; with bays the numbering continues
    local p = ADRouteBuilder.params
    if p.buildType == "S" and p.startNumber ~= nil then
        p.startNumber = p.startNumber + p.count
        ADRouteBuilder.values.startNumber = tostring(p.startNumber)
        ADRouteBuilder.saveSettings()
    end
    ADRouteBuilder.posLocked = false
    ADRouteBuilder.anchor = nil
    ADRouteBuilder.lineStart = nil
end

--- replaces the point "index" of a route by an existing AutoDrive waypoint: the point is not created,
--- its connections go to the waypoint (negative index in the route = waypoint id)
function ADRouteBuilder.mergeIntoWayPoint(route, index, wayPointId)
    local newPoints, map = {}, {}
    for i, p in ipairs(route.points) do
        if i ~= index then
            table.insert(newPoints, p)
            map[i] = #newPoints
        end
    end
    map[index] = -wayPointId
    local newConnections = {}
    for _, c in ipairs(route.connections) do
        table.insert(newConnections, {map[c[1]], map[c[2]], c[3]})
    end
    local newMarkers = {}
    for _, m in ipairs(route.markers or {}) do
        if map[m[1]] ~= nil and map[m[1]] > 0 then
            table.insert(newMarkers, {map[m[1]], m[2]})
        end
    end
    return {points = newPoints, connections = newConnections, markers = newMarkers}
end

--- cycles the connection type of curve and arc: forward -> both ways -> reverse
function ADRouteBuilder.cycleConnection()
    local p = ADRouteBuilder.params
    if p == nil then
        return
    end
    if p.buildType == "Y" or p.buildType == "Z" then
        if p.branchConnection == ADRouteBuilder.CON_DUAL then
            p.branchConnection = ADRouteBuilder.CON_FORWARD
            ADRouteBuilder.values.branchConnection = "V"
        else
            p.branchConnection = ADRouteBuilder.CON_DUAL
            ADRouteBuilder.values.branchConnection = "B"
        end
        return
    end
    local order = {ADRouteBuilder.CON_FORWARD, ADRouteBuilder.CON_DUAL, ADRouteBuilder.CON_REVERSE}
    local letters = {[ADRouteBuilder.CON_FORWARD] = "V", [ADRouteBuilder.CON_DUAL] = "B", [ADRouteBuilder.CON_REVERSE] = "R"}
    local field = p.buildType == "G" and "lineConnection" or "curveConnection"
    local current = 1
    for i, c in ipairs(order) do
        if c == p[field] then
            current = i
        end
    end
    p[field] = order[current % #order + 1]
    ADRouteBuilder.values[field] = letters[p[field]]
end

function ADRouteBuilder.isSubRoute()
    return ADRouteBuilder.values.subRoute == "1"
end

function ADRouteBuilder.toggleSubRoute()
    ADRouteBuilder.values.subRoute = ADRouteBuilder.isSubRoute() and "0" or "1"
    pcall(ADRouteBuilder.saveSettings)
end

function ADRouteBuilder.getConnectionText(p)
    local keys = {[ADRouteBuilder.CON_FORWARD] = "adrb_conForward", [ADRouteBuilder.CON_DUAL] = "adrb_conDual", [ADRouteBuilder.CON_REVERSE] = "adrb_conReverse"}
    local con = p.curveConnection
    if p.buildType == "Y" or p.buildType == "Z" then
        con = p.branchConnection
    elseif p.buildType == "G" then
        con = p.lineConnection
    end
    local text = getText(keys[con] or "adrb_conForward", "connection")
    if p.buildType == "K" or p.buildType == "B" or p.buildType == "G" then
        text = text .. ", " .. getText(ADRouteBuilder.isSubRoute() and "adrb_subRoute" or "adrb_mainRoute", "route")
    end
    return text
end

--- switches the build type while placing (Num1)
function ADRouteBuilder.switchBuildType(buildType)
    local values = {}
    for k, v in pairs(ADRouteBuilder.values) do
        values[k] = v
    end
    values.buildType = buildType
    local params, err = ADRouteBuilder.getParams(values)
    if params == nil then
        g_currentMission:showBlinkingWarning(string.format(getText("adrb_invalid", "invalid: %s"), err), 3000)
        return
    end
    ADRouteBuilder.values = values
    ADRouteBuilder.params = params
    ADRouteBuilder.posLocked = false
    ADRouteBuilder.lastArc = nil
    ADRouteBuilder.lineStart = nil
    ADRouteBuilder.copyData = nil
    if buildType == "B" and #ADRouteBuilder.guides >= 2 then
        ADRouteBuilder.rotation = ADRouteBuilder.guides[#ADRouteBuilder.guides - 1].rot
    end
end

--- starts placing directly with the last values (without the dialog)
function ADRouteBuilder.quickPlace()
    if not ADRouteBuilder.resolveAutoDrive() then
        g_currentMission:showBlinkingWarning(getText("adrb_noAD", "AutoDrive missing"), 3000)
        return
    end
    if ADRouteBuilder.isPlacing then
        return
    end
    local params, err = ADRouteBuilder.getParams(ADRouteBuilder.values)
    if params == nil then
        ADRouteBuilder.openDialog()
        return
    end
    ADRouteBuilder.startPlacing(params)
end

local function drawLine(a, b, r, g, bl)
    DebugUtil.drawDebugLine(a[1], a[2] + 0.4, a[3], b[1], b[2] + 0.4, b[3], r, g, bl)
end

local function drawCross(p, size, r, g, b)
    DebugUtil.drawDebugLine(p[1] - size, p[2] + 0.4, p[3], p[1] + size, p[2] + 0.4, p[3], r, g, b)
    DebugUtil.drawDebugLine(p[1], p[2] + 0.4, p[3] - size, p[1], p[2] + 0.4, p[3] + size, r, g, b)
    DebugUtil.drawDebugLine(p[1], p[2] + 0.1, p[3], p[1], p[2] + 1.0, p[3], r, g, b)
end

local function terrainY(x, z)
    return getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + 0.3
end

function ADRouteBuilder.drawHelpers(route)
    if route.helpers ~= nil then
        ADRouteBuilder.drawLines(route.helpers)
    end
end

function ADRouteBuilder.drawLines(lines)
    for _, h in ipairs(lines) do
        local x1, z1, x2, z2, kind = h[1], h[2], h[3], h[4], h[5]
        local guideColors = {guideCross = {0.6, 0.6, 0.6}}
        local gc = guideColors[kind]
        local mainColor = ADRouteBuilder.GUIDE_COLORS[kind]
        if mainColor ~= nil then
            -- main guide line: one solid, dark line
            local len = MathUtil.vector2Length(x2 - x1, z2 - z1)
            if len > 0.01 then
                local dx, dz = (x2 - x1) / len, (z2 - z1) / len
                local px, pz = -dz, dx
                local t = 0
                while t < len do
                    local t2 = math.min(len, t + 2)
                    local ax, az, bx, bz = x1 + dx * t, z1 + dz * t, x1 + dx * t2, z1 + dz * t2
                    local ay, by = terrainY(ax, az), terrainY(bx, bz)
                    DebugUtil.drawDebugLine(ax, ay, az, bx, by, bz, mainColor[1], mainColor[2], mainColor[3])
                    t = t2
                end
            end
        elseif gc ~= nil then
            -- dashed guide line (1.5 m line, 1 m gap)
            local len = MathUtil.vector2Length(x2 - x1, z2 - z1)
            if len > 0.01 then
                local dx, dz = (x2 - x1) / len, (z2 - z1) / len
                local t = 0
                while t < len do
                    local t2 = math.min(len, t + 1.5)
                    local ax, az, bx, bz = x1 + dx * t, z1 + dz * t, x1 + dx * t2, z1 + dz * t2
                    DebugUtil.drawDebugLine(ax, terrainY(ax, az), az, bx, terrainY(bx, bz), bz, gc[1], gc[2], gc[3])
                    t = t + 2.5
                end
            end
        elseif kind == "guideCentre" then
            DebugUtil.drawDebugLine(x1, terrainY(x1, z1), z1, x2, terrainY(x2, z2), z2, 1, 1, 0)
        elseif kind == "axis" then
            -- dashed: 2 m line, 1 m gap
            local len = MathUtil.vector2Length(x2 - x1, z2 - z1)
            if len > 0.01 then
                local dx, dz = (x2 - x1) / len, (z2 - z1) / len
                local t = 0
                while t < len do
                    local t2 = math.min(len, t + 2)
                    local ax, az, bx, bz = x1 + dx * t, z1 + dz * t, x1 + dx * t2, z1 + dz * t2
                    DebugUtil.drawDebugLine(ax, terrainY(ax, az), az, bx, terrainY(bx, bz), bz, 0.9, 0.9, 0.9)
                    t = t + 3
                end
            end
        elseif kind == "circle" then
            DebugUtil.drawDebugLine(x1, terrainY(x1, z1), z1, x2, terrainY(x2, z2), z2, 0.55, 0.55, 0.55)
        else
            DebugUtil.drawDebugLine(x1, terrainY(x1, z1), z1, x2, terrainY(x2, z2), z2, 1, 0.85, 0.2)
        end
    end
end

--- arrow head on the connection a -> b (at the given fraction of the way, default the middle)
function ADRouteBuilder.drawArrow(a, b, r, g, bl, at)
    local f = at or 0.5
    local dx, dz = b[1] - a[1], b[3] - a[3]
    local len = MathUtil.vector2Length(dx, dz)
    if len < 0.05 then
        return
    end
    dx, dz = dx / len, dz / len
    local size = math.min(0.8, len * 0.35)
    local tipX, tipZ = a[1] + (b[1] - a[1]) * (f + 0.15), a[3] + (b[3] - a[3]) * (f + 0.15)
    local tipY = a[2] + (b[2] - a[2]) * (f + 0.15) + 0.4
    local px, pz = -dz, dx
    for _, side in ipairs({1, -1}) do
        local ex = tipX - dx * size + px * size * 0.6 * side
        local ez = tipZ - dz * size + pz * size * 0.6 * side
        DebugUtil.drawDebugLine(tipX, tipY, tipZ, ex, tipY, ez, r, g, bl)
    end
end

function ADRouteBuilder.drawPreview(route)
    if ADRouteBuilder.showHelpers or route.isGuide then
        ADRouteBuilder.drawHelpers(route)
    end
    for _, c in ipairs(route.connections) do
        local a, b = route.points[c[1]], route.points[c[2]]
        if a ~= nil and b ~= nil then
            if c[3] == ADRouteBuilder.CON_REVERSE then
                drawLine(a, b, 0, 0.57, 0.84)
                ADRouteBuilder.drawArrow(a, b, 0, 0.57, 0.84)
            elseif c[3] == ADRouteBuilder.CON_DUAL then
                drawLine(a, b, 0, 0, 1)
                ADRouteBuilder.drawArrow(a, b, 0, 0, 1, 0.35)
                ADRouteBuilder.drawArrow(b, a, 0, 0, 1, 0.35)
            elseif c[3] == ADRouteBuilder.CON_FORWARD_AND_REVERSE_BACK then
                drawLine(a, b, 0, 0, 1)
                ADRouteBuilder.drawArrow(a, b, 0, 1, 0, 0.35)
                ADRouteBuilder.drawArrow(b, a, 0, 0.57, 0.84, 0.35)
            else
                drawLine(a, b, 0, 1, 0)
                ADRouteBuilder.drawArrow(a, b, 0, 1, 0)
            end
        end
    end
    for _, p in ipairs(route.points) do
        drawCross(p, 0.25, 1, 0, 0)
    end
    if route.startIndex ~= nil then
        drawCross(route.points[route.startIndex], 0.8, 1, 1, 0)
    end
    for _, c in ipairs(route.extraCrosses or {}) do
        if route.points[c[1]] ~= nil then
            drawCross(route.points[c[1]], 0.6, c[2], c[3], c[4])
        end
    end
    for _, pv in ipairs(route.preview) do
        local t = route.points[pv.target]
        drawCross(t, 0.8, 1, 1, 0)
        if Utils.renderTextAtWorldPosition ~= nil then
            Utils.renderTextAtWorldPosition(t[1], t[2] + 2.0, t[3], pv.name, getCorrectTextSize(0.016), 0)
        end
        drawCross(route.points[pv.pointE], 0.6, 0, 1, 1)
        if pv.approachStart ~= nil then
            drawCross(route.points[pv.approachStart], 0.6, 0, 1, 0)
        end
        if pv.exitEnd ~= nil then
            drawCross(route.points[pv.exitEnd], 0.6, 1, 0.5, 0)
        end
    end
end

-------------------------------------------------------------------------------------------------
-- mod event listener
-------------------------------------------------------------------------------------------------

function ADRouteBuilder:loadMap(name)
    ADRouteBuilder.resolveAutoDrive()
    ADRouteBuilder.loadSettings()
    ADRouteBuilder.gui = nil
end

--- dialog closed with "back": continue placing as before
function ADRouteBuilder.resumePlacing()
    local r = ADRouteBuilder.resume
    ADRouteBuilder.resume = nil
    if r ~= nil and r.params ~= nil then
        ADRouteBuilder.startPlacing(r.params, true)
        if r.topView then
            ADRouteBuilder.enterTopView()
        end
    end
end

--- dialog closed with "place": the new values are used, the top view comes back if it was on
function ADRouteBuilder.afterDialogStart()
    local r = ADRouteBuilder.resume
    ADRouteBuilder.resume = nil
    if r ~= nil and r.topView then
        ADRouteBuilder.enterTopView()
    end
end

--- LCtrl + LAlt + B: not building yet = start with the guide line (no dialog),
--- while building = settings of the build type in use
function ADRouteBuilder.openOrStart()
    if not ADRouteBuilder.resolveAutoDrive() then
        g_currentMission:showBlinkingWarning(getText("adrb_noAD", "AutoDrive missing"), 3000)
        return
    end
    if ADRouteBuilder.isPlacing or g_gui:getIsGuiVisible() then
        ADRouteBuilder.openDialog()
        return
    end
    local values = {}
    for k, v in pairs(ADRouteBuilder.values) do
        values[k] = v
    end
    values.buildType = "L"
    local params = ADRouteBuilder.getParams(values)
    if params == nil then
        -- a saved value is invalid: show the dialog so that it can be corrected
        ADRouteBuilder.openDialog()
        return
    end
    ADRouteBuilder.values = values
    ADRouteBuilder.startPlacing(params)
end

function ADRouteBuilder.openDialog()
    if not ADRouteBuilder.resolveAutoDrive() then
        g_currentMission:showBlinkingWarning(getText("adrb_noAD", "AutoDrive missing"), 3000)
        return
    end
    if ADRouteBuilder.isPlacing then
        -- remember where we were: after the dialog the placing goes on (also in the top view)
        ADRouteBuilder.resume = {params = ADRouteBuilder.params, topView = ADRouteBuilder.topView}
        ADRouteBuilder.stopPlacing()
    else
        ADRouteBuilder.resume = nil
    end
    if ADRouteBuilder.gui == nil then
        ADRouteBuilder.gui = ADRouteBuilderGui.new()
        g_gui:loadGui(ADRouteBuilder.MOD_DIR .. "gui/routeBuilderGUI.xml", "ADRouteBuilderGui", ADRouteBuilder.gui)
    end
    g_gui:showDialog("ADRouteBuilderGui")
end

function ADRouteBuilder:update(dt)
    if not ADRouteBuilder.isPlacing then
        return
    end
    if g_gui:getIsGuiVisible() then
        return
    end
    if ADRouteBuilder.topView and ADRouteBuilder.topCamera ~= nil then
        ADRouteBuilder.topCamera:update(dt)
    end
    local p = ADRouteBuilder.params
    if ADRouteBuilder.anchor ~= nil and (not ADRouteBuilder.posLocked or p == nil or (p.buildType ~= "Y" and p.buildType ~= "Z")) then
        ADRouteBuilder.anchor = nil
    end
    if ADRouteBuilder.anchor ~= nil then
        -- branch start fixed on an AD point: the branch turns around it
        -- (merge: the end of the outgoing line is fixed, the merge point lies behind it)
        local a = ADRouteBuilder.anchor
        local sign = p.buildType == "Z" and -1 or 1
        ADRouteBuilder.lastX = a.x + math.sin(ADRouteBuilder.rotation) * p.branchIn * sign
        ADRouteBuilder.lastZ = a.z + math.cos(ADRouteBuilder.rotation) * p.branchIn * sign
    elseif not ADRouteBuilder.posLocked then
        -- branch / merge: while LCtrl or LAlt is held the position stays, so that a side or a guide line
        -- can be clicked (aligning, removing a branch) and the wheel changes radius / points in place
        local _, ctrlHeld, altHeld = ADRouteBuilder.getModifiers()
        local hold = (ctrlHeld or altHeld) and p ~= nil and (p.buildType == "Y" or p.buildType == "Z" or p.buildType == "S")
            and ADRouteBuilder.lastX ~= nil
        local x, z = ADRouteBuilder.getMouseTerrainPos()
        if x ~= nil and not hold then
            ADRouteBuilder.lastX, ADRouteBuilder.lastZ = x, z
        end
    end
    ADRouteBuilder.lineSnap = nil
    if p ~= nil and p.buildType == "G" and not ADRouteBuilder.editMode and ADRouteBuilder.lastX ~= nil then
        -- straight line on a guide: the position is put onto the nearest guide line (after the start:
        -- onto the guide of the start)
        local guideIndex = ADRouteBuilder.lineStart ~= nil and ADRouteBuilder.lineStart.target or nil
        local pr = ADRouteBuilder.projectOnGuide(ADRouteBuilder.lastX, ADRouteBuilder.lastZ, guideIndex, true)
        if pr ~= nil and (guideIndex ~= nil or pr.d <= ADRouteBuilder.GUIDE_SNAP_DISTANCE) then
            ADRouteBuilder.lineSnap = pr
            ADRouteBuilder.lastX, ADRouteBuilder.lastZ = pr.x, pr.z
        end
    end
    ADRouteBuilder.align = nil
    if #ADRouteBuilder.alignList > 0 and p ~= nil and (p.buildType == "Y" or p.buildType == "Z") and ADRouteBuilder.lastX ~= nil
        and not ADRouteBuilder.editMode then
        ADRouteBuilder.align = ADRouteBuilder.computeTangentAlign(p, ADRouteBuilder.lastX, ADRouteBuilder.lastZ,
            ADRouteBuilder.rotation, ADRouteBuilder.anchor ~= nil and ADRouteBuilder.anchor.id ~= nil,
            ADRouteBuilder.alignList)
    end
    if ADRouteBuilder.editMode then
        ADRouteBuilder.previewRoute = nil
    elseif p ~= nil and p.buildType == "M" then
        ADRouteBuilder.previewRoute = nil
        if ADRouteBuilder.selectUpdate ~= nil then
            ADRouteBuilder.selectUpdate()
        end
    elseif ADRouteBuilder.lastX ~= nil then
        local ep, ex, ez = ADRouteBuilder.getEffective()
        ADRouteBuilder.previewRoute = ADRouteBuilder.buildRouteWorld(ep, ex, ez, ADRouteBuilder.rotation)
    end
end

--- While building, AutoDrive's own mouse editor is set to "show only" so that clicks do not select or
--- create AD points at the same time; in "edit AutoDrive" and after closing, its mode comes back.
function ADRouteBuilder.syncAdEditor()
    if not ADRouteBuilder.resolveAutoDrive() or AutoDrive.getEditorMode == nil or AutoDrive.setEditorMode == nil then
        return
    end
    local ok, err = pcall(function()
        local current = AutoDrive.getEditorMode()
        local building = ADRouteBuilder.isPlacing and not ADRouteBuilder.editMode
        if building then
            if current == AutoDrive.EDITOR_ON or current == AutoDrive.EDITOR_EXTENDED then
                ADRouteBuilder.adEditorSaved = current
                AutoDrive.setEditorMode(AutoDrive.EDITOR_SHOW)
            end
        elseif ADRouteBuilder.adEditorSaved ~= nil then
            if current == AutoDrive.EDITOR_SHOW then
                AutoDrive.setEditorMode(ADRouteBuilder.adEditorSaved)
            end
            ADRouteBuilder.adEditorSaved = nil
        end
    end)
    if not ok then
        Logging.warning("[AD Route Builder] switching the AD editor: %s", tostring(err))
    end
end

--- switches between building and editing the AutoDrive network (the route builder stays open,
--- the top view stays as it is, mouse and wheel are left to AutoDrive)
function ADRouteBuilder.setEditMode(active)
    ADRouteBuilder.editMode = active == true
    if ADRouteBuilder.editMode then
        -- the build type menu belongs to building
        ADRouteBuilder.typeMenu = false
    end
    ADRouteBuilder.previewRoute = nil
    ADRouteBuilder.stopLooking()
    if ADRouteBuilder.editMode then
        ADRouteBuilder.anchor = nil
        ADRouteBuilder.posLocked = false
        -- AutoDrive only reacts to the mouse while the cursor is shown and its HUD is on
        pcall(function()
            if ADRouteBuilder.resolveAutoDrive() and AutoDrive.getSetting ~= nil and not AutoDrive.getSetting("showHUD")
                and AutoDrive.Hud ~= nil and AutoDrive.Hud.toggleHud ~= nil then
                AutoDrive.Hud:toggleHud(AutoDrive.getADFocusVehicle ~= nil and AutoDrive.getADFocusVehicle() or nil)
            end
        end)
        g_inputBinding:setShowMouseCursor(true)
    end
    ADRouteBuilder.syncAdEditor()
end

--- small diagnostics for the help panel: last key, AD point under the mouse, visible points
function ADRouteBuilder.getDiagnostics(t)
    local lines = {}
    local k = ADRouteBuilder.lastKey
    if k ~= nil and g_time - (k.time or 0) < 4000 then
        local ch = (k.unicode ~= nil and k.unicode > 32 and k.unicode < 127) and string.char(k.unicode) or "-"
        table.insert(lines, string.format(t.diagKey, tostring(k.sym), ch))
    end
    if ADRouteBuilder.editMode and ADRouteBuilder.resolveAutoDrive() and AutoDrive.getADFocusVehicle ~= nil then
        local vehicle = AutoDrive.getADFocusVehicle()
        if vehicle ~= nil and vehicle.ad ~= nil then
            local h = vehicle.ad.hoveredNodeId
            table.insert(lines, h ~= nil and string.format(t.diagHover, h) or t.diagNoHover)
        end
    end
    if not ADRouteBuilder.editMode and ADRouteBuilder.params ~= nil and ADRouteBuilder.params.buildType == "M" and ADRouteBuilder.countVisiblePoints ~= nil then
        if ADRouteBuilder.visibleCountTime == nil or g_time - ADRouteBuilder.visibleCountTime > 500 then
            ADRouteBuilder.visibleCountTime = g_time
            ADRouteBuilder.visibleCount = ADRouteBuilder.countVisiblePoints()
        end
        table.insert(lines, string.format(t.diagVisible, ADRouteBuilder.visibleCount or 0))
    end
    return lines
end

--- state of AutoDrive's editor for the help panel
function ADRouteBuilder.getAdEditState(t)
    local lines = {}
    if not ADRouteBuilder.resolveAutoDrive() then
        return lines
    end
    local vehicle = AutoDrive.getADFocusVehicle ~= nil and AutoDrive.getADFocusVehicle() or nil
    if vehicle == nil then
        table.insert(lines, {t.adNoVehicle, "warn"})
    else
        table.insert(lines, {string.format(t.adVehicle, vehicle.getFullName ~= nil and vehicle:getFullName() or "?"), "ok"})
    end
    local mode = AutoDrive.getEditorMode ~= nil and AutoDrive.getEditorMode() or nil
    local names = {[AutoDrive.EDITOR_OFF or 1] = t.adModeOff, [AutoDrive.EDITOR_ON or 2] = t.adModeOn,
        [AutoDrive.EDITOR_EXTENDED or 3] = t.adModeExt, [AutoDrive.EDITOR_SHOW or 4] = t.adModeShow}
    local okMode = mode == AutoDrive.EDITOR_EXTENDED
    table.insert(lines, {string.format(t.adMode, names[mode] or tostring(mode)) .. (okMode and "" or ("  -  " .. t.adModeHint)), okMode and "ok" or "warn"})
    if AutoDrive.getSetting ~= nil then
        local hud = AutoDrive.getSetting("showHUD")
        table.insert(lines, {hud and t.adHudOn or t.adHudOff, hud and "ok" or "warn"})
    end
    if vehicle ~= nil and AutoDrive.drawDistance ~= nil then
        table.insert(lines, {string.format(t.adRange, AutoDrive.drawDistance), "key"})
    end
    return lines
end

-------------------------------------------------------------------------------------------------
-- on-screen panel while placing: current values and the keys of the build type (Num- = on/off)
-------------------------------------------------------------------------------------------------
ADRouteBuilder.showPanel = true
local PANEL_KEYS = {
    de = {
        S = {
            "Kurven größer / kleiner\tLStrg + Mausrad (fein: + LUmschalt)",
            "Mehr / weniger Punkte in den Kurven\tLAlt + Mausrad",
            "Buchten automatisch ins Fahrsilo setzen\tMaus ins Silo (nahe der Einfahrt), dann Num9",
            "Maus an der ersten Bucht / in der Mitte\tNum3",
            "Zu- oder Abfahrt an Hilfslinie anlegen\tLStrg + Linksklick auf die Kurve, dann auf die Linie",
            "Anlegen an Hilfslinie aufheben\tLStrg + Num0",
            "Zu- oder Abfahrt auf die andere Seite\tLAlt + Linksklick auf die Kurve"},
        K = {
            "Kurve größer / kleiner\tLStrg + Mausrad (fein: + LUmschalt)",
            "Mehr / weniger Punkte\tLAlt + Mausrad",
            "Einbahn / beidseitig / rückwärts\tNum,",
            "Fahrtrichtung umdrehen\tLStrg + Num, (oder Num3)",
            "Haupt- / Nebenstrecke\tLAlt + Num,"},
        B = {
            "Ecke und Größe wählen\tMaus bewegen",
            "Bogen größer / kleiner\tLStrg + Mausrad",
            "Mehr / weniger Punkte\tLAlt + Mausrad",
            "Einbahn / beidseitig / rückwärts\tNum,",
            "Fahrtrichtung umdrehen\tLStrg + Num, (oder Num3)",
            "Haupt- / Nebenstrecke\tLAlt + Num,"},
        L = {
            "Hilfslinie setzen\tLinksklick",
            "Linie länger / kürzer\tLStrg + Mausrad (fein: + LUmschalt)",
            "Linie parallel verschieben\tLAlt + Mausrad (LAlt nochmal drücken: 1 m / 0,5 m / 0,1 m / 0,01 m)",
            "Parallel zu Linie, Silowand oder Gebäude\tLStrg + Linksklick daran",
            "Linie bei der Maus löschen\tEntf (zurückholen: LUmschalt + Entf)",
            "Alle Hilfslinien löschen\tLStrg + LAlt + L"},
        M = {
            "Punkte auswählen\tLinke Maustaste gedrückt halten und Kasten ziehen",
            "Mehr Punkte dazu / Punkte abwählen\tKasten mit LUmschalt / mit LStrg",
            "Einen Punkt auswählen\tLinksklick auf den Punkt (+ LUmschalt = dazu / weg)",
            "Auswahl aufheben\tNum0",
            "Auswahl verschieben\tAusgewählten Punkt mit der linken Maustaste ziehen",
            "Fein verschieben\tNum8/2/4/6 (0,1 m, mit LStrg 0,01 m)",
            "Nur entlang / quer zur Hilfslinie schieben\tNum3",
            "Auswahl gerade auf die Hilfslinie legen\tNum7 (Num9: dazu gleichmäßig verteilen)",
            "Einbahn / beidseitig / rückwärts\tNum,",
            "Fahrtrichtung umdrehen\tLStrg + Num,",
            "Haupt- / Nebenstrecke\tLAlt + Num,",
            "Punkte einer Kurve ändern\tKurve wählen, LAlt + Mausrad, dann Linksklick (Num0 = abbrechen)",
            "Gerade zwischen zwei Punkten\t2 Punkte wählen, Num/, dann Linksklick",
            "AD-Ziel setzen / umbenennen / löschen\t1 Punkt wählen, Num5",
            "Auswahl kopieren\tLStrg + C, Linksklick fügt ein, LUmschalt + Mausrad dreht, Num0 = fertig",
            "Auswahl löschen\tEntf, dann nochmal Entf (nicht rückgängig!)",
            "Baukasten beenden\tEnde"},
        G = {
            "Start setzen\t1. Linksklick nahe der Hilfslinie",
            "Ende setzen und bauen\t2. Linksklick",
            "Abstand der Punkte\tLAlt + Mausrad",
            "Einbahn / beidseitig / rückwärts\tNum,",
            "Fahrtrichtung umdrehen\tLStrg + Num,",
            "Haupt- / Nebenstrecke\tLAlt + Num,",
            "Start verwerfen\tNum0",
            "Zurück zur vorigen Bauart\tLAlt + Num1"},
        Z = {
            "Wo die Strecken zusammenkommen\tMaus (Richtung: drehen)",
            "Kurven größer / kleiner\tLStrg + Mausrad",
            "Mehr / weniger Punkte\tLAlt + Mausrad",
            "Einbahn / beidseitig\tNum,",
            "An einen AD-Punkt anschließen\tNum0 (das Ende kommt auf den AD-Punkt)",
            "Seite an Hilfslinie anlegen\tLStrg + Linksklick (oder Maustaste %d) auf die Seite, dann auf die Linie",
            "Anlegen an Hilfslinie aufheben\tLStrg + Num0",
            "Eine Seite weglassen / zurückholen\tLAlt + Linksklick auf die Seite"},
        Y = {
            "Kurven größer / kleiner\tLStrg + Mausrad",
            "Mehr / weniger Punkte\tLAlt + Mausrad",
            "Einbahn / beidseitig\tNum,",
            "An einen AD-Punkt anschließen\tNum0 (der Start kommt auf den AD-Punkt)",
            "Abzweig an Hilfslinie anlegen\tLStrg + Linksklick (oder Maustaste %d) auf den Abzweig, dann auf die Linie",
            "Anlegen an Hilfslinie aufheben\tLStrg + Num0",
            "Einen Abzweig weglassen / zurückholen\tLAlt + Linksklick auf die Seite"},
        common = {
            "Bauen / beenden\tLinksklick / Ende",
            "Drehen\tLUmschalt + Mausrad oder , / . (fein: LUmschalt + LAlt + Mausrad)",
            "Fein verschieben / festhalten\tNum8/2/4/6 (mit LStrg 0,01 m) / Num5",
            "An einen AD-Punkt setzen\tNum0",
            "Andere Bauart\tNum1, dann Zahl oder Klick",
            "Draufsicht an / aus\tNum+ (zurück zu dir / zum Fahrzeug: LStrg + Num+)",
            "Draufsicht bewegen / drehen\tW A S D / Leertaste halten + Maus ziehen",
            "Kamera zoomen / umsehen\tMausrad / mittlere Maustaste oder Num/",
            "AutoDrive-Netz zeigen\tNum*",
            "Selbst mit AutoDrive bearbeiten\tkurzer Rechtsklick oder Num Enter",
            "Letzte Strecke rückgängig\tLStrg + LAlt + Z",
            "Einstellungen der Bauart\tLStrg + LAlt + B",
            "Hilfe / Hilfskreise ein / aus\tNum- / H"},
        title = "Strecken-Baukasten", values = "Aktuell", keys = "Hilfe", head = "Was du machen willst  -  so geht's",
        editTitle = "AutoDrive bearbeiten (Bauen pausiert)",
        edit = {
            "Maus und Tasten gehören jetzt AutoDrive (Bauen ist pausiert).",
            "Mit der Maus bearbeiten (Modus 'erweitert')\tNum/",
            "Zurück zum Bauen\tNum Enter (mit Bauart-Menü: Num1)",
            "Baukasten beenden\tEnde",
            "Draufsicht an / aus\tNum+ (zurück zu dir / zum Fahrzeug: LStrg + Num+)",
            "Draufsicht drehen\tLeertaste halten + Maus ziehen (Pos1: ohne Leertaste)",
            "AutoDrive-Netz / Hilfe\tNum* / Num-"},
        adNoVehicle = "Kein AD-Fahrzeug: AutoDrive bearbeitet nur, wenn du in einem Fahrzeug sitzt!",
        adVehicle = "AD-Fahrzeug: %s",
        adMode = "AD-Editor: %s", adModeHint = "für Maus-Bearbeitung 'erweitert' nötig (Num/)",
        adModeOff = "aus", adModeOn = "an", adModeExt = "erweitert", adModeShow = "nur anzeigen",
        adRange = "AutoDrive bearbeitet nur Punkte bis ca. %d m um das Fahrzeug",
        adHudOn = "AD-HUD: eingeblendet", adHudOff = "AD-HUD: ausgeblendet - ohne HUD bearbeitet AutoDrive nichts (LAlt + Num0 außerhalb der Draufsicht)",
        diagKey = "Letzte Taste: %s (Zeichen %s)", diagHover = "AutoDrive: Punkt %d unter der Maus",
        diagNoHover = "AutoDrive: kein Punkt unter der Maus", diagVisible = "AD-Punkte im Bild: %d",
    },
    en = {
        S = {
            "Curves bigger / smaller\tLCtrl + wheel (fine: + LShift)",
            "More / fewer points in the curves\tLAlt + wheel",
            "Put the bays into a bunker silo\tmouse into the silo (near the entrance), then Num9",
            "Mouse at the first bay / in the middle\tNum3",
            "Approach or exit along a guide line\tLCtrl + left click on the curve, then on the line",
            "Undo the guide line fit\tLCtrl + Num0",
            "Approach or exit to the other side\tLAlt + left click on the curve"},
        K = {
            "Curve bigger / smaller\tLCtrl + wheel (fine: + LShift)",
            "More / fewer points\tLAlt + wheel",
            "One-way / both ways / reverse\tNum,",
            "Turn the driving direction\tLCtrl + Num, (or Num3)",
            "Main / sub route\tLAlt + Num,"},
        B = {
            "Choose corner and size\tmove the mouse",
            "Arc bigger / smaller\tLCtrl + wheel",
            "More / fewer points\tLAlt + wheel",
            "One-way / both ways / reverse\tNum,",
            "Turn the driving direction\tLCtrl + Num, (or Num3)",
            "Main / sub route\tLAlt + Num,"},
        L = {
            "Set a guide line\tleft click",
            "Line longer / shorter\tLCtrl + wheel (fine: + LShift)",
            "Move the line sideways\tLAlt + wheel (press LAlt again: 1 m / 0.5 m / 0.1 m / 0.01 m)",
            "Parallel to a line, silo wall or building\tLCtrl + left click on it",
            "Delete the line near the mouse\tDel (bring it back: LShift + Del)",
            "Delete all guide lines\tLCtrl + LAlt + L"},
        M = {
            "Select points\thold the left mouse button and drag a box",
            "Add points / deselect points\tbox with LShift / with LCtrl",
            "Select one point\tleft click on the point (+ LShift = add / remove)",
            "Clear the selection\tNum0",
            "Move the selection\tdrag a selected point with the left mouse button",
            "Fine move\tNum8/2/4/6 (0.1 m, with LCtrl 0.01 m)",
            "Move only along / across the guide line\tNum3",
            "Put the selection straight on the guide line\tNum7 (Num9: and spread evenly)",
            "One-way / both ways / reverse\tNum,",
            "Turn the driving direction\tLCtrl + Num,",
            "Main / sub route\tLAlt + Num,",
            "Change the points of a curve\tselect the curve, LAlt + wheel, then left click (Num0 = cancel)",
            "Straight line between two points\tselect 2 points, Num/, then left click",
            "Set / rename / delete an AD target\tselect 1 point, Num5",
            "Copy the selection\tLCtrl + C, left click pastes, LShift + wheel rotates, Num0 = done",
            "Delete the selection\tDel, then Del again (no undo!)",
            "Close the builder\tEnd"},
        G = {
            "Set the start\t1st left click near the guide line",
            "Set the end and build\t2nd left click",
            "Spacing of the points\tLAlt + wheel",
            "One-way / both ways / reverse\tNum,",
            "Turn the driving direction\tLCtrl + Num,",
            "Main / sub route\tLAlt + Num,",
            "Discard the start\tNum0",
            "Back to the type before\tLAlt + Num1"},
        Z = {
            "Where the routes meet\tmouse (direction: rotate)",
            "Curves bigger / smaller\tLCtrl + wheel",
            "More / fewer points\tLAlt + wheel",
            "One-way / both ways\tNum,",
            "Connect to an AD point\tNum0 (the end goes onto the AD point)",
            "Side along a guide line\tLCtrl + left click (or mouse button %d) on the side, then on the line",
            "Undo the guide line fit\tLCtrl + Num0",
            "Leave out a side / bring it back\tLAlt + left click on the side"},
        Y = {
            "Curves bigger / smaller\tLCtrl + wheel",
            "More / fewer points\tLAlt + wheel",
            "One-way / both ways\tNum,",
            "Connect to an AD point\tNum0 (the start goes onto the AD point)",
            "Branch along a guide line\tLCtrl + left click (or mouse button %d) on the branch, then on the line",
            "Undo the guide line fit\tLCtrl + Num0",
            "Leave out a branch / bring it back\tLAlt + left click on the side"},
        common = {
            "Build / finish\tleft click / End",
            "Rotate\tLShift + wheel or , / . (fine: LShift + LAlt + wheel)",
            "Fine move / lock position\tNum8/2/4/6 (with LCtrl 0.01 m) / Num5",
            "Put onto an AD point\tNum0",
            "Other build type\tNum1, then number or click",
            "Top view on / off\tNum+ (back to you / the vehicle: LCtrl + Num+)",
            "Move / rotate the top view\tW A S D / hold Space + drag the mouse",
            "Camera zoom / look around\twheel / middle mouse button or Num/",
            "Show the AutoDrive network\tNum*",
            "Edit with AutoDrive yourself\tshort right click or Num Enter",
            "Undo the last route\tLCtrl + LAlt + Z",
            "Settings of the build type\tLCtrl + LAlt + B",
            "Help / helper circles on / off\tNum- / H"},
        title = "Route Builder", values = "Current", keys = "help", head = "What you want to do  -  how",
        editTitle = "edit AutoDrive (building paused)",
        edit = {
            "Mouse and keys now belong to AutoDrive (building is paused).",
            "Edit with the mouse (mode 'extended')\tNum/",
            "Back to building\tNum Enter (with build type menu: Num1)",
            "Close the route builder\tEnd",
            "Top view on / off\tNum+ (back to you / the vehicle: LCtrl + Num+)",
            "Rotate the top view\thold Space + drag the mouse (Home: without Space)",
            "AutoDrive network / help\tNum* / Num-"},
        adNoVehicle = "No AD vehicle: AutoDrive only edits while you sit in a vehicle!",
        adVehicle = "AD vehicle: %s",
        adMode = "AD editor: %s", adModeHint = "mouse editing needs 'extended' (Num/)",
        adModeOff = "off", adModeOn = "on", adModeExt = "extended", adModeShow = "show only",
        adRange = "AutoDrive only edits points up to about %d m around the vehicle",
        adHudOn = "AD HUD: shown", adHudOff = "AD HUD: hidden - without the HUD AutoDrive edits nothing (LAlt + Num0 outside the top view)",
        diagKey = "Last key: %s (character %s)", diagHover = "AutoDrive: point %d under the mouse",
        diagNoHover = "AutoDrive: no point under the mouse", diagVisible = "AD points on screen: %d",
    }
}

function ADRouteBuilder.drawPanel()
    local p = ADRouteBuilder.params
    if p == nil then
        return
    end
    local t = (g_languageShort == "de") and PANEL_KEYS.de or PANEL_KEYS.en
    local size = 0.0125
    local lineH = size * 1.35
    local lines = {}
    local function add(text, kind)
        -- "what\thow": two columns, the function left, the keys right
        local what, how = string.match(text, "^(.-)\t(.*)$")
        if what ~= nil then
            table.insert(lines, {text = what, how = how, kind = kind})
        else
            table.insert(lines, {text = text, kind = kind})
        end
    end
    if ADRouteBuilder.editMode then
        add(t.title .. ": " .. t.editTitle, "title")
        if ADRouteBuilder.showPanel then
            for _, l in ipairs(ADRouteBuilder.getAdEditState(t)) do
                add("  " .. l[1], l[2])
            end
            for _, l in ipairs(ADRouteBuilder.getDiagnostics(t)) do
                add("  " .. l, "common")
            end
            add("", "space")
            add(t.head, "head")
            for _, l in ipairs(t.edit) do
                add("  " .. l, "key")
            end
        else
            add("Num-: " .. t.keys, "key")
        end
    else
        add(t.title .. ": " .. getText(ADRouteBuilder.BUILD_TYPE_TEXTS[p.buildType] .. "Long", p.buildType), "title")
    end
    if ADRouteBuilder.editMode then
        -- nothing more
    elseif not ADRouteBuilder.showPanel then
        add("Num-: " .. t.keys, "key")
    else
        local live = ADRouteBuilder.getLiveInfo()
        local first = true
        for part in string.gmatch(live .. " - ", "(.-) %- ") do
            if not first and part ~= "" then
                add("  " .. part, "value")
            end
            first = false
        end
        for _, l in ipairs(ADRouteBuilder.getDiagnostics(t)) do
            add("  " .. l, "common")
        end
        add("", "space")
        add(t.head, "head")
        for _, l in ipairs(t[p.buildType] or {}) do
            if string.find(l, "%%d") ~= nil then
                l = string.format(l, ADRouteBuilder.getAlignButton())
            end
            add("  " .. l, "key")
        end
        add("", "space")
        for _, l in ipairs(t.common) do
            -- the select tool uses Num0, Num5, Num/, the left click and Num8/2/4/6 itself (see its own lines)
            local skip = p.buildType == "M" and (string.find(l, "Num0", 1, true) or string.find(l, "Num5", 1, true)
                or string.find(l, "Num/", 1, true) or string.find(l, "Num8", 1, true)
                or string.find(l, "Bauen /", 1, true) or string.find(l, "Build /", 1, true))
            if not skip then
                add("  " .. l, "common")
            end
        end
    end
    -- size of the panel
    local colX = 0
    for _, l in ipairs(lines) do
        if l.how ~= nil then
            colX = math.max(colX, getTextWidth(size, l.text))
        end
    end
    colX = colX + size * 1.5
    local width = 0
    for _, l in ipairs(lines) do
        if l.how ~= nil then
            width = math.max(width, colX + getTextWidth(size, l.how))
        else
            width = math.max(width, getTextWidth(size, l.text))
        end
    end
    local pad = 0.008
    local x = 0.012
    local top = 0.80
    local height = #lines * lineH + pad * 2
    drawFilledRect(x - pad, top - height + pad, width + pad * 2, height, 0, 0, 0, 0.65)
    setTextAlignment(RenderText.ALIGN_LEFT)
    local y = top - lineH
    for _, l in ipairs(lines) do
        if l.kind == "title" then
            setTextBold(true)
            setTextColor(0.6, 0.85, 0.15, 1)
        elseif l.kind == "head" then
            setTextBold(true)
            setTextColor(1, 1, 1, 1)
        elseif l.kind == "warn" then
            setTextBold(true)
            setTextColor(1, 0.45, 0.35, 1)
        elseif l.kind == "ok" then
            setTextBold(false)
            setTextColor(0.5, 1, 0.5, 1)
        elseif l.kind == "value" then
            setTextBold(false)
            setTextColor(1, 0.9, 0.35, 1)
        elseif l.kind == "common" then
            setTextBold(false)
            setTextColor(0.75, 0.75, 0.75, 1)
        else
            setTextBold(false)
            setTextColor(1, 1, 1, 1)
        end
        if l.text ~= "" then
            renderText(x, y, size, l.text)
        end
        if l.how ~= nil then
            -- the keys in light blue (a bit dimmer for the general lines)
            setTextBold(false)
            if l.kind == "common" then
                setTextColor(0.55, 0.72, 0.85, 1)
            else
                setTextColor(0.55, 0.85, 1, 1)
            end
            renderText(x + colX, y, size, l.how)
        end
        y = y - lineH
    end
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end

-------------------------------------------------------------------------------------------------
-- build type menu (Num1): all types with a number, choose with the number key (top row or numpad)
-- or a left click, Esc closes it
-------------------------------------------------------------------------------------------------
function ADRouteBuilder.openTypeMenu(open)
    ADRouteBuilder.typeMenu = open
    ADRouteBuilder.typeMenuRects = nil
end

function ADRouteBuilder.chooseType(index)
    local bt = ADRouteBuilder.BUILD_TYPES[index]
    ADRouteBuilder.openTypeMenu(false)
    if bt ~= nil and ADRouteBuilder.params ~= nil and bt ~= ADRouteBuilder.params.buildType then
        ADRouteBuilder.switchBuildType(bt)
    end
end

function ADRouteBuilder.drawTypeMenu()
    local size = 0.016
    local lineH = size * 1.6
    local pad = 0.008
    local entries = {}
    local width = getTextWidth(size, getText("adrb_typeMenuTitle", "Build type"))
    for i, bt in ipairs(ADRouteBuilder.BUILD_TYPES) do
        local text = string.format("%d   %s", i, getText(ADRouteBuilder.BUILD_TYPE_TEXTS[bt] .. "Long", bt))
        entries[i] = text
        width = math.max(width, getTextWidth(size, text))
    end
    local hint = getText("adrb_typeMenuHint", "number key or click = choose, Esc = close")
    width = math.max(width, getTextWidth(size * 0.8, hint))
    local height = (#entries + 2) * lineH + pad * 2
    local x = 0.5 - width * 0.5 - pad
    local top = 0.5 + height * 0.5
    drawFilledRect(x, top - height, width + pad * 2, height, 0, 0, 0, 0.8)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(0.6, 0.85, 0.15, 1)
    local y = top - pad - lineH + lineH * 0.25
    renderText(x + pad, y, size, getText("adrb_typeMenuTitle", "Build type"))
    local rects = {}
    for i, text in ipairs(entries) do
        y = y - lineH
        local current = ADRouteBuilder.params ~= nil and ADRouteBuilder.BUILD_TYPES[i] == ADRouteBuilder.params.buildType
        local hover = ADRouteBuilder.mouseX ~= nil and ADRouteBuilder.mouseX >= x and ADRouteBuilder.mouseX <= x + width + pad * 2
            and ADRouteBuilder.mouseY >= y - lineH * 0.25 and ADRouteBuilder.mouseY < y + lineH * 0.75
        if hover then
            drawFilledRect(x, y - lineH * 0.25, width + pad * 2, lineH, 0.6, 0.85, 0.15, 0.25)
        end
        setTextBold(current)
        if current then
            setTextColor(1, 0.9, 0.35, 1)
        else
            setTextColor(1, 1, 1, 1)
        end
        renderText(x + pad, y, size, text)
        rects[i] = {x1 = x, x2 = x + width + pad * 2, y1 = y - lineH * 0.25, y2 = y + lineH * 0.75}
    end
    y = y - lineH
    setTextBold(false)
    setTextColor(0.75, 0.75, 0.75, 1)
    renderText(x + pad, y, size * 0.8, hint)
    setTextColor(1, 1, 1, 1)
    ADRouteBuilder.typeMenuRects = rects
end

function ADRouteBuilder:draw()
    if g_gui:getIsGuiVisible() then
        return
    end
    if ADRouteBuilder.isPlacing and ADRouteBuilder.isNetworkShown() then
        local okN, errN = pcall(ADRouteBuilder.drawNetwork, ADRouteBuilder.lastX, ADRouteBuilder.lastZ)
        if not okN and not ADRouteBuilder.networkErrorShown then
            ADRouteBuilder.networkErrorShown = true
            Logging.warning("[AD Route Builder] network display: %s", tostring(errN))
        end
    end
    if ADRouteBuilder.isPlacing and not ADRouteBuilder.editMode and ADRouteBuilder.params ~= nil and ADRouteBuilder.params.buildType == "M"
        and ADRouteBuilder.selectDraw ~= nil then
        local okS, errS = pcall(ADRouteBuilder.selectDraw)
        if not okS and not ADRouteBuilder.selectErrorShown then
            ADRouteBuilder.selectErrorShown = true
            Logging.warning("[AD Route Builder] selection display: %s", tostring(errS))
        end
    end
    if ADRouteBuilder.isPlacing and ADRouteBuilder.typeMenu then
        local okM, errM = pcall(ADRouteBuilder.drawTypeMenu)
        if not okM and not ADRouteBuilder.menuErrorShown then
            ADRouteBuilder.menuErrorShown = true
            Logging.warning("[AD Route Builder] type menu: %s", tostring(errM))
        end
    end
    if ADRouteBuilder.isPlacing then
        local ok, err = pcall(ADRouteBuilder.drawPanel)
        if not ok and not ADRouteBuilder.panelErrorShown then
            ADRouteBuilder.panelErrorShown = true
            Logging.warning("[AD Route Builder] help panel: %s", tostring(err))
        end
    end
    if #ADRouteBuilder.guides > 0 then
        local n = #ADRouteBuilder.guides
        for i, guide in ipairs(ADRouteBuilder.guides) do
            -- main lines of the last two guides are the lines used for the arc (B): 1 = orange, 2 = cyan
            local kind = "guide"
            if n >= 2 and i == n - 1 then
                kind = "guideArc1"
            elseif n >= 2 and i == n then
                kind = "guideArc2"
            end
            ADRouteBuilder.drawLines(ADRouteBuilder.getGuideLines(guide, kind))
            local c = ADRouteBuilder.GUIDE_COLORS[kind] or ADRouteBuilder.GUIDE_COLORS.guide
            ADRouteBuilder.drawGuideScale(guide, false, c[1], c[2], c[3])
        end
    end
    if ADRouteBuilder.isPlacing and not ADRouteBuilder.editMode and ADRouteBuilder.params ~= nil and ADRouteBuilder.params.buildType == "L" and ADRouteBuilder.lastX ~= nil then
        ADRouteBuilder.drawGuideScale({x = ADRouteBuilder.lastX, z = ADRouteBuilder.lastZ, rot = ADRouteBuilder.rotation,
            length = ADRouteBuilder.guideLength}, true, 0.1, 0.1, 0.1)
        -- distance to the line it is parallel to: yellow measuring line with the value
        local dist, fx, fz = ADRouteBuilder.getParallelDistance()
        if dist ~= nil and dist > 0.01 then
            local y1 = terrainY(ADRouteBuilder.lastX, ADRouteBuilder.lastZ) + 0.3
            local y2 = terrainY(fx, fz) + 0.3
            DebugUtil.drawDebugLine(ADRouteBuilder.lastX, y1, ADRouteBuilder.lastZ, fx, y2, fz, 1, 0.85, 0)
            if Utils.renderTextAtWorldPosition ~= nil then
                Utils.renderTextAtWorldPosition((ADRouteBuilder.lastX + fx) * 0.5, (y1 + y2) * 0.5 + 0.8, (ADRouteBuilder.lastZ + fz) * 0.5,
                    string.format("%.2f m", dist), getCorrectTextSize(0.016), 0)
            end
        end
    end
    if ADRouteBuilder.isPlacing and ADRouteBuilder.previewRoute ~= nil then
        ADRouteBuilder.drawPreview(ADRouteBuilder.previewRoute)
    end
end

-------------------------------------------------------------------------------------------------
-- guide lines (cross: line in the set direction + perpendicular line), local for this player only
-------------------------------------------------------------------------------------------------

function ADRouteBuilder.getGuideLines(guide, mainKind)
    local dirX, dirZ = math.sin(guide.rot), math.cos(guide.rot)
    local rightX, rightZ = dirZ, -dirX
    local L = guide.length
    local q = L * 0.5
    return {
        {guide.x - dirX * L, guide.z - dirZ * L, guide.x + dirX * L, guide.z + dirZ * L, mainKind or "guide"},
        {guide.x - rightX * q, guide.z - rightZ * q, guide.x + rightX * q, guide.z + rightZ * q, "guideCross"},
        {guide.x - dirX * 1.5, guide.z - dirZ * 1.5, guide.x + dirX * 1.5, guide.z + dirZ * 1.5, "guideCentre"},
        {guide.x - rightX * 1.5, guide.z - rightZ * 1.5, guide.x + rightX * 1.5, guide.z + rightZ * 1.5, "guideCentre"}
    }
end

--- ruler on a guide line: small ticks every metre, medium every 5 m, long ticks with the distance every 10 m,
--- end bars with the length. The ticks stand on the right side of the line like on a ruler.
function ADRouteBuilder.drawGuideScale(guide, withLabels, r, g, b)
    local dirX, dirZ = math.sin(guide.rot), math.cos(guide.rot)
    local rightX, rightZ = dirZ, -dirX
    local L = guide.length
    local labelStep = L <= 100 and 10 or (L <= 250 and 50 or 100)
    local smallStep = L <= 150 and 1 or 5
    local textSize = getCorrectTextSize ~= nil and getCorrectTextSize(0.013) or 0.013
    local function tick(d, length, both)
        local cx, cz = guide.x + dirX * d, guide.z + dirZ * d
        local y = terrainY(cx, cz)
        local sx, sz = both and (cx - rightX * length) or cx, both and (cz - rightZ * length) or cz
        DebugUtil.drawDebugLine(sx, y, sz, cx + rightX * length, y, cz + rightZ * length, r, g, b)
        return cx + rightX * length, y, cz + rightZ * length
    end
    if withLabels and setTextColor ~= nil then
        setTextColor(1, 1, 0.4, 1)
    end
    local d = smallStep
    while d < L - 0.01 do
        local isTen = d % 10 < 0.01
        local isFive = d % 5 < 0.01
        for _, side in ipairs({1, -1}) do
            local length = isTen and 1.2 or (isFive and 0.7 or 0.3)
            local tx, ty, tz = tick(side * d, length, false)
            if withLabels and d % labelStep < 0.01 and Utils.renderTextAtWorldPosition ~= nil then
                Utils.renderTextAtWorldPosition(tx + rightX * 0.6, ty + 0.3, tz + rightZ * 0.6, string.format("%d", d), textSize, 0)
            end
        end
        d = d + smallStep
    end
    -- ends: bar across the line and the length
    for _, side in ipairs({1, -1}) do
        local ex, ey, ez = tick(side * L, 2.0, true)
        if Utils.renderTextAtWorldPosition ~= nil then
            Utils.renderTextAtWorldPosition(ex + rightX * 0.6, ey + 0.5, ez + rightZ * 0.6, string.format("%d m", L), textSize * 1.3, 0)
        end
    end
    -- zero point
    tick(0, 1.5, true)
    if withLabels and Utils.renderTextAtWorldPosition ~= nil then
        local zx, zz = guide.x + rightX * 2.1, guide.z + rightZ * 2.1
        Utils.renderTextAtWorldPosition(zx, terrainY(zx, zz) + 0.3, zz, "0", textSize, 0)
    end
    if setTextColor ~= nil then
        setTextColor(1, 1, 1, 1)
    end
end

function ADRouteBuilder.clearGuides()
    if #ADRouteBuilder.guides > 0 then
        for i, g in ipairs(ADRouteBuilder.guides) do
            table.insert(ADRouteBuilder.removedGuides, {guide = g, index = i})
        end
        ADRouteBuilder.guides = {}
        ADRouteBuilder.lineStart = nil
        ADRouteBuilder.moveGuideIndex = nil
        ADRouteBuilder.alignList = {}
        ADRouteBuilder.alignPending = nil
        ADRouteBuilder.bayAlign = {}
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, getText("adrb_guidesCleared", "guides removed"))
        pcall(ADRouteBuilder.saveSettings)
    end
end

--- removes the guide line nearest the mouse (Del), LShift + Del brings the last removed one back
ADRouteBuilder.removedGuides = {}
function ADRouteBuilder.removeGuideNearMouse()
    local mx, mz = ADRouteBuilder.getMouseTerrainPos()
    if mx == nil then
        mx, mz = ADRouteBuilder.lastX, ADRouteBuilder.lastZ
    end
    local pr = mx ~= nil and ADRouteBuilder.projectOnGuide(mx, mz, nil, true) or nil
    if pr == nil or pr.d > ADRouteBuilder.GUIDE_SNAP_DISTANCE then
        g_currentMission:showBlinkingWarning(getText("adrb_guideNoneNear", "no guide line near the mouse"), 2000)
        return
    end
    local index = pr.index
    table.insert(ADRouteBuilder.removedGuides, {guide = table.remove(ADRouteBuilder.guides, index), index = index})
    -- keep the references to guide lines by number right
    local list = {}
    for _, e in ipairs(ADRouteBuilder.alignList) do
        local t = ADRouteBuilder.targetAfterRemove(e.target, index)
        if t ~= nil then
            table.insert(list, {side = e.side, target = t})
        end
    end
    ADRouteBuilder.alignList = list
    ADRouteBuilder.moveGuideIndex = ADRouteBuilder.targetAfterRemove(ADRouteBuilder.moveGuideIndex, index)
    for _, kind in ipairs({"approach", "exit"}) do
        ADRouteBuilder.bayAlign[kind] = ADRouteBuilder.targetAfterRemove(ADRouteBuilder.bayAlign[kind], index)
    end
    if ADRouteBuilder.lineStart ~= nil then
        ADRouteBuilder.lineStart.target = ADRouteBuilder.targetAfterRemove(ADRouteBuilder.lineStart.target, index)
        if ADRouteBuilder.lineStart.target == nil then
            ADRouteBuilder.lineStart = nil
        end
    end
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format(getText("adrb_guideRemoved", "guide line %d removed (%d left)"), index, #ADRouteBuilder.guides))
    pcall(ADRouteBuilder.saveSettings)
end

function ADRouteBuilder.restoreGuide()
    local last = table.remove(ADRouteBuilder.removedGuides)
    if last == nil then
        return
    end
    local index = math.min(last.index, #ADRouteBuilder.guides + 1)
    table.insert(ADRouteBuilder.guides, index, last.guide)
    for _, e in ipairs(ADRouteBuilder.alignList) do
        e.target = ADRouteBuilder.targetAfterInsert(e.target, index)
    end
    ADRouteBuilder.moveGuideIndex = ADRouteBuilder.targetAfterInsert(ADRouteBuilder.moveGuideIndex, index)
    for _, kind in ipairs({"approach", "exit"}) do
        ADRouteBuilder.bayAlign[kind] = ADRouteBuilder.targetAfterInsert(ADRouteBuilder.bayAlign[kind], index)
    end
    if ADRouteBuilder.lineStart ~= nil then
        ADRouteBuilder.lineStart.target = ADRouteBuilder.targetAfterInsert(ADRouteBuilder.lineStart.target, index)
    end
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format(getText("adrb_guideRestored", "guide line %d back"), index))
    pcall(ADRouteBuilder.saveSettings)
end

--- live changes while placing: free curve (K) or both curves of the bay (S)
local function fmt(n)
    local t = string.format("%.1f", n)
    return (t:gsub("%.0$", ""))
end

function ADRouteBuilder.changeRadius(delta)
    local p = ADRouteBuilder.params
    if p == nil then
        return
    end
    if p.buildType == "L" then
        ADRouteBuilder.guideLength = math.max(5, math.min(500, ADRouteBuilder.guideLength + delta * 10))
    elseif p.buildType == "B" then
        -- change the radius: move the tangent point along line 1
        local a = ADRouteBuilder.lastArc
        if a ~= nil and a.error == nil and ADRouteBuilder.lastX ~= nil then
            local newRadius = math.max(0.5, a.radius + delta)
            local newTangent = newRadius / math.tan(math.rad(a.angle) * 0.5)
            ADRouteBuilder.posLocked = true
            ADRouteBuilder.lastX = a.ix + a.u1x * newTangent + a.offX
            ADRouteBuilder.lastZ = a.iz + a.u1z * newTangent + a.offZ
        end
    elseif p.buildType == "K" then
        p.curveRadius = math.max(1, math.min(300, p.curveRadius + delta))
        ADRouteBuilder.values.curveRadius = fmt(p.curveRadius)
    elseif p.buildType == "Y" or p.buildType == "Z" then
        p.branchLeftRadius = math.max(1, math.min(300, p.branchLeftRadius + delta))
        p.branchRightRadius = math.max(1, math.min(300, p.branchRightRadius + delta))
        ADRouteBuilder.values.branchLeftRadius = fmt(p.branchLeftRadius)
        ADRouteBuilder.values.branchRightRadius = fmt(p.branchRightRadius)
    elseif p.buildType == "S" then
        -- bays: also for a curve aligned to a guide line - there the joining point follows the radius
        p.approachRadius = math.max(1, math.min(200, p.approachRadius + delta))
        p.exitRadius = math.max(1, math.min(200, p.exitRadius + delta))
        ADRouteBuilder.values.approachRadius = fmt(p.approachRadius)
        ADRouteBuilder.values.exitRadius = fmt(p.exitRadius)
    end
end

ADRouteBuilder.GUIDE_SHIFT_STEPS = {1, 0.5, 0.1, 0.01}
function ADRouteBuilder.getGuideShiftStep()
    return ADRouteBuilder.GUIDE_SHIFT_STEPS[ADRouteBuilder.guideShiftIndex or 1] or 1
end

function ADRouteBuilder.changePoints(delta)
    local p = ADRouteBuilder.params
    if p ~= nil and p.buildType == "L" then
        -- guide line: LAlt + wheel moves it sideways (parallel); every new LAlt press: 1 m -> 0.5 m -> 0.1 m -> 0.01 m
        if ADRouteBuilder.lastX ~= nil then
            local step = ADRouteBuilder.getGuideShiftStep()
            local dirX, dirZ = math.sin(ADRouteBuilder.rotation), math.cos(ADRouteBuilder.rotation)
            -- local x points to the left; wheel up = to the right
            local rx, rz = -dirZ, dirX
            if not ADRouteBuilder.posLocked then
                -- first step: start exactly on the line it is parallel to, so the distance goes in clean steps
                local dist, fx, fz = ADRouteBuilder.getParallelDistance()
                if dist ~= nil then
                    ADRouteBuilder.lastX, ADRouteBuilder.lastZ = fx, fz
                end
            end
            ADRouteBuilder.posLocked = true
            ADRouteBuilder.lastX = ADRouteBuilder.lastX + rx * step * delta
            ADRouteBuilder.lastZ = ADRouteBuilder.lastZ + rz * step * delta
        end
        return
    end
    if p == nil then
        return
    end
    if p.buildType == "M" then
        -- select / move: number of points of the selected segment
        if ADRouteBuilder.resampleChange ~= nil and ADRouteBuilder.copyData == nil then
            ADRouteBuilder.resampleChange(delta)
        end
        return
    end
    if p.buildType == "K" or p.buildType == "B" then
        p.curveCount = math.max(1, math.min(100, math.floor(p.curveCount) + delta))
        ADRouteBuilder.values.curveCount = tostring(p.curveCount)
    elseif p.buildType == "G" then
        p.lineSpacing = math.max(0.5, math.min(100, p.lineSpacing - delta * 0.5))
        ADRouteBuilder.values.lineSpacing = fmt(p.lineSpacing)
    elseif p.buildType == "Y" or p.buildType == "Z" then
        p.branchPoints = math.max(1, math.min(60, p.branchPoints + delta))
        ADRouteBuilder.values.branchPoints = tostring(p.branchPoints)
    else
        p.curvePoints = math.max(2, math.min(60, p.curvePoints + delta))
        p.exitPoints = math.max(2, math.min(60, p.exitPoints + delta))
        ADRouteBuilder.values.curvePoints = tostring(p.curvePoints)
        ADRouteBuilder.values.exitPoints = tostring(p.exitPoints)
    end
end

function ADRouteBuilder.getLiveInfo()
    local p = ADRouteBuilder.params
    if p == nil then
        return ""
    end
    local deg = math.deg(ADRouteBuilder.rotation) % 360
    local pos = getText(ADRouteBuilder.BUILD_TYPE_TEXTS[p.buildType] or "adrb_typeS", p.buildType) .. " - " ..
        string.format(getText("adrb_liveAngle", "angle %.2f deg"), deg)
    if ADRouteBuilder.anchor ~= nil then
        if ADRouteBuilder.anchor.id ~= nil then
            pos = pos .. " - " .. string.format(getText("adrb_liveAnchor", "start on AD point %d (gets connected), rotate around it"), ADRouteBuilder.anchor.id)
        else
            pos = pos .. " - " .. getText("adrb_liveAnchorMoved", "start moved away from the AD point (not connected)")
        end
    elseif ADRouteBuilder.posLocked then
        pos = pos .. " - " .. getText("adrb_liveLocked", "position locked")
    end
    return pos .. " - " .. ADRouteBuilder.getLiveInfoValues(p)
end

function ADRouteBuilder.getLiveInfoValues(p)
    if p.buildType == "M" then
        return ADRouteBuilder.selectLiveInfo ~= nil and ADRouteBuilder.selectLiveInfo() or ""
    end
    if p.buildType == "L" then
        local text = string.format(getText("adrb_liveGuide", "guide length %d m"), ADRouteBuilder.guideLength)
            .. " - " .. string.format(getText("adrb_liveGuideShift", "LAlt + wheel moves sideways by %s m"), string.format("%g", ADRouteBuilder.getGuideShiftStep()))
        local dist = ADRouteBuilder.getParallelDistance()
        if dist ~= nil then
            text = text .. " - " .. string.format(getText("adrb_liveParallelDist", "distance to the parallel line %.2f m"), dist)
        end
        local last = ADRouteBuilder.guides[#ADRouteBuilder.guides]
        if last ~= nil then
            local diff = math.deg(ADRouteBuilder.rotation - last.rot) % 180
            text = text .. " - " .. string.format(getText("adrb_liveGuideAngle", "angle to last guide %.2f deg"), diff)
        end
        return text
    end
    if p.buildType == "B" then
        local a = ADRouteBuilder.lastArc
        if a == nil or a.error ~= nil then
            return getText(a ~= nil and a.error or "adrb_arcNeedGuides", "arc not possible")
        end
        local dirText = getText(ADRouteBuilder.arcReverseDir and "adrb_arcDir21" or "adrb_arcDir12", "1 -> 2")
        return string.format(getText("adrb_liveArc", "arc: radius %s m, tangent %s m, angle %.1f deg, %d points"),
            fmt(a.radius), fmt(a.tangent), a.angle, p.curveCount) .. " - " .. ADRouteBuilder.getConnectionText(p) .. " - " .. dirText
    end
    if p.buildType == "G" then
        local text
        local r = ADRouteBuilder.previewRoute
        if #ADRouteBuilder.guides == 0 then
            text = getText("adrb_lineNeedGuide", "set a guide line first")
        elseif ADRouteBuilder.lineStart == nil then
            text = getText(ADRouteBuilder.lineSnap ~= nil and "adrb_lineClickStart" or "adrb_lineTooFar", "click the start")
        elseif r ~= nil and r.lineLength ~= nil then
            text = string.format(getText("adrb_liveLine", "length %.1f m, %d points, spacing %.2f m"), r.lineLength, #r.points, r.lineSpacingUsed)
        else
            text = getText("adrb_lineClickEnd", "click the end")
        end
        return text .. " - " .. string.format(getText("adrb_liveLineMax", "max. %s m"), fmt(p.lineSpacing))
            .. " - " .. ADRouteBuilder.getConnectionText(p)
            .. " - " .. getText(ADRouteBuilder.arcReverseDir and "adrb_curveDirBack" or "adrb_curveDirFwd", "direction")
    end
    local alignText = ""
    if ADRouteBuilder.alignPending ~= nil and (p.buildType == "Y" or p.buildType == "Z") then
        alignText = " - " .. string.format(getText("adrb_alignPickGuide", "%s chosen: now LCtrl + mouse button %d or LCtrl + left click on the guide line (no line there = alignment of this side off)"),
            getText(ADRouteBuilder.alignPending < 0 and "adrb_optLeft" or "adrb_optRight", ""), ADRouteBuilder.getAlignButton())
    elseif #ADRouteBuilder.alignList > 0 and (p.buildType == "Y" or p.buildType == "Z") then
        local a = ADRouteBuilder.align
        if a == nil then
            alignText = " - " .. getText("adrb_alignNone", "no fitting guide line")
        else
            alignText = " - " .. string.format(getText("adrb_liveAlign", "tangent to guide %s: %s %.1f deg"), ADRouteBuilder.getTargetName(a.guide),
                getText(a.side < 0 and "adrb_optLeft" or "adrb_optRight", ""), a.angle)
            if a.second ~= nil then
                alignText = alignText .. string.format(getText("adrb_liveAlign2", ", 2nd guide %s: %s %.1f deg, starts at %.1f m"), ADRouteBuilder.getTargetName(a.secondGuide),
                    getText(a.side < 0 and "adrb_optRight" or "adrb_optLeft", ""), a.second.angle, a.second.at)
            elseif a.secondFailed then
                alignText = alignText .. getText("adrb_alignSecondNone", ", 2nd guide line does not fit the other side")
            end
            if a.params.branchIn ~= p.branchIn then
                alignText = alignText .. string.format(getText(p.buildType == "Z" and "adrb_liveAlignOut" or "adrb_liveAlignIn", " line %.1f m"), a.params.branchIn)
            end
        end
    end
    if p.buildType == "Z" then
        return string.format(getText("adrb_liveBranch", "left %s m, right %s m, %d points"),
            fmt(p.branchLeftRadius), fmt(p.branchRightRadius), p.branchPoints) .. " - " .. ADRouteBuilder.getConnectionText(p) .. alignText
    end
    if p.buildType == "Y" then
        return string.format(getText("adrb_liveBranch", "left %s m, right %s m, %d points"),
            fmt(p.branchLeftRadius), fmt(p.branchRightRadius), p.branchPoints)
            .. " - " .. ADRouteBuilder.getConnectionText(p) .. alignText
    end
    if p.buildType == "K" then
        local dirText = getText(ADRouteBuilder.arcReverseDir and "adrb_curveDirBack" or "adrb_curveDirFwd", "direction")
        return string.format(getText("adrb_liveCurve", "radius %s m, points %d"), fmt(p.curveRadius), p.curveCount)
            .. " - " .. ADRouteBuilder.getConnectionText(p) .. " - " .. dirText
    end
    return string.format(getText("adrb_liveBay", "approach %s m / %d, exit %s m / %d"),
        fmt(p.approachRadius), p.curvePoints, fmt(p.exitRadius), p.exitPoints) .. " - "
        .. getText(ADRouteBuilder.values.bayAnchor == "M" and "adrb_bayAnchorM" or "adrb_bayAnchorE", "reference point")
        .. ((ADRouteBuilder.hasBayAlign() or ADRouteBuilder.alignPending ~= nil) and (" - " .. ADRouteBuilder.getBayAlignText()) or "")
end

--- moves the position onto the nearest AutoDrive waypoint and turns the direction along its connection
function ADRouteBuilder.snapToWayPoint()
    if ADRouteBuilder.lastX == nil or not ADRouteBuilder.resolveAutoDrive() then
        return
    end
    local best, bestDist = nil, 10
    for _, wp in pairs(ADGraphManager:getWayPoints()) do
        local d = MathUtil.vector2Length(wp.x - ADRouteBuilder.lastX, wp.z - ADRouteBuilder.lastZ)
        if d < bestDist then
            best, bestDist = wp, d
        end
    end
    if best == nil then
        g_currentMission:showBlinkingWarning(getText("adrb_noSnap", "no waypoint within 10 m"), 2000)
        return
    end
    ADRouteBuilder.lastX, ADRouteBuilder.lastZ = best.x, best.z
    ADRouteBuilder.posLocked = true
    if ADRouteBuilder.params ~= nil and (ADRouteBuilder.params.buildType == "Y" or ADRouteBuilder.params.buildType == "Z") then
        ADRouteBuilder.anchor = {x = best.x, z = best.z, id = best.id}
    end
    local other = nil
    if best.out ~= nil and #best.out > 0 then
        other = ADGraphManager:getWayPointById(best.out[1])
    elseif best.incoming ~= nil and #best.incoming > 0 then
        other = ADGraphManager:getWayPointById(best.incoming[1])
    end
    if other ~= nil then
        local dx, dz = other.x - best.x, other.z - best.z
        if MathUtil.vector2Length(dx, dz) > 0.01 then
            -- keep the side the line was already pointing to
            local newRot = math.atan2(dx, dz)
            local diff = (newRot - ADRouteBuilder.rotation + math.pi) % (2 * math.pi) - math.pi
            if math.abs(diff) > math.pi / 2 then
                newRot = newRot + math.pi
            end
            ADRouteBuilder.rotation = newRot
        end
    end
end

--- current state of the left modifier keys (directly from the engine if possible)
function ADRouteBuilder.getModifiers()
    if Input.isKeyPressed ~= nil then
        local ok, shift = pcall(Input.isKeyPressed, Input.KEY_lshift)
        if ok then
            return shift == true, Input.isKeyPressed(Input.KEY_lctrl) == true, Input.isKeyPressed(Input.KEY_lalt) == true
        end
    end
    return ADRouteBuilder.shiftPressed == true, ADRouteBuilder.ctrlPressed == true, ADRouteBuilder.altPressed == true
end

function ADRouteBuilder.stopLooking()
    ADRouteBuilder.lookByMouse = false
    if ADRouteBuilder.isLooking then
        ADRouteBuilder.isLooking = false
        ADRouteBuilder.posLocked = ADRouteBuilder.lockedBeforeLook == true
        if ADRouteBuilder.isPlacing then
            g_inputBinding:setShowMouseCursor(true)
        end
    end
end

--- true while the mouse wheel is used for the route builder (camera zoom has to stay where it is)
function ADRouteBuilder.isWheelUsed()
    if not ADRouteBuilder.isPlacing or ADRouteBuilder.isLooking or ADRouteBuilder.editMode or g_gui:getIsGuiVisible() then
        return false
    end
    local shift, ctrl, alt = ADRouteBuilder.getModifiers()
    return shift or ctrl or alt
end

function ADRouteBuilder:mouseEvent(posX, posY, isDown, isUp, button)
    if not ADRouteBuilder.isPlacing or g_gui:getIsGuiVisible() then
        return
    end
    if ADRouteBuilder.topView and ADRouteBuilder.topCamera ~= nil then
        ADRouteBuilder.topCamera:mouseEvent(posX, posY, isDown, isUp, button)
    end
    if ADRouteBuilder.editMode then
        -- AutoDrive editing: only follow the mouse (centre of the network display), nothing else
        ADRouteBuilder.mouseX, ADRouteBuilder.mouseY = posX, posY
        return
    end
    local middle = Input.MOUSE_BUTTON_MIDDLE or 2
    if ADRouteBuilder.topView and button == middle then
        return
    end
    -- hold the middle mouse button (wheel) = look around: the cursor is hidden, the camera follows the mouse
    if button == middle then
        if isDown and not ADRouteBuilder.isLooking then
            ADRouteBuilder.lookByMouse = true
            ADRouteBuilder.isLooking = true
            ADRouteBuilder.lockedBeforeLook = ADRouteBuilder.posLocked
            ADRouteBuilder.posLocked = true
            g_inputBinding:setShowMouseCursor(false)
        elseif isUp and ADRouteBuilder.isLooking and ADRouteBuilder.lookByMouse then
            ADRouteBuilder.lookByMouse = false
            ADRouteBuilder.stopLooking()
        end
        return
    end
    if ADRouteBuilder.isLooking then
        return
    end
    local cam = ADRouteBuilder.topCamera
    if not (ADRouteBuilder.topView and cam ~= nil and cam.isCatchingCursor) then
        ADRouteBuilder.mouseX, ADRouteBuilder.mouseY = posX, posY
    end
    if ADRouteBuilder.typeMenu then
        -- build type menu open: a right click only closes the menu (building goes on, no "edit AutoDrive")
        if button == Input.MOUSE_BUTTON_RIGHT then
            if isDown then
                ADRouteBuilder.openTypeMenu(false)
                ADRouteBuilder.rightDownTime = nil
                ADRouteBuilder.ignoreRightUp = true
            end
            return
        end
        -- a left click chooses, nothing is built
        if isDown and button == Input.MOUSE_BUTTON_LEFT then
            for i, r in ipairs(ADRouteBuilder.typeMenuRects or {}) do
                if posX >= r.x1 and posX <= r.x2 and posY >= r.y1 and posY < r.y2 then
                    ADRouteBuilder.chooseType(i)
                    return
                end
            end
            ADRouteBuilder.openTypeMenu(false)
            return
        end
        if button == Input.MOUSE_BUTTON_LEFT then
            return
        end
    end
    local shift, ctrl, alt = ADRouteBuilder.getModifiers()
    if isDown and button ~= nil and button ~= 0 then
        ADRouteBuilder.lastMouseButton = button
    end
    if ADRouteBuilder.learnAlignButton and isDown and button ~= nil and button ~= 0 then
        if button == Input.MOUSE_BUTTON_LEFT or button == Input.MOUSE_BUTTON_RIGHT or button == 4 or button == 5 then
            g_currentMission:showBlinkingWarning(string.format(getText("adrb_alignLearnBad", "mouse button %d is already used, take another one"), button), 3000)
        else
            ADRouteBuilder.learnAlignButton = false
            ADRouteBuilder.values.alignButton = tostring(button)
            ADRouteBuilder.saveSettings()
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
                string.format(getText("adrb_alignLearned", "aligning: LCtrl + mouse button %d"), button))
        end
        return
    end
    local pAlign = ADRouteBuilder.params
    local alignType = pAlign ~= nil and (pAlign.buildType == "Y" or pAlign.buildType == "Z" or pAlign.buildType == "L" or pAlign.buildType == "S")
    if isDown and ctrl and button ~= nil and button > 5 and button ~= ADRouteBuilder.getAlignButton() and alignType then
        -- LCtrl + an extra mouse button (side button): it is taken as the align button right away
        ADRouteBuilder.values.alignButton = tostring(button)
        pcall(ADRouteBuilder.saveSettings)
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
            string.format(getText("adrb_alignLearned", "aligning: LCtrl + mouse button %d"), button))
    end
    -- LCtrl + left click does the same (for mice without a side button)
    local alignLeft = button == Input.MOUSE_BUTTON_LEFT and not alt and not shift
    if isDown and ctrl and (button == ADRouteBuilder.getAlignButton() or alignLeft) and alignType then
        if pAlign.buildType == "L" then
            ADRouteBuilder.alignGuideParallel()
        elseif pAlign.buildType == "S" then
            ADRouteBuilder.bayAlignClick()
        else
            ADRouteBuilder.alignClick()
        end
        return
    end
    if ADRouteBuilder.params ~= nil and ADRouteBuilder.params.buildType == "M" and ADRouteBuilder.selectMouseEvent ~= nil then
        if button == Input.MOUSE_BUTTON_LEFT or (not isDown and not isUp) then
            ADRouteBuilder.selectMouseEvent(posX, posY, isDown, isUp, button)
        end
        if button == Input.MOUSE_BUTTON_LEFT then
            return
        end
    end
    if isUp and (button == 4 or button == 5) then
        -- the wheel only changes something together with a modifier key, without one it zooms the camera
        local dir = button == 4 and 1 or -1
        if shift and alt then
            -- fine rotation: 0.1 deg per step, with LCtrl too 0.01 deg
            ADRouteBuilder.rotation = ADRouteBuilder.rotation + dir * math.rad(ctrl and 0.01 or 0.1)
        elseif ctrl then
            ADRouteBuilder.changeRadius(dir * (shift and 0.1 or 0.5))
        elseif alt then
            ADRouteBuilder.changePoints(dir)
        elseif shift then
            ADRouteBuilder.rotation = ADRouteBuilder.rotation + dir * math.rad(5)
        end
    elseif isDown and button == Input.MOUSE_BUTTON_LEFT and alt and not ctrl and not shift and ADRouteBuilder.params ~= nil
        and ADRouteBuilder.params.buildType == "S" then
        -- LAlt + left click on the approach / exit of a bay: it turns to the other side
        ADRouteBuilder.toggleBaySideAtMouse()
    elseif isDown and button == Input.MOUSE_BUTTON_LEFT and alt and not ctrl and not shift and ADRouteBuilder.params ~= nil
        and (ADRouteBuilder.params.buildType == "Y" or ADRouteBuilder.params.buildType == "Z") then
        -- LAlt + left click on a side of the branch: remove that branch / bring it back
        ADRouteBuilder.toggleArmAtMouse()
    elseif isDown and button == Input.MOUSE_BUTTON_LEFT then
        ADRouteBuilder.build()
    elseif isDown and button == Input.MOUSE_BUTTON_RIGHT then
        ADRouteBuilder.rightDownTime = g_time
        ADRouteBuilder.rightDownX, ADRouteBuilder.rightDownY = posX, posY
    elseif isUp and button == Input.MOUSE_BUTTON_RIGHT and ADRouteBuilder.ignoreRightUp then
        -- release of the right click that closed the build type menu
        ADRouteBuilder.ignoreRightUp = false
    elseif isUp and button == Input.MOUSE_BUTTON_RIGHT and ADRouteBuilder.rightDownTime ~= nil then
        -- a short click finishes; holding / dragging (camera rotation in the top view) does not
        local dragged = math.abs(posX - (ADRouteBuilder.rightDownX or posX)) + math.abs(posY - (ADRouteBuilder.rightDownY or posY)) > 0.01
        local cam = ADRouteBuilder.topCamera
        if ADRouteBuilder.topView and cam ~= nil and cam.lastActionFrame ~= nil and cam.lastActionFrame > ADRouteBuilder.rightDownTime then
            dragged = true
        end
        local short = g_time - ADRouteBuilder.rightDownTime < 400
        ADRouteBuilder.rightDownTime = nil
        if short and not dragged then
            ADRouteBuilder.setEditMode(true)
        end
    end
end

-- numpad keys: if the engine constant does not exist, the character of the key is used instead
local KEYPAD_FALLBACK = {KEY_KP_divide = 47, KEY_KP_multiply = 42, KEY_KP_minus = 45, KEY_KP_plus = 43}
for name, _ in pairs(KEYPAD_FALLBACK) do
    if Input ~= nil and Input[name] == nil then
        Input[name] = "ADRB_" .. name
        print(string.format("[AD Route Builder] Input.%s missing, using the key character", name))
    end
end

function ADRouteBuilder:keyEvent(unicode, sym, modifier, isDown)
    ADRouteBuilder.shiftPressed = bit32.band(modifier, Input.MOD_LSHIFT) > 0
    ADRouteBuilder.ctrlPressed = bit32.band(modifier, Input.MOD_LCTRL) > 0
    ADRouteBuilder.altPressed = bit32.band(modifier, Input.MOD_LALT) > 0
    if Input.KEY_lalt ~= nil and sym == Input.KEY_lalt then
        if isDown and not ADRouteBuilder.altHeld and ADRouteBuilder.isPlacing and ADRouteBuilder.params ~= nil
            and ADRouteBuilder.params.buildType == "L" then
            -- guide line: every new LAlt press changes the step of the sideways move
            ADRouteBuilder.guideShiftIndex = (ADRouteBuilder.guideShiftIndex or 0) % #ADRouteBuilder.GUIDE_SHIFT_STEPS + 1
        end
        ADRouteBuilder.altHeld = isDown
    end
    if not ADRouteBuilder.isPlacing or not isDown or g_gui:getIsGuiVisible() then
        return
    end
    for name, char in pairs(KEYPAD_FALLBACK) do
        if type(Input[name]) == "string" and unicode == char then
            sym = Input[name]
        end
    end
    ADRouteBuilder.lastKey = {sym = sym, unicode = unicode, time = g_time}
    if ADRouteBuilder.typeMenu then
        -- build type menu: number keys (top row or numpad) choose, Esc / Num Enter close
        local index = nil
        for i = 1, 9 do
            if (Input["KEY_" .. i] ~= nil and sym == Input["KEY_" .. i]) or (Input["KEY_KP_" .. i] ~= nil and sym == Input["KEY_KP_" .. i]) then
                index = i
            end
        end
        if index == nil and unicode ~= nil and unicode >= 49 and unicode <= 57 then
            -- fallback: the character of the key ("1" ... "9")
            index = unicode - 48
        end
        if index ~= nil then
            ADRouteBuilder.chooseType(index)
            return
        end
        if sym == Input.KEY_esc or sym == Input.KEY_KP_enter then
            ADRouteBuilder.openTypeMenu(false)
            return
        end
    end
    if sym == Input.KEY_KP_enter and ADRouteBuilder.resampleData ~= nil and not ADRouteBuilder.editMode then
        -- apply the new number of points of the selected segment
        ADRouteBuilder.resampleApply()
        return
    end
    if sym == Input.KEY_KP_enter then
        ADRouteBuilder.setEditMode(not ADRouteBuilder.editMode)
        return
    elseif sym == Input.KEY_b and ADRouteBuilder.ctrlPressed and ADRouteBuilder.altPressed and ADRouteBuilder.topView then
        -- in the top view the global key is not active: open the settings from here
        ADRouteBuilder.openDialog()
        return
    elseif sym == Input.KEY_home then
        ADRouteBuilder.topRotateFree = not ADRouteBuilder.topRotateFree
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
            getText(ADRouteBuilder.topRotateFree and "adrb_rotateFree" or "adrb_rotateLocked", "camera rotation"))
        return
    elseif sym == Input.KEY_end then
        ADRouteBuilder.stopPlacing()
        return
    end
    if ADRouteBuilder.editMode and sym == Input.KEY_KP_divide then
        if ADRouteBuilder.resolveAutoDrive() and AutoDrive.setEditorMode ~= nil then
            AutoDrive.setEditorMode(AutoDrive.EDITOR_EXTENDED)
        end
        return
    elseif ADRouteBuilder.editMode and sym == Input.KEY_KP_1 then
        -- back to building and straight into the build type menu (8 = select / move)
        ADRouteBuilder.setEditMode(false)
        ADRouteBuilder.openTypeMenu(true)
        return
    end
    if ADRouteBuilder.editMode and sym ~= Input.KEY_KP_plus and sym ~= Input.KEY_KP_multiply and sym ~= Input.KEY_KP_minus
        and sym ~= Input.KEY_esc then
        -- while editing the AutoDrive network the keys belong to AutoDrive
        return
    end
    local stepAngle = math.rad(ADRouteBuilder.shiftPressed and 1 or 5)
    if sym == Input.KEY_l and ADRouteBuilder.ctrlPressed and ADRouteBuilder.altPressed and ADRouteBuilder.topView then
        -- in the top view our own input context is active, the global key for removing the guides is not
        ADRouteBuilder.clearGuides()
        return
    end
    if ADRouteBuilder.params ~= nil and ADRouteBuilder.params.buildType == "M" and ADRouteBuilder.toggleCopy ~= nil
        and ((sym == Input.KEY_c and ADRouteBuilder.ctrlPressed and not ADRouteBuilder.altPressed)
            or (Input.KEY_insert ~= nil and sym == Input.KEY_insert)) then
        -- LCtrl + C / Ins: copy the selection, the copy hangs on the mouse
        ADRouteBuilder.toggleCopy()
        return
    end
    if sym == Input.KEY_n and ADRouteBuilder.ctrlPressed and ADRouteBuilder.altPressed then
        -- learn the mouse button for aligning to guide lines: the next mouse button pressed is taken
        ADRouteBuilder.learnAlignButton = true
        g_currentMission:showBlinkingWarning(getText("adrb_alignLearn", "press the mouse button for aligning now"), 5000)
        return
    end
    if Input.KEY_delete ~= nil and sym == Input.KEY_delete then
        if ADRouteBuilder.params ~= nil and ADRouteBuilder.params.buildType == "M" and ADRouteBuilder.countSelection ~= nil
            and ADRouteBuilder.countSelection() > 0 then
            -- select / move: delete the selected AutoDrive points
            ADRouteBuilder.deleteSelection()
        elseif ADRouteBuilder.shiftPressed then
            ADRouteBuilder.restoreGuide()
        else
            ADRouteBuilder.removeGuideNearMouse()
        end
        return
    end
    if (sym == Input.KEY_z or sym == Input.KEY_y) and ADRouteBuilder.ctrlPressed and ADRouteBuilder.altPressed then
        -- undo while placing: Z and Y both work (German keyboards have Y and Z swapped; the global key
        -- binding follows the key position). undoLast ignores a 2nd call at the same moment.
        ADRouteBuilder.undoLast()
        return
    end
    if ADRouteBuilder.params ~= nil and ADRouteBuilder.params.buildType == "M" and ADRouteBuilder.selectKeyEvent ~= nil
        and ADRouteBuilder.selectKeyEvent(sym) then
        return
    end
    -- fine adjustment with the numpad
    -- (fine rotation: LShift + LAlt + mouse wheel, see mouseEvent)
    -- 0.01 m with LCtrl (LShift + numpad gives the arrow keys on Windows with NumLock on); LShift kept as well
    local fineMove = (ADRouteBuilder.ctrlPressed or ADRouteBuilder.shiftPressed) and 0.01 or 0.1
    if sym == Input.KEY_KP_minus then
        ADRouteBuilder.showPanel = not ADRouteBuilder.showPanel
        return
    elseif sym == Input.KEY_KP_divide then
        -- Num/ = look around on / off (alternative to holding the middle mouse button)
        if ADRouteBuilder.topView then
            return
        elseif ADRouteBuilder.isLooking then
            ADRouteBuilder.stopLooking()
        else
            ADRouteBuilder.isLooking = true
            ADRouteBuilder.lockedBeforeLook = ADRouteBuilder.posLocked
            ADRouteBuilder.posLocked = true
            g_inputBinding:setShowMouseCursor(false)
        end
        return
    elseif sym == Input.KEY_KP_5 then
        ADRouteBuilder.posLocked = not ADRouteBuilder.posLocked
        return
    elseif sym == Input.KEY_KP_9 and ADRouteBuilder.params ~= nil and ADRouteBuilder.params.buildType == "S" then
        ADRouteBuilder.fitBaysToSilo()
        return
    elseif sym == Input.KEY_KP_3 then
        local p = ADRouteBuilder.params
        if p ~= nil and p.buildType == "Y" then
            g_currentMission:showBlinkingWarning(getText("adrb_mergeIsZ", "merging in: build type 7 merge"), 3000)
        elseif p ~= nil and p.buildType == "S" then
            -- bays: reference point = first bay or middle of all bays
            local toMiddle = ADRouteBuilder.values.bayAnchor ~= "M"
            ADRouteBuilder.values.bayAnchor = toMiddle and "M" or "E"
            -- the bays stay where they are: with a fixed position the reference point moves instead
            if ADRouteBuilder.posLocked and ADRouteBuilder.lastX ~= nil and p.count > 1 then
                local rot = ADRouteBuilder.rotation or 0
                local rightX, rightZ = math.cos(rot), -math.sin(rot)
                local d = p.spacing * (p.count - 1) * 0.5 * (toMiddle and 1 or -1)
                ADRouteBuilder.lastX = ADRouteBuilder.lastX + rightX * d
                ADRouteBuilder.lastZ = ADRouteBuilder.lastZ + rightZ * d
            end
        elseif p ~= nil and (p.buildType == "K" or p.buildType == "B" or p.buildType == "G") then
            ADRouteBuilder.arcReverseDir = not ADRouteBuilder.arcReverseDir
        end
        return
    elseif sym == Input.KEY_KP_plus and ADRouteBuilder.ctrlPressed then
        -- LCtrl + Num+: top view back above the person / vehicle, in their view direction
        ADRouteBuilder.centerTopView()
        return
    elseif sym == Input.KEY_KP_plus then
        if ADRouteBuilder.topView then
            ADRouteBuilder.exitTopView()
        else
            ADRouteBuilder.enterTopView()
        end
        return
    elseif sym == Input.KEY_KP_multiply then
        ADRouteBuilder.showNetwork = not ADRouteBuilder.isNetworkShown()
        return
    elseif sym == Input.KEY_esc and ADRouteBuilder.topView then
        ADRouteBuilder.exitTopView()
        return
    elseif sym == Input.KEY_KP_period or sym == Input.KEY_KP_comma then
        -- like in the select tool: Num, = one-way / both ways / reverse, LCtrl + Num, = turn the
        -- direction around, LAlt + Num, = main / sub route
        local bt = ADRouteBuilder.params ~= nil and ADRouteBuilder.params.buildType or ""
        if ADRouteBuilder.altPressed then
            if bt == "K" or bt == "B" or bt == "G" then
                ADRouteBuilder.toggleSubRoute()
            end
        elseif ADRouteBuilder.ctrlPressed then
            if bt == "K" or bt == "B" or bt == "G" then
                ADRouteBuilder.arcReverseDir = not ADRouteBuilder.arcReverseDir
            end
        elseif bt == "K" or bt == "B" or bt == "G" or bt == "Y" or bt == "Z" then
            ADRouteBuilder.cycleConnection()
        end
        return
    elseif sym == Input.KEY_KP_0 then
        local bt = ADRouteBuilder.params ~= nil and ADRouteBuilder.params.buildType or ""
        if ADRouteBuilder.altPressed then
            -- LAlt + Num0 (and LCtrl + LAlt + Num0) belong to AutoDrive
            return
        end
        if ADRouteBuilder.ctrlPressed then
            -- LCtrl + Num0: switch the alignment to guide lines off (both sides)
            if bt == "Y" or bt == "Z" then
                ADRouteBuilder.alignList = {}
                ADRouteBuilder.alignPending = nil
            elseif bt == "S" then
                ADRouteBuilder.bayAlign = {}
                ADRouteBuilder.alignPending = nil
            end
            return
        end
        if bt == "G" then
            -- straight line: discard the start
            ADRouteBuilder.lineStart = nil
        else
            ADRouteBuilder.snapToWayPoint()
        end
        return
    elseif sym == Input.KEY_KP_8 or sym == Input.KEY_KP_2 or sym == Input.KEY_KP_4 or sym == Input.KEY_KP_6 then
        if ADRouteBuilder.lastX ~= nil then
            local dirX, dirZ = math.sin(ADRouteBuilder.rotation), math.cos(ADRouteBuilder.rotation)
            local rightX, rightZ = dirZ, -dirX
            local mx, mz = 0, 0
            if sym == Input.KEY_KP_8 then mx, mz = dirX, dirZ
            elseif sym == Input.KEY_KP_2 then mx, mz = -dirX, -dirZ
            -- (rightX/rightZ is the local x axis, which points to the left of the driving direction in
            -- the game: Num6 = to the right on the screen = -x)
            elseif sym == Input.KEY_KP_6 then mx, mz = -rightX, -rightZ
            else mx, mz = rightX, rightZ end
            ADRouteBuilder.posLocked = true
            if ADRouteBuilder.anchor ~= nil then
                ADRouteBuilder.anchor.x = ADRouteBuilder.anchor.x + mx * fineMove
                ADRouteBuilder.anchor.z = ADRouteBuilder.anchor.z + mz * fineMove
                ADRouteBuilder.anchor.id = nil
            end
            ADRouteBuilder.lastX = ADRouteBuilder.lastX + mx * fineMove
            ADRouteBuilder.lastZ = ADRouteBuilder.lastZ + mz * fineMove
        end
        return
    end
    if sym == Input.KEY_KP_1 and ADRouteBuilder.altPressed then
        -- LAlt + Num1: straight line on a guide line, again: back to the type before
        local p = ADRouteBuilder.params
        if p.buildType == "G" then
            ADRouteBuilder.switchBuildType(ADRouteBuilder.typeBeforeLine or "L")
        else
            ADRouteBuilder.typeBeforeLine = p.buildType
            ADRouteBuilder.switchBuildType("G")
        end
        return
    end
    if sym == Input.KEY_KP_1 then
        -- Num1: menu with all build types, choose directly with the number
        ADRouteBuilder.openTypeMenu(true)
        return
    end
    if unicode == 104 or unicode == 72 then -- 'h' toggles the helper lines
        ADRouteBuilder.showHelpers = not ADRouteBuilder.showHelpers
    elseif unicode == 44 then -- ','
        ADRouteBuilder.rotation = ADRouteBuilder.rotation + stepAngle
    elseif unicode == 46 then -- '.'
        ADRouteBuilder.rotation = ADRouteBuilder.rotation - stepAngle
    end
end

function ADRouteBuilder:deleteMap()
    ADRouteBuilder.exitTopView()
    if ADRouteBuilder.topCamera ~= nil then
        pcall(ADRouteBuilder.topCamera.delete, ADRouteBuilder.topCamera)
        ADRouteBuilder.topCamera = nil
    end
    ADRouteBuilder.isPlacing = false
    if ADRouteBuilder.gui ~= nil then
        ADRouteBuilder.gui:delete()
        ADRouteBuilder.gui = nil
    end
end

-- mouse wheel together with LShift / LCtrl / LAlt while placing: do not zoom the camera
-- (same technique AutoDrive uses for its curve editor)
if VehicleCamera ~= nil and VehicleCamera.zoomSmoothly ~= nil then
    VehicleCamera.zoomSmoothly = Utils.overwrittenFunction(VehicleCamera.zoomSmoothly, function(self, superFunc, offset, ...)
        if ADRouteBuilder.isWheelUsed() then
            return
        end
        return superFunc(self, offset, ...)
    end)
end
if PlayerInputComponent ~= nil and PlayerInputComponent.onInputZoomInOut ~= nil then
    PlayerInputComponent.onInputZoomInOut = Utils.overwrittenFunction(PlayerInputComponent.onInputZoomInOut, function(self, superFunc, ...)
        if ADRouteBuilder.isWheelUsed() then
            return
        end
        return superFunc(self, ...)
    end)
end

--- top view: turning / tilting the camera with the mouse only while Space is held (or after Pos1 = free),
--- so that the middle / right mouse button can be used by AutoDrive to move points
function ADRouteBuilder.isTopRotateAllowed()
    if ADRouteBuilder.topRotateFree then
        return true
    end
    if Input.isKeyPressed ~= nil and Input.KEY_space ~= nil then
        local ok, pressed = pcall(Input.isKeyPressed, Input.KEY_space)
        return ok and pressed == true
    end
    return false
end
if GuiTopDownCamera ~= nil then
    for _, name in ipairs({"onRotate", "onTilt"}) do
        if GuiTopDownCamera[name] ~= nil then
            local field = name == "onRotate" and "inputRotate" or "inputTilt"
            GuiTopDownCamera[name] = Utils.overwrittenFunction(GuiTopDownCamera[name], function(self, superFunc, actionName, inputValue, callbackState, isAnalog, isMouse, ...)
                if self == ADRouteBuilder.topCamera and isMouse and not ADRouteBuilder.isTopRotateAllowed() then
                    self[field] = 0
                    return
                end
                return superFunc(self, actionName, inputValue, callbackState, isAnalog, isMouse, ...)
            end)
        end
    end
end
if GuiTopDownCamera ~= nil and GuiTopDownCamera.onZoom ~= nil then
    GuiTopDownCamera.onZoom = Utils.overwrittenFunction(GuiTopDownCamera.onZoom, function(self, superFunc, ...)
        if self == ADRouteBuilder.topCamera and ADRouteBuilder.isWheelUsed() then
            return
        end
        return superFunc(self, ...)
    end)
end

-- global key (on foot and in vehicles, same hook as Courseplay uses)
local function addPlayerActionEvents(self, superFunc, ...)
    superFunc(self, ...)
    local _, id = g_inputBinding:registerActionEvent(InputAction.ADRB_OPEN, ADRouteBuilder, function()
        ADRouteBuilder.openOrStart()
    end, false, true, false, true, nil, false)
    if id ~= nil then
        g_inputBinding:setActionEventTextVisibility(id, false)
    end
    local _, undoId = g_inputBinding:registerActionEvent(InputAction.ADRB_UNDO, ADRouteBuilder, function()
        ADRouteBuilder.undoLast()
    end, false, true, false, true, nil, false)
    if undoId ~= nil then
        g_inputBinding:setActionEventTextVisibility(undoId, false)
    end
    local _, placeId = g_inputBinding:registerActionEvent(InputAction.ADRB_PLACE, ADRouteBuilder, function()
        ADRouteBuilder.quickPlace()
    end, false, true, false, true, nil, false)
    if placeId ~= nil then
        g_inputBinding:setActionEventTextVisibility(placeId, false)
    end
    local _, clearId = g_inputBinding:registerActionEvent(InputAction.ADRB_CLEAR_GUIDES, ADRouteBuilder, function()
        ADRouteBuilder.clearGuides()
    end, false, true, false, true, nil, false)
    if clearId ~= nil then
        g_inputBinding:setActionEventTextVisibility(clearId, false)
    end
end
PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.overwrittenFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents, addPlayerActionEvents)

addModEventListener(ADRouteBuilder)
print("[AD Route Builder] loaded (v1.8.12.2)")
