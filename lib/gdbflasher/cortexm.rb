module GdbFlasher

  class CortexM < MCU
    protected

    def initialize_environment
      @connection.write_register 25, 0x01000000
    end

    def breakpoint_kind
      2 # Thumb-2 breakpoint
    end

    def lr_offset
      1
    end
  end

end
