package nes

import "core:fmt"
import "core:log"
import "core:time"

import "vendor:sdl3"

import "hardware:cpu/mos6502"


CLOCK_SPEED: u64 : 1789 // KHz
SAVE_INTERVAL_CYCLES :: 5 * 1789 * 1000
FAST_FORWARD_SPEED :: 4.0

// CPU cycles in one NES frame, used to pace how often SDL input is polled
INPUT_POLL_CYCLES :: 29780

RenderInfo :: struct {
	renderer: ^sdl3.Renderer,
	texture:  ^sdl3.Texture,
	// surface:  ^sdl3.Surface,
	// pixels:   []u8,
}

Bus :: struct {
	using bus: mos6502.Bus,
	cpu_vram:  [2048]u8,
	ppu:       Ricoh2c02,
	apu:       APU,
	jp1:       JoyPad,
	jp2:       JoyPad,
	ri:        RenderInfo,
	cart:      Cartridge,

	// Emulated frames arrive at 60 * speed per second, so presenting one in
	// every "speed" of them holds the display at roughly 60 FPS no matter how
	// fast the emulation is running. 1 at normal speed presents every frame
	frame_counter:      int,
	frames_per_present: int,
}

NES :: struct {
	cpu6502: mos6502.MOS6502,
	bus:     Bus,
}

RAM: u16 : 0x0000
RAM_MIRRORS_END: u16 : 0x1FFF
PPU_REGISTERS: u16 : 0x2000
PPU_REGISTERS_MIRRORS_END: u16 : 0x3FFF
APU_REGISTERS: u16 : 0x4000
APU_REGISTERS_END: u16 : 0x4015

bus_mem_read :: proc(bus: ^mos6502.Bus, addr: u16) -> u8 {
	bus := cast(^Bus)bus
	mem_val: u8

	switch addr {
	case RAM ..= RAM_MIRRORS_END:
		mirror_down_addr := addr & 0b00000111_11111111
		mem_val = bus.cpu_vram[mirror_down_addr]
	case PPU_REGISTERS ..= PPU_REGISTERS_MIRRORS_END:
		mem_val = read_ppu_register(&bus.ppu, addr)
	case 0x4016:
		mem_val = read_joypad(&bus.jp1)
	case 0x4017:
	// mem_val = read_joypad(&bus.jp2)
	// case 0x4000 ..= 0x4015:
	case APU_REGISTERS ..= APU_REGISTERS_END:
		mem_val = read_apu_register(&bus.apu, addr)
	case 0x6000 ..= 0x7FFF:
		mem_val = prg_ram_read(&bus.cart, addr)
	case 0x8000 ..= 0xFFFF:
		mem_val = prg_read(&bus.cart, addr)
	case:
		log.warn("Ignoring mem access at ", addr)
		mem_val = 0
	}

	return mem_val
}

bus_mem_write :: proc(bus: ^mos6502.Bus, addr: u16, data: u8) {
	// Could probably move write to PPU addresses into a separate function in ppu.odin.
	// They just take the ppu, address, and data

	bus := cast(^Bus)bus

	switch addr {
	case RAM ..= RAM_MIRRORS_END:
		mirror_down_addr := addr & 0b00000111_11111111
		bus.cpu_vram[mirror_down_addr] = data
	// Start of the PPU registers
	case PPU_REGISTERS ..= PPU_REGISTERS_MIRRORS_END:
		write_ppu_register(&bus.ppu, addr, data)
	case 0x4014:
		ppu_oam_dma(bus, data)
	case APU_REGISTERS ..= APU_REGISTERS_END:
		write_apu_register(&bus.apu, addr, data)
	case 0x4016:
		write_joypad(&bus.jp1, data)
		write_joypad(&bus.jp2, data)
	case 0x4017:
		// Writing to 0x4017 writes to the APU
		write_apu_register(&bus.apu, addr, data)
	case 0x6000 ..= 0x7FFF:
		prg_ram_write(&bus.cart, addr, data)
	case 0x8000 ..= 0xFFFF:
		prg_write(&bus.cart, addr, data)
	case:
		fmt.println("Ignoring mem write-access at", addr)
	}
}

ppu_oam_dma :: proc(bus: ^Bus, addr: u8) {

	addr_min := (u16(addr) << 8) | 0
	// addr_max := (u16(addr) << 8) | 0xFF

	for i in 0 ..< 256 {
		bus.ppu.oam_data[i] = bus.read(bus, u16(i) + addr_min)
	}

	// The DMA unit halts the CPU for 513 cycles while it copies, and games time
	// raster effects around that. The copy above is instant, so the PPU and APU
	// have to be advanced by hand to keep them in phase with the CPU
	// TODO: Can I figure out a way to move this to within cpu6502.odin (the cycle number)?
	// Or is the cycle count specific to the NES?
	tick(bus, 513)
}

init_nes :: proc(fn: string) -> ^NES {
	// nes := NES{}
	nes := new(NES)

	// Set up the bus read/write functions
	nes.bus.read = bus_mem_read
	nes.bus.write = bus_mem_write

	// The NES version of the CPU does not implement decimal mode
	nes.cpu6502.dm_avail = false

	// prg_rom, chr_rom, mapper, mirroring := read_ines(fn)
	nes.bus.cart = read_ines(fn)

	// The PPU reads its CHR data, mirroring, and CHR banking off the cartridge
	nes.bus.ppu.cart = &nes.bus.cart

	nes.bus.cart.prg_ram = make([]u8, nes.bus.cart.prg_ram_size)
	if nes.bus.cart.has_battery {
		nes.bus.cart.save_path = save_path_for_rom(fn)
		load_sram(&nes.bus.cart)
	} else do nes.bus.cart.save_path = ""

	// Initialize the MapperInfo structure with the mapper num. This runs after the
	// cart is in place because a mapper can override the header's mirroring.
	init_mapper(&nes.bus.cart)

	// APU DMC needs ability to read memory
	nes.bus.apu.dmc.bus = &nes.bus

	// if mirroring == 0 do nes.bus.ppu.mirroring = .HORIZONTAL
	// if mirroring == 1 do nes.bus.ppu.mirroring = .VERTICAL
	// if mirroring == 2 do nes.bus.ppu.mirroring = .FOUR_SCREEN

	init_audio(&nes.bus.apu)

	reset(nes)

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

	reset_apu(&nes.bus.apu)

	// Reset the joypad status
	nes.bus.jp1.button_index = 0
	nes.bus.jp1.strobe = false
	nes.bus.jp1.button_status = {}

	// nes.bus.jp2.button_index = 0
	// nes.bus.jp2.strobe = false
	// nes.bus.jp2.button_status = {}

	// Reset vector
	low := nes.bus.read(&nes.bus, 0xFFFC)
	high := nes.bus.read(&nes.bus, 0xFFFD)

	reset_pc := (u16(high) << 8) | u16(low)

	nes.cpu6502.pc = auto_cast reset_pc

}

// Checks whether a NMI interrupt was generated
poll_nmi_status :: proc(bus: ^Bus) -> bool {
	return poll_nmi_interrupt(&bus.ppu)
}

tick :: proc(bus: ^Bus, ncycles: int) {

	// frame := bus.ppu.frame
	bus.ncycles += ncycles

	// Play catch-up with the PPU. Since it runs 3 times as fast execute
	// 3 times the number of cycles as the previous CPU instruction

	nmi_before := bus.ppu.nmi_interrupt
	// tick_ppu(&bus.ppu, 3 * ncycles)
	for i in 0 ..< 3 * ncycles {
		tick_once(&bus.ppu)
	}
	for i in 0 ..< ncycles {
		// tick_once(&bus.ppu)
		// tick_once(&bus.ppu)
		// tick_once(&bus.ppu)
		tick_apu(&bus.apu)
	}

	nmi_after := bus.ppu.nmi_interrupt

	if !nmi_before && nmi_after {
		// render_background(&bus.ppu, &bus.ppu.frame)
		// render_sprites(&bus.ppu, &bus.ppu.frame)
		// render_frame_texture(&bus.ppu.frame, &bus.ri)
		bus.frame_counter += 1
		if bus.frame_counter >= bus.frames_per_present {
			render_image(bus.ppu.image[:], &bus.ri)
			bus.frame_counter = 0
		}
	}
}

calc_duration :: proc(sw: ^time.Stopwatch) -> i64 {
	time.stopwatch_stop(sw)
	duration := time.stopwatch_duration(sw^)
	dur := time.duration_nanoseconds(duration)
	time.stopwatch_reset(sw)
	time.stopwatch_start(sw)

	return dur
}

run :: proc(nes: ^NES) {

	sw: time.Stopwatch
	num_cycles_tot: int = 0
	save_accum_cycles : int = 0
	nmi_pending := false
	fast_forward := false
	input_accum_cycles := 0

	time.stopwatch_start(&sw)
	for {

		speed := FAST_FORWARD_SPEED if fast_forward else 1.0
		nes.bus.apu.speed = speed
		nes.bus.frames_per_present = auto_cast speed

		// OAM DMA and the NMI push cycles through tick() that emulate6502p
		// never reports, so the throttle below has to read the bus counter
		// rather than the CPU return value. Missing them let the APU run about
		// 1.7% fast, and since the SDL stream has no backpressure that surplus
		// piled up as ever growing audio latency
		prev_ncycles := nes.bus.ncycles

		// The PPU is ticked after each instruction, so an NMI it raises belongs to
		// the middle of the instruction that gets executed next. The CPU always
		// finishes that instruction before servicing the interrupt, which is what
		// lets a loop polling 0x2002 see the vblank flag before the NMI handler
		// gets a chance to clear it.
		take_nmi := nmi_pending
		nmi_pending = poll_nmi_status(&nes.bus)
		if take_nmi do interrupt_nmi(&nes.cpu6502, &nes.bus)

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

		// Tick the APU and PPU by a number of cycles based off the number of cycles
		// of the CPU
		tick(&nes.bus, num_cycles)

		// Polling SDL pumps the OS event loop, which costs roughly a microsecond
		// on macOS. Doing that once per instruction dominated the run time and
		// held the emulator to about 1.1x. Once per frame is also when a real
		// console latches the controller, so nothing is lost by waiting
		input_accum_cycles += num_cycles
		if input_accum_cycles >= INPUT_POLL_CYCLES {
			ex := check_input1(&nes.bus.jp1, &fast_forward)
			if ex == -1 {
				save_sram(&nes.bus.cart)
				return
			}
			input_accum_cycles = 0
		}

		// Increment the save counter and attempt to save if it is above the threshold
		save_accum_cycles += num_cycles
		if save_accum_cycles >= SAVE_INTERVAL_CYCLES {
			save_sram(&nes.bus.cart)
			save_accum_cycles = 0
		}

		// Do some calculation based on the time to execute the instruction and time it would
		// take NES to execute the instruction and sleep to match up
		/* dur := calc_duration(&sw)
		ns_per_cycle := 558.6592
		time_to_sleep: int = auto_cast (f64(num_cycles) * ns_per_cycle - f64(dur))
		// time.accurate_sleep(4000) // nanoseconds
		time.accurate_sleep(auto_cast time_to_sleep)
		calc_duration(&sw) // need to reset stopwatch after sleep
		*/
		
		// Do some calculation based on the time it would take the NES to execute
		// the instruction. Keep track across multiple instructions and
		// sleep when the time crosses a certain threshold.
		num_cycles_tot += nes.bus.ncycles - prev_ncycles
		// 1e9 / CPU_CLOCK_HZ. Has to agree with the clock the APU derives its
		// sample rate from or the two drift apart
		ns_per_cycle := 558.7301
		// time_cycles : int = auto_cast(f64(num_cycles_tot) * ns_per_cycle)
		real_ns := f64(num_cycles_tot) * ns_per_cycle / speed
		// if time_cycles > 1_000_000 {
		if real_ns > 1_000_000 {
			// This resets the stopwatch so we only call it when we need to sleep. 
			// Otherwise we would be resetting it every instruction and losing the
			// cumulative time across instructions.
			dur := calc_duration(&sw)

			// time_to_sleep: int = auto_cast (f64(num_cycles_tot) * ns_per_cycle - f64(dur))
			time_to_sleep: int = auto_cast(real_ns - f64(dur))
			time.accurate_sleep(auto_cast time_to_sleep)
			calc_duration(&sw) // need to reset stopwatch after sleep
			num_cycles_tot = 0 // reset the total number of cycles after sleeping
		}
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
