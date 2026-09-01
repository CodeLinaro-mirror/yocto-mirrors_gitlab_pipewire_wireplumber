-- WirePlumber
--
-- Copyright © 2024 Collabora Ltd.
--
-- SPDX-License-Identifier: MIT

local cutils = require ("common-utils")

local module = {}

function module.get_session_priority (node_props)
  local priority = node_props ["priority.session"]
  -- fallback to driver priority if session priority is not set
  if not priority then
    priority = node_props ["priority.driver"]
  end
  return math.tointeger (priority) or 0
end

-- Builds the key that module.compare_nodes() ranks a node by:
--
--  priority       the session priority, or the driver priority if unset
--  route_priority the priority of the device route that carries this node
function module.get_node_ranking (node_props)
  local ranking = {
    priority = module.get_session_priority (node_props),
    route_priority = 0,
  }

  local card_profile_device = node_props ["card.profile.device"]
  local device_id = node_props ["device.id"]

  -- if the node does not have an associated device, it has no route
  if not card_profile_device or not device_id then
    return ranking
  end

  -- Get the device
  local devices_om = cutils.get_object_manager ("device")
  local device = devices_om:lookup {
    Constraint { "bound-id", "=", device_id, type = "gobject" },
  }

  if not device then
    return ranking
  end

  -- Get the priority of the associated route
  for p in device:iterate_params ("Route") do
    local route = cutils.parseParam (p, "Route")
    if route and (route.device == tonumber (card_profile_device)) then
      ranking.route_priority = route.priority
      break
    end
  end

  return ranking
end

-- Returns true if node ranking 'a' should be preferred over ranking 'b'.
function module.compare_nodes (a, b)
  if a.priority ~= b.priority then
    return a.priority > b.priority
  else
    return a.route_priority > b.route_priority
  end
end

return module
