module GdbFlasher

class MCU
  def initialize(connection)
    @connection = connection
    @symbol_table = {}

    helper_hex = File.join HELPERS, helper_name + ".hex"
    helper_sym = File.join HELPERS, helper_name + ".sym"

    File.open(helper_sym, "r") do |f|
      f.each_line do |line|
        line.rstrip!

        address, symbol = line.split(" ")

        @symbol_table[symbol.intern] = address.to_i 16
      end
    end

    helper = nil
    File.open(helper_hex, "r") { |f| helper = IHex.load f }

    connection.reset
    connection.get_stop_reply

    helper.segments.each do |segment|
      connection.write_memory segment.base, segment.data
    end

    initialize_environment

    @connection.insert_breakpoint 0, @symbol_table[:trap], breakpoint_kind

    call_helper :initialize
  end

  def finalize
    call_helper :finalize

    @connection.remove_breakpoint 0, @symbol_table[:trap], breakpoint_kind
  end

  def program_ihex(ihex, extra = {})
    sectors = []
    sector_actions = []

    sector_map = self.class.const_get :SECTORS

    sector_map.each_index do |i|
      sector_begin, sector_end = sector_map[i]

      sector_segment = nil

      ihex.segments.each do |segment|
        intersection = segment.intersect sector_begin, sector_end

        if intersection.size > 0
          if sector_segment.nil?
            sector_segment = IHex::Segment.new
            sector_segment.base = sector_begin
            sector_segment.data = blank_byte.chr * (sector_end - sector_begin + 1)

            sectors << sector_segment
          end

          affected_range = intersection.base - sector_begin...intersection.base + intersection.size - sector_begin
          sector_segment.data[affected_range] = intersection.data
        end
      end
    end

    if extra[:read_disallowed]
      sector_actions = [ [ :erase, :program ] ] * sectors.count
    else
      puts "Checking sectors"

      sectors.each do |sector|
        data = @connection.read_memory sector.base, sector.size

        if data == sector.data
          sector_actions << [ ]
        elsif is_blank(data)
          sector_actions << [ :program, :verify ]
        elsif is_blank(sector.data)
          sector_actions << [ :erase, :verify ]
        else
          sector_actions << [ :erase, :program, :verify ]
        end
      end
    end

    puts "Programming sectors:"
    sectors.each_index do |i|
      sector = sectors[i]
      actions = sector_actions[i]

      next if actions.empty?

      sector_id = sector_map.index { |i| i[0] == sector.base }

      printf " - %08X - %08X: ", sector.base, sector.base + sector.size - 1

      actions.each do |action|
        case action
        when :erase
          print "erase, "

          status = erase sector_id
          if status != 0
            puts "failure!"
            warn "Unable to erase sector #{sector_id}, vendor-specific error #{status}"

            return false
          end

        when :program
          print "program, "

          offset = 0
          page_size = @symbol_table[:PAGE_SIZE]
          buffer = @symbol_table[:page_buffer]

          while offset < sector.size
            @connection.write_memory buffer, sector.data[offset...offset + page_size]
            status = program sector.base + offset

            if status != 0
              puts "failure!"
              warn "Unable to program page #{(sector.base + offset).to_s 16}, vendor-specific error #{status}"

              return false
            end

            offset += page_size
          end

        when :verify
          print "verify, "

          data = @connection.read_memory sector.base, sector.size

          if data != sector.data
            puts "failure!"
            warn "Verification of sector #{sector_id} failed."

            return false
          end
        end
      end

      print "all ok.\n"
    end

    true
  end

  protected

  def blank_byte
    0xFF
  end

  def erase(sector_id)
    call_helper :erase, sector_id
  end

  def program(offset)
    call_helper :program, offset
  end

  def is_blank(string)
    string.bytes.all? { |byte| byte == blank_byte }
  end

  def initialize_environment

  end

  def breakpoint_kind
    4 # ARM breakpoint
  end

  def lr_offset
    0
  end

  def call_helper(func, r0 = 0, r1 = 0, r2 = 0, r3 = 0)
    regs = @connection.read_registers
    regs[0..3] = r0, r1, r2, r3
    regs[14] = @symbol_table[:trap] | lr_offset
    regs[15] = @symbol_table[func]
    @connection.write_registers regs

    reply = @connection.continue

    regs = @connection.read_registers

    if reply.signal != 0x05 || regs[15] != @symbol_table[:trap]
      raise "Target stopped by signal #{reply.signal}, PC = #{regs[15].to_s 16}"
    end

    regs[0]
  end

end

end
