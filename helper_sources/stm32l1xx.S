.set PAGE_SIZE, 256

.set FLASH_BASE, 0x40023C00

.set FLASH_ACR, 0x00
.set FLASH_PECR, 0x04
.set FLASH_PDKEYR, 0x08
.set FLASH_PEKEYR, 0x0C
.set FLASH_PRGKEYR, 0x10
.set FLASH_OPTKEYR, 0x14
.set FLASH_SR, 0x18

.globl trap
.globl initialize
.globl finalize
.globl erase
.globl program
.globl page_buffer
.globl PAGE_SIZE

.arch armv7-m
.syntax unified
.thumb
.text

trap:
  nop

initialize:
  ldr R7, =FLASH_BASE

  ldr R0, =0x89ABCDEF
  str R0, [R7, #FLASH_PEKEYR]
  ldr R0, =0x02030405
  str R0, [R7, #FLASH_PEKEYR]

  ldr R0, =0x8C9DAEBF
  str R0, [R7, #FLASH_PRGKEYR]
  ldr R0, =0x13141516
  str R0, [R7, #FLASH_PRGKEYR]

  bx LR

finalize:
  mov R0, #7
  str R0, [R7, #FLASH_PECR]

  bx LR

erase:
  mov R1, #0x20C
  str R1, [R7, #FLASH_PECR]

1:ldr R1, [R7, #FLASH_SR]
  tst R1, #1
  bne 1b

  mov R1, #0
  str R1, [R0]

1:ldr R1, [R7, #FLASH_SR]
  tst R1, #1
  bne 1b
  and R0, R1, #0xF00

  mov R1, #4
  str R1, [R7, #FLASH_PECR]

  bx LR

program:
  ldr R1, [R7, #FLASH_SR]
  tst R1, #1
  bne program

  ldr R4, =page_buffer
  mov R2, #0

1:
  ldr R3, [R4, R2]
  str R3, [R0, R2]

2:ldr R1, [R7, #FLASH_SR]
  tst R1, #1
  bne 2b
  ands R1, R1, #0xF00
  bne 1f

  add R2, #4
  cmp R2, #PAGE_SIZE
  blo 1b

1:
  mov R0, R1
  bx  LR


.bss
page_buffer:
.fill PAGE_SIZE, 1
.size page_buffer, . - page_buffer
