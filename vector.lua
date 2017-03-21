local vector = {}

function vector.add(v1, v2)
  return {
    x = v1.x + v2.x,
    y = v1.y + v2.y,
  }
end

function vector.add_scalar(v, s)
  return {
    x = v.x + s,
    y = v.y + s,
  }
end

function vector.multiply(v1, v2)
  return {
    x = v1.x * v2.x,
    y = v1.y * v2.y,
  }
end

function vector.multiply_scalar(v, s)
  return {
    x = v.x * s,
    y = v.y * s,
  }
end

-- when you want to keep the direction of a vector, but discard the magnitude
-- you want the 'unit vector' aka 'normalised vector'
function vector.normalise(v)
  if v.x == 0 and v.y == 0 then
    return {x = 0, y = 0}
  end
  -- get vector magnitude
  local m = math.sqrt(v.x * v.x + v.y * v.y)
  -- divide scalars by magnitude
  return {
    x = v.x / m,
    y = v.y / m,
  }
end

-- useful for finding the direction to one vector from another
-- eg. v1 is the target, v2 is the source
function vector.subtract(v1, v2)
  return {
    x = v1.x - v2.x,
    y = v1.y - v2.y,
  }
end

function vector.equal(v1, v2)
  return v1.x == v2.x and v1.y == v2.y
end

return vector
