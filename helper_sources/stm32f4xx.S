.set PAGE_SIZE, 16 * 1024

.set FLASH_BASE,      0x40023C00

.set FLASH_ACR,       0x00
.set FLASH_KEYR,      0x04
.set FLASH_OPTKEYR,   0x08
.set FLASH_SR,        0x0C
.set FLASH_CR,        0x10
.set FLASH_OPTCR,     0x14

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

  ldr R0, =0x45670123
  str R0, [R7, #FLASH_KEYR]
  ldr R0, =0xCDEF89AB
  str R0, [R7, #FLASH_KEYR]

  bx  LR

finalize:
  mov R0, #1 << 31

  str R0, [R7, #FLASH_CR]
  bx  LR

erase:
  ldr R1, [R7, #FLASH_SR]
  tst R1, #1 << 16
  bne erase

  mov R1, #0xF0
  str R1, [R7, #FLASH_SR]

  ldr R2, =0x202
  lsl R1, R0, #3
  orr R1, R2
  str R1, [R7, #FLASH_CR]
  orr R1, #1 << 16
  str R1, [R7, #FLASH_CR]

1:ldr R0, [R7, #FLASH_SR]
  tst R0, #1 << 16
  bne 1b

  and R0, #0xF0

  mov R1, #0
  str R1, [R7, #FLASH_CR]

  bx  LR

program:
  ldr R1, [R7, #FLASH_SR]
  tst R1, #1 << 16
  bne program

  ldr R1, =0x201
  str R1, [R7, #FLASH_CR]

  mov R1, #0xF0
  str R1, [R7, #FLASH_SR]

  ldr R4, =page_buffer
  mov R2, #0

1:
  ldr R3, [R4, R2]
  str R3, [R0, R2]

2:ldr R1, [R7, #FLASH_SR]
  tst R1, #1 << 16
  bne 2b

  ands R1, #0xF0
  bne 1f

  add R2, #4
  cmp R2, #PAGE_SIZE
  blo 1b

1:
  mov R0, R1
  mov R1, #0
  str R1, [R7, #FLASH_CR]

  bx  LR

.bss
page_buffer:
.fill PAGE_SIZE, 1
.size page_buffer, . - page_buffer
