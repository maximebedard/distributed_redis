# distributed_redis

Gem that provides a set of tools to deal with redis in an distributed environment (behind a proxy).

- Lazy evaluated redis scripts
- Script registry

## usage

Adding a script:

```rb
# register script from disk
ScriptRegistry[:relock] = File.open("./foo/bar/relock.lua")

# register from string
ScriptRegistry[:relock] = StringIO.new(<<~LUA)
  return redis.call("ping")
LUA
```

Using a script:

```rb
redis = ::Redis.new
ScriptRegistry[:relock].call(redis, keys: ["foo", "bar"], argv: [1, 2, 3])
```

Ensuring all scripts are loaded:

```rb
upstream_a = ::Redis.new(port: 6379)
upstream_b = ::Redis.new(port: 6380)
ScriptRegistry.ensure_loaded([redis_a, redis_b])
```

Loading all the STD scripts:

```rb
require "distributed_redis/prelude"

redis = ::Redis.new
ScriptRegistry[:relock].call(redis, keys: ["foo", "bar"], argv: [1, 2, 3])
```
