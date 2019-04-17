# frozen_string_literal: true

require "test_helper"

module DistributedRedis
  class ScriptTest < Minitest::Test
    def test_cache_hit
      called = false
      tc = self
      script = Script.new("redis.call('ping')")
      redis = Class.new do
        define_method(:evalsha) do |digest, *args|
          tc.assert_equal(script.digest, digest)
          tc.assert_equal([:a, :b], args)
          called = true
        end
      end.new

      script.call(redis, :a, :b)
      assert(called)
    end

    def test_cache_miss
      called = false
      tc = self
      script = Script.new("redis.call('ping')")
      redis = Class.new do
        define_method(:evalsha) do |*|
          raise Redis::CommandError, "NOSCRIPT No matching script. Please use EVAL."
        end
        define_method(:eval) do |content, *args|
          tc.assert_equal(script.content, content)
          tc.assert_equal([:a, :b], args)
          called = true
        end
      end.new

      script.call(redis, :a, :b)
      assert(called)
    end

    def test_user_error
      script = Script.new("redis.call('ping')")
      redis = Class.new do
        define_method(:evalsha) do |*|
          raise Redis::CommandError, "ERR Error compiling ....."
        end
      end.new

      assert_raises(Script::UserError) do
        script.call(redis, :a, :b)
      end
    end
  end
end
