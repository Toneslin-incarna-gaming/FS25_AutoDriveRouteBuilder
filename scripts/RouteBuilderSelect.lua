--
-- AutoDrive Route Builder - build type "M": select existing AutoDrive points and move them
--   left mouse drag on free space      = selection box (LShift = add, LCtrl = remove)
--   left click on a point              = select only this point (LShift = add / remove it)
--   left mouse drag on a selected point = move the selection (free / along / across the last guide line)
--   Num3 = move mode, Num8/2/4/6 = nudge, Num0 = clear selection, LCtrl + LAlt + Z = undo last move
--   Del (twice) = delete the selected points
--   LCtrl + C / Ins = copy the selection, left click pastes it (free / along / across a guide line, rotatable)
-- Moving uses AutoDrive's own function (ADGraphManager:moveWayPoint), which also sends it to the server.
--

ADRouteBuilder.selection = {}
ADRouteBuilder.moveMode = 1          -- 1 = free, 2 = along the last guide line, 3 = across the last guide line
ADRouteBuilder.moveStack = {}
local PICK_RADIUS = 0.018            -- screen distance for clicking a point

local function getText(key, fallback)
    return ADRouteBuilder.getText(key, fallback)
end

local function countSelection()
    local n = 0
    for _ in pairs(ADRouteBuilder.selection) do
        n = n + 1
    end
    return n
end
ADRouteBuilder.countSelection = countSelection

--- screen position of a waypoint (nil if behind the camera / off screen)
local function screenPos(wp)
    local sx, sy, depth = project(wp.x, wp.y + 0.3, wp.z)
    if sx == nil or depth == nil or depth <= 0 or depth >= 1 or sx < 0 or sx > 1 or sy < 0 or sy > 1 then
        return nil
    end
    return sx, sy
end

function ADRouteBuilder.countVisiblePoints()
    if not ADRouteBuilder.resolveAutoDrive() then
        return 0
    end
    local n = 0
    for _, wp in pairs(ADGraphManager:getWayPoints()) do
        if screenPos(wp) ~= nil then
            n = n + 1
        end
    end
    return n
end

local function nearestPointOnScreen(mx, my)
    if not ADRouteBuilder.resolveAutoDrive() then
        return nil
    end
    local best, bestDist = nil, PICK_RADIUS
    for _, wp in pairs(ADGraphManager:getWayPoints()) do
        local sx, sy = screenPos(wp)
        if sx ~= nil then
            local d = math.sqrt((sx - mx) ^ 2 + ((sy - my) * 0.5625) ^ 2)
            if d < bestDist then
                best, bestDist = wp, d
            end
        end
    end
    return best
end

--- guide line for "along" / "across": the one chosen with Num3 (near the mouse), otherwise the last one
function ADRouteBuilder.getMoveGuide()
    local g = ADRouteBuilder.getGuideTarget(ADRouteBuilder.moveGuideIndex)
    return g or ADRouteBuilder.guides[#ADRouteBuilder.guides]
end

--- direction of the move (constrained to the chosen guide line if wanted)
local function constrain(dx, dz)
    local mode = ADRouteBuilder.moveMode
    local guide = ADRouteBuilder.getMoveGuide()
    if mode == 1 or guide == nil then
        return dx, dz
    end
    local ax, az = math.sin(guide.rot), math.cos(guide.rot)
    if mode == 3 then
        ax, az = az, -ax
    end
    local t = dx * ax + dz * az
    return ax * t, az * t
end

local function commitMove(dx, dz)
    if not ADRouteBuilder.resolveAutoDrive() or (math.abs(dx) < 0.001 and math.abs(dz) < 0.001) then
        return
    end
    local undo = {}
    for id, _ in pairs(ADRouteBuilder.selection) do
        local wp = ADGraphManager:getWayPointById(id)
        if wp ~= nil then
            table.insert(undo, {id, wp.x, wp.y, wp.z})
            local nx, nz = wp.x + dx, wp.z + dz
            local ny = ADRouteBuilder.getHeight(nx, nz) or wp.y
            ADGraphManager:moveWayPoint(id, nx, ny, nz, wp.flags or 0)
        end
    end
    if #undo > 0 then
        table.insert(ADRouteBuilder.moveStack, undo)
        if #ADRouteBuilder.moveStack > 30 then
            table.remove(ADRouteBuilder.moveStack, 1)
        end
        ADRouteBuilder.lastActionWasMove = true
    end
end

--- puts the selected points exactly onto the guide line they lie along (Num7), with Num9 also
--- spread evenly between the two outer points. The guide line (main or cross line) is the one with
--- the smallest mean distance to the selected points (at most 15 m).
ADRouteBuilder.STRAIGHTEN_MAX_DISTANCE = 15
function ADRouteBuilder.straightenSelection(even)
    if not ADRouteBuilder.resolveAutoDrive() then
        return
    end
    local wps = {}
    for id, _ in pairs(ADRouteBuilder.selection) do
        local wp = ADGraphManager:getWayPointById(id)
        if wp ~= nil then
            table.insert(wps, wp)
        end
    end
    if #wps < 2 then
        g_currentMission:showBlinkingWarning(getText("adrb_straightenFew", "select at least 2 points"), 2500)
        return
    end
    if #ADRouteBuilder.guides == 0 then
        g_currentMission:showBlinkingWarning(getText("adrb_lineNeedGuide", "set a guide line first"), 2500)
        return
    end
    -- guide line with the smallest mean distance
    local best, bestMean = nil, nil
    for i, _ in ipairs(ADRouteBuilder.guides) do
        for _, target in ipairs({i, -i}) do
            local g = ADRouteBuilder.getGuideTarget(target)
            local dx, dz = math.sin(g.rot), math.cos(g.rot)
            local sum = 0
            for _, wp in ipairs(wps) do
                sum = sum + math.abs((wp.x - g.x) * dz - (wp.z - g.z) * dx)
            end
            local mean = sum / #wps
            if bestMean == nil or mean < bestMean then
                best, bestMean = target, mean
            end
        end
    end
    if bestMean > ADRouteBuilder.STRAIGHTEN_MAX_DISTANCE then
        g_currentMission:showBlinkingWarning(string.format(getText("adrb_straightenFar",
            "the points are %.1f m away from the nearest guide line on average (max. 15 m)"), bestMean), 3000)
        return
    end
    local g = ADRouteBuilder.getGuideTarget(best)
    local dx, dz = math.sin(g.rot), math.cos(g.rot)
    local list = {}
    for _, wp in ipairs(wps) do
        table.insert(list, {wp = wp, t = (wp.x - g.x) * dx + (wp.z - g.z) * dz})
    end
    table.sort(list, function(a, b) return a.t < b.t end)
    local t1, t2 = list[1].t, list[#list].t
    local undo = {}
    for k, e in ipairs(list) do
        local t = e.t
        if even and #list > 1 then
            t = t1 + (t2 - t1) * (k - 1) / (#list - 1)
        end
        local nx, nz = g.x + dx * t, g.z + dz * t
        local ny = ADRouteBuilder.getHeight(nx, nz) or e.wp.y
        table.insert(undo, {e.wp.id, e.wp.x, e.wp.y, e.wp.z})
        ADGraphManager:moveWayPoint(e.wp.id, nx, ny, nz, e.wp.flags or 0)
    end
    table.insert(ADRouteBuilder.moveStack, undo)
    if #ADRouteBuilder.moveStack > 30 then
        table.remove(ADRouteBuilder.moveStack, 1)
    end
    ADRouteBuilder.lastActionWasMove = true
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format(getText(even and "adrb_straightenedEven" or "adrb_straightened", "%d points put onto guide line %s"),
            #list, ADRouteBuilder.getTargetName(best)))
end

--- AD target on the selected point (Num5): set, rename (enter another name) or remove (empty name).
--- Uses AutoDrive's own functions, so it works anywhere on the map and in multiplayer.
function ADRouteBuilder.editTargetOfSelection()
    if not ADRouteBuilder.resolveAutoDrive() then
        return
    end
    local ids = {}
    for id, _ in pairs(ADRouteBuilder.selection) do
        if ADGraphManager:getWayPointById(id) ~= nil then
            table.insert(ids, id)
        end
    end
    if #ids ~= 1 then
        g_currentMission:showBlinkingWarning(getText("adrb_targetOnePoint", "select exactly one point"), 2500)
        return
    end
    local wpId = ids[1]
    local function findMarker()
        for index, m in pairs(ADGraphManager:getMapMarkers() or {}) do
            if m.id == wpId then
                return m, index
            end
        end
        return nil, nil
    end
    local marker = findMarker()
    local title = getText("adrb_targetName", "name of the AD target (empty = remove the target)")
    TextInputDialog.show(function(_, text, clickOk)
        if not clickOk then
            return
        end
        local name = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local current, index = findMarker()
        if name == "" then
            if current ~= nil then
                ADGraphManager:removeMapMarker(index, true)
                g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
                    string.format(getText("adrb_targetRemoved", "target '%s' removed"), current.name))
            end
            return
        end
        local other = ADGraphManager:getMapMarkerByName(name)
        if other ~= nil and other.id ~= wpId then
            g_currentMission:showBlinkingWarning(string.format(getText("adrb_targetExists", "a target '%s' already exists"), name), 3000)
            return
        end
        if current ~= nil then
            if current.name ~= name then
                ADGraphManager:renameMapMarker(name, index, true)
            end
        else
            ADGraphManager:createMapMarker(wpId, name, true)
        end
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
            string.format(getText("adrb_targetSet", "AD target '%s' set"), name))
    end, ADRouteBuilder, marker ~= nil and marker.name or "", title, title, 40, g_i18n:getText("button_ok"))
end

--- undo of the last move; returns true if something was undone
function ADRouteBuilder.undoLastMove()
    local undo = table.remove(ADRouteBuilder.moveStack)
    if undo == nil or not ADRouteBuilder.resolveAutoDrive() then
        return false
    end
    if undo.kind == "con" then
        ADRouteBuilder.undoConChange(undo)
        ADRouteBuilder.lastActionWasMove = #ADRouteBuilder.moveStack > 0
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, getText("adrb_conUndone", "connection change undone"))
        return true
    end
    for _, u in ipairs(undo) do
        local wp = ADGraphManager:getWayPointById(u[1])
        if wp ~= nil then
            ADGraphManager:moveWayPoint(u[1], u[2], u[3], u[4], wp.flags or 0)
        end
    end
    ADRouteBuilder.lastActionWasMove = #ADRouteBuilder.moveStack > 0
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, getText("adrb_moveUndone", "move undone"))
    return true
end

function ADRouteBuilder.selectMouseEvent(posX, posY, isDown, isUp, button)
    local shift, ctrl = ADRouteBuilder.getModifiers()
    if ADRouteBuilder.copyData ~= nil then
        if button == Input.MOUSE_BUTTON_LEFT and isDown then
            ADRouteBuilder.pasteCopy()
        end
        return
    end
    -- straight line / new point count shown: a left click anywhere confirms it (like Num Enter)
    if ADRouteBuilder.resampleData ~= nil and button == Input.MOUSE_BUTTON_LEFT and isDown then
        ADRouteBuilder.resampleApply()
        ADRouteBuilder.ignoreNextLeftUp = true
        return
    end
    if ADRouteBuilder.ignoreNextLeftUp and button == Input.MOUSE_BUTTON_LEFT and isUp then
        ADRouteBuilder.ignoreNextLeftUp = false
        return
    end
    if button == Input.MOUSE_BUTTON_LEFT and isDown then
        local wp = nearestPointOnScreen(posX, posY)
        ADRouteBuilder.dragStart = {x = posX, y = posY}
        if wp ~= nil and ADRouteBuilder.selection[wp.id] and not shift and not ctrl then
            -- start moving the selection
            local tx, tz = ADRouteBuilder.getMouseTerrainPos()
            if tx ~= nil then
                ADRouteBuilder.dragMove = {startX = tx, startZ = tz, dx = 0, dz = 0}
            end
        else
            ADRouteBuilder.dragBox = {x1 = posX, y1 = posY, x2 = posX, y2 = posY, clickPoint = wp}
        end
        return
    end
    if button == Input.MOUSE_BUTTON_LEFT and isUp then
        -- a new selection or a move ends the point count change
        ADRouteBuilder.resampleData = nil
        if ADRouteBuilder.dragMove ~= nil then
            local m = ADRouteBuilder.dragMove
            ADRouteBuilder.dragMove = nil
            commitMove(m.dx, m.dz)
        elseif ADRouteBuilder.dragBox ~= nil then
            local b = ADRouteBuilder.dragBox
            ADRouteBuilder.dragBox = nil
            local isClick = math.abs(b.x2 - b.x1) < 0.004 and math.abs(b.y2 - b.y1) < 0.004
            if isClick then
                local wp = b.clickPoint
                if wp == nil then
                    if not shift and not ctrl then
                        ADRouteBuilder.selection = {}
                    end
                elseif shift then
                    ADRouteBuilder.selection[wp.id] = not ADRouteBuilder.selection[wp.id] or nil
                elseif ctrl then
                    ADRouteBuilder.selection[wp.id] = nil
                else
                    ADRouteBuilder.selection = {[wp.id] = true}
                end
            elseif ADRouteBuilder.resolveAutoDrive() then
                if not shift and not ctrl then
                    ADRouteBuilder.selection = {}
                end
                local x1, x2 = math.min(b.x1, b.x2), math.max(b.x1, b.x2)
                local y1, y2 = math.min(b.y1, b.y2), math.max(b.y1, b.y2)
                for _, wp in pairs(ADGraphManager:getWayPoints()) do
                    local sx, sy = screenPos(wp)
                    if sx ~= nil and sx >= x1 and sx <= x2 and sy >= y1 and sy <= y2 then
                        ADRouteBuilder.selection[wp.id] = (not ctrl) or nil
                    end
                end
            end
        end
        return
    end
    -- mouse moved
    if ADRouteBuilder.dragBox ~= nil then
        ADRouteBuilder.dragBox.x2, ADRouteBuilder.dragBox.y2 = posX, posY
    end
end

function ADRouteBuilder.selectUpdate()
    local c = ADRouteBuilder.copyData
    if c ~= nil then
        local tx, tz = ADRouteBuilder.getMouseTerrainPos()
        if tx ~= nil then
            if c.startX == nil then
                c.startX, c.startZ = tx, tz
            end
            local dx, dz = constrain(tx - c.startX, tz - c.startZ)
            c.dx, c.dz = c.baseDx + dx, c.baseDz + dz
        end
    end
    local m = ADRouteBuilder.dragMove
    if m ~= nil then
        local tx, tz = ADRouteBuilder.getMouseTerrainPos()
        if tx ~= nil then
            m.dx, m.dz = constrain(tx - m.startX, tz - m.startZ)
        end
    end
end

--- keys of the select mode; returns true if the key was used
function ADRouteBuilder.selectKeyEvent(sym)
    local shift = ADRouteBuilder.shiftPressed
    if sym == Input.KEY_KP_3 then
        ADRouteBuilder.moveMode = ADRouteBuilder.moveMode % 3 + 1
        if ADRouteBuilder.moveMode > 1 and #ADRouteBuilder.guides == 0 then
            g_currentMission:showBlinkingWarning(getText("adrb_moveNeedGuide", "set a guide line first"), 3000)
        elseif ADRouteBuilder.moveMode == 2 then
            -- the guide line near the mouse (up to 15 m), otherwise the last one
            ADRouteBuilder.moveGuideIndex = nil
            local mx, mz = ADRouteBuilder.getMouseTerrainPos()
            if mx ~= nil and ADRouteBuilder.projectOnGuide ~= nil then
                local pr = ADRouteBuilder.projectOnGuide(mx, mz, nil, true)
                if pr ~= nil and pr.d <= ADRouteBuilder.GUIDE_SNAP_DISTANCE then
                    ADRouteBuilder.moveGuideIndex = pr.target
                end
            end
        end
        if ADRouteBuilder.copyData ~= nil then
            -- the copy starts again from where it is now
            local c = ADRouteBuilder.copyData
            c.baseDx, c.baseDz = c.dx, c.dz
            c.startX, c.startZ = ADRouteBuilder.getMouseTerrainPos()
        end
        return true
    elseif sym == Input.KEY_KP_5 then
        -- AD target on the selected point
        if ADRouteBuilder.copyData == nil then
            ADRouteBuilder.editTargetOfSelection()
        end
        return true
    elseif sym == Input.KEY_KP_7 or sym == Input.KEY_KP_9 then
        -- put the selection onto its guide line (Num9: and spread evenly)
        if ADRouteBuilder.copyData == nil then
            ADRouteBuilder.straightenSelection(sym == Input.KEY_KP_9)
        end
        return true
    elseif sym == Input.KEY_KP_divide then
        -- straight line between the two selected points
        if ADRouteBuilder.copyData == nil then
            ADRouteBuilder.startStraightLine()
        end
        return true
    elseif (sym == Input.KEY_KP_comma or sym == Input.KEY_KP_period) and ADRouteBuilder.resampleData ~= nil
        and ADRouteBuilder.resampleData.straight then
        ADRouteBuilder.cycleStraightKind()
        return true
    elseif (sym == Input.KEY_KP_comma or sym == Input.KEY_KP_period) and ADRouteBuilder.copyData == nil
        and ADRouteBuilder.resampleData == nil then
        -- the numpad decimal key (German keyboard: ",", others: "."): connections of the selection
        -- one-way / both ways / reverse, LCtrl = turn the direction around, LAlt = main / sub route
        -- turning the direction uses LCtrl: with LShift Windows turns the numpad key into "Del"
        -- (NumLock on), so LShift + Num, never arrives here
        if ADRouteBuilder.altPressed then
            ADRouteBuilder.toggleSelectionSubPrio()
        else
            ADRouteBuilder.changeSelectionConnection(ADRouteBuilder.ctrlPressed or shift)
        end
        return true
    elseif sym == Input.KEY_KP_0 and ADRouteBuilder.resampleData ~= nil then
        ADRouteBuilder.resampleData = nil
        return true
    elseif sym == Input.KEY_KP_0 then
        if ADRouteBuilder.copyData ~= nil then
            ADRouteBuilder.copyData = nil
        else
            ADRouteBuilder.selection = {}
        end
        return true
    elseif sym == Input.KEY_KP_8 or sym == Input.KEY_KP_2 or sym == Input.KEY_KP_4 or sym == Input.KEY_KP_6 then
        -- 0.01 m with LCtrl (LShift + numpad gives the arrow keys on Windows with NumLock on)
        local step = (shift or ADRouteBuilder.ctrlPressed) and 0.01 or 0.1
        local guide = ADRouteBuilder.getMoveGuide()
        local rot = guide ~= nil and guide.rot or ADRouteBuilder.rotation
        local dirX, dirZ = math.sin(rot), math.cos(rot)
        local rightX, rightZ = dirZ, -dirX
        local dx, dz = 0, 0
        if sym == Input.KEY_KP_8 then dx, dz = dirX, dirZ
        elseif sym == Input.KEY_KP_2 then dx, dz = -dirX, -dirZ
        elseif sym == Input.KEY_KP_6 then dx, dz = rightX, rightZ
        else dx, dz = -rightX, -rightZ end
        local c = ADRouteBuilder.copyData
        if c ~= nil then
            -- nudge the copy instead of the selection
            c.baseDx, c.baseDz = c.baseDx + dx * step, c.baseDz + dz * step
            c.dx, c.dz = c.dx + dx * step, c.dz + dz * step
        else
            commitMove(dx * step, dz * step)
        end
        return true
    end
    return false
end

-------------------------------------------------------------------------------------------------
-- copy: the selected points with their connections between each other (and their flags, e.g. sub
-- route) hang on the mouse and are created again with every left click; targets are not copied
-- (AutoDrive needs unique target names)
-------------------------------------------------------------------------------------------------
local function has(list, id)
    for _, v in ipairs(list or {}) do
        if v == id then
            return true
        end
    end
    return false
end

function ADRouteBuilder.toggleCopy()
    if ADRouteBuilder.copyData ~= nil then
        ADRouteBuilder.copyData = nil
        return
    end
    if not ADRouteBuilder.resolveAutoDrive() then
        return
    end
    local ids = {}
    for id, _ in pairs(ADRouteBuilder.selection) do
        if ADGraphManager:getWayPointById(id) ~= nil then
            table.insert(ids, id)
        end
    end
    if #ids == 0 then
        g_currentMission:showBlinkingWarning(getText("adrb_copyNothing", "select points first"), 2000)
        return
    end
    table.sort(ids)
    local index, points, cx, cz = {}, {}, 0, 0
    for i, id in ipairs(ids) do
        local wp = ADGraphManager:getWayPointById(id)
        index[id] = i
        table.insert(points, {x = wp.x, y = wp.y, z = wp.z, flags = wp.flags or 0})
        cx, cz = cx + wp.x, cz + wp.z
    end
    cx, cz = cx / #ids, cz / #ids
    local CF, CD, CR, CFR = ADRouteBuilder.CON_FORWARD, ADRouteBuilder.CON_DUAL, ADRouteBuilder.CON_REVERSE, ADRouteBuilder.CON_FORWARD_AND_REVERSE_BACK
    local connections = {}
    for _, aId in ipairs(ids) do
        local a = ADGraphManager:getWayPointById(aId)
        for _, bId in ipairs(a.out or {}) do
            local b = ADGraphManager:getWayPointById(bId)
            if b ~= nil and index[bId] ~= nil and bId ~= aId then
                local ia, ib = index[aId], index[bId]
                local back = has(b.out, aId)
                local fwdA = has(b.incoming, aId)      -- a -> b is a normal (forward) connection
                if not back then
                    table.insert(connections, {ia, ib, fwdA and CF or CR})
                elseif aId < bId then
                    -- both directions: handled once per pair
                    local fwdB = has(a.incoming, bId)
                    if fwdA and fwdB then
                        table.insert(connections, {ia, ib, CD})
                    elseif fwdA then
                        table.insert(connections, {ia, ib, CFR})
                    elseif fwdB then
                        table.insert(connections, {ib, ia, CFR})
                    else
                        table.insert(connections, {ia, ib, CR})
                        table.insert(connections, {ib, ia, CR})
                    end
                end
            end
        end
    end
    local mx, mz = ADRouteBuilder.getMouseTerrainPos()
    ADRouteBuilder.copyData = {points = points, connections = connections, cx = cx, cz = cz, startX = mx, startZ = mz,
        dx = 0, dz = 0, baseDx = 0, baseDz = 0, rot0 = ADRouteBuilder.rotation}
    ADRouteBuilder.dragMove = nil
    ADRouteBuilder.dragBox = nil
end

--- the copy at its current place (precise = heights with AutoDrive's raycast)
function ADRouteBuilder.getCopyRoute(precise)
    local c = ADRouteBuilder.copyData
    if c == nil then
        return nil
    end
    local d = ADRouteBuilder.rotation - c.rot0
    local cs, sn = math.cos(d), math.sin(d)
    local route = {points = {}, connections = c.connections, markers = {}, flags = {}, preview = {}}
    for i, q in ipairs(c.points) do
        local rx, rz = q.x - c.cx, q.z - c.cz
        local x = c.cx + rx * cs + rz * sn + c.dx
        local z = c.cz - rx * sn + rz * cs + c.dz
        local y
        if precise then
            y = ADRouteBuilder.getHeight(x, z)
        else
            y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
        end
        route.points[i] = {x, y or q.y, z}
        route.flags[i] = q.flags
    end
    return route
end

function ADRouteBuilder.pasteCopy()
    local route = ADRouteBuilder.getCopyRoute(true)
    if route == nil or #route.points == 0 then
        return
    end
    ADRBRouteEvent.sendEvent({points = route.points, connections = route.connections, markers = {}, flags = route.flags})
    ADRouteBuilder.lastActionWasMove = false
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format(getText("adrb_pasted", "%d points pasted"), #route.points))
end

--- deletes the selected AutoDrive points (Del, then Del again within 3 s to confirm).
--- AutoDrive renumbers all following points after each deletion, so the ids are sent from high to low
--- with AutoDrive's own event (also for multiplayer); map markers on these points are removed by AutoDrive.
ADRouteBuilder.DELETE_CONFIRM_MS = 3000
function ADRouteBuilder.deleteSelection()
    if not ADRouteBuilder.resolveAutoDrive() then
        return
    end
    local ids, markers = {}, 0
    for id, _ in pairs(ADRouteBuilder.selection) do
        if ADGraphManager:getWayPointById(id) ~= nil then
            table.insert(ids, id)
        end
    end
    if #ids == 0 then
        ADRouteBuilder.selection = {}
        return
    end
    local selected = {}
    for _, id in ipairs(ids) do
        selected[id] = true
    end
    for _, m in pairs(ADGraphManager:getMapMarkers() or {}) do
        if m.id ~= nil and selected[m.id] then
            markers = markers + 1
        end
    end
    local c = ADRouteBuilder.deleteConfirm
    if c == nil or c.count ~= #ids or g_time - c.time > ADRouteBuilder.DELETE_CONFIRM_MS then
        ADRouteBuilder.deleteConfirm = {count = #ids, time = g_time}
        local text = string.format(getText("adrb_deleteAsk", "delete %d points? press Del again"), #ids)
        if markers > 0 then
            text = text .. " " .. string.format(getText("adrb_deleteAskMarkers", "(%d targets are removed too)"), markers)
        end
        g_currentMission:showBlinkingWarning(text, ADRouteBuilder.DELETE_CONFIRM_MS)
        return
    end
    ADRouteBuilder.deleteConfirm = nil
    table.sort(ids, function(a, b) return a > b end)
    AutoDriveDeleteWayPointsEvent.sendEvent(ids)
    ADRouteBuilder.selection = {}
    -- the point numbers have changed: the undo lists would hit wrong points now
    ADRouteBuilder.moveStack = {}
    ADRouteBuilder.buildStack = {}
    ADRouteBuilder.lastActionWasMove = false
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format(getText("adrb_deleted", "%d points deleted"), #ids))
end

function ADRouteBuilder.getMoveModeText()
    local keys = {"adrb_moveFree", "adrb_moveAlong", "adrb_moveAcross"}
    return getText(keys[ADRouteBuilder.moveMode], "")
end

function ADRouteBuilder.selectLiveInfo()
    local text = string.format(getText("adrb_liveSelect", "%d points selected"), countSelection()) .. " - " .. ADRouteBuilder.getMoveModeText()
    if ADRouteBuilder.resampleData ~= nil then
        text = text .. " - " .. ADRouteBuilder.resampleInfo()
    end
    local c = ADRouteBuilder.copyData
    if c ~= nil then
        text = text .. " - " .. string.format(getText("adrb_liveCopy", "copy of %d points: offset %.2f m, rotated %.1f deg"), #c.points,
            math.sqrt(c.dx * c.dx + c.dz * c.dz), math.deg(ADRouteBuilder.rotation - c.rot0))
    end
    local m = ADRouteBuilder.dragMove
    if m ~= nil then
        text = text .. " - " .. string.format(getText("adrb_liveMove", "move %.2f m"), math.sqrt(m.dx * m.dx + m.dz * m.dz))
    end
    return text
end

function ADRouteBuilder.selectDraw()
    if not ADRouteBuilder.resolveAutoDrive() then
        return
    end
    local m = ADRouteBuilder.dragMove
    local dx, dz = 0, 0
    if m ~= nil then
        dx, dz = m.dx, m.dz
    end
    local wps = ADGraphManager:getWayPoints()
    for id, _ in pairs(ADRouteBuilder.selection) do
        local wp = wps[id]
        if wp ~= nil then
            local x, z = wp.x + dx, wp.z + dz
            local y = wp.y + 0.4
            DebugUtil.drawDebugLine(x - 0.5, y, z, x + 0.5, y, z, 1, 1, 0)
            DebugUtil.drawDebugLine(x, y, z - 0.5, x, y, z + 0.5, 1, 1, 0)
            DebugUtil.drawDebugLine(x, y - 0.3, z, x, y + 1.2, z, 1, 1, 0)
            if m ~= nil then
                -- ghost of the moved connections
                for _, list in ipairs({wp.out or {}, wp.incoming or {}}) do
                    for _, otherId in ipairs(list) do
                        local o = wps[otherId]
                        if o ~= nil then
                            local ox, oz = o.x, o.z
                            if ADRouteBuilder.selection[otherId] then
                                ox, oz = ox + dx, oz + dz
                            end
                            DebugUtil.drawDebugLine(x, y, z, ox, o.y + 0.4, oz, 1, 1, 0.3)
                        end
                    end
                end
            end
        end
    end
    if ADRouteBuilder.resampleData ~= nil then
        ADRouteBuilder.resampleDraw()
    end
    -- copy hanging on the mouse
    if ADRouteBuilder.copyData ~= nil then
        local route = ADRouteBuilder.getCopyRoute(false)
        if route ~= nil then
            ADRouteBuilder.drawPreview(route)
        end
        local c = ADRouteBuilder.copyData
        if c.startX ~= nil then
            m = {startX = c.startX, startZ = c.startZ}
        end
    end
    -- axis of the move
    local guide = ADRouteBuilder.getMoveGuide()
    if m ~= nil and ADRouteBuilder.moveMode > 1 and guide ~= nil then
        local ax, az = math.sin(guide.rot), math.cos(guide.rot)
        if ADRouteBuilder.moveMode == 3 then
            ax, az = az, -ax
        end
        local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, m.startX, 0, m.startZ) + 0.4
        DebugUtil.drawDebugLine(m.startX - ax * 30, y, m.startZ - az * 30, m.startX + ax * 30, y, m.startZ + az * 30, 1, 0.5, 0)
    end
    -- selection box on screen
    local b = ADRouteBuilder.dragBox
    if b ~= nil and (math.abs(b.x2 - b.x1) > 0.004 or math.abs(b.y2 - b.y1) > 0.004) then
        local x1, x2 = math.min(b.x1, b.x2), math.max(b.x1, b.x2)
        local y1, y2 = math.min(b.y1, b.y2), math.max(b.y1, b.y2)
        local t = 0.0015
        drawFilledRect(x1, y1, x2 - x1, y2 - y1, 1, 1, 0, 0.08)
        drawFilledRect(x1, y1, x2 - x1, t, 1, 1, 0, 0.9)
        drawFilledRect(x1, y2 - t, x2 - x1, t, 1, 1, 0, 0.9)
        drawFilledRect(x1, y1, t, y2 - y1, 1, 1, 0, 0.9)
        drawFilledRect(x2 - t, y1, t, y2 - y1, 1, 1, 0, 0.9)
    end
end

-------------------------------------------------------------------------------------------------
-- change the number of points of a segment (LAlt + wheel in "select / move"):
-- select the points of a curve / straight, or only its first and last point (the way between them
-- is searched). The segment keeps its shape (spline through the old points); the end points stay,
-- the inner points are replaced. Num Enter = apply, Num0 = cancel.
-------------------------------------------------------------------------------------------------
local function neighbours(wp)
    local list, seen = {}, {}
    for _, l in ipairs({wp.out or {}, wp.incoming or {}}) do
        for _, id in ipairs(l) do
            if not seen[id] then
                seen[id] = true
                table.insert(list, id)
            end
        end
    end
    -- reverse connections only exist in "out" of the other point
    return list
end

local function linked(a, b)
    return table.contains(a.out or {}, b.id) or table.contains(b.out or {}, a.id)
end

--- the selected chain as an ordered list of waypoints, or nil and an error text key
function ADRouteBuilder.getSelectedChain()
    local ids = {}
    for id, _ in pairs(ADRouteBuilder.selection) do
        if ADGraphManager:getWayPointById(id) ~= nil then
            table.insert(ids, id)
        end
    end
    if #ids < 2 then
        return nil, "adrb_resampleSelect"
    end
    local wps = ADGraphManager:getWayPoints()
    if #ids == 2 then
        -- only first and last point: shortest way between them (both directions of the connections)
        local startId, endId = ids[1], ids[2]
        local prev, queue, head = {[startId] = 0}, {startId}, 1
        -- reverse connections are only stored at the start point: build the reverse lookup once
        local into = {}
        for _, wp in pairs(wps) do
            for _, o in ipairs(wp.out or {}) do
                into[o] = into[o] or {}
                table.insert(into[o], wp.id)
            end
        end
        while head <= #queue and prev[endId] == nil and #queue < 5000 do
            local cur = queue[head]
            head = head + 1
            local wp = wps[cur]
            local cand = {}
            for _, o in ipairs(wp.out or {}) do table.insert(cand, o) end
            for _, o in ipairs(into[cur] or {}) do table.insert(cand, o) end
            for _, n in ipairs(cand) do
                if prev[n] == nil and wps[n] ~= nil then
                    prev[n] = cur
                    table.insert(queue, n)
                end
            end
        end
        if prev[endId] == nil then
            return nil, "adrb_resampleNoWay"
        end
        local chain, cur = {}, endId
        while cur ~= 0 do
            table.insert(chain, 1, wps[cur])
            cur = prev[cur]
        end
        if #chain > 300 then
            return nil, "adrb_resampleNoWay"
        end
        return chain
    end
    -- many points: they must form one line
    local inSel = {}
    for _, id in ipairs(ids) do
        inSel[id] = true
    end
    local deg, adj = {}, {}
    for _, id in ipairs(ids) do
        adj[id] = {}
        for _, other in ipairs(ids) do
            if other ~= id and linked(wps[id], wps[other]) then
                table.insert(adj[id], other)
            end
        end
        deg[id] = #adj[id]
    end
    local startId, ends = nil, 0
    for _, id in ipairs(ids) do
        if deg[id] == 1 then
            ends = ends + 1
            startId = startId or id
        elseif deg[id] ~= 2 then
            return nil, "adrb_resampleNotLine"
        end
    end
    if ends ~= 2 then
        return nil, "adrb_resampleNotLine"
    end
    local chain, last, cur = {}, nil, startId
    while cur ~= nil do
        table.insert(chain, wps[cur])
        local nextId = nil
        for _, n in ipairs(adj[cur]) do
            if n ~= last then
                nextId = n
            end
        end
        last, cur = cur, nextId
        if #chain > #ids then
            return nil, "adrb_resampleNotLine"
        end
    end
    if #chain ~= #ids then
        return nil, "adrb_resampleNotLine"
    end
    return chain
end

--- connection type between a and b seen from a: forward, dual, reverse, or nil (and swapped flag)
local function connType(a, b)
    local ab, ba = table.contains(a.out or {}, b.id), table.contains(b.out or {}, a.id)
    local abFwd = ab and table.contains(b.incoming or {}, a.id)
    local baFwd = ba and table.contains(a.incoming or {}, b.id)
    if ab and ba and abFwd and baFwd then
        return "dual"
    elseif ab and not ba then
        return abFwd and "fwd" or "rev"
    elseif ba and not ab then
        return baFwd and "fwdBack" or "revBack"
    end
    return "mixed"
end

--- Catmull-Rom spline through the points, sampled densely; returns {x, z, s} with arc length s
local function densePath(chain)
    local pts = {}
    for _, wp in ipairs(chain) do
        table.insert(pts, {wp.x, wp.z})
    end
    local out = {{pts[1][1], pts[1][2], 0}}
    local s = 0
    for i = 1, #pts - 1 do
        local p0, p1, p2, p3 = pts[math.max(1, i - 1)], pts[i], pts[i + 1], pts[math.min(#pts, i + 2)]
        local steps = 20
        for k = 1, steps do
            local t = k / steps
            local t2, t3 = t * t, t * t * t
            local function cr(a, b, c, d)
                return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
            end
            local x, z = cr(p0[1], p1[1], p2[1], p3[1]), cr(p0[2], p1[2], p2[2], p3[2])
            local prev = out[#out]
            s = s + MathUtil.vector2Length(x - prev[1], z - prev[2])
            table.insert(out, {x, z, s})
        end
    end
    return out, s
end

local function sampleAt(dense, s)
    for i = 2, #dense do
        if dense[i][3] >= s then
            local a, b = dense[i - 1], dense[i]
            local f = (b[3] - a[3]) > 0 and (s - a[3]) / (b[3] - a[3]) or 0
            return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f
        end
    end
    local last = dense[#dense]
    return last[1], last[2]
end

function ADRouteBuilder.resampleChange(delta)
    if not ADRouteBuilder.resolveAutoDrive() then
        return
    end
    local r = ADRouteBuilder.resampleData
    if r == nil then
        local chain, err = ADRouteBuilder.getSelectedChain()
        if chain == nil then
            g_currentMission:showBlinkingWarning(getText(err, "select a curve"), 3000)
            return
        end
        -- checks: inner points without branches, targets; one connection type along the chain
        local markers = {}
        for _, m in pairs(ADGraphManager:getMapMarkers() or {}) do
            markers[m.id] = m.name
        end
        local inChain = {}
        for _, wp in ipairs(chain) do
            inChain[wp.id] = true
        end
        local wps = ADGraphManager:getWayPoints()
        for i = 2, #chain - 1 do
            local wp = chain[i]
            if markers[wp.id] ~= nil then
                g_currentMission:showBlinkingWarning(string.format(getText("adrb_resampleMarker", "target '%s' lies inside the segment"), markers[wp.id]), 3500)
                return
            end
            for _, n in ipairs(neighbours(wp)) do
                if n ~= chain[i - 1].id and n ~= chain[i + 1].id then
                    g_currentMission:showBlinkingWarning(getText("adrb_resampleBranch", "a road branches off inside the segment"), 3500)
                    return
                end
            end
            for _, other in pairs(wps) do
                if not inChain[other.id] and table.contains(other.out or {}, wp.id) then
                    g_currentMission:showBlinkingWarning(getText("adrb_resampleBranch", "a road branches off inside the segment"), 3500)
                    return
                end
            end
        end
        local kind = nil
        for i = 1, #chain - 1 do
            local k = connType(chain[i], chain[i + 1])
            if kind == nil then
                kind = k
            elseif k ~= kind then
                kind = "mixed"
            end
        end
        if kind == "mixed" or kind == nil then
            g_currentMission:showBlinkingWarning(getText("adrb_resampleMixed", "the segment has mixed connection types"), 3500)
            return
        end
        if kind == "fwdBack" or kind == "revBack" then
            -- turn the chain round so that it runs in driving direction
            local rev = {}
            for i = #chain, 1, -1 do
                table.insert(rev, chain[i])
            end
            chain = rev
            kind = kind == "fwdBack" and "fwd" or "rev"
        end
        local dense, length = densePath(chain)
        r = {chain = chain, kind = kind, dense = dense, length = length, inner = #chain - 2, oldInner = #chain - 2,
            flags = #chain > 2 and (chain[2].flags or 0) or (chain[1].flags or 0)}
        ADRouteBuilder.resampleData = r
        if delta == 0 then
            return
        end
    end
    r.inner = math.max(0, math.min(200, r.inner + delta))
end

--- new inner points of the segment {x, y, z} (precise = AutoDrive's raycast heights)
--- straight line between two selected points (Num/): the number of points is changed with LAlt + wheel
--- like for a segment, Num, changes the connection (forward / backward / both ways), Num Enter creates it
ADRouteBuilder.STRAIGHT_KINDS = {"fwd", "back", "dual"}
function ADRouteBuilder.startStraightLine()
    if not ADRouteBuilder.resolveAutoDrive() then
        return
    end
    local ids = {}
    for id, _ in pairs(ADRouteBuilder.selection) do
        if ADGraphManager:getWayPointById(id) ~= nil then
            table.insert(ids, id)
        end
    end
    if #ids ~= 2 then
        g_currentMission:showBlinkingWarning(getText("adrb_straightTwo", "select exactly two points"), 2500)
        return
    end
    table.sort(ids)
    local a, b = ADGraphManager:getWayPointById(ids[1]), ADGraphManager:getWayPointById(ids[2])
    -- direction: from the end of a road to the start of a road if that is clear, otherwise a -> b
    local aOut, bOut = #(a.out or {}) > 0, #(b.out or {}) > 0
    if aOut and not bOut then
        a, b = b, a
    end
    local dense, length = densePath({a, b})
    local spacing = (ADRouteBuilder.params ~= nil and ADRouteBuilder.params.lineSpacing) or 5
    local segments = math.max(1, math.ceil(length / spacing - 0.001))
    ADRouteBuilder.resampleData = {chain = {a, b}, kind = "fwd", dense = dense, length = length, inner = segments - 1,
        oldInner = 0, flags = 0, straight = true}
end

--- Num, while a straight line is shown: forward -> other direction -> both ways
function ADRouteBuilder.cycleStraightKind()
    local r = ADRouteBuilder.resampleData
    if r == nil or not r.straight then
        return false
    end
    if r.kind == "fwd" then
        -- other direction: swap the end points
        r.chain = {r.chain[2], r.chain[1]}
        r.dense, r.length = densePath(r.chain)
        r.kind = "fwdSwapped"
    elseif r.kind == "fwdSwapped" then
        r.chain = {r.chain[2], r.chain[1]}
        r.dense, r.length = densePath(r.chain)
        r.kind = "dual"
    else
        r.kind = "fwd"
    end
    return true
end

function ADRouteBuilder.getResamplePoints(precise, data)
    local r = data or ADRouteBuilder.resampleData
    local pts = {}
    local n = r.inner + 1
    for k = 1, r.inner do
        local x, z = sampleAt(r.dense, r.length * k / n)
        local y
        if precise then
            y = ADRouteBuilder.getHeight(x, z)
        else
            y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
        end
        table.insert(pts, {x, y, z})
    end
    return pts
end

function ADRouteBuilder.getResampleCon(r)
    if r.kind == "dual" then
        return ADRouteBuilder.CON_DUAL
    elseif r.kind == "rev" then
        return ADRouteBuilder.CON_REVERSE
    end
    return ADRouteBuilder.CON_FORWARD
end

function ADRouteBuilder.resampleDraw()
    local r = ADRouteBuilder.resampleData
    if r == nil then
        return
    end
    local first, last = r.chain[1], r.chain[#r.chain]
    local route = {points = {{first.x, first.y, first.z}}, connections = {}, markers = {}, preview = {}}
    for _, p in ipairs(ADRouteBuilder.getResamplePoints(false)) do
        table.insert(route.points, p)
    end
    table.insert(route.points, {last.x, last.y, last.z})
    local con = ADRouteBuilder.getResampleCon(r)
    for i = 1, #route.points - 1 do
        table.insert(route.connections, {i, i + 1, con})
    end
    ADRouteBuilder.drawPreview(route)
end

function ADRouteBuilder.resampleInfo()
    local r = ADRouteBuilder.resampleData
    if r == nil then
        return nil
    end
    if r.straight then
        return string.format(getText("adrb_liveStraight", "straight %.1f m: %d inner points, spacing %.2f m, %s | Num, = connection, left click / Num Enter = create, Num0 = cancel"),
            r.length, r.inner, r.length / (r.inner + 1),
            getText(r.kind == "dual" and "adrb_conDual" or "adrb_conForward", "connection"))
    end
    return string.format(getText("adrb_liveResample", "segment %.1f m: %d inner points (before %d), spacing %.2f m | left click / Num Enter = apply, Num0 = cancel"),
        r.length, r.inner, r.oldInner, r.length / (r.inner + 1))
end

--- replaces the inner points: delete the old ones (ids high to low), then create the new ones between
--- the two end points (their ids move down by the number of deleted points with a smaller id)
function ADRouteBuilder.resampleApply()
    local r = ADRouteBuilder.resampleData
    ADRouteBuilder.resampleData = nil
    if r == nil or not ADRouteBuilder.resolveAutoDrive() then
        return
    end
    -- the graph may have changed meanwhile
    for _, wp in ipairs(r.chain) do
        local now = ADGraphManager:getWayPointById(wp.id)
        if now == nil or now ~= wp then
            g_currentMission:showBlinkingWarning(getText("adrb_resampleChanged", "the network has changed, select again"), 3000)
            return
        end
    end
    local newPoints = ADRouteBuilder.getResamplePoints(true, r)
    local deleted = {}
    for i = 2, #r.chain - 1 do
        table.insert(deleted, r.chain[i].id)
    end
    table.sort(deleted, function(a, b) return a > b end)
    local function newId(id)
        local n = 0
        for _, d in ipairs(deleted) do
            if d < id then
                n = n + 1
            end
        end
        return id - n
    end
    local firstId, lastId = newId(r.chain[1].id), newId(r.chain[#r.chain].id)
    if #deleted > 0 then
        AutoDriveDeleteWayPointsEvent.sendEvent(deleted)
    else
        -- no inner points so far: remove the direct connection between the end points first
        local a, b = r.chain[1], r.chain[#r.chain]
        local ab, ba = table.contains(a.out or {}, b.id), table.contains(b.out or {}, a.id)
        if ab then
            ADGraphManager:toggleConnectionBetween(a, b, false, false)
        end
        if ba then
            ADGraphManager:toggleConnectionBetween(b, a, false, false)
        end
    end
    local con = ADRouteBuilder.getResampleCon(r)
    local route = {points = newPoints, connections = {}, markers = {}, flags = {}}
    local seq = {-firstId}
    for i = 1, #newPoints do
        table.insert(seq, i)
        route.flags[i] = r.flags
    end
    table.insert(seq, -lastId)
    for i = 1, #seq - 1 do
        table.insert(route.connections, {seq[i], seq[i + 1], con})
    end
    ADRBRouteEvent.sendEvent(route)
    ADRouteBuilder.selection = {}
    ADRouteBuilder.moveStack = {}
    ADRouteBuilder.buildStack = {}
    ADRouteBuilder.lastActionWasMove = false
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format(getText(r.straight and "adrb_straightDone" or "adrb_resampled", "segment now has %d inner points (before %d)"), #newPoints, r.oldInner))
end

-------------------------------------------------------------------------------------------------
-- connections of the selection: Num, = one-way / both ways / reverse, LCtrl + Num, = turn the
-- direction around, LAlt + Num, = main / sub route. Uses AutoDrive's own functions with network events
-- (ADGraphManager:setConnectionBetween, ADGraphManager:setWayPointFlags). Undo: LCtrl + LAlt + Z/Y.
-------------------------------------------------------------------------------------------------
local CON_DIR = {fwd = 1, dual = 3, rev = 4}

--- the connections of the selection as {from, to, kind} (kind fwd / dual / rev / mixed) plus the points
local function selectionEdges()
    local chain = ADRouteBuilder.getSelectedChain()
    local edges, points = {}, {}
    local function add(a, b)
        local t = connType(a, b)
        if t == "fwdBack" then
            table.insert(edges, {from = b, to = a, kind = "fwd"})
        elseif t == "revBack" then
            table.insert(edges, {from = b, to = a, kind = "rev"})
        else
            table.insert(edges, {from = a, to = b, kind = t})
        end
    end
    if chain ~= nil then
        -- the chain runs in the direction most of its one-way connections already have
        local score = 0
        for i = 1, #chain - 1 do
            local t = connType(chain[i], chain[i + 1])
            if t == "fwd" or t == "rev" then
                score = score + 1
            elseif t == "fwdBack" or t == "revBack" then
                score = score - 1
            end
        end
        if score < 0 then
            local r = {}
            for i = #chain, 1, -1 do
                table.insert(r, chain[i])
            end
            chain = r
        end
        for i = 1, #chain - 1 do
            add(chain[i], chain[i + 1])
        end
        points = chain
    else
        local ids = {}
        for id, _ in pairs(ADRouteBuilder.selection) do
            local wp = ADGraphManager:getWayPointById(id)
            if wp ~= nil then
                table.insert(ids, id)
                table.insert(points, wp)
            end
        end
        table.sort(ids)
        for i = 1, #ids do
            for j = i + 1, #ids do
                local a, b = ADGraphManager:getWayPointById(ids[i]), ADGraphManager:getWayPointById(ids[j])
                if linked(a, b) then
                    add(a, b)
                end
            end
        end
    end
    return edges, points
end

local function pushConUndo(edges, flags)
    local undo = {kind = "con", edges = {}, flags = flags}
    for _, e in ipairs(edges) do
        if CON_DIR[e.kind] ~= nil then
            table.insert(undo.edges, {e.from.id, e.to.id, CON_DIR[e.kind]})
        end
    end
    table.insert(ADRouteBuilder.moveStack, undo)
    if #ADRouteBuilder.moveStack > 30 then
        table.remove(ADRouteBuilder.moveStack, 1)
    end
    ADRouteBuilder.lastActionWasMove = true
end

--- undo of a connection / route type change (called from undoLastMove)
function ADRouteBuilder.undoConChange(undo)
    for _, e in ipairs(undo.edges or {}) do
        local a, b = ADGraphManager:getWayPointById(e[1]), ADGraphManager:getWayPointById(e[2])
        if a ~= nil and b ~= nil then
            ADGraphManager:setConnectionBetween(a, b, e[3])
        end
    end
    for _, f in ipairs(undo.flags or {}) do
        if ADGraphManager:getWayPointById(f[1]) ~= nil then
            ADGraphManager:setWayPointFlags(f[1], f[2])
        end
    end
end

--- Num, : one-way -> both ways -> reverse -> one-way (flip = true: turn the direction around)
function ADRouteBuilder.changeSelectionConnection(flip)
    if not ADRouteBuilder.resolveAutoDrive() or ADGraphManager.setConnectionBetween == nil then
        return
    end
    local edges = selectionEdges()
    if #edges == 0 then
        g_currentMission:showBlinkingWarning(getText("adrb_conNone", "select connected points first"), 2500)
        return
    end
    local count = {}
    for _, e in ipairs(edges) do
        count[e.kind] = (count[e.kind] or 0) + 1
    end
    local newKind
    if flip then
        if (count.fwd or 0) + (count.rev or 0) == 0 then
            g_currentMission:showBlinkingWarning(getText("adrb_conFlipDual", "both-way connections have no direction"), 2500)
            return
        end
    elseif count.fwd == #edges then
        newKind = "dual"
    elseif count.dual == #edges then
        newKind = "rev"
    else
        newKind = "fwd"
    end
    pushConUndo(edges, nil)
    for _, e in ipairs(edges) do
        if flip then
            if e.kind == "fwd" or e.kind == "rev" then
                ADGraphManager:setConnectionBetween(e.to, e.from, CON_DIR[e.kind])
            end
        else
            ADGraphManager:setConnectionBetween(e.from, e.to, CON_DIR[newKind])
        end
    end
    local key = flip and "adrb_conFlipped" or ({fwd = "adrb_conFwd", dual = "adrb_selConDual", rev = "adrb_conRev"})[newKind]
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format(getText(key, "%d connections changed"), #edges))
end

--- LAlt + Num, : main route <-> sub route for the selected points
function ADRouteBuilder.toggleSelectionSubPrio()
    if not ADRouteBuilder.resolveAutoDrive() or ADGraphManager.setWayPointFlags == nil then
        return
    end
    local _, points = selectionEdges()
    if #points == 0 then
        g_currentMission:showBlinkingWarning(getText("adrb_conNone", "select connected points first"), 2500)
        return
    end
    local sub = AutoDrive ~= nil and AutoDrive.FLAG_SUBPRIO or 1
    local allSub = true
    for _, wp in ipairs(points) do
        if bit32.band(wp.flags or 0, sub) == 0 then
            allSub = false
        end
    end
    local flags = {}
    for _, wp in ipairs(points) do
        local f = wp.flags or 0
        table.insert(flags, {wp.id, f})
        local isSub = bit32.band(f, sub) > 0
        if allSub and isSub then
            ADGraphManager:setWayPointFlags(wp.id, f - sub)
        elseif not allSub and not isSub then
            ADGraphManager:setWayPointFlags(wp.id, f + sub)
        end
    end
    pushConUndo({}, flags)
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format(getText(allSub and "adrb_conMain" or "adrb_conSub", "%d points changed"), #points))
end
