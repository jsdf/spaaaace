
-- import our vector math functions module
local vector = require "vector"


-- IMMUTABLE GLOBALS
-- stuff which never changes

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
  ship2 = 50,
  ship3 = 60,
  ship4 = 40,
}

object_types_projectile_speeds = {
  player = 200,
  ship1 = 200,
  ship2 = 200,
  ship3 = 200,
  ship4 = 200,
}

ship_velocity_bias = {x = 2, y = 1} -- ships move faster in x dimension

object_types_cooldown_times = {
  player = 0.2,
  ship1 = 1,
  ship2 = 1,
  ship3 = 1,
  ship4 = 1,
}

enemy_types_points = {
  ship1 = 3500,
  ship2 = 2000,
  ship3 = 1500,
  ship4 = 4000,
}

enemy_types = {
  'ship1',
  'ship2',
  'ship3',
  'ship4',
}

enemy_spawn_interval = 3
max_stars = 100 -- how many stars we want
hitbox_scale = 0.85 -- scale hitboxes by this much
object_scale = 1 -- scale drawn objects
offscreen_space = 200 -- distance objects can go out of bounds before being destroyed

-- graphics

font_filepath = 'fonts/slkscr.ttf'

object_types_image_files = {
  player = 'ship5.png',
  ship1 = 'ship1.png',
  ship2 = 'ship2.png',
  ship3 = 'ship3.png',
  ship4 = 'ship4.png',
  player_projectile = 'projectile2.png',
  enemy_projectile = 'projectile3.png',
}

-- MUTABLE GLOBALS
-- stuff which changes at runtime

world_objects = {}

game = {
  enemy_spawn_timer = 0,
  time = 0,
  score = 0,
  state = 'title',
}

player = nil -- the player game object, we'll set this later

-- graphics stuff (only loaded once)

object_types_images = {}
object_types_dimensions = {}
stars = {}


-- LOVE CALLBACKS

-- startup
function love.load()
  math.randomseed(os.time()) -- seed random number generator with current time

  init_graphics()
  game.state = 'title'
end

-- draw a frame
function love.draw()
  -- always draw background
  draw_background()

  if game.state == 'running' or game.state == 'paused' then
    draw_world_objects()
  end

  if game.state == 'title' then
    draw_title('spaaaace')
  elseif game.state == 'gameover' then
    draw_title('player is kill')
  elseif game.state == 'paused' then
    draw_title('paaaaused')
  end

  draw_score()
end

-- update the world
function love.update(dt)
  if game.state ~= 'running' then
    return -- don't do anything
  end

  game.time = game.time + dt

  update_destroy_out_of_bounds_objects()
  update_spawn_enemies(dt)
  update_player(dt)
  update_world_objects(dt)
  update_detect_collisions()
end

function love.keypressed(key)
  if key == 'escape' then
    love.event.quit()
  elseif key == 'tab' then
    if game.state == 'running' then
      game.state = 'paused'
    elseif game.state == 'paused' then
      game.state = 'running'
    end
  else -- pressed the 'any' key
    if game.state == 'title' or game.state == 'gameover' then
      game_reset()
    end
  end
end


-- GAME

function game_reset()
  -- new world
  world_objects = {}
  -- reset all game state
  game.time = 0
  game.score = 0
  game.enemy_spawn_timer = 0
  game.state = 'running'

  game_spawn_player()
end

function game_spawn_player()
  player = make_object('player', 'player')
  -- start in the middle of the screen
  local screen_width, screen_height = love.graphics.getDimensions()
  player.position = {x = screen_width/2, y = screen_height/2}
  -- add to world
  table.insert(world_objects, player)
end

function game_spawn_enemy(enemy_type)
  local enemy = make_object('enemy', enemy_type)
  -- give enemy random position at top of screen
  local screen_width = love.graphics.getWidth()
  enemy.position = {
    x = math.random(0, screen_width),
    y = -100, -- off top of screen
  }
  -- facing downward
  enemy.rotation = math.rad(180) -- convert degrees to radians
  -- add to world
  table.insert(world_objects, enemy)
  print('spawing '..format_object_pos(enemy))
end

function game_spawn_projectile(projectile_type, owner, direction)
  local projectile = make_object('projectile', projectile_type)
  projectile.owner = owner
  projectile.position = owner.position
  projectile.direction = direction
  -- calculate rotation from direction vector
  projectile.rotation = math.atan2(direction.x, direction.y) + math.rad(180)
  -- add to world
  table.insert(world_objects, projectile)
  print('spawing '..format_object_pos(projectile))
end

function game_player_fire_projectile()
  game_spawn_projectile(
    'player_projectile',
    player,
    directions_vectors.up
  )
  player.last_shot = game.time
end

function game_enemy_fire_projectile(enemy)
  game_spawn_projectile(
    'enemy_projectile',
    enemy,
    directions_vectors.down
  )
  enemy.last_shot = game.time
end

function game_destroy_enemy(enemy)
  remove_item(world_objects, enemy)
  game.score = game.score + enemy_types_points[enemy.type]
end

function game_destroy_projectile(projectile)
  remove_item(world_objects, projectile)
end

function game_destroy_player()
  game.state = 'gameover'
end

function init_graphics()
  -- load images
  for object_type, filename in pairs(object_types_image_files) do
    local object_image = love.graphics.newImage('images/'..filename)
    object_types_images[object_type] = object_image
    -- use image dimensions for object dimensions
    object_types_dimensions[object_type] = {
      width = object_image:getWidth(),
      height = object_image:getHeight(),
    }
  end

  love.graphics.setNewFont(font_filepath, 36)

  -- create starfield (from https://love2d.org/wiki/love.graphics.point)
  for i = 1, max_stars do -- generate the coords of our stars
    local x = math.random(5, love.graphics.getWidth()-5) -- generate a "random" number for the x coord of this star
    local y = math.random(5, love.graphics.getHeight()-5) -- both coords are limited to the screen size, minus 5 pixels of padding
    stars[i] = {x, y} -- stick the values into the table
   end
end

function update_world_objects(dt)
  for index, object in pairs(world_objects) do
    if object.category == 'enemy' then
      update_enemy(object, dt)
    elseif object.category == 'projectile' then
      update_projectile(object, dt)
    end
  end
end

function update_enemy(enemy, dt)
  local enemy_speed = object_types_speeds[enemy.type]
  -- enemies move downward
  local enemy_movement_vector = directions_vectors.down
  -- some enemy types also move toward player (but only in the x dimension)
  if enemy.type == 'ship3' or enemy.type == 'ship2' then
    local vector_toward_player = vector.normalise(vector.subtract(player.position, enemy.position))
    local vector_toward_player_in_x_dimension = {
      x = vector_toward_player.x,
      y = 0
    }
    enemy_movement_vector = vector.add(enemy_movement_vector, vector_toward_player_in_x_dimension)
  end
  move_ship(enemy, enemy_movement_vector, enemy_speed * dt)

  if game.time > enemy.last_shot + object_types_cooldown_times[enemy.type] then
    game_enemy_fire_projectile(enemy)
  end
end

function update_projectile(projectile, dt)
  local projectile_speed = object_types_projectile_speeds[projectile.owner.type]
  move_object(projectile, projectile.direction, projectile_speed * dt)
end

function update_player(dt)
  -- update player based on input
  local player_movement = {x = 0, y = 0}
  for key, direction in pairs(keys_directions) do
    if love.keyboard.isDown(key) then
      local movement_vector = directions_vectors[direction]
      player_movement = vector.add(player_movement, movement_vector)
    end
  end

  if player_movement.x ~= 0 or player_movement.y ~= 0 then
    local player_speed = object_types_speeds.player
    move_ship(player, player_movement, player_speed * dt)

    -- clamp player position to screen bounds.
    -- the screen bounds need to be padded inwards by half player dimensions 
    -- so the player can't go half outside the screen
    local screen_width, screen_height = love.graphics.getDimensions()
    local player_dimensions = object_types_dimensions.player

    local min_x = 0 + player_dimensions.width/2 -- left bound
    local max_x = screen_width - player_dimensions.width/2 -- right bound
    local min_y = 0 + player_dimensions.height/2 -- top bound
    local max_y = screen_height - player_dimensions.height/2 -- bottom bound

    player.position = {
      x = clamp(player.position.x, min_x, max_x),
      y = clamp(player.position.y, min_y, max_y),
    }
  end

  if love.keyboard.isDown(' ') then
    if game.time > player.last_shot + object_types_cooldown_times.player then
      game_player_fire_projectile()
    end
  end
end

function update_detect_collisions()
  for i, object in pairs(world_objects) do
    for j, other_object in pairs(world_objects) do
      if object ~= other_object then
        if collision(object, other_object) then
          print(format_object_pos(object)..' collided with '..format_object_pos(other_object))
          if object.category == 'player' and other_object.category == 'enemy' then
            game_destroy_player()
          elseif object.category == 'projectile' then
            if object.type == 'player_projectile' and other_object.category == 'enemy' then
              game_destroy_enemy(other_object)
              game_destroy_projectile(object)
            elseif object.type == 'enemy_projectile' and other_object.category == 'player' then
              game_destroy_player()
            end
          end
        end
      end
    end
  end
end

function update_spawn_enemies(dt)  
  game.enemy_spawn_timer = game.enemy_spawn_timer + dt
  -- is it time to spawn an enemy?
  if game.enemy_spawn_timer > enemy_spawn_interval then
    -- generate random enemy type
    local enemy_type_to_spawn = enemy_types[math.random(1,4)]
    game_spawn_enemy(enemy_type_to_spawn)
    -- reset timer
    game.enemy_spawn_timer = game.enemy_spawn_timer - enemy_spawn_interval
  end
end

function update_destroy_out_of_bounds_objects()
  local screen_width, screen_height = love.graphics.getDimensions()

  for index, object in pairs(world_objects) do
    if (
        object.position.x < 0 - offscreen_space 
        or object.position.x > screen_width + offscreen_space
        or object.position.y < 0 - offscreen_space 
        or object.position.y > screen_height + offscreen_space
    ) then
      if object.category == 'player' then
        error('player went out of bounds')
      end
      print('removing '..format_object_pos(object))
      world_objects[index] = nil
    end
  end
  compact(world_objects)
end

function draw_background()
  -- space is black
  love.graphics.setBackgroundColor(0, 0, 0)

  -- draw stars
  love.graphics.setColor(200, 200, 200) -- the stars aren't so bright
  local screen_height = love.graphics.getHeight()

  for i = 1, #stars do -- loop through all of our stars
    local star_x = stars[i][1]
    local star_y = stars[i][2]
    -- elapsed game time determines how far stars have scrolled
    local stars_offset = game.time * 500    
    -- use modulus to make stars wrap around when they scroll farther than screen height
    star_y = (star_y + stars_offset) % screen_height
    -- draw star
    love.graphics.point(star_x, star_y)
  end
end

function draw_world_objects()
  -- projectile layer
  for index, object in pairs(world_objects) do
    if object.category == 'projectile' then
      draw_object(object)
    end
  end
  -- ship layer
  for index, object in pairs(world_objects) do
    if object.category ~= 'projectile' then
      draw_object(object)
    end
  end
end

function draw_object(object)
  local object_image = object_types_images[object.type]
  local object_dimensions = object_types_dimensions[object.type]

  love.graphics.draw(
    object_image,
    object.position.x,
    object.position.y,
    object.rotation, -- in radians
    object_scale,
    object_scale,
    -- offset draw positions by half dimension so it appears centered
    object_dimensions.width/2,
    object_dimensions.height/2
  )
end

function draw_title(text)
  love.graphics.setNewFont(font_filepath, 36)
  local screen_width, screen_height = love.graphics.getDimensions()
  love.graphics.printf(text, 0, screen_height/2, screen_width, 'center')
end

function draw_score()
  love.graphics.setNewFont(font_filepath, 24)
  local screen_width, screen_height = love.graphics.getDimensions()
  love.graphics.printf(game.score, 0, 0, screen_width, 'right')
end

-- OBJECTS + DYNAMICS

function make_object(object_category, object_type)
  return {
    category = object_category,
    type = object_type,
    position = {
      x = 0,
      y = 0,
    },
    rotation = 0, -- in radians
    last_shot = 0, -- game time of last shot fired
  }
end

function move_object(object, movement_vector, magnitude)
  local direction = vector.normalise(movement_vector)
  local velocity = vector.multiply_scalar(direction, magnitude)
  object.position = vector.add(object.position, velocity)
end

function move_ship(object, movement_vector, magnitude)
  local direction = vector.normalise(movement_vector)
  local velocity = vector.multiply(direction, vector.multiply_scalar(ship_velocity_bias, magnitude))
  object.position = vector.add(object.position, velocity)
end

function move_object_by_velocity(object, velocity)
  object.position = vector.add(object.position, velocity)
end

-- checks for rectangular overlap between two objects
function collision(a, b)
  -- work out the corners (x1,x2,y1,y1) of each rectangle 
  local a_pos = a.position
  local a_dim = object_types_dimensions[a.type]
  local ax1 = a_pos.x - (a_dim.width/2)*hitbox_scale
  local ax2 = a_pos.x + (a_dim.width/2)*hitbox_scale
  local ay1 = a_pos.y - (a_dim.height/2)*hitbox_scale
  local ay2 = a_pos.y + (a_dim.height/2)*hitbox_scale

  local b_pos = b.position
  local b_dim = object_types_dimensions[b.type]
  local bx1 = b_pos.x - (b_dim.width/2)*hitbox_scale
  local bx2 = b_pos.x + (b_dim.width/2)*hitbox_scale
  local by1 = b_pos.y - (b_dim.height/2)*hitbox_scale
  local by2 = b_pos.y + (b_dim.height/2)*hitbox_scale

  -- test rectangular overlap
  return not (
    ax1 > bx2 or
    bx1 > ax2 or
    ay1 > by2 or
    by1 > ay2
   )
end


-- UTIL

-- ensure a value is within a lower and upper bound
function clamp(val, lower, upper)
  return math.max(lower, math.min(upper, val))
end

-- remove all the nil entries from a table so it has no gaps
function compact(list)
  for i = #list, 1, -1 do
    if list[i] == nil then
      table.remove(list, i)
    end
  end
end

-- remove an item by identity in a table
function remove_item(list, item)
  local index = find_index(list, item)
  if index ~= nil then
    table.remove(list, index)
  end
end

-- find the index of an item in a table
function find_index(list, target_item)
  for index, current_item in pairs(list) do
    if current_item == target_item then
      return index
    end
  end
  return nil
end

-- text description of a vector
function format_vector(v)
  return math.floor(v.x)..','..math.floor(v.y)
end

-- text description of a game object
function format_object(object)
  return object.category..':'..object.type
end

function format_object_pos(object)
  return object.category..':'..object.type..'('..format_vector(object.position)..')'
end
