package ppu

import "core:log"

RicohMirroring :: enum {
	VERTICAL,
	HORIZONTAL,
	FOUR_SCREEN,
}

Ricoh2c02 :: struct {
	chr_rom:           []u8,
	palette_table:     [32]u8,
	vram:              [2048]u8,
	oam_data:          [256]u8,
	mirroring:         RicohMirroring,
	addr:              AddrRegister,
	ctrl:              Controller_Bitset,
	internal_data_buf: u8,
}

AddrRegister :: struct {
	value:  [2]u8,
	hi_ptr: bool,
}

new_addr_register :: proc() -> AddrRegister {
	addr: AddrRegister
	addr.hi_ptr = true

	return addr
}

set_addr :: proc(addr: ^AddrRegister, data: u16) {
	addr.value[0] = auto_cast (data >> 8)
	addr.value[1] = auto_cast (data & 0xFF)
}

update_addr :: proc(addr: ^AddrRegister, data: u8) {
	if addr.hi_ptr {
		addr.value[0] = data
	} else {
		addr.value[1] = data
	}

	// 0x3FFF = 0b00111111_11111111
	if int(get_addr(addr)) > 0x3FFF do set_addr(addr, get_addr(addr) & 0x3FFF)
}

increment_addr :: proc(addr: ^AddrRegister, inc: u8) {
	lo := addr.value[1]
	addr.value[1] += inc
	if lo > addr.value[1] do addr.value[0] += 1

	if int(get_addr(addr)) > 0x3FFF do set_addr(addr, get_addr(addr) & 0x3FFF)
}

reset_latch_addr :: proc(addr: ^AddrRegister) {
	addr.hi_ptr = true
}

get_addr :: proc(addr: ^AddrRegister) -> u16 {
	return (u16(addr.value[0]) << 8) | u16(addr.value[1])
}

write_to_ppu :: proc(ppu: ^Ricoh2c02, value: u8) {
	update_addr(&ppu.addr, value)
}

Controller_Flags :: enum u8 {
	NAMETABLE1              = 0b00000001,
	NAMETABLE2              = 0b00000010,
	VRAM_ADD_INCREMENT      = 0b00000100,
	SPRITE_PATTERN_ADDR     = 0b00001000,
	BACKGROUND_PATTERN_ADDR = 0b00010000,
	SPRITE_SIZE             = 0b00100000,
	MASTER_SLAVE_SELECT     = 0b01000000,
	GENERATE_NMI            = 0b10000000,
}

Controller_Bitset :: bit_set[Controller_Flags]

new_controller :: proc() -> Controller_Bitset {
	return Controller_Bitset{}
}

vram_addr_increment :: proc(controller: ^Controller_Bitset) -> u8 {
	if .VRAM_ADD_INCREMENT in controller {
		return 1
	} else {
		return 32
	}
}

// Can this just be implemented in code and not a procedure
/*
update_controller :: proc(controller: ^Controller_Bitset, data: u8) {
	bitset_data := get_controller_bitset(data)
	controller^ = bitset_data
}
*/

get_controller_bitset :: proc(data: u8) -> Controller_Bitset {
	bitset_tmp := Controller_Bitset{}

	for i in 0 ..< 8 {
		bit_tmp := u8(1) << uint(i)
		if bit_tmp & data != 0 do bitset_tmp += {Controller_Flags(bit_tmp)}
	}

	return bitset_tmp
}

write_to_ctrl :: proc(ppu: ^Ricoh2c02, value: u8) {
	ppu.ctrl = get_controller_bitset(value)
}

read_ppu_data :: proc(ppu: ^Ricoh2c02) -> u8 {
	mem_addr := get_addr(&ppu.addr)
	increment_vram_addr(ppu)

	result: u8
	switch mem_addr {
	case 0 ..= 0x1FFF:
		result = ppu.internal_data_buf
		ppu.internal_data_buf = ppu.chr_rom[mem_addr]
	case 0x2000 ..= 0x2FFF:
		result = ppu.internal_data_buf
		ppu.internal_data_buf = ppu.vram[mirror_vram_addr(mem_addr)]
	case 0x3000 ..= 0x3EFF:
		log.error("Address space 0x3000..0x3EFF is not expected to be used:", mem_addr)
	case 0x3F00 ..= 0x3FFF:
		result = ppu.palette_table[(mem_addr - 0x3F00)]
	}
	return result
}

increment_vram_addr :: proc(ppu: ^Ricoh2c02) {
	increment_addr(&ppu.addr, vram_addr_increment(&ppu.ctrl))
}

mirror_vram_addr :: proc(mem_addr: u16) -> u16 {
	return mem_addr
}

write_ppu_data :: proc(ppu: ^Ricoh2c02, mem_addr: u16, value: u8) {

}
