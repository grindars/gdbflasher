module GdbFlasher
  class IHex
    class Record
      attr_accessor :length, :address, :type, :data

      TYPES = {
        0 => :data,
        1 => :eof,
        4 => :extended_address,
        5 => :start_address
      }

      def initialize
        @length = nil
        @address = nil
        @type = nil
        @data = nil
      end

      def valid?
        @length == @data.length
      end

      def self.parse(line)
        if line.match(/^:([0-9a-fA-F]{2})+$/).nil?
          raise "Malformed Intel Hex line: #{line}"
        end

        line.slice! 0

        bytes = Array.new(line.length / 2) { |i| line[i * 2..i * 2 + 1].hex }

        record = Record.new
        record.length = bytes[0]
        record.address = (bytes[1] << 8) | bytes[2]
        record.type = TYPES[bytes[3]]
        record.data = bytes[4..-2].pack("C*")

        checksum = (~bytes.reduce(:+) + 1) & 0xFF

        if !record.valid? || record.type.nil? || checksum != 0
          raise "Malformed Intel Hex line: #{line}"
        end

        record
      end
    end

    class Segment
      attr_accessor :base, :data

      def initialize
        @base = 0
        @data = ""
      end

      def size
        @data.length
      end

      def intersect(region_base, region_end)
        if region_base == region_end
          raise ArgumentError, "Region is empty"
        end

        segment_range = @base...@base + size
        region_range  = region_base..region_end

        intersection_base = nil, intersection_end = nil

        if segment_range.cover? region_range.min
          intersection_base = region_range.min
        elsif region_range.cover? segment_range.min
          intersection_base = segment_range.min
        else
          return Segment.new
        end

        if segment_range.cover? region_range.max
          intersection_end = region_range.max
        elsif region_range.cover? segment_range.max
          intersection_end = segment_range.max
        else
          return Segment.new
        end

        segment = Segment.new
        segment.base = intersection_base
        segment.data = @data[intersection_base - @base..intersection_end - @base]

        segment
      end

      def pad_segment!(psize, fill_byte = 0x00)
        if @base % size != 0
          padding = size - (@base % size)

          @base -= padding
          @data = ([ fill_byte ] * padding).pack("C*") + @data
        end

        if @data.size % size != 0
          padding = size - (@data.size % size)

          @data += ([ fill_byte ] * padding).pack "C*"
        end
      end
    end


    attr_accessor :segments

    def initialize
      @segments = []
    end

    def self.load(stream)
      high_address = 0
      lines = {}

      stream.each_line do |line|
        line.rstrip!

        record = Record.parse line

        case record.type
        when :eof
          break

        when :extended_address
          high_address, = record.data.unpack "n"

        when :data
          lines[(high_address << 16) | record.address] = record.data
        end
      end

      segment = nil
      ihex = self.new

      lines.sort_by { |k1,v1,k2,b2| k1 <=> k2 }.each do |address, data|
        if segment.nil? || segment.base + segment.size != address
          segment = Segment.new
          segment.base = address
          segment.data = data

          ihex.segments << segment
        else
          segment.data += data
        end
      end

      ihex
    end

    def split_segments!(size, fill_byte = 0x00)
      pad_segments! size, fill_byte

      i = 0

      while i < @segments.length
        segment = @segments[i]
        parts = segment.size / size

        for j in 1...parts do
          new_segment = Segment.new
          new_segment.base = segment.base + size * j
          new_segment.data = segment.data[j * size...(j + 1) * size]

          @segments.insert i + j, new_segment
        end

        segment.data = segment.data[0...size]

        i += parts
      end

      self
    end

    def pad_segments!(size, fill_byte = 0x00)
      @segments.each do |segment|
        segment.pad_segment! size, fill_byte
      end

      self
    end
  end
end
