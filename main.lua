
local vector = require "vector"

player = {
  gameobject = nil,
}

keys_directions = {
  w = 'up',
  a = 'left',
  s = 'down',
  d = 'right',
}

directions_vectors = {
  up = {x = 0,y = -1},
  down = {x = 0, y = 1},
  left = {x = -1, y = 0},
  right = {x = 1, y = 0},
}

object_types_speeds = {
  player = 100,
  ship1 = 30,
  ship2 = 30,
  ship3 = 30,
  ship4 = 30,
}

object_types_image_files = {
  player = 'ship5.png',
  ship1 = 'ship1.png',
  ship2 = 'ship2.png',
  ship3 = 'ship3.png',
  ship4 = 'ship4.png',
}

object_types_images = {}

enemy_spawn_timer = 0
enemy_spawn_interval = 5

enemy_types = {
  'ship1',
  'ship2',
  'ship3',
  'ship4',
}

world_objects = {}

-- UTIL

function format_vector(v)
  return v.x..','..v.y
end

-- GAME

function make_gameobject(object_category, object_type)
  return {
    category = object_category,
    type = object_type,
    position = {
      x = 100,
      y = 100,
    },
  }
end

function move_gameobject(object, movement_vector, magnitude)
  local direction = vector.normalise(movement_vector)
  local position_change = vector.multiply_scalar(direction, magnitude)
  object.position = vector.add(object.position, position_change)
end

-- LOVE CALLBACKS

function love.load()
  -- init graphics
  -- love.graphics.setBackgroundColor(104, 136, 248)
  -- load images
  for object_type, filename in pairs(object_types_image_files) do
    object_types_images[object_type] = love.graphics.newImage(filename)
  end

  -- create player
  local player_gameobject = make_gameobject('player', 'player')
  player.gameobject = player_gameobject
  table.insert(world_objects, player_gameobject)
end

function love.draw()
  for index, object in pairs(world_objects) do
    love.graphics.draw(object_types_images[object.type], object.position.x, object.position.y)
  end
end

function love.update(dt)
  enemy_spawn_timer = enemy_spawn_timer + dt
  if enemy_spawn_timer > enemy_spawn_interval then
    -- generate random enemy type
    enemy_type_to_spawn = enemy_types[math.random(1,4)]
    print('spawing enemy of type '..enemy_type_to_spawn)
    enemy = make_gameobject('enemy', enemy_type_to_spawn)
    table.insert(world_objects, enemy)
    -- reset timer
    enemy_spawn_timer = enemy_spawn_timer - enemy_spawn_interval
  end

  -- update player based on input
  local player_movement = {x = 0, y = 0}
  for key, direction in pairs(keys_directions) do
    if love.keyboard.isDown(key) then
      local direction = keys_directions[key]
      local movement_vector = directions_vectors[direction]
      player_movement = vector.add(player_movement, movement_vector)
    end
  end
  local player_speed = object_types_speeds.player
  move_gameobject(player.gameobject, player_movement, player_speed * dt)

  -- update enemies
  for index, object in pairs(world_objects) do
    if object.category == 'enemy' then
      local object_speed = object_types_speeds[object.type]
      local direction_to_player = vector.subtract(player.gameobject.position, object.position)
      move_gameobject(object, direction_to_player, object_speed * dt)
    end
  end
end
