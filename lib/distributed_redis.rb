require "redis"
require "distributed_redis/version"

module DistributedRedis
  # Lazy evaluated redis script.
  #
  # Redis supports LUA scripts that have many interesting properties such as serialization and are executed
  # sequentially. Redis is also able to conserve a compiled version of a script in memory, via a `SCRIPT LOAD`
  # command, but can also fill it's cache by using an `EVAL script` instead. This class is an optimization that
  # removes a command sent to redis:
  #
  #   Before: EVALSHA -> miss, SCRIPT LOAD -> ok, EVALSHA -> ok
  #   After: EVALSHA -> miss, EVAL -> ok, any other EVALSHA will use the cached script
  class Script
    # User error raised when the redis script is invalid (syntax error, script consumes too much memory, etc.)
    UserError = Class.new(Redis::CommandError)

    attr_reader(
      :content,
      :digest,
    )

    def initialize(content)
      @content = content
      @digest = Digest::SHA1.hexdigest(@content)
    end

    def call(redis, *args)
      begin
        redis.evalsha(digest, *args)
      rescue Redis::CommandError => err
        if err.message.start_with?("NOSCRIPT")
          redis.eval(@content, *args)
        else
          raise
        end
      end
    rescue Redis::CommandError => err
      # We need to be able to discriminate between user error (script that cannot be compiled, runtime errors), and
      # execution error such as connection errors, timeouts, OOM, etc.
      #
      # Previously, wolverine was doing the same thing, but was also trying to infer from the stack trace the location of
      # the script on disk, the line at which the error occured, and reformat the whole exception. This is indeed
      # convenient, but adds a lot of overhead for error messages, and it's also much trickier to pinpoint for inlined
      # scripts. Personally I think the error message are good enough, but it's probably because I'm used to them.
      if err.message.start_with?(/ERR Error (compiling|running)/)
        raise UserError, err
      else
        raise
      end
    end
  end
  private_constant(:Script)

  class ScriptRegistry
    class << self
      def load_glob(glob)
        Dir.glob(glob).each do |f|
          @registry[File.basename(f)] = File.open(f)
        end
      end

      def []=(name, io)
        @registry[name] = Script.new(io.read)
      end

      def [](name)
        @registry[name]
      end

      def ensure_loaded(upstreams)
        Array(upstreams).each do |upstream|
          upstream.pipelined do
            @registry.each_value { |script| upstream.script(:load, script.content) }
          end
        end
      end
    end

    @registry = {}
  end
end
