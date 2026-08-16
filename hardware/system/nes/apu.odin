package nes

import "core:fmt"

import "vendor:sdl3"

AUDIO_SAMPLE_RATE :: 44100 // 44.1 KHz
// AUDIO_SAMPLE_RATE :: 48000

// The NES CPU clock. CLOCK_SPEED is only accurate to the KHz which is enough
// for pacing but drifts the sample rate, so the audio math uses the real value
CPU_CLOCK_HZ: f64 : 1_789_773.0

TICKS_PER_SAMPLE: f64 : CPU_CLOCK_HZ / f64(AUDIO_SAMPLE_RATE)

// Frame sequencer step boundaries in CPU cycles
FRAME_STEP1 :: 7457
FRAME_STEP2 :: 14913
FRAME_STEP3 :: 22371
FRAME_STEP4 :: 29829
FRAME_STEP5 :: 37281

// Coefficient for a one pole high pass at roughly 90 Hz, matching the DC
// blocking filter on real hardware. 1 - 2*pi*90/44100
HP_ALPHA :: 0.98718

BUFFER_SIZE :: 512

// NES APU Implementation
APU :: struct {
	pulse1:             PulseChannel,
	pulse2:             PulseChannel,
	triangle:           TriangleChannel,
	noise:              NoiseChannel,
	dmc:                DMC,
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

	// Running sum of the mixer output since the last sample was emitted.
	// Averaging these is what keeps the ~1.79 MHz -> 44.1 kHz decimation
	// from aliasing everything above 22 kHz back into the audible range
	sample_sum:         f32,
	sample_num:         f32,

	// DC blocking filter state. See HP_ALPHA
	hp_prev_in:         f32,
	hp_prev_out:        f32,

	// Frame counter IRQ flag. Reported in bit 6 of $4015. The 6502 core has
	// no IRQ line implemented yet, so nothing is asserted from this
	frame_interrupt:    bool,

	// Speed number for whether we are fast forwarding or not
	speed:				f64,
}

LengthCounter :: struct {
	val:  u8,
	halt: bool,
}

LinearCounter :: struct {
	control:     bool,
	val:         u8,
	reload:      u8,
	reload_flag: bool,
}

Envelope :: struct {
	reload:          u8,
	decay:           u8,
	constant_volume: bool,
	divider:         u8,
	start:           bool,
	loop:            bool,
}

Sweep :: struct {
	enabled:       bool,
	period:        u8,
	negate:        bool,
	shift:         u8,
	divider:       u8,
	reload:        bool,
	target_period: u16,
	new_period:    int,
}

// Pulse Channel struct and functions
PulseChannel :: struct {
	duty:           u8,
	// length_counter:      u8,
	// envelope_volume: u8,
	period:         u16,
	enabled:        bool,
	// length_counter_halt: bool,
	// constant_volume: bool,
	// envelope_start:  bool,
	// volume:         u8,
	timer:          u16,
	duty_position:  u8,
	length_counter: LengthCounter,
	env:            Envelope,
	sweep:          Sweep,
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
	length_counter: LengthCounter,
	env:            Envelope,
	// volume:          u8,
	mode6:          bool,
	shift_reg:      u16,
	timer:          u16,
	// constant_volume: bool,
}

DMC :: struct {
	enabled:         bool,
	silence:         bool,
	period:          u16,
	timer:           u16,
	loop:            bool,

	// For where to read memory
	sample_address:  u16,
	sample_length:   u16,
	bytes_remaining: u16,
	curr_address:    u16,

	// Output
	output_level:    u8,
	interrupt:       bool,

	// Sample processing
	sample_buffer:   u8,
	shift_register:  u8,
	bits_remaining:  int,
	last_sample:     bool,

	// DMC needs access to the bus to read the samples from memory
	bus:             ^Bus,
}

//odinfmt: disable
lc_table : [32]u8 = {10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14,
					 12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30}

np_table : [16]u16 = {4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068}

dmc_table : [16]u16 = {428, 380, 340, 320, 286, 254, 226, 214, 190, 160, 142, 128, 106, 84, 72, 54}

// Duty table is weird looking because duty_position is decreased
// every time the pulse is clocked
duty_table : [32]u8 = {
	0, 1, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 0, 0, 0, 0,
	0, 1, 1, 1, 1, 0, 0, 0,
	1, 0, 0, 1, 1, 1, 1, 1,
}

triangle_table : [32]u8 = {
	15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
}
//odinfmt: enable

clock_linear_counter :: proc(lc: ^LinearCounter) {
	if lc.reload_flag {
		lc.val = lc.reload
	} else if lc.val > 0 {
		lc.val -= 1
	}

	// The reload flag is only cleared while the control flag is clear,
	// which is what lets a held note keep reloading
	if !lc.control do lc.reload_flag = false
}

clock_length_counter :: proc(lc: ^LengthCounter) {
	// Length counter value is decreased unless
	// it is zero or the halt flag is set
	if lc.val > 0 && !lc.halt do lc.val -= 1
}

clock_envelope :: proc(env: ^Envelope) {
	if env.start {
		env.start = false
		env.decay = 15
		env.divider = env.reload
	} else {
		clock_env_divider(env)
	}
}

clock_env_divider :: proc(env: ^Envelope) {
	if env.divider > 0 {
		env.divider -= 1
	} else {
		env.divider = env.reload
		clock_env_decay(env)
	}
}

clock_env_decay :: proc(env: ^Envelope) {
	if env.decay > 0 {
		env.decay -= 1
	} else if env.loop {
		env.decay = 15
	}
}

clock_sweep :: proc(pulse: ^PulseChannel, num: int) {
	// The target period has to be kept current even when the sweep is
	// disabled, because it is what mutes the channel
	pulse.sweep.target_period = update_target_period(&pulse.sweep, pulse.period, num)

	if pulse.sweep.divider == 0 &&
	   pulse.sweep.enabled &&
	   pulse.sweep.shift != 0 &&
	   !is_pulse_muted(pulse) {
		pulse.period = pulse.sweep.target_period
		pulse.sweep.target_period = update_target_period(&pulse.sweep, pulse.period, num)
	}

	if pulse.sweep.divider == 0 || pulse.sweep.reload {
		pulse.sweep.divider = pulse.sweep.period
		pulse.sweep.reload = false
	} else {
		pulse.sweep.divider -= 1
	}
}

update_target_period :: proc(sweep: ^Sweep, period: u16, num: int) -> u16 {
	period_shift: int = auto_cast (period >> sweep.shift)

	if sweep.negate {
		period_shift = -period_shift

		// Pulses 1 and 2 have different negations of the period shift
		if num == 1 do period_shift -= 1
	}

	target_period := int(period) + period_shift

	if target_period < 0 do target_period = 0

	return u16(target_period)
}

is_pulse_muted :: proc(pulse: ^PulseChannel) -> bool {
	// If the current period is less than 8
	// If at any time, the target period is greater than 0x7FF
	return (pulse.period < 8) || (pulse.sweep.target_period > 0x7FF)
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
	if !pulse.enabled || pulse.length_counter.val == 0 || is_pulse_muted(pulse) do return 0

	idx := 8 * pulse.duty + pulse.duty_position

	volume := pulse.env.reload if pulse.env.constant_volume else pulse.env.decay
	return duty_table[idx] * volume

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
	// No silencing check here on purpose. Hardware only halts the sequencer
	// (see clock_triangle) and holds the last value on the DAC. Forcing the
	// output to 0 puts a step of up to 15 levels into the mix at every
	// note-off, which is audible as a pop
	return triangle_table[tri.sequence_position]
}

// TODO: Check implementation of noise
clock_noise :: proc(noise: ^NoiseChannel) {
	if noise.timer > 0 {
		noise.timer -= 1
	} else {
		// np_table holds the absolute period in CPU cycles, unlike the
		// pulse/triangle registers where the value means period+1
		noise.timer = noise.period - 1

		// XOR bit 0 with bit 1 or 6 depending on whether mode6 is set or not
		feedback := ((noise.shift_reg & 0x1) ~ ((noise.shift_reg >> (noise.mode6 ? 6 : 1)) & 0x1))
		noise.shift_reg = (noise.shift_reg >> 1) | (feedback << 14)
	}
}

output_noise :: proc(noise: ^NoiseChannel) -> u8 {
	if !noise.enabled || noise.length_counter.val == 0 do return 0

	volume := noise.env.reload if noise.env.constant_volume else noise.env.decay

	return u8(noise.shift_reg & 0x1) * volume
}


clock_dmc :: proc(dmc: ^DMC) {
	if dmc.timer > 0 {
		dmc.timer -= 1
	} else {
		// dmc_table also holds the absolute period in CPU cycles
		dmc.timer = dmc.period - 1

		// Only change the output level if we have bits remaining
		// Only time this should be 0 here is if we ran out of
		// data to load or disabled the DMC
		if !dmc.silence && dmc.bits_remaining > 0 {

			// Output level is shifted by 2 or -2 depending on bit 0 of shift register
			// But output level is unchanged if it would wrap the 7-bit value
			if dmc.shift_register & 1 != 0 && dmc.output_level <= 125 do dmc.output_level += 2
			if dmc.shift_register & 1 == 0 && dmc.output_level >= 2 do dmc.output_level -= 2

			dmc.shift_register >>= 1
			dmc.bits_remaining -= 1
		}

		// No else statement because we want it to possibly run after the previous statement 
		if dmc.bits_remaining == 0 do load_new_dmc_sample(dmc)
	}
}

load_new_dmc_sample :: proc(dmc: ^DMC) {

	// If the last sample was already moved to the shift
	// register or the dmc is not enabled, we silence the channel
	if dmc.last_sample || !dmc.enabled {
		dmc.silence = true
		return
	}

	dmc.silence = false
	dmc.shift_register = dmc.sample_buffer
	dmc.bits_remaining = 8

	// Load the new sample into the sample buffer. If there are no more
	// samples to load, then set the last_sample flag as the last sample
	// has already been moved to the shift register
	if dmc.bytes_remaining == 0 {
		if dmc.loop {
			dmc.bytes_remaining = dmc.sample_length
			dmc.curr_address = dmc.sample_address
		} else {
			dmc.last_sample = true
			return
		}
	}

	dmc.sample_buffer = dmc.bus.read(dmc.bus, dmc.curr_address)
	// TODO: Probably need to clock PPU here since reading a sample stalls the CPU for 1-4 cycles

	if dmc.curr_address == 0xFFFF {
		dmc.curr_address = 0xC000
	} else {
		dmc.curr_address += 1
	}

	dmc.bytes_remaining -= 1
}

output_dmc :: proc(dmc: ^DMC) -> u8 {
	// Same as the triangle: silencing stops the level from being updated
	// (in clock_dmc) but the delta counter keeps driving the DAC
	return dmc.output_level
}

reset_apu :: proc(apu: ^APU) {
	// TODO: Reset all registers here

	// A shift register of 0 is a fixed point of the feedback, so the noise
	// channel is silent forever if this is not seeded
	apu.noise.shift_reg = 1

	// Both of these reload their timer with period-1, so they need a sane
	// period before their period register is first written
	apu.noise.period = np_table[0]
	apu.dmc.period = dmc_table[0]
}

write_apu_register :: proc(apu: ^APU, addr: u16, value: u8) {
	switch addr {
	case 0x4000:
		apu.pulse1.duty = (value >> 6) & 0x3
		// Bit 5 is both the length counter halt and the envelope loop flag
		apu.pulse1.length_counter.halt = value & 0b0010_0000 != 0
		apu.pulse1.env.loop = value & 0b0010_0000 != 0
		apu.pulse1.env.constant_volume = value & 0b0001_0000 != 0
		apu.pulse1.env.reload = value & 0xF
	case 0x4001:
		apu.pulse1.sweep.enabled = (value & 0b1000_0000) != 0
		apu.pulse1.sweep.period = (value >> 4) & 0x7
		apu.pulse1.sweep.negate = (value & 0b0000_1000) != 0
		apu.pulse1.sweep.shift = value & 0x7
		apu.pulse1.sweep.reload = true
	case 0x4002:
		// Keep highest 3 of 11 bits and add the 8 bits here as the lowest 8 bits
		apu.pulse1.period = apu.pulse1.period & 0x700 | u16(value)
	case 0x4003:
		apu.pulse1.period = (apu.pulse1.period & 0xFF) | ((u16(value) & 0x7) << 8)
		if apu.pulse1.enabled do apu.pulse1.length_counter.val = lc_table[value >> 3]
		apu.pulse1.duty_position = 0
		apu.pulse1.env.start = true
	case 0x4004:
		apu.pulse2.duty = (value >> 6) & 0x3
		apu.pulse2.length_counter.halt = value & 0b0010_0000 != 0
		apu.pulse2.env.loop = value & 0b0010_0000 != 0
		apu.pulse2.env.constant_volume = value & 0b0001_0000 != 0
		apu.pulse2.env.reload = value & 0xF
	case 0x4005:
		apu.pulse2.sweep.enabled = (value & 0b1000_0000) != 0
		apu.pulse2.sweep.period = (value >> 4) & 0x7
		apu.pulse2.sweep.negate = (value & 0b0000_1000) != 0
		apu.pulse2.sweep.shift = value & 0x7
		apu.pulse2.sweep.reload = true
	case 0x4006:
		apu.pulse2.period = (apu.pulse2.period & 0x700) | u16(value)
	case 0x4007:
		apu.pulse2.period = (apu.pulse2.period & 0xFF) | ((u16(value) & 0x7) << 8)
		if apu.pulse2.enabled do apu.pulse2.length_counter.val = lc_table[value >> 3]
		apu.pulse2.duty_position = 0
		apu.pulse2.env.start = true
	case 0x4008:
		apu.triangle.linear_counter.control = value >> 7 != 0
		apu.triangle.length_counter.halt = value >> 7 != 0
		apu.triangle.linear_counter.reload = value & 0b0111_1111
	case 0x4009: // unused
	case 0x400A:
		// TODO: Does timer get reset when updating the period????
		apu.triangle.period = apu.triangle.period & 0x700 | u16(value)
	case 0x400B:
		apu.triangle.period = (apu.triangle.period & 0xFF) | ((u16(value) & 0x7) << 8)
		if apu.triangle.enabled do apu.triangle.length_counter.val = lc_table[value >> 3]
		apu.triangle.linear_counter.reload_flag = true
	case 0x400C:
		apu.noise.env.reload = value & 0xF
		apu.noise.length_counter.halt = (value & 0b0010_0000) != 0
		apu.noise.env.loop = (value & 0b0010_0000) != 0
		apu.noise.env.constant_volume = (value & 0b0001_0000) != 0
	case 0x400D:
	// not used
	case 0x400E:
		apu.noise.period = np_table[value & 0xF]
		apu.noise.mode6 = (value & 0b1000_0000) != 0
	case 0x400F:
		if apu.noise.enabled do apu.noise.length_counter.val = lc_table[value >> 3]
		apu.noise.env.start = true
	case 0x4010:
		apu.dmc.interrupt = (value & 0b1000_0000) != 0
		apu.dmc.loop = (value & 0b0100_0000) != 0
		idx := value & 0b0000_1111
		apu.dmc.period = dmc_table[idx]
	// stuff here
	case 0x4011:
		// Output level is 7 bit
		apu.dmc.output_level = value & 0b0111_1111
	// stuff here
	case 0x4012:
		apu.dmc.sample_address = 0xC000 | (u16(value) << 6)
	case 0x4013:
		apu.dmc.sample_length = (u16(value) << 4) + 1
		apu.dmc.last_sample = false
	case 0x4015:
		apu.pulse1.enabled = (value & 0b0000_0001) != 0
		apu.pulse2.enabled = (value & 0b0000_0010) != 0
		apu.triangle.enabled = (value & 0b0000_0100) != 0
		apu.noise.enabled = (value & 0b0000_1000) != 0
		apu.dmc.enabled = (value & 0b0001_0000) != 0

		// Disabling a channel immediately zeroes its length counter, and it
		// stays zero until the next write to its length register
		if !apu.pulse1.enabled do apu.pulse1.length_counter.val = 0
		if !apu.pulse2.enabled do apu.pulse2.length_counter.val = 0
		if !apu.triangle.enabled do apu.triangle.length_counter.val = 0
		if !apu.noise.enabled do apu.noise.length_counter.val = 0

		if apu.dmc.enabled {
			// Only restart the sample if it is not already playing
			if apu.dmc.bytes_remaining == 0 {
				apu.dmc.curr_address = apu.dmc.sample_address
				apu.dmc.bytes_remaining = apu.dmc.sample_length
				apu.dmc.last_sample = false
			}
		} else {
			apu.dmc.bytes_remaining = 0
		}

		apu.dmc.interrupt = false // writing to this register clears the DMC interrupt flag
	case 0x4017:
		apu.five_step = (value & 0b1000_0000) != 0
		apu.irq_inhibit = (value & 0b0100_0000) != 0

		if apu.irq_inhibit do apu.frame_interrupt = false

		// Writing here resets the frame sequencer, and in 5 step mode it
		// also clocks the quarter and half frame units immediately
		apu.counter = 0
		if apu.five_step {
			clock_quarter(apu)
			clock_half(apu)
		}
	}
}

read_apu_register :: proc(apu: ^APU, addr: u16) -> u8 {

	res: u8 = 0
	if addr == 0x4015 {
		if apu.pulse1.length_counter.val > 0 do res |= 0b0000_0001
		if apu.pulse2.length_counter.val > 0 do res |= 0b0000_0010
		if apu.triangle.length_counter.val > 0 do res |= 0b0000_0100
		if apu.noise.length_counter.val > 0 do res |= 0b0000_1000
		if apu.dmc.bytes_remaining > 0 do res |= 0b0001_0000
		if apu.frame_interrupt do res |= 0b0100_0000
		if apu.dmc.interrupt do res |= 0b1000_0000

		// Reading this register clears the frame interrupt flag
		apu.frame_interrupt = false
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

	clock_envelope(&apu.pulse1.env)
	clock_envelope(&apu.pulse2.env)
	clock_envelope(&apu.noise.env)
}

clock_frame_sequencer :: proc(apu: ^APU) {
	// The quarter frame units are clocked on every step and the half frame
	// units on the even steps. 5 step mode adds an idle step at FRAME_STEP4
	// and runs one step longer
	switch apu.counter {
	case FRAME_STEP1, FRAME_STEP3:
		clock_quarter(apu)
	case FRAME_STEP2:
		clock_quarter(apu)
		clock_half(apu)
	}

	last_step := FRAME_STEP5 if apu.five_step else FRAME_STEP4

	// Compared with >= rather than == so that toggling five_step while the
	// counter is past the new last step cannot wedge the sequencer
	if apu.counter >= last_step {
		if !apu.five_step && !apu.irq_inhibit do apu.frame_interrupt = true
		clock_quarter(apu)
		clock_half(apu)
		apu.counter = 0
	}
}

clock_half :: proc(apu: ^APU) {
	clock_length_counter(&apu.pulse1.length_counter)
	clock_length_counter(&apu.pulse2.length_counter)
	clock_length_counter(&apu.triangle.length_counter)
	clock_length_counter(&apu.noise.length_counter)

	clock_sweep(&apu.pulse1, 1)
	clock_sweep(&apu.pulse2, 2)
}

tick_apu :: proc(apu: ^APU) {
	// Tick is called for each CPU cycle
	// apu.frame_tick_counter += 1
	apu.sample_counter += 1
	apu.counter += 1

	apu.clock_all = ~apu.clock_all

	// Triangle is clocked every CPU cycle
	clock_triangle(&apu.triangle)

	// Should be clocked every other CPU cycle, but timer that this clocks
	// is number of CPU cycles
	clock_noise(&apu.noise)

	// Same for the DMC, dmc_table holds periods in CPU cycles
	clock_dmc(&apu.dmc)

	// Everything else is clocked every other CPU cycle
	if apu.clock_all {
		clock_pulse(&apu.pulse1)
		clock_pulse(&apu.pulse2)
	}

	clock_frame_sequencer(apu)

	// Accumulate the mixer output every cycle so that decimating down to
	// AUDIO_SAMPLE_RATE averages it rather than point sampling it, which
	// would alias everything above 22 kHz back into the audible range
	apu.sample_sum += get_sample(apu)
	apu.sample_num += 1

	ticks_per_sample := TICKS_PER_SAMPLE * apu.speed

	// CPU runs at 1.789 MHz and we want to generate samples at AUDIO_SAMPLE_RATE
	// It would be around 40.5 samples so we need to take care of the fractions
	// if apu.sample_counter >= TICKS_PER_SAMPLE {
	if apu.sample_counter >= ticks_per_sample {
		raw := apu.sample_sum / apu.sample_num
		apu.sample_sum = 0
		apu.sample_num = 0

		// DC blocking high pass. The mix is unipolar and channels hold a non
		// zero level when silenced, so without this every note boundary is a
		// step in the output that is heard as a pop
		sample := raw - apu.hp_prev_in + HP_ALPHA * apu.hp_prev_out
		apu.hp_prev_in = raw
		apu.hp_prev_out = sample

		apu.buffer[apu.buf_idx] = sample
		apu.buf_idx += 1

		// sdl3.PutAudioStreamData(apu.audio, &sample, size_of(f32))

		// If we have filled up a seconds worth of data, send it to
		// the audio device and reset the buffer index
		if apu.buf_idx >= BUFFER_SIZE {
			lenbuf: i32 = BUFFER_SIZE * size_of(f32)
			buf := raw_data(apu.buffer)

			// TODO: Check if I can just take a pointer to the array
			sdl3.PutAudioStreamData(apu.audio, buf, lenbuf)
			apu.buf_idx = 0
			// fmt.println("Putting Samples", apu.buffer[:25])
		}

		apu.sample_counter -= ticks_per_sample
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
	// apu.buffer = make([]f32, AUDIO_SAMPLE_RATE)
	apu.buffer = make([]f32, BUFFER_SIZE)
	apu.buf_idx = 0

	// apu.triangle.enabled = true

	// Normal (not fast-forward) speed
	apu.speed = 1.0
}
