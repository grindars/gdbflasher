# gdbflasher

gdbflasher is a easy to use flash loader for ARM-based MCUs. It can be used with any emulator that has a GDB server
capability. No emulator-side support for flashing is required.

## Installation

Install with:

```
$ gem install gdbflasher
```

## Usage

```
gdbflasher [options] <FIRMWARE FILE>
```

Options:
 * `server`: GDB server address. By default, `127.0.0.1:2331` is used.
 * `mcu`: One of MCU types (see below). Must be specified.
 * `start`: Start application after flashing. Does not work with all servers.
 * `version`: Print gdbflasher version and exit.
 * `help`: Print list of options and exit.
 
Firmware file must be in the Intel HEX format, ELF executables are not currently supported.

## Supported MCUs

 * `stm32f4xx` - ST STM32F40x and STM32F41x devices
 * `stm32fl1x` - ST STM32L15xxx medium-density devices
 * `stm32f10xx_hd` - ST STM32F10x high-density devices
 * `stm32f10xx_md` - ST STM32F10x medium-density devices

This list can also be retrieved by invoking
```
$ gdbflasher -mcu list
```
