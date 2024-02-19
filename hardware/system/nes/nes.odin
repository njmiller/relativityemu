package nes

import "core:fmt"
import "core:log"

import "hardware:cpu/mos6502"

Bus :: struct {
	using bus: mos6502.Bus,
	cpu_vram:  [2048]u8,
	prg_rom:   []u8,
	// rom:       Rom,
	ppu:       Ricoh2c02,
	mapper:    u8,
}

NES :: struct {
	cpu6502: mos6502.MOS6502,
	bus:     Bus,
}

RAM: u16 : 0x0000
RAM_MIRRORS_END: u16 : 0x1FFF
PPU_REGISTERS: u16 : 0x2000
PPU_REGISTERS_MIRRORS_END: u16 : 0x3FFF

bus_mem_read :: proc(bus: ^mos6502.Bus, addr: u16) -> u8 {
	bus := cast(^Bus)bus
	mem_val: u8

	switch addr {
	case RAM ..= RAM_MIRRORS_END:
		mirror_down_addr := addr & 0b00000111_11111111
		mem_val = bus.cpu_vram[mirror_down_addr]
	case 0x2000, 0x2001, 0x2003, 0x2005, 0x2006:
		when ODIN_DEBUG {
			// Because disassembling instruction might try to read from here
			log.warn("Attempt to read from write-only PPU address:", addr)
		} else {
			log.fatal("Attempt to read from write-only PPU address:", addr)
		}
	case 0x2002:
		mem_val = read_ppu_status(&bus.ppu)
	case 0x2004:
	case 0x2007:
		mem_val = read_ppu_data(&bus.ppu)
	case 0x2008 ..= PPU_REGISTERS_MIRRORS_END:
		// Calculate what address this address mirrors and then
		// read from that address instead
		mirror_down_addr := addr & 0b00100000_00000111
		mem_val = bus_mem_read(bus, mirror_down_addr)
	case 0x8000 ..= 0xFFFF:
		mem_val = prg_read(bus.prg_rom, addr)
	case:
		log.warn("Ignoring mem access at ", addr)
		mem_val = 0
	}

	return mem_val
}

// Maybe rewrite back as PPU_REGISTERS ..= PPU_REGISTERS_END and move
// the switch statements here to a separate PPU read/write function
bus_mem_write :: proc(bus: ^mos6502.Bus, addr: u16, data: u8) {
	bus := cast(^Bus)bus

	switch addr {
	case RAM ..= RAM_MIRRORS_END:
		mirror_down_addr := addr & 0b00000111_11111111
		bus.cpu_vram[mirror_down_addr] = data
	case 0x2000:
		write_to_ctrl(&bus.ppu, data)
	case 0x2001:
		write_to_mask(&bus.ppu, data)
	case 0x2002:
		log.panic("Attempting to write to status which is read only")
	case 0x2003:
		write_oamaddr(&bus.ppu, data)
	case 0x2004:
		write_oamdata(&bus.ppu, data)
	case 0x2005:
		write_to_scroll(&bus.ppu, data)
	case 0x2006:
		write_to_addr(&bus.ppu, data)
	case 0x2007:
		write_to_ppu_data(&bus.ppu, data)
	case 0x2008 ..= PPU_REGISTERS_MIRRORS_END:
		// Calculate what address this address mirrors and write
		// to that address
		mirror_down_addr := addr & 0b00100000_00000111
		bus_mem_write(bus, mirror_down_addr, data)
	case 0x4014:
		ppu_oam_dma(bus, data)
	case 0x8000 ..= 0xFFFF:
		log.error("Attempting to write to a cartridge ROM space.")
	case:
		fmt.println("Ignoring mem write-access at", addr)
	}
}

ppu_oam_dma :: proc(bus: ^Bus, addr: u8) {

	addr_min := (u16(addr) << 8) | 0
	addr_max := (u16(addr) << 8) | 0xFF

	for i in 0 ..< 256 {
		bus.ppu.oam_data[i] = bus.read(bus, u16(i) + addr_min)
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

	// rom := load_rom(fn)
	// nes.bus.rom = rom

	prg_rom, chr_rom, mapper, mirroring := read_ines(fn)

	nes.bus.prg_rom = prg_rom
	nes.bus.mapper = mapper
	nes.bus.ppu.chr_rom = chr_rom

	if mirroring == 0 do nes.bus.ppu.mirroring = .VERTICAL
	if mirroring == 1 do nes.bus.ppu.mirroring = .HORIZONTAL
	if mirroring == 2 do nes.bus.ppu.mirroring = .FOUR_SCREEN

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

	// Reset vector
	low := nes.bus.read(&nes.bus, 0xFFFC)
	high := nes.bus.read(&nes.bus, 0xFFFD)

	reset_pc := (u16(high) << 8) | u16(low)

	fmt.printf("RESET %4x", reset_pc)

	nes.cpu6502.pc = auto_cast reset_pc

}

// Checks whether a NMI interrupt was generated
poll_nmi_status :: proc(bus: ^Bus) -> bool {
	return poll_nmi_interrupt(&bus.ppu)
}

tick :: proc(bus: ^Bus, ncycles: int) {
	frame: Frame

	bus.ncycles += ncycles

	nmi_before := bus.ppu.nmi_interrupt
	tick_ppu(&bus.ppu, 3 * ncycles)
	nmi_after := bus.ppu.nmi_interrupt

	if !nmi_before && nmi_after {
		render_background(&bus.ppu, &frame)
		render_frame(&frame, 5)
	}
}

run :: proc(nes: ^NES) {

	// num_cycles: int

	for {

		// Check for NMI before executing each instruction
		if poll_nmi_status(&nes.bus) do interrupt_nmi(&nes.cpu6502, &nes.bus)


		when ODIN_DEBUG {
			mos6502.disassemble6502p_ver2(&nes.cpu6502, &nes.bus)
			mos6502.display_registers(&nes.cpu6502)
			fmt.printf(" ")
			display_ppu_cycles()
			fmt.printf(" ")
			mos6502.display_cycles(&nes.cpu6502, nes.bus.ncycles)
			fmt.printf("\n")
		}
		// Execute next instruction and determine how long it took
		num_cycles := mos6502.emulate6502p(&nes.cpu6502, &nes.bus)
		tick(&nes.bus, num_cycles)
		// tot_cycles += num_cycles

		// Play catch-up with the PPU. Since it runs 3 times as fast execute
		// 3 times the number of cycles as the previous CPU instruction
		// tick_ppu(&nes.bus.ppu, 3 * num_cycles)

	}
}

interrupt_nmi :: proc(state: ^mos6502.MOS6502, bus: ^Bus) {
	// Implement the non-maskable interrupt
	// Push the current PC and status on the stack
	// and then jump to the location stored at 0xFFFA-0xFFFB
	high, low := mos6502.getHighLow(u16(state.pc))
	mos6502.pushR(high, low, state, bus)
	flags := state.status

	state.status = state.status | mos6502.BreakCommand2
	state.status = state.status &~ mos6502.BreakCommand

	mos6502.push8(state.status, state, bus)
	state.status = state.status | mos6502.InterruptDisable

	tick(bus, 2)

	low_nmi := bus.read(bus, 0xFFFA)
	high_nmi := bus.read(bus, 0xFFFB)

	nmi_pc := (u16(high_nmi) << 8) | u16(low_nmi)
	state.pc = auto_cast nmi_pc
}
