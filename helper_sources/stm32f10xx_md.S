.set PAGE_SIZE, 1024

.set FPEC, 0x40022000

.set FLASH_ACR,     0
.set FLASH_KEYR,    4
.set FLASH_OPTKEYR, 8
.set FLASH_SR,      12
.set FLASH_CR,      16
.set FLASH_AR,      20

.set FLASH_SR_EOP,      1 << 5
.set FLASH_SR_WRPRTERR, 1 << 4
.set FLASH_SR_PGERR,    1 << 2
.set FLASH_SR_BSY,      1 << 0

.set FLASH_CR_EOPIE,    1 << 12
.set FLASH_CR_ERRIE,    1 << 10
.set FLASH_CR_OPTWRE,   1 << 9
.set FLASH_CR_LOCK,     1 << 7
.set FLASH_CR_STRT,     1 << 6
.set FLASH_CR_OPTER,    1 << 5
.set FLASH_CR_OPTPG,    1 << 4
.set FLASH_CR_MER,      1 << 2
.set FLASH_CR_PER,      1 << 1
.set FLASH_CR_PG,       1 << 0

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
    ldr R7, =FPEC

    ldr R0, =0x45670123
    str R0, [R7, #FLASH_KEYR]
    ldr R0, =0xCDEF89AB
    str R0, [R7, #FLASH_KEYR]

    bx LR

finalize:
    mov R1, #FLASH_CR_LOCK
    str R1, [R7, #FLASH_CR]

    bx LR

erase:
    ldr R1, [R7, #FLASH_CR]
    orr R1, #FLASH_CR_PER
    str R1, [R7, #FLASH_CR]
    str R0, [R7, #FLASH_AR]
    orr R1, #FLASH_CR_STRT
    str R1, [R7, #FLASH_CR]

1:  ldr R2, [R7, #FLASH_SR]
    tst R2, #FLASH_SR_BSY
    bne 1b

    bic R1, #FLASH_CR_PER | FLASH_CR_STRT
    str R1, [R7, #FLASH_CR]

    and R0, R2, #FLASH_SR_WRPRTERR | FLASH_SR_PGERR
    str R2, [R7, #FLASH_SR]

    bx LR

program:
    ldr R1, [R7, #FLASH_CR]
    orr R1, #FLASH_CR_PG
    str R1, [R7, #FLASH_CR]

    ldr R4, =page_buffer
    mov R2, #0

1:
    ldrh R3, [R4, R2]
    strh R3, [R0, R2]

2:  ldr R1, [R7, #FLASH_SR]
    tst R1, #FLASH_SR_BSY
    bne 2b

    str R1, [R7, #FLASH_SR]
    ands R1, R1, #FLASH_SR_WRPRTERR | FLASH_SR_PGERR
    bne 1f

    add R2, #2
    cmp R2, #PAGE_SIZE
    blo 1b
1:

    ldr R2, [R7, #FLASH_CR]
    bic R2, #FLASH_CR_PG
    str R2, [R7, #FLASH_CR]

    mov R0, R1
    bx  LR

.bss
page_buffer:
.fill PAGE_SIZE, 1
.size page_buffer, . - page_buffer
