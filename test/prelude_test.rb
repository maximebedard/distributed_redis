# frozen_string_literal: true

require "test_helper"

module DistributedRedis
  class PreludeTest < Minitest::Test
    def setup
      @redis = Redis.new
      @redis.flushall(async: true)
    end

    def test_incrbyuntil_init_0
      assert_equal 10, ::DistributedRedis::ScriptRegistry[:incrbyuntil].call(@redis, ["foo"], [10, 100])
      assert_equal "10", @redis.get("foo")
    end

    def test_incrbyuntil_default
      assert_equal 25, ::DistributedRedis::ScriptRegistry[:incrbyuntil].call(@redis, ["foo"], [10, 100, 15])
      assert_equal "25", @redis.get("foo")
    end

    def test_incrbyuntil_raises_when_default_gt_max
      assert_raises Redis::CommandError do
        ::DistributedRedis::ScriptRegistry[:incrbyuntil].call(@redis, ["foo"], [10, 100, 105])
      end
    end

    def test_incrbyuntil_increments_up_to_the_max
      assert_equal 10, ::DistributedRedis::ScriptRegistry[:incrbyuntil].call(@redis, ["foo"], [10, 15])
      assert_equal 15, ::DistributedRedis::ScriptRegistry[:incrbyuntil].call(@redis, ["foo"], [10, 15])
      assert_equal 15, ::DistributedRedis::ScriptRegistry[:incrbyuntil].call(@redis, ["foo"], [10, 15])
      assert_equal "15", @redis.get("foo")
    end

    def test_incrbyuntil_returns_current_when_gt_max
      @redis.set("foo", 20)
      assert_equal 20, ::DistributedRedis::ScriptRegistry[:incrbyuntil].call(@redis, ["foo"], [10, 15])
      assert_equal "20", @redis.get("foo")
    end

    def test_decrbyuntil_init_0
      assert_equal(-10, ::DistributedRedis::ScriptRegistry[:decrbyuntil].call(@redis, ["foo"], [10, -100]))
      assert_equal "-10", @redis.get("foo")
    end

    def test_decrbyuntil_default
      assert_equal(-25, ::DistributedRedis::ScriptRegistry[:decrbyuntil].call(@redis, ["foo"], [10, -100, -15]))
      assert_equal "-25", @redis.get("foo")
    end

    def test_incrbyuntil_raises_when_default_lt_min
      assert_raises Redis::CommandError do
        ::DistributedRedis::ScriptRegistry[:decrbyuntil].call(@redis, ["foo"], [10, -100, -105])
      end
    end

    def test_decrbyuntil_decrement_down_to_the_min
      assert_equal(-10, ::DistributedRedis::ScriptRegistry[:decrbyuntil].call(@redis, ["foo"], [10, -15]))
      assert_equal(-15, ::DistributedRedis::ScriptRegistry[:decrbyuntil].call(@redis, ["foo"], [10, -15]))
      assert_equal(-15, ::DistributedRedis::ScriptRegistry[:decrbyuntil].call(@redis, ["foo"], [10, -15]))
      assert_equal "-15", @redis.get("foo")
    end

    def test_decrbyuntil_returns_current_when_lt_min
      @redis.set("foo", -20)
      assert_equal(-20, ::DistributedRedis::ScriptRegistry[:decrbyuntil].call(@redis, ["foo"], [10, -15]))
      assert_equal "-20", @redis.get("foo")
    end

    def test_deleq_only_when_values_are_equals
      @redis.set("foo", "bar")
      assert_equal(1, ::DistributedRedis::ScriptRegistry[:deleq].call(@redis, ["foo"], ["bar"]))
      assert_equal(0, ::DistributedRedis::ScriptRegistry[:deleq].call(@redis, ["foo"], ["bar"]))
    end

    def test_relock_increases_the_ttl_when_the_key_already_exists
      assert(::DistributedRedis::ScriptRegistry[:relock].call(@redis, keys: ["foo"], argv: [1000, "bar"]))

      acquire_ttl = @redis.pttl("foo").to_i
      refute_equal(0, acquire_ttl)
      assert(999_000 < acquire_ttl && acquire_ttl <= 1_000_000)

      assert(::DistributedRedis::ScriptRegistry[:relock].call(@redis, keys: ["foo"], argv: [1001, "bar"]))

      relock_ttl = @redis.pttl("foo").to_i
      refute_equal(acquire_ttl, relock_ttl)
      assert(1_000_000 < relock_ttl && relock_ttl <= 1_001_000)
    end
  end
end
