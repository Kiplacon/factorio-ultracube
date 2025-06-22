local cube_search = require("__Ultracube__/scripts/cube_search")
local remote_ownership = {}
local max_timeout_ticks = 60 * 60

local function get_ownership_table()
  local t = storage.remote_ownership_table
  if not t then
    t = {}
    storage.remote_ownership_table = t
    storage.remote_ownership_next_id = 1
    storage.remote_ownership_free_list = {}
  end
  return t, storage.remote_ownership_free_list
end

function remote_ownership.create_token(item, count, timeout_ticks, data)
  local ownership_table, free_list = get_ownership_table()
  local token_id, _ = next(free_list)
  if token_id then
    free_list[token_id] = nil
  else
    token_id = storage.remote_ownership_next_id
    storage.remote_ownership_next_id = token_id + 1
  end

  ownership_table[token_id] = {
    item = item,
    count = count or 1,
    surface = data.surface,
    spill_position = data.spill_position,
    position = data.position,
    velocity = data.velocity,
    height = data.height,
    timeout = math.min(timeout_ticks or 1, max_timeout_ticks),
  }
  return token_id
end

function remote_ownership.update_token(token_id, timeout_ticks, update_data)
  if token_id == 0 then
    return
  end
  local ownership_table, _ = get_ownership_table()
  local data = ownership_table[token_id]
  if not data then
    return
  end
  data.surface = update_data.surface or data.surface
  data.spill_position = update_data.spill_position or data.spill_position
  data.position = update_data.position or data.position
  data.velocity = update_data.velocity or data.velocity
  data.height = update_data.height or data.height
  if timeout_ticks then
    data.timeout = math.min(timeout_ticks or 1, max_timeout_ticks)
  end
end

function remote_ownership.release_token(token_id)
  if token_id == 0 then
    return nil
  end
  local ownership_table, free_list = get_ownership_table()
  local data = ownership_table[token_id]
  if not data then
    if token_id < storage.remote_ownership_next_id and not free_list[token_id] then
      free_list[token_id] = true
    end
    return nil
  end
  local item = data.item
  local count = data.count
  ownership_table[token_id] = nil
  free_list[token_id] = true
  return {name = item, count = count}
end

function remote_ownership.tick()
  local ownership_table = storage.remote_ownership_table
  if not ownership_table then
    return
  end

  for token_id, data in pairs(ownership_table) do
    local timeout = data.timeout
    timeout = timeout - 1
    if timeout > 0 then
      data.timeout = timeout
    else
      local surface = data.surface
      if not surface or not surface.valid then
        surface = game.surfaces[1]
      end
      local position = data.spill_position or data.position or {x = 0, y = 0}
      local spill = surface.spill_item_stack {
          position = position,
          stack = {name = data.item, count = data.count},
          allow_belts = false,
      }
      for _, e in ipairs(spill) do
        cube_search.hint_entity(e)
      end
      ownership_table[token_id] = nil
    end
  end
end

return remote_ownership