--
-- AutoDrive Route Builder - network event
-- Transports a complete route (points, connections, markers) from the building client to the server.
-- The server creates the route on its own AutoDrive graph and forwards the event to all clients,
-- which create the same route on their graph. All machines start from the same waypoint count,
-- so the ids of the new waypoints are identical everywhere (same principle AutoDrive uses itself).
--

ADRBRouteEvent = {}
local ADRBRouteEvent_mt = Class(ADRBRouteEvent, Event)

InitEventClass(ADRBRouteEvent, "ADRBRouteEvent")

function ADRBRouteEvent.emptyNew()
    return Event.new(ADRBRouteEvent_mt)
end

---@param route table {points = {{x,y,z},...}, connections = {{a,b,type},...}, markers = {{index,name},...}}
function ADRBRouteEvent.new(route)
    local self = ADRBRouteEvent.emptyNew()
    self.route = route
    return self
end

function ADRBRouteEvent:writeStream(streamId, connection)
    local route = self.route
    streamWriteUInt16(streamId, #route.points)
    for i, p in ipairs(route.points) do
        streamWriteFloat32(streamId, p[1])
        streamWriteFloat32(streamId, p[2])
        streamWriteFloat32(streamId, p[3])
        -- AutoDrive flags of the point (e.g. sub route), used when copying points
        streamWriteUInt8(streamId, route.flags ~= nil and route.flags[i] or 0)
    end
    streamWriteUInt16(streamId, #route.connections)
    for _, c in ipairs(route.connections) do
        -- Int32: negative values are existing AutoDrive waypoints
        streamWriteInt32(streamId, c[1])
        streamWriteInt32(streamId, c[2])
        streamWriteUIntN(streamId, c[3], 4)
    end
    streamWriteUInt16(streamId, #route.markers)
    for _, m in ipairs(route.markers) do
        streamWriteUInt16(streamId, m[1])
        streamWriteString(streamId, m[2])
    end
end

function ADRBRouteEvent:readStream(streamId, connection)
    local route = {points = {}, connections = {}, markers = {}, flags = {}}
    local n = streamReadUInt16(streamId)
    for i = 1, n do
        local x = streamReadFloat32(streamId)
        local y = streamReadFloat32(streamId)
        local z = streamReadFloat32(streamId)
        route.points[i] = {x, y, z}
        route.flags[i] = streamReadUInt8(streamId)
    end
    n = streamReadUInt16(streamId)
    for i = 1, n do
        local a = streamReadInt32(streamId)
        local b = streamReadInt32(streamId)
        local t = streamReadUIntN(streamId, 4)
        route.connections[i] = {a, b, t}
    end
    n = streamReadUInt16(streamId)
    for i = 1, n do
        local index = streamReadUInt16(streamId)
        local name = streamReadString(streamId)
        route.markers[i] = {index, name}
    end
    self.route = route
    self:run(connection)
end

function ADRBRouteEvent:run(connection)
    if g_server ~= nil and connection ~= nil and not connection:getIsServer() then
        -- request from a client: build on the server and forward to all clients
        ADRouteBuilder.applyRoute(self.route)
        g_server:broadcastEvent(ADRBRouteEvent.new(self.route), false)
    else
        -- from the server: build on this client
        ADRouteBuilder.applyRoute(self.route)
    end
end

function ADRBRouteEvent.sendEvent(route)
    if g_server ~= nil then
        -- single player / host: build locally and forward to the clients
        ADRouteBuilder.applyRoute(route)
        g_server:broadcastEvent(ADRBRouteEvent.new(route), false)
    else
        g_client:getServerConnection():sendEvent(ADRBRouteEvent.new(route))
    end
end
