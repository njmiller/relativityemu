package nes

// import "vendor:sdl3"

AUDIO_SAMPLE_RATE :: 44100 // 44.1 KHz

TICKS_PER_SAMPLE :: 1

// NES APU Implementation
APU :: struct {
	pulse1:         PulseChannel,
	pulse2:         PulseChannel,
	triangle:       TriangleChannel,
	noise:          NoiseChannel,
	dmc:            DMCChannel,
	clock_all:      bool,
	sample_counter: f32,
	five_step:      bool,
	irq_inhibit:    bool,
	counter:        u16,
}

LengthCounter :: struct {
	val:  u8,
	halt: bool,
}

LinearCounter :: struct {
	control: bool,
	val:     u8,
	reload:  i8,
	// reload_flag: bool,
}

// Pulse Channel struct and functions
PulseChannel :: struct {
	duty:            u8,
	// length_counter:      u8,
	envelope_volume: u8,
	period:          u16,
	enabled:         bool,
	// length_counter_halt: bool,
	constant_volume: bool,
	envelope_start:  bool,
	volume:          u8,
	timer:           u16,
	duty_position:   u8,
	length_counter:  LengthCounter,
}

// Triangle Channel
TriangleChannel :: struct {
	period:            u16,
	enabled:           bool,
	length_counter:    LengthCounter,
	linear_counter:    LinearCounter,
	timer:             u16,
	sequence_position: u8,
}

NoiseChannel :: struct {
	period:         u16,
	enabled:        bool,
	// length_counter: u8,
	length_counter: LengthCounter,
	volume:         u8,
	mode:           bool,
	shift_register: u16,
	timer:          u16,
}

DMCChannel :: struct {
	sample_address: u16,
	sample_length:  u16,
	current_sample: u8,
	enabled:        bool,
	period:         u16,
	timer:          u16,
	output_level:   u8,
	interrupt:      bool,
}

//odinfmt: disable
lc_table : [32]u8 = {10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14,
					 12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30}

//odinfmt: enable

clock_linear_counter :: proc(lc: ^LinearCounter) {
	if lc.reload > 0 {
		lc.val = auto_cast lc.reload
		lc.reload = -1
	} else {
		lc.val -= 1
	}
}

clock_length_counter :: proc(lc: ^LengthCounter) {
	if lc.val > 0 do lc.val -= 1
}

clock_pulse :: proc(pulse_channel: ^PulseChannel) {
	if pulse_channel.timer > 0 {
		pulse_channel.timer -= 1
	} else {
		pulse_channel.timer = pulse_channel.period
		pulse_channel.duty_position = (pulse_channel.duty_position + 1) & 0x7
	}
}

output_pulse :: proc(pulse: ^PulseChannel) -> u8 {
	if !pulse.enabled || pulse.length_counter.val == 0 do return 0
	
    //odinfmt: disable
	duty_table := [32]u8 {
		0, 1, 0, 0, 0, 0, 0, 0,
		0, 1, 1, 0, 0, 0, 0, 0,
		0, 1, 1, 1, 1, 0, 0, 0,
		1, 0, 0, 1, 1, 1, 1, 1,
	}
    //odinfmt: enable

	
	//odinfmt: disable
	duty_table_2 := [32]u8 {
		0, 0, 0, 0, 0, 0, 0, 1,
		0, 0, 0, 0, 0, 0, 1, 1,
		0, 0, 0, 0, 1, 1, 1, 1,
		1, 1, 1, 1, 1, 1, 0, 0,
	}
	//odinfmt: enable

	idx := 8 * pulse.duty + pulse.duty_position
	return duty_table[idx] * pulse.volume
	// return duty_table[pulse.duty, pulse.duty_position] * pulse.volume

}

// Clocked every CPU cycle
clock_triangle :: proc(tri: ^TriangleChannel) {
	// Counts t, t-1, ..., 1, 0, t, t-1, ...
	// where t is the timer value written to the register
	// Every time it goes from 0 to t, it clocks the waveform generator
	if tri.timer > 0 {
		tri.timer -= 1
	} else {
		tri.timer = tri.period
		if tri.enabled && tri.length_counter.val > 0 && tri.linear_counter.val > 0 {
			// Sequence position goes from 0 to 31
			tri.sequence_position = (tri.sequence_position + 1) & 0x1F
		}
	}
}

output_triangle :: proc(tri: ^TriangleChannel) -> u8 {
	if !tri.enabled || tri.length_counter.val == 0 || tri.linear_counter.val == 0 do return 0
	
    //odinfmt: disable
	triangle_table := [32]u8 {
		15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
		0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
	}
    //odinfmt: enable

	return triangle_table[tri.sequence_position]
}


clock_noise :: proc(noise: ^NoiseChannel) {
	if noise.timer > 0 {
		noise.timer -= 1
	} else {
		noise.timer = noise.period
		feedback: u16 =
			((noise.shift_register & 0x1) ~ ((noise.shift_register >> (noise.mode ? 6 : 1)) & 0x1))
		noise.shift_register = (noise.shift_register >> 1) | (feedback << 14)
	}
}

output_noise :: proc(noise: ^NoiseChannel) -> u8 {
	if !noise.enabled || noise.length_counter.val == 0 do return 0
	return u8(noise.shift_register & 0x1) * noise.volume
}


clock_dmc :: proc(dmc: ^DMCChannel) {
	if dmc.timer > 0 {
		dmc.timer -= 1
	} else {
		dmc.timer = dmc.period
		// TODO: DMC Sample processing would go here
	}
}

output_dmc :: proc(dmc: ^DMCChannel) -> u8 {
	return dmc.output_level
}

reset_apu :: proc(apu: ^APU) {
	// TODO: Reset all registers here

	apu.noise.shift_register = 1
}

write_apu_register :: proc(apu: ^APU, addr: u16, value: u8) {
	switch addr {
	case 0x4000:
		apu.pulse1.duty = (value >> 6) & 0x3
		// apu.pulse1.length_counter_halt = (value >> 5) & 0x1 != 0
		apu.pulse2.length_counter.halt = value & 0b0010_0000 != 0
		apu.pulse1.constant_volume = value & 0b0001_0000 != 0
		apu.pulse1.volume = value & 0xF
	case 0x4001:
	// apu.pulse1.sweep_enabled = (value >> 7) & 0x1 != 0 ? true : false
	// apu.pulse1.sweep_period = (value >> 4) & 0x7
	// apu.pulse1.sweep_negate = (value >> 3) & 0x1
	// apu.pulse1.sweep_shift = value & 0x7
	//apu.pulse1.sweep_reload = True
	case 0x4002:
		// Keep highest 3 of 11 bits and add the 8 bits here as the lowest 8 bits
		apu.pulse1.period = apu.pulse1.period & 0x700 | u16(value)
	case 0x4003:
		apu.pulse1.period = (apu.pulse1.period & 0xFF) | ((u16(value) & 0x7) << 8)
		apu.pulse1.length_counter.val = lc_table[value >> 3]
		apu.pulse1.envelope_start = true
	case 0x4004:
		apu.pulse2.duty = (value >> 6) & 0x3
		// apu.pulse2.length_counter_halt = (value >> 5) & 0x1 != 0
		apu.pulse2.length_counter.halt = value & 0b0010_0000 != 0
		// apu.pulse2.constant_volume = (value >> 4) & 0x1 != 0
		apu.pulse2.constant_volume = value & 0b0001_0000 != 0
		apu.pulse2.volume = value & 0xF
	case 0x4005:
	// apu.pulse2.sweep_enabled = (value >> 7) & 0x1 != 0 ? true : false
	// apu.pulse2.sweep_period = (value >> 4) & 0x7
	// apu.pulse2.sweep_negate = (value >> 3) & 0x1
	// apu.pulse2.sweep_shift = value & 0x7
	//apu.pulse1.sweep_reload = True
	case 0x4006:
		apu.pulse2.period = (apu.pulse2.period & 0x700) | u16(value)
	case 0x4007:
		apu.pulse2.period = (apu.pulse2.period & 0xFF) | ((u16(value) & 0x7) << 8)
		apu.pulse2.length_counter.val = lc_table[value >> 3]
		apu.pulse2.envelope_start = true
	case 0x4008:
		apu.triangle.linear_counter.control = value >> 7 != 0
		apu.triangle.length_counter.halt = value >> 7 != 0
		apu.triangle.linear_counter.reload = auto_cast (value & 0b0111_1111)
	case 0x4009: // unused
	case 0x400A:
		// TODO: Does timer get reset when updating the period????
		apu.triangle.period = apu.triangle.period & 0x700 | u16(value)
	case 0x400B:
		apu.triangle.period = (apu.triangle.period & 0xFF) | ((u16(value) & 0x7) << 8)
		apu.triangle.length_counter.val = lc_table[value >> 3]
	case 0x400C:
		apu.noise.volume = value & 0xF
	// apu.noise.length_counter_halt = (value >> 5) & 0x1 != 0
	// apu.noise.constant_volume = (value >> 4) & 0x1 != 0
	case 0x400D:
	// not used
	case 0x400E:
		apu.noise.period = u16(value & 0xF)
	// apu.noise.loop_noise = value >> 7 != 0
	case 0x400F:
	// apu.noise.length_counter_load = value >> 3
	case 0x4010:
	// stuff here
	case 0x4011:
	// stuff here
	case 0x4012:
		apu.dmc.sample_address = u16(value)
	case 0x4013:
		apu.dmc.sample_length = u16(value)
	case 0x4015:
		apu.pulse1.enabled = (value & 0b0000_0001) != 0
		apu.pulse2.enabled = (value & 0b0000_0010) != 0
		apu.triangle.enabled = (value & 0b0000_0100) != 0
		apu.noise.enabled = (value & 0b0000_1000) != 0
		apu.dmc.enabled = (value & 0b0001_0000) != 0
		apu.dmc.interrupt = false // writing to this register clears the DMC interrupt flag
	case 0x4017:
		apu.five_step = (value & 0b1000_0000) != 0
		apu.irq_inhibit = (value & 0b0100_0000) != 0
	}
}

read_apu_register :: proc(apu: ^APU, addr: u16) -> u8 {

	res: u8 = 0
	if addr == 0x4015 {
		if apu.pulse1.length_counter.val > 0 do res |= 0b0000_0001
		if apu.pulse2.length_counter.val > 0 do res |= 0b0000_0010
		if apu.triangle.length_counter.val > 0 do res |= 0b0000_0100
		if apu.noise.length_counter.val > 0 do res |= 0b0000_1000
		if apu.dmc.enabled do res |= 0b0001_0000
	}
	return res
}

// clock_frame_counter :: proc(apu: ^APU) {
// Clock length counters and envelope shifts
// clock_length_counter(&apu.pulse1.length_counter)
// clock_length_counter(&apu.pulse2.length_counter)
// clock_length_counter(&apu.triangle.length_counter)
// clock_length_counter(&apu.noise.length_counter)

// if apu.pulse1.length_counter.val > 0 && !apu.pulse1.length_counter.halt do apu.pulse1.length_counter.val -= 1

// Similar for other channels
// }

// clock :: proc(apu: ^APU) {
// clock_pulse(&apu.pulse1)
// clock_pulse(&apu.pulse2)
// clock_triangle(&apu.triangle)
// clock_noise(&apu.noise)
// clock_dmc(&apu.dmc)
// }

get_sample :: proc(apu: ^APU) -> u16 {
	// Linear approximation. Could also try lookup table
	pulse_out := 0.00752 * f32(output_pulse(&apu.pulse1) + output_pulse(&apu.pulse2))
	tnd_out := 0.00851 * f32(output_triangle(&apu.triangle))
	tnd_out += 0.00494 * f32(output_noise(&apu.noise))
	tnd_out += 0.00335 * f32(output_dmc(&apu.dmc))

	return u16((pulse_out + tnd_out) * 32767)
}

clock_quarter :: proc(apu: ^APU) {
	clock_linear_counter(&apu.triangle.linear_counter)
}

clock_half :: proc(apu: ^APU) {
	clock_length_counter(&apu.pulse1.length_counter)
	clock_length_counter(&apu.pulse2.length_counter)
	clock_length_counter(&apu.triangle.length_counter)
	clock_length_counter(&apu.noise.length_counter)
}

tick_apu :: proc(apu: ^APU) {
	// Tick is called for each CPU cycle

	apu.clock_all = ~apu.clock_all

	// Triangle is clocked every CPU cycle
	clock_triangle(&apu.triangle)

	// Everything else is clocked every other CPU cycle
	if apu.clock_all {
		clock_pulse(&apu.pulse1)
		clock_pulse(&apu.pulse2)
		clock_noise(&apu.noise)
		clock_dmc(&apu.dmc)
	}


	// 4-steps per frame

	QUARTER_FRAME :: 10
	// Quarter frame
	if apu.counter == QUARTER_FRAME {
		clock_quarter(apu)
	}

	HALF_FRAME :: 20
	// Half frame
	if apu.counter == HALF_FRAME {
		clock_quarter(apu)
		clock_half(apu)
	}

	THREEQ_FRAME :: 30
	// Three Quarters frame
	if apu.counter == THREEQ_FRAME {
		clock_quarter(apu)
	}

	FULL_FRAME: u16 = 40
	// Full Frame
	if apu.counter == FULL_FRAME {
		clock_quarter(apu)
		clock_half(apu)
		if !apu.five_step && !apu.irq_inhibit {
			// Implement the IRQ
		}
	}

	// CPU runs at 1.789 MHz and we want to generate samples at AUDIO_SAMPLE_RATE
	do_sample := false
	if do_sample {
		sample := get_sample(apu)
		sample += 1
		// TODO: Implement SDL audio stuff here????
	}
}
