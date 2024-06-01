
all:
	alr build
	eval `alr printenv`; arm-eabi-objcopy -O binary bin/lado.elf bin/lado.bin
	ls -l bin

ocd-fk723m1:
	openocd -f interface/cmsis-dap.cfg -f target/stm32h7x.cfg

gdb-fk723m1:
	eval `alr printenv`; arm-eabi-gdb --command="gdbinit" bin/lado.elf

edit:
	eval `alr printenv`; ~/local/gnatstudio-24.1/bin/gnatstudio -P gnat/lado.gpr &
