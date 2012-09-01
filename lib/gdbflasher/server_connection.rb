require "socket"

module GdbFlasher
  class ServerConnection
    class StopReply
      attr_accessor :signal, :attributes

      def initialize(signal, attributes = {})
        @signal = signal
        @attributes = attributes
      end
    end

    def initialize
      @socket = nil
    end

    def connect(address)
      raise "Already connected" unless @socket.nil?

      match = address.match /^([0-9\.]+|\[[0-9a-fA-F:]\]+):([0-9]+)$/

      if match.nil?
        raise "Invalid server address: #{address}"
      end

      @buf = ""
      @features = {}
      @need_ack = true

      begin
        @socket = Socket.new Socket::AF_INET, Socket::SOCK_STREAM
        @socket.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1
        @socket.connect Socket.sockaddr_in match[2].to_i, match[1]

        # Query stub features
        command("qSupported").split(';').each do |feature|
          if feature[-1] == '-'
            @features.delete feature[0...-1].intern
          elsif feature[-1] == '+'
            @features[feature[0...-1].intern] = true
          else
            sep = feature.index '='

            if sep.nil?
              raise "Unexpected item in qSupported response: #{sep}"
            end

            @features[feature[0...sep].intern] = feature[sep + 1..-1]
          end
        end

        if @features[:PacketSize].nil?
          raise "PacketSize isn't present in qSupported response"
        end

        if @features[:QStartNoAckMode]
          response = command("QStartNoAckMode")

          if response != "OK"
            raise "Unable to enter NoAck mode: #{response}"
          end

          @need_ack = false
        end

        # Load target description
        if @features[:"qXfer:features:read"]
          description = read_xfer "features", "target.xml"

          # TODO: parse target description and use register map from it.
        end

      rescue Exception => e
        @socket.close unless @socket.nil?
        @socket = nil

        raise e
      end
    end

    def close
      @socket.close
      @socket = nil
    end

    def read_registers
      response = command "g"

      if (response[0] != 'E' || response.length != 3) && response.length % 8 != 0
        raise "Malformed 'g' response"
      end

      if response[0] == 'E'
        raise "GDB server error: #{response[1..2].to_i 16}"
      end

      Array.new response.length / 8 do |i|
        big2native response[i * 8...(i + 1) * 8].to_i(16)
      end
    end

    def write_registers(regs)
      send_packet "G" + regs.map { |r| sprintf "%08x", native2big(r) }.join
    end

    def write_memory(base, string)
      max_size = (@features[:PacketSize].to_i - 19) & ~1

      offset = 0
      data = string.unpack("C*").map { |byte| sprintf "%02X", byte }.join

      while offset < data.length
        chunk_size = [ max_size, data.length - offset ].min

        response = command "M#{base.to_s 16},#{(chunk_size / 2).to_s 16}:#{data[offset...offset + chunk_size]}"

        if response != "OK"
          raise "Memory write failed: #{response}"
        end

        base += chunk_size / 2
        offset += chunk_size
      end
    end

    def read_memory(base, size)
      max_size = (@features[:PacketSize].to_i - 19) & ~1
      offset = 0
      data = ""
      size *= 2

      while offset < size
        chunk_size = [ max_size, size - offset ].min

        response = command "m#{base.to_s 16},#{(chunk_size / 2).to_s 16}"

        if response[0] == "E"
          raise "Memory read failed: #{response}"
        end

        data += response

        base += chunk_size / 2
        offset += chunk_size
      end

      Array.new(data.length / 2) do |i|
        data[i * 2..i * 2 + 1].to_i 16
      end.pack("C*")
    end

    def insert_breakpoint(type, address, kind)
      response = command "Z#{type.to_s 16},#{address.to_s 16},#{kind.to_s 16}"

      if response != "OK"
        raise "Breakpoint insertion failed: #{response}"
      end
    end

    def remove_breakpoint(type, address, kind)
      response = command "z#{type.to_s 16},#{address.to_s 16},#{kind.to_s 16}"

      if response != "OK"
        raise "Breakpoint removal failed: #{response}"
      end
    end

    def continue
      parse_stop_reply command("c")
    end

    def step
      parse_stop_reply command("s")
    end

    def reset
      reply = command "r"

      if reply != "OK"
        raise "Reset failed: #{reply}"
      end
    end

    def get_stop_reply
      parse_stop_reply command("?")
    end

    def write_register(reg, value)
      reply = command sprintf("P%x=%08x", reg, big2native(value))

      if reply != "OK"
        raise "Register write failed: #{reply}"
      end
    end

    protected

    def parse_stop_reply(reply)
      case reply[0]
      when 'S'
        StopReply.new reply[1..2].to_i(16)

      when 'T'
        pairs = reply[3..-1].split ';'
        values = {}
        pairs.each do |pair|
          key, value = pair.split ':'

          if key.match /^[0-9a-fA-F]+/
            values[key.to_i 16] = value.to_i 16
          else
            values[key] = value
          end
        end

        StopReply.new reply[1..2].to_i(16), values

      else
        raise "Unknown stop reply: #{reply}"
      end
    end

    def read_xfer(object, annex)
      offset = 0
      size = @features[:PacketSize].to_i - 4
      contents = ""

      loop do
        response = command "qXfer:#{object}:read:#{annex}:#{offset}:#{size}"

        offset += response.length - 1
        contents += response[1..-1]

        if response[0] == 'l'
          break
        elsif response[0] != 'm'
          raise "qXfer failed: #{response}"

        end
      end

      contents
    end

    def command(s, extra = {})
      send_packet s, extra

      response = receive_packet
    end

    def send_packet(data, extra = {})
      data = data.dup

      if extra[:escape]
        i = 0

        while i < data.length
          byte = data[i]

          if byte == '$' || byte == '#' || byte == 0x7d.chr
            data.insert i, 0x7d.chr

            i += 1
          end

          i += 1
        end
      end

      message = sprintf "$%s#%02x", data, data.sum(8)

      if !@features[:PacketSize].nil? && @features[:PacketSize].to_i < message.length
        raise "Internal error: message is too long"
      end

      @socket.write message

      if @need_ack
        loop do
          ack = @socket.read 1

          case ack
          when '+'
            break

          when '-'
            @socket.write message

          else
            raise "Unexpected response from server: #{ack}"
          end
        end
      end
    end

    def receive_packet
      loop do
        @buf += @socket.readpartial 4096

        if @buf[0] != '$'
          raise "Invalid response from server"
        end

        idx = @buf.index '#'

        if !idx.nil? && idx + 2 <= @buf.length
          message = @buf.slice! 0..idx + 2

          data = message[1..-4]

          if @need_ack
            checksum = data.sum 8
            if checksum != message[-2..-1].to_i(16)
              @socket.write '-'
            else
              @socket.write '+'

              return data
            end
          else
            return data
          end
        end
      end
    end

    def native2big(v)
      [ v ].pack("N").unpack("L")[0]
    end

    def big2native(v)
      [ v ].pack("L").unpack("N")[0]
    end
  end
end
