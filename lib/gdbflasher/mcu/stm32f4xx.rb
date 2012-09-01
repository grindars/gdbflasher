module GdbFlasher
  class Stm32f4xx < CortexM
    SECTORS = [
      [ 0x08000000, 0x08003FFF ], # Sector 0, 16 KiB
      [ 0x08004000, 0x08007FFF ], # Sector 1, 16 KiB
      [ 0x08008000, 0x0800BFFF ], # Sector 2, 16 KiB
      [ 0x0800C000, 0x0800FFFF ], # Sector 3, 16 KiB
      [ 0x08010000, 0x0801FFFF ], # Sector 4, 64 KiB
      [ 0x08020000, 0x0803FFFF ], # Sector 5, 64 KiB
      [ 0x08040000, 0x0805FFFF ], # Sector 6, 64 KiB
      [ 0x08060000, 0x0807FFFF ], # Sector 7, 64 KiB
      [ 0x08080000, 0x0809FFFF ], # Sector 8, 64 KiB
      [ 0x080A0000, 0x080BFFFF ], # Sector 9, 64 KiB
      [ 0x080C0000, 0x080DFFFF ], # Sector 10, 64 KiB
      [ 0x080E0000, 0x080FFFFF ], # Sector 11, 64 KiB
    ]

    protected

    def helper_name
      "stm32f4xx"
    end
  end

end
