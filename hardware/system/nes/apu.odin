package nes

import "core:fmt"

import "vendor:sdl3"

AUDIO_SAMPLE_RATE :: 44100 // 44.1 KHz

TICKS_PER_SAMPLE: f64 : f64(CLOCK_SPEED * 1000.0) / f64(AUDIO_SAMPLE_RATE)

// 60 Hz for 4 step
TICKS_PER_FRAME: int : auto_cast CLOCK_SPEED * 1000 / 60

// NES APU Implementation
APU :: struct {
	pulse1:             PulseChannel,
	pulse2:             PulseChannel,
	triangle:           TriangleChannel,
	noise:              NoiseChannel,
	dmc:                DMCChannel,
	clock_all:          bool,
	five_step:          bool,
	irq_inhibit:        bool,

	// Tick counter
	counter:            int,

	// Interaction with audio device. Buffer holds the samples
	// that have been generated and when it fills we send to
	// to the audio device
	audio:              ^sdl3.AudioStream,
	buffer:             []f32,
	buf_idx:            int,

	// Frame tick counter. When to clock the linear/length counters
	frame_tick_counter: f32,

	// Sample counter. When to generate a sample
	sample_counter:     f64,
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

// The NES APU noise channel generates pseudo-random 1-bit noise at 16 different frequencies
NoiseChannel :: struct {
	period:         u16,
	enabled:        bool,
	// length_counter: u8,
	length_counter: LengthCounter,
	volume:         u8,
	mode6:          bool,
	shift_reg:      u16,
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
	// Length counter value is decreased unless
	// it is zero or the halt flag is set
	if lc.val > 0 && !lc.halt do lc.val -= 1
}

clock_pulse :: proc(pulse_channel: ^PulseChannel) {
	if pulse_channel.timer > 0 {
		pulse_channel.timer -= 1
	} else {
		pulse_channel.timer = pulse_channel.period
		pulse_channel.duty_position = (pulse_channel.duty_position - 1) & 0x7
	}
}

output_pulse :: proc(pulse: ^PulseChannel) -> u8 {
	if !pulse.enabled || pulse.length_counter.val == 0 do return 0

	// Duty table is weird looking because duty_position is decreased
	// every time the pulse is clocked
    //odinfmt: disable
	duty_table := [32]u8 {
		0, 1, 0, 0, 0, 0, 0, 0,
		0, 1, 1, 0, 0, 0, 0, 0,
		0, 1, 1, 1, 1, 0, 0, 0,
		1, 0, 0, 1, 1, 1, 1, 1,
	}
    //odinfmt: enable

	idx := 8 * pulse.duty + pulse.duty_position
	return duty_table[idx] * pulse.volume
	// return duty_table[pulse.duty, pulse.duty_position] * pulse.volume

}

clock_triangle :: proc(tri: ^TriangleChannel) {
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

// TODO: Check implementation of noise
clock_noise :: proc(noise: ^NoiseChannel) {
	if noise.timer > 0 {
		noise.timer -= 1
	} else {
		noise.timer = noise.period

		// XOR bit 0 with bit 1 or 6 depending on whether mode6 is set or not
		feedback: u16 =
			((noise.shift_reg & 0x1) ~ ((noise.shift_reg >> (noise.mode6 ? 6 : 1)) & 0x1))
		noise.shift_reg = (noise.shift_reg >> 1) | (feedback << 14)
	}
}

output_noise :: proc(noise: ^NoiseChannel) -> u8 {
	if !noise.enabled || noise.length_counter.val == 0 do return 0

	return u8(noise.shift_reg & 0x1) * noise.volume
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

	apu.noise.shift_reg = 1
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

get_sample :: proc(apu: ^APU) -> f32 {
	// Linear approximation. Could also try lookup table
	pulse_out := 0.00752 * f32(output_pulse(&apu.pulse1) + output_pulse(&apu.pulse2))
	tnd_out := 0.00851 * f32(output_triangle(&apu.triangle))
	tnd_out += 0.00494 * f32(output_noise(&apu.noise))
	tnd_out += 0.00335 * f32(output_dmc(&apu.dmc))

	// return i16((pulse_out + tnd_out) * 32767)
	return pulse_out + tnd_out
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
	// apu.frame_tick_counter += 1
	apu.sample_counter += 1
	apu.counter += 1

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


	// This is done 4 times per frame. We probably
	// don't need to worry about fractions and can
	// just deal with ints
	QUARTER_FRAME :: TICKS_PER_FRAME / 4
	HALF_FRAME :: 2 * TICKS_PER_FRAME / 4
	THREEQ_FRAME :: 3 * TICKS_PER_FRAME / 4
	FULL_FRAME: int
	if apu.five_step {
		FULL_FRAME = 5 * TICKS_PER_FRAME / 4
	} else {
		FULL_FRAME = TICKS_PER_FRAME
	}

	// Quarter frame
	if apu.counter == QUARTER_FRAME {
		clock_quarter(apu)
	}

	// Half frame
	if apu.counter == HALF_FRAME {
		clock_quarter(apu)
		clock_half(apu)
	}

	// Three Quarters frame
	if apu.counter == THREEQ_FRAME {
		clock_quarter(apu)
	}

	// Full Frame
	if apu.counter == FULL_FRAME {
		clock_quarter(apu)
		clock_half(apu)
		if !apu.five_step && !apu.irq_inhibit {
			// Implement the IRQ
		}

		// Reset counter at full frame
		apu.counter = 0
	}

	// CPU runs at 1.789 MHz and we want to generate samples at AUDIO_SAMPLE_RATE
	// It would be around 40.5 samples so we need to take care of the fractions
	if apu.sample_counter >= TICKS_PER_SAMPLE {
		sample := get_sample(apu)
		apu.buffer[apu.buf_idx] = sample
		apu.buf_idx += 1

		// If we have filled up a seconds worth of data, send it to
		// the audio device and reset the buffer index
		if apu.buf_idx >= AUDIO_SAMPLE_RATE {
			lenbuf: i32 = AUDIO_SAMPLE_RATE * size_of(f32)
			buf := raw_data(apu.buffer)

			// TODO: Check if I can just take a pointer to the array
			sdl3.PutAudioStreamData(apu.audio, buf, lenbuf)
			apu.buf_idx = 0
			fmt.println("Putting Samples", apu.buffer[:25])
			fmt.println(
				"AAA:",
				apu.triangle.enabled,
				apu.triangle.length_counter.val,
				apu.triangle.linear_counter.val,
			)
		}

		apu.sample_counter -= TICKS_PER_SAMPLE
		// fmt.println("TEST", apu.buf_idx)
	}
}

init_audio :: proc(apu: ^APU) {
	fmt.println("Initializing Audio")

	// Not sure why this needs to be here because I am trying to init the audio at the start of the program
	// but I get a audio subsytem not initialized if I don't do it here
	assert(sdl3.InitSubSystem(sdl3.INIT_AUDIO), auto_cast sdl3.GetError())

	audio_spec := sdl3.AudioSpec{.F32, 1, AUDIO_SAMPLE_RATE}
	apu.audio = sdl3.OpenAudioDeviceStream(
		sdl3.AUDIO_DEVICE_DEFAULT_PLAYBACK,
		&audio_spec,
		nil,
		nil,
	)

	assert(sdl3.ResumeAudioDevice(sdl3.GetAudioStreamDevice(apu.audio)), auto_cast sdl3.GetError())
	// if !tmp {
	// fmt.println("ISSUE WITH AUDIO DEVICE")
	// fmt.println(sdl3.GetError())
	// }

	// tmp2 := sdl3.GetAudioStreamDevice(apu.audio)
	// fmt.println("TTT:", tmp2)

	// Buffer of one sec
	apu.buffer = make([]f32, AUDIO_SAMPLE_RATE)
	apu.buf_idx = 0

	// apu.triangle.enabled = true
}
