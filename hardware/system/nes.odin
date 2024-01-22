package system

import "core:fmt"

import "hardware:cpu"

ReadFn :: #type proc(bus: ^Bus, addr: u16) -> u8
WriteFn :: #type proc(bus: ^Bus, addr: u16, data: u8)

Mirroring :: enum {
	VERTICAL,
	HORIZONTAL,
	FOUR_SCREEN,
}

Rom :: struct {
	prg_rom:          []u8,
	chr_rom:          []u8,
	mapper:           u8,
	screen_mirroring: Mirroring,
}

Bus :: struct {
	cpu_vram: [2048]u8,
	rom:      Rom,
	read8:    ReadFn,
	write8:   WriteFn,
}

NES :: struct {
	cpu6502: cpu.MOS6502,
	memory:  []u8,
	bus:     Bus,
}

RAM: u16 : 0x0000
RAM_MIRRORS_END: u16 : 0x1FFF
PPU_REGISTERS: u16 : 0x2000
PPU_REGISTERS_MIRRORS_END: u16 : 0x3FFF

bus_mem_read :: proc(bus: ^Bus, addr: u16) -> u8 {

	mem_val: u8
	switch addr {
	case RAM ..= RAM_MIRRORS_END:
		mirror_down_addr := addr & 0b00000111_11111111
		mem_val = bus.cpu_vram[mirror_down_addr]
	case PPU_REGISTERS ..= PPU_REGISTERS_MIRRORS_END:
		mirror_down_addr := addr & 0b00100000_00000111
		fmt.println("PPU is not supported yet")
		mem_val = 0
	case:
		fmt.println("Ignoring mem access at ", addr)
		mem_val = 0
	}
	return mem_val
}

bus_mem_write :: proc(bus: ^Bus, addr: u16, data: u8) {

	switch addr {
	case RAM ..= RAM_MIRRORS_END:
		mirror_down_addr := addr & 0b00000111_11111111
		bus.cpu_vram[mirror_down_addr] = data
	case PPU_REGISTERS ..= PPU_REGISTERS_MIRRORS_END:
		mirror_down_addr := addr & 0b00100000_00000111
		fmt.println("PPU is not supported yet")
	case:
		fmt.println("Ignoring mem write-access at", addr)
	}
}

init_nes :: proc() -> NES {
	nes := NES{}

	// Set up the bus read/write functions
	nes.bus.read8 = bus_mem_read
	nes.bus.write8 = bus_mem_write

	return nes
}
