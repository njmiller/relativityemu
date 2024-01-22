package system

import "core:fmt"

import "hardware:cpu"
import "hardware:memory"

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
	using bus: memory.Bus,
	cpu_vram:  [2048]u8,
	rom:       Rom,
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

bus_mem_read :: proc(bus: ^memory.Bus, addr: u16) -> u8 {
	bus := cast(^Bus)bus
	mem_val: u8
	/*
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
    */
	mem_val = bus.cpu_vram[addr]
	return mem_val
}

bus_mem_write :: proc(bus: ^memory.Bus, addr: u16, data: u8) {
	bus := cast(^Bus)bus
	/*
	switch addr {
	case RAM ..= RAM_MIRRORS_END:
		mirror_down_addr := addr & 0b00000111_11111111
		bus.cpu_vram[mirror_down_addr] = data
	case PPU_REGISTERS ..= PPU_REGISTERS_MIRRORS_END:
		mirror_down_addr := addr & 0b00100000_00000111
		fmt.println("PPU is not supported yet")
	case:
		fmt.println("Ignoring mem write-access at", addr)
	}*/
	bus.cpu_vram[addr] = data
}

init_nes :: proc() -> NES {
	nes := NES{}

	// Set up the bus read/write functions
	nes.bus.read = bus_mem_read
	nes.bus.write = bus_mem_write

	nes.cpu6502.sp = 0xFF

	return nes
}
