# Acquire or extend a lock.
#
# Usage:
#
#   call(redis, keys: [key], argv: [duration, token])
DistributedRedis::ScriptRegistry[:relock] = StringIO.new(<<~LUA)
  -- Acquire or extend a lock
  local key = KEYS[1]
  local duration = ARGV[1]
  local token = ARGV[2]
  local value = redis.call('get', key)
  if not value then
    redis.call('setex', key, duration, token)
    return true
  elseif value == token then
    redis.call('expire', key, duration)
    return true
  end
LUA

# Decrement a value until minimum is reached.
#
# Usage:
#
#   call(redis, keys: [key], argv: [decrement, min])
#   call(redis, keys: [key], argv: [decrement, min, default])
DistributedRedis::ScriptRegistry[:decrbyuntil] = StringIO.new(<<~LUA)
  local key = KEYS[1]
  local decrement = tonumber(ARGV[1])
  local min = tonumber(ARGV[2])
  local default = tonumber(ARGV[3]) or 0
  if default < min then
    return redis.error_reply("decrbyuntil: default must not be less than min")
  end
  local current = tonumber(redis.call('get', key)) or default
  if current <= min then
    return current
  else
    local value = math.max(min, current - decrement)
    redis.call('set', key, value)
    return value
  end
LUA

# Increment a value until maximum is reached.
#
# Usage:
#
#   call(redis, keys: [key], argv: [increment, max])
#   call(redis, keys: [key], argv: [increment, max, default])
DistributedRedis::ScriptRegistry[:incrbyuntil] = StringIO.new(<<~LUA)
  local key = KEYS[1]
  local increment = tonumber(ARGV[1])
  local max = tonumber(ARGV[2])
  local default = tonumber(ARGV[3]) or 0
  if default > max then
    return redis.error_reply("incrbyuntil: default must not be greater than max")
  end
  local current = tonumber(redis.call('get', key)) or default
  if current >= max then
    return current
  else
    local value = math.min(max, current + increment)
    redis.call('set', key, value)
    return value
  end
LUA

# Delete a key only if it's equal to the given value.
#
# Usage:
#
#   call(redis, keys: [key], argv: [value])
DistributedRedis::ScriptRegistry[:deleq] = StringIO.new(<<~LUA)
  if redis.call('get', KEYS[1]) == ARGV[1] then
    return redis.call('del', KEYS[1])
  end
  return 0
LUA
