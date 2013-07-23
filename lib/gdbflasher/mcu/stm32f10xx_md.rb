module GdbFlasher
  class Stm32f10xxMD < CortexM

    SECTORS = (0...128).map { |i| [ 0x08000000 + 1024 * i, 0x08000000 + 1024 * (i + 1) - 1 ] }

    protected

    def helper_name
      "stm32f10xx_md"
    end

    def erase(sector_index)
      call_helper :erase, SECTORS[sector_index][0]
    end
  end

end
