package emulator

import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:os"
import "core:time"

import "hardware:cpu/mos6502"
import "hardware:system/nes"

import "vendor:sdl2"

// FRAME_WIDTH :: 256
// FRAME_HEIGHT :: 240

/*
get_color :: proc(val: u8) -> rl.Color {

	switch val {
	case 0:
		return rl.BLACK
	case 1:
		return rl.WHITE
	case 2, 9:
		return rl.GRAY
	case 3, 10:
		return rl.RED
	case 4, 11:
		return rl.GREEN
	case 5, 12:
		return rl.BLUE
	case 6, 13:
		return rl.MAGENTA
	case 7, 14:
		return rl.YELLOW
	case:
		return rl.SKYBLUE
	}
}

update_screen :: proc(screen_state: []rl.Color, scaling: i32) {
	pix_x: i32 = 0
	pix_y: i32 = 0

	for i in 0 ..< 0x400 {
		color := screen_state[i]
		pix_x, pix_y = auto_cast i % 32, auto_cast i / 32
		rl.DrawRectangle(pix_x * scaling, pix_y * scaling, scaling, scaling, color)
	}
}

// Read the screen state into an array of raylib Color structs
read_screen_state :: proc(screen_memory: []u8, screen_state: []rl.Color) -> bool {

	screen_size := len(screen_memory)
	update_screen := false

	for i in 0 ..< screen_size {
		color := get_color(screen_memory[i])
		if color != screen_state[i] {
			screen_state[i] = color
			update_screen = true
		}
	}

	return update_screen
}

// Maybe just pass a pointer to the correct memory location
handle_input :: proc(memory: []u8) {
	if rl.IsKeyPressed(rl.KeyboardKey.W) do memory[0xFF] = 0x77
	if rl.IsKeyPressed(rl.KeyboardKey.S) do memory[0xFF] = 0x73
	if rl.IsKeyPressed(rl.KeyboardKey.A) do memory[0xFF] = 0x61
	if rl.IsKeyPressed(rl.KeyboardKey.D) do memory[0xFF] = 0x64
}


run_snake :: proc(nes1: ^nes.NES) {
	totCycles: int

	screen_state := make([]rl.Color, 0x400)
	screen_state2: rl.Image

	do_update: bool

	/* Game loop */
	for !rl.WindowShouldClose() {

		// Read user input and write it to mem[0xFF]
		handle_input(nes1.bus.cpu_vram[:])

		// update mem[0xFE] with new random number
		nes1.bus.cpu_vram[0xFE] = auto_cast (0xFF & rand.uint32())

		// read mem mapped screen state
		do_update = read_screen_state(nes1.bus.cpu_vram[0x0200:0x0600], screen_state)

		// render screen state
		if do_update {
			// Update the display
			rl.BeginDrawing()
			rl.ClearBackground(rl.WHITE)
			update_screen(screen_state, 10)
			rl.EndDrawing()

		}

		// fmt.println("AAA:", nes.cpu6502.pc, nes.bus.cpu_vram[nes.cpu6502.pc])
		debug := false
		if debug {
			mos6502.disassemble6502p_ver2(&nes1.cpu6502, &nes1.bus)
			fmt.printf(" ")
			nes.display_ppu_cycles()
			fmt.printf(" ")
			mos6502.display_cycles(&nes1.cpu6502, totCycles)
			fmt.printf("\n")
		}
		totCycles += mos6502.emulate6502p(&nes1.cpu6502, &nes1.bus)

		//fmt.println("STACK:", nes.bus.cpu_vram[0x01C0:0x0200])
		time.accurate_sleep(70000)
		if nes1.bus.read(&nes1.bus, auto_cast nes1.cpu6502.pc) == 0 do break
		//if totCycles > 50 do break
	}
}
*/

debug6502 :: proc() {
	nes1 := nes.init_nes("games/nestest.nes")

	nes1.cpu6502.pc = 0xC000

	totCycles := 7
	for totCycles < 30000 {

		// cpu.disassemble6502p(&nes.cpu6502, &nes.bus)
		mos6502.disassemble6502p_ver2(&nes1.cpu6502, &nes1.bus)
		mos6502.display_registers(&nes1.cpu6502)
		fmt.printf(" ")
		nes.display_ppu_cycles()
		fmt.printf(" ")
		mos6502.display_cycles(&nes1.cpu6502, totCycles)
		fmt.printf("\n")

		totCycles += mos6502.emulate6502p(&nes1.cpu6502, &nes1.bus)


	}
}

/*
test_snake_game :: proc() {

	// Test game code for snake game
	game_code := [?]u8 {
		0x20, // 0x600
		0x06, // 0x601
		0x06, // 0x602
		0x20, // 0x603
		0x38, // 0x604
		0x06, // 0x605
		0x20, // 0x606
		0x0d, // 0x607
		0x06, // 0x608
		0x20, // 0x609
		0x2a, // 0x60a
		0x06, // 0x60b
		0x60, // 0x60c
		0xa9, // 0x60d
		0x02, // 0x60e
		0x85, // 0x60f
		0x02, // 0x610
		0xa9, // 0x611
		0x04, // 0x612
		0x85, // 0x613
		0x03, // 0x614
		0xa9, // 0x615
		0x11, // 0x616
		0x85, // 0x617
		0x10, // 0x618
		0xa9, // 0x619
		0x10, // 0x61a
		0x85, // 0x61b
		0x12, // 0x61c
		0xa9, // 0x61d
		0x0f, // 0x61e
		0x85, // 0x61f
		0x14, // 0x620
		0xa9, // 0x621
		0x04, // 0x622
		0x85, // 0x623
		0x11, // 0x624
		0x85, // 0x625
		0x13, // 0x626
		0x85, // 0x627
		0x15, // 0x628
		0x60, // 0x629
		0xa5, // 0x62a
		0xfe, // 0x62b
		0x85, // 0x62c
		0x00, // 0x62d
		0xa5, // 0x62e
		0xfe, // 0x62f
		0x29, // 0x630
		0x03, // 0x631
		0x18, // 0x632
		0x69, // 0x633
		0x02, // 0x634
		0x85, // 0x635
		0x01, // 0x636
		0x60, // 0x637
		0x20,
		0x4d,
		0x06,
		0x20,
		0x8d,
		0x06,
		0x20,
		0xc3,
		0x06, // 0x640
		0x20,
		0x19,
		0x07,
		0x20,
		0x20,
		0x07,
		0x20,
		0x2d,
		0x07,
		0x4c,
		0x38,
		0x06,
		0xa5,
		0xff,
		0xc9,
		0x77, // 0x650
		0xf0,
		0x0d,
		0xc9,
		0x64,
		0xf0,
		0x14,
		0xc9,
		0x73,
		0xf0,
		0x1b,
		0xc9,
		0x61,
		0xf0,
		0x22,
		0x60,
		0xa9, // 0x660
		0x04,
		0x24,
		0x02,
		0xd0,
		0x26,
		0xa9,
		0x01,
		0x85,
		0x02,
		0x60,
		0xa9,
		0x08,
		0x24,
		0x02,
		0xd0,
		0x1b, // 0x670
		0xa9,
		0x02,
		0x85,
		0x02,
		0x60,
		0xa9,
		0x01,
		0x24,
		0x02,
		0xd0,
		0x10,
		0xa9,
		0x04,
		0x85,
		0x02,
		0x60, // 0x680
		0xa9,
		0x02,
		0x24,
		0x02,
		0xd0,
		0x05,
		0xa9,
		0x08,
		0x85,
		0x02,
		0x60,
		0x60,
		0x20,
		0x94,
		0x06,
		0x20, // 0x690
		0xa8,
		0x06,
		0x60,
		0xa5,
		0x00,
		0xc5,
		0x10,
		0xd0,
		0x0d,
		0xa5,
		0x01,
		0xc5,
		0x11,
		0xd0,
		0x07,
		0xe6, // 0x6a0
		0x03,
		0xe6,
		0x03,
		0x20,
		0x2a,
		0x06,
		0x60,
		0xa2,
		0x02,
		0xb5,
		0x10,
		0xc5,
		0x10,
		0xd0,
		0x06,
		0xb5, // 0x6b0
		0x11,
		0xc5,
		0x11,
		0xf0,
		0x09,
		0xe8,
		0xe8,
		0xe4,
		0x03,
		0xf0,
		0x06,
		0x4c,
		0xaa,
		0x06,
		0x4c,
		0x35, // 0x6c0
		0x07,
		0x60,
		0xa6,
		0x03,
		0xca,
		0x8a,
		0xb5,
		0x10,
		0x95,
		0x12,
		0xca,
		0x10, // 0x6cc
		0xf9,
		0xa5,
		0x02,
		0x4a, // 0x6d0
		0xb0,
		0x09,
		0x4a,
		0xb0,
		0x19,
		0x4a,
		0xb0,
		0x1f,
		0x4a,
		0xb0,
		0x2f,
		0xa5,
		0x10,
		0x38,
		0xe9,
		0x20, // 0x6e0
		0x85,
		0x10,
		0x90,
		0x01,
		0x60,
		0xc6,
		0x11,
		0xa9,
		0x01,
		0xc5,
		0x11,
		0xf0,
		0x28,
		0x60,
		0xe6,
		0x10, // 0x6f0
		0xa9,
		0x1f,
		0x24,
		0x10,
		0xf0,
		0x1f,
		0x60,
		0xa5,
		0x10,
		0x18,
		0x69,
		0x20,
		0x85,
		0x10,
		0xb0,
		0x01, // 0x700
		0x60,
		0xe6,
		0x11,
		0xa9,
		0x06,
		0xc5,
		0x11,
		0xf0,
		0x0c,
		0x60,
		0xc6,
		0x10,
		0xa5,
		0x10,
		0x29,
		0x1f, // 0x710
		0xc9,
		0x1f,
		0xf0,
		0x01,
		0x60,
		0x4c,
		0x35,
		0x07,
		0xa0,
		0x00,
		0xa5,
		0xfe,
		0x91,
		0x00,
		0x60,
		0xa6, // 0x720
		0x03,
		0xa9,
		0x00,
		0x81,
		0x10,
		0xa2,
		0x00,
		0xa9,
		0x01,
		0x81,
		0x10,
		0x60,
		0xa2,
		0x00,
		0xea,
		0xea, // 0x730
		0xca,
		0xd0,
		0xfb,
		0x60,
	}

	context.logger = log.create_console_logger()

	sw: time.Stopwatch

	// nes_state: system.NES
	nes_state := nes.init_nes("TEST")

	rl.InitWindow(320, 320, "Odin NES")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)


	//nes_state.memory = make([]u8, 0xFFFF)

	copy(nes_state.bus.cpu_vram[0x0600:], game_code[:])

	nes_state.cpu6502.pc = 0x0600

	run_snake(&nes_state)

	// pc := 0
	// for i in 0 ..< len(game_code) {
	// fmt.println("TEST:", i, " ", game_code[i])
	// pc += cpu.disassemble6502p(memory, pc)
	// cpu.emulate6502p(&state, memory)
	// }

	// fmt.printf("%02x", state.ix)
}
*/

run_game :: proc(fn: string) {

	nes_state := nes.init_nes(fn)

	assert(sdl2.Init(sdl2.INIT_VIDEO) == 0, sdl2.GetErrorString())
	defer sdl2.Quit()

	window := sdl2.CreateWindow(
		"Odin Emulator",
		sdl2.WINDOWPOS_CENTERED,
		sdl2.WINDOWPOS_CENTERED,
		640,
		480,
		sdl2.WINDOW_SHOWN,
	)
	assert(window != nil, sdl2.GetErrorString())
	defer sdl2.DestroyWindow(window)

	// Must not do VSync because we run the tick loop on the same thread as rendering.
	renderer := sdl2.CreateRenderer(window, -1, sdl2.RENDERER_ACCELERATED)
	// renderer := sdl2.CreateRenderer(window, -1, sdl2.RENDERER_SOFTWARE)
	assert(renderer != nil, sdl2.GetErrorString())
	defer sdl2.DestroyRenderer(renderer)

	scaling := 2
	sdl2.RenderSetScale(renderer, auto_cast scaling, auto_cast scaling)

	texture := sdl2.CreateTexture(
		renderer,
		auto_cast sdl2.PixelFormatEnum.RGB24,
		// auto_cast sdl2.PixelFormatEnum.RGBA8888,
		sdl2.TextureAccess.STREAMING,
		nes.FRAME_WIDTH,
		nes.FRAME_HEIGHT,
	)
	defer sdl2.DestroyTexture(texture)

	sdl2.SetTextureBlendMode(texture, sdl2.BlendMode.NONE)

	// pitch: i32 = nes.FRAME_WIDTH * 3
	// npix := nes.FRAME_HEIGHT * nes.FRAME_WIDTH * 3

	// sdl2.CreateRGBSurface()
	// pixels: []u8 = make([]u8, npix)
	// succt := sdl2.LockTexture(texture, nil, auto_cast &pixels, &pitch)
	// defer sdl2.UnlockTexture(texture)

	ri := nes.RenderInfo{renderer, texture}

	nes_state.bus.ri = ri

	nes.run(nes_state)

}


/*
test_render :: proc() {
	prg, chr, mapper, mirroring := nes.read_ines("games/pacman.nes")
	tile_frame: nes.Frame

	bank := 0
	for i in 0 ..< 256 {
		x_off := (i * 9) % 180
		y_off := ((i * 9) / 180) * 9
		// y_off := 0
		nes.show_tile(&tile_frame, x_off, y_off, chr, bank, i)
	}

	rl.InitWindow(1920, 1080, "Test Render")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	scaling: i32 = 5
	for {
		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE)
		nes.render_frame(&tile_frame, scaling)
		rl.EndDrawing()
	}
}
*/

main :: proc() {
	//test_snake_game()

	context.logger = log.create_console_logger()
	context.user_index = 0

	// when ODIN_DEBUG {
	// debug6502()
	// } else {
	// run_game("games/snake.nes")
	// test_render()
	run_game(os.args[1])
	// run_game("games/nestest.nes")
	// run_game("games/pacman.nes")
	// nes_game := nes.init_nes("games/pacman.nes")
	// nes.run(&nes_game)
	// }
}
