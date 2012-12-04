OUTPUT_FORMAT(elf32-littlearm)

MEMORY
{
  sram : ORIGIN = 0x20000000, LENGTH = 4K
}

SECTIONS
{
  .text : {
    *(.text)

    . = ALIGN(4);

    *(.rodata)
  } > sram

  . = ALIGN(4);

  .bss : {
    *(.bss)
  } > sram

  . = ALIGN(4);
}
