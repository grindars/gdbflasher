MCUS = stm32f4xx stm32l1xx stm32f10xx_hd stm32f10xx_md

HELPERS = $(addprefix ../helpers/,$(addsuffix .hex,${MCUS}) $(addsuffix .sym,${MCUS}))
ELVES = $(addsuffix .elf,${MCUS})
OBJECTS = $(addsuffix .o,${MCUS})

all: ${HELPERS}

clean:
	rm -f ${HELPERS} ${ELVES} ${OBJECTS}

../helpers/%.sym: %.elf
	${CROSS_COMPILE}nm -n $< | awk '$$2 == "T" || $$2 == "B" || $$2 == "A" { print $$1 " " $$3 }' > $@

../helpers/%.hex: %.elf
	${CROSS_COMPILE}objcopy -O ihex $< $@

%.elf: %.lds %.o
	${CROSS_COMPILE}ld -o $@ -T$^

%.o: %.S
	${CROSS_COMPILE}as -o $@ $<
