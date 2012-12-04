module GdbFlasher
  class Stm32f10xxHD < CortexM

    SECTORS = (0...256).map { |i| [ 0x08000000 + 2048 * i, 0x08000000 + 2048 * (i + 1) - 1 ] }

    protected

    def helper_name
      "stm32f10xx_hd"
    end

    def erase(sector_index)
      call_helper :erase, SECTORS[sector_index][0]
    end
  end

end
