# frozen_string_literal: true

module Deflake
  # Starts a test process and waits for it. The output goes to a file, not a pipe: a process the
  # tests started in the background would keep a pipe open, and deflake would wait for it. The
  # test process gets a session of its own, without a terminal: in deflake's process group a test
  # that touches the terminal settings would be stopped, and a timeout or an interrupt stops
  # whatever it started too. After an interrupt the killed process is reaped before deflake exits,
  # not left to init
  module Child
    # The status of a process killed because it ran longer than the timeout
    TimedOut = Struct.new(:status, :seconds) do
      def success? = false
      def signaled? = false
      def exitstatus = nil
    end

    module_function

    # Returns the process status, or TimedOut. timeout: seconds, nil for no limit
    def run(env, command, log, timeout)
      pid = start(env, command, log)
      waiter = Process.detach(pid)
      return waiter.value if waiter.join(timeout)

      kill(pid)
      TimedOut.new(waiter.value, timeout)
    ensure
      if waiter&.alive?
        kill(pid)
        waiter.join(5)
      end
    end

    def start(env, command, log)
      Process.fork do
        Process.setsid
        exec(env, *command, in: File::NULL, %i[out err] => log)
      rescue SystemCallError => e
        File.write(log, "deflake: #{e.message}\n")
        exit!(127)
      end
    end

    # Before the new process starts its session, it has no group of its own yet
    def kill(pid)
      Process.kill("KILL", -pid)
    rescue SystemCallError
      begin
        Process.kill("KILL", pid)
      rescue SystemCallError
        nil
      end
    end

    def ending(status)
      return "timed out after #{status.seconds} seconds" if status.is_a?(TimedOut)
      return "was killed by SIG#{Signal.signame(status.termsig)}" if status.signaled?

      "exited with status #{status.exitstatus}"
    end
  end
end
