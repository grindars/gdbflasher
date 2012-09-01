module GdbFlasher
  class Stm32l1xx < CortexM

    SECTORS = (0...512).map { |i| [ 0x08000000 + 256 * i, 0x08000000 + 256 * (i + 1) - 1 ] }

    protected

    def helper_name
      "stm32l1xx"
    end

    def erase(sector_index)
      call_helper :erase, SECTORS[sector_index][0]
    end

    def blank_byte
      0x00
    end
  end

end
