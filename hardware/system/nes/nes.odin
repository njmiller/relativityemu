package system

import "core:fmt"
import "core:log"

import "hardware:cpu/mos6502"
import "hardware:io"
import "hardware:memory"
import "hardware:ppu"

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
	ppu0:      ppu.Ricoh2c02,
}

NES :: struct {
	cpu6502: mos6502.MOS6502,
	bus:     Bus,
}

RAM: u16 : 0x0000
RAM_MIRRORS_END: u16 : 0x1FFF
PPU_REGISTERS: u16 : 0x2000
PPU_REGISTERS_MIRRORS_END: u16 : 0x3FFF

bus_mem_read :: proc(bus: ^memory.Bus, addr: u16) -> u8 {
	bus := cast(^Bus)bus
	mem_val: u8

	switch addr {
	case RAM ..= RAM_MIRRORS_END:
		mirror_down_addr := addr & 0b00000111_11111111
		mem_val = bus.cpu_vram[mirror_down_addr]
	case PPU_REGISTERS ..= PPU_REGISTERS_MIRRORS_END:
		mirror_down_addr := addr & 0b00100000_00000111
		log.fatal("PPU is not supported yet")
		mem_val = 0
	case 0x8000 ..= 0xFFFF:
		mem_val = prg_read(bus.rom.prg_rom, addr)
	case:
		log.warn("Ignoring mem access at ", addr)
		mem_val = 0
	}

	return mem_val
}

bus_mem_write :: proc(bus: ^memory.Bus, addr: u16, data: u8) {
	bus := cast(^Bus)bus

	switch addr {
	case RAM ..= RAM_MIRRORS_END:
		mirror_down_addr := addr & 0b00000111_11111111
		bus.cpu_vram[mirror_down_addr] = data
	case PPU_REGISTERS ..= PPU_REGISTERS_MIRRORS_END:
		mirror_down_addr := addr & 0b00100000_00000111
		log.error("PPU is not supported yet")
		ppu.write_ppu_data(&bus.ppu0, addr, data)
	case 0x8000 ..= 0xFFFF:
		log.error("Attempting to write to a cartridge ROM space.")
	case:
		fmt.println("Ignoring mem write-access at", addr)
	}
}

prg_read :: proc(prg_rom: []u8, addr: u16) -> u8 {
	addr := addr - 0x8000
	if len(prg_rom) == 0x4000 && addr >= 0x4000 {
		addr = addr % 0x4000
	}
	return prg_rom[addr]
}

init_nes :: proc(fn: string) -> NES {
	nes := NES{}

	// Set up the bus read/write functions
	nes.bus.read = bus_mem_read
	nes.bus.write = bus_mem_write

	// The NES version of the CPU does not implement decimal mode
	nes.cpu6502.dm_avail = false

	rom := load_rom(fn)
	nes.bus.rom = rom
	reset(&nes)

	return nes
}

reset :: proc(nes: ^NES) {
	// TODO: Check where stack pointer is actually initialized
	// Initialization to 0 might explain the -1 initially in the CPU
	// stack stuff though I do see a 0xFD somewhere else
	nes.cpu6502.sp = 0xFD

	// Set registers to 0
	nes.cpu6502.a = 0
	nes.cpu6502.ix = 0
	nes.cpu6502.iy = 0
	nes.cpu6502.status = 0x24 // TODO: Check this
	nes.cpu6502.ec = 0

	// TODO: Move read 16 from CPU to bus
	// Reset vector
	low := nes.bus.read(&nes.bus, 0xFFFC)
	high := nes.bus.read(&nes.bus, 0xFFFD)

	//fmt.println("Setting pc to 0C00 to nestest.nes because PPU is not implemented yet.")
	low = 0

	nes.cpu6502.pc = auto_cast ((u16(high) << 8) | u16(low))
	//nes.cpu6502.pc = nes.bus.read16(&nes.bus, 0xFFFC)

}

load_rom :: proc(fn: string) -> Rom {
	prg_rom, chr_rom, mapper, mirroring := io.read_ines(fn)

	mirr_enum: Mirroring
	if mirroring == 0 {
		mirr_enum = Mirroring.HORIZONTAL
	} else if mirroring == 1 {
		mirr_enum = Mirroring.VERTICAL
	} else if mirroring == 2 {
		mirr_enum = Mirroring.FOUR_SCREEN
	} else {
		log.error("Mirroring value is not valid")
	}

	rom_out := Rom {
		prg_rom          = prg_rom,
		chr_rom          = chr_rom,
		mapper           = mapper,
		screen_mirroring = mirr_enum,
	}

	return rom_out
}
