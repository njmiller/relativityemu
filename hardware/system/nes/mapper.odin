package nes

import "core:log"

// Code to implement some "mapper" chips by storing the info needed to determine
// which PRG and CHR blocks are currently accessible to the NES.

MapperInfo :: struct {
	num:  int,
	info: [10]int,
}

// Call the different mapper routines implemented in the mapper package.
update_mi :: proc(mi: ^MapperInfo, addr: u16, data: u8) {
	// delete(bus.prg_rom)

	switch mi.num {
	case 0:
		update_mapper_0()
	case 2:
		update_mapper_2(mi, data)
	// delete(bus.prg_rom)
	// bus.prg_rom = mapper.mapper2(bus.rom.prg_rom, data)
	case:
		log.fatal("Unimplemented mapper:", mi.num)
	}
}

update_mapper_0 :: proc() {
	log.fatal("Trying to write to PRG RAM in Mapper 0")
}

update_mapper_2 :: proc(mi: ^MapperInfo, data: u8) {
	mi.info[0] = auto_cast (data & 0b0000_1111)
}

init_mapper :: proc(mapper_num: int, mi: ^MapperInfo, nprg: int, nchr: int) {

	mi.num = mapper_num

	switch mapper_num {
	case 0:
		init_mapper_0(mi, nprg)
	case 2:
		init_mapper_2(mi, nprg)
	}
}

init_mapper_0 :: proc(mi: ^MapperInfo, nprg: int) {
	// For Mapper 0, just store the number of PRG banks in the
	// first element of the info (either 1 or 2)
	mi.info[0] = nprg
}

init_mapper_2 :: proc(mi: ^MapperInfo, nprg: int) {
	// FOr Mapper 2, store the current bank in the first element
	// and the number of the last bank in the second element
	mi.info[0] = 0
	mi.info[1] = nprg - 1
}

prg_read :: proc(prg_rom: []u8, mi: ^MapperInfo, addr: u16) -> u8 {
	data: u8
	switch mi.num {
	case 0:
		data = read_mapper_0(prg_rom, mi, addr)
	case 2:
		data = read_mapper_2(prg_rom, mi, addr)
	case:
		log.fatal("Unimplemented mapper.")
	}
	return data
}

read_mapper_0 :: proc(prg_rom: []u8, mi: ^MapperInfo, addr: u16) -> u8 {
	nbanks := mi.info[0]
	addr := addr - 0x8000
	if nbanks == 1 && addr >= 0x4000 do addr = addr % 0x4000
	return prg_rom[addr]
}

read_mapper_2 :: proc(prg_rom: []u8, mi: ^MapperInfo, addr: u16) -> u8 {
	addr: int = auto_cast addr - 0x8000

	if addr < 0x4000 {
		return prg_rom[0x4000 * mi.info[0] + addr]
	} else {
		addr = addr % 4000
		return prg_rom[0x4000 * mi.info[1] + addr]
	}
}
