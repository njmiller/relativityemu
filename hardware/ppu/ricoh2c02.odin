package ppu

RicohMirroring :: enum {
	VERTICAL,
	HORIZONTAL,
	FOUR_SCREEN,
}

Ricoh2c02 :: struct {
	chr_rom:       []u8,
	palette_table: [32]u8,
	vram:          [2048]u8,
	oam_data:      [256]u8,
	mirroring:     RicohMirroring,
}
