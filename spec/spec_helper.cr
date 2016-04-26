require "spec"
require "../src/kt"

def start_server(host : String, port : Int32)
  if server_connected?(host, port)
    raise "Server already running on port #{port}"
  end

  args = ["-host", host, "-port", port.to_s]
  cmd = Process.new("ktserver", args)

  50.times do
    if server_connected?(host, port)
      return cmd
    end
    sleep 0.05
  end

  raise "Server failed to start on port #{port}"
end

def stop_server(process : Process)
  Process.kill(Signal::KILL, process.pid)
end

def server_connected?(host : String, port : Int32) : Bool
  begin
    socket = TCPSocket.new(host, port)
    return true
  rescue e : Errno
  ensure
    socket.try &.close
  end

  false
end
