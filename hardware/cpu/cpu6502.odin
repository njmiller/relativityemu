package cpu

import "core:fmt"
import "core:log"
import "core:math/bits"

OpCode :: enum u8 {
	BRK     = 0x00,
	ASL_ZP  = 0x06,
	ASL_ACC = 0x0A,
	ASL_A   = 0x0E,
	BPL     = 0x10,
	ASL_ZPX = 0x16,
	CLC     = 0x18,
	ASL_AX  = 0x1E,
	AND_IX  = 0x21,
	BIT_ZP  = 0x24,
	AND_ZP  = 0x25,
	AND_IM  = 0x29,
	BIT_A   = 0x2C,
	AND_A   = 0x2D,
	BMI     = 0x30,
	AND_IY  = 0x31,
	AND_ZPX = 0x35,
	AND_AY  = 0x39,
	AND_AX  = 0x3D,
	BVC     = 0x50,
	CLI     = 0x58,
	ADC_IX  = 0x61,
	ADC_ZP  = 0x65,
	ADC_IM  = 0x69,
	ADC_A   = 0x6D,
	BVS     = 0x70,
	ADC_IY  = 0x71,
	ADC_ZPX = 0x75,
	ADC_AY  = 0x79,
	ADC_AX  = 0x7D,
	DEY     = 0x88,
	BCC     = 0x90,
	LDA_IX  = 0xA1,
	LDA_ZP  = 0xA5,
	LDA_IM  = 0xA9,
	TAX     = 0xAA,
	LDA_A   = 0xAD,
	BCS     = 0xB0,
	LDA_IY  = 0xB1,
	LDA_ZPX = 0xB5,
	CLV     = 0xB8,
	LDA_AY  = 0xB9,
	LDA_AX  = 0xBD,
	CPY_I   = 0xC0,
	CMP_IX  = 0xC1,
	CPY_ZP  = 0xC4,
	CMP_ZP  = 0xC5,
	DEC_ZP  = 0xC6,
	CMP_I   = 0xC9,
	DEX     = 0xCA,
	CPY_A   = 0xCC,
	CMP_A   = 0xCD,
	DEC_A   = 0xCE,
	BNE     = 0xD0,
	CMP_IY  = 0xD1,
	CMP_ZPX = 0xD5,
	DEC_ZPX = 0xD6,
	CLD     = 0xD8,
	CMP_AY  = 0xD9,
	CMP_AX  = 0xDD,
	DEC_AX  = 0xDE,
	CPX_I   = 0xE0,
	CPX_ZP  = 0xE4,
	INX     = 0xE8,
	CPX_A   = 0xEC,
	BEQ     = 0xF0,
}

AddModeMap := map[OpCode]OpCodeInfo {
	.BRK = {7, .NoneAddressing},
	.LDA_IM = {2, .Immediate},
	.LDA_ZP = {3, .ZeroPage},
	.LDA_ZPX = {4, .ZeroPage_X},
	.LDA_A = {4, .Absolute},
	.LDA_AX = {4, .Absolute_X},
	.LDA_AY = {4, .Absolute_Y},
	.LDA_IX = {6, .Indirect_X},
	.LDA_IY = {5, .Indirect_Y},
	.TAX = {2, .NoneAddressing},
	.INX = {2, .NoneAddressing},
	.ADC_IM = {2, .Immediate},
	.ADC_ZP = {3, .ZeroPage},
	.ADC_ZPX = {4, .ZeroPage_X},
	.ADC_A = {4, .Absolute},
	.ADC_AX = {4, .Absolute_X},
	.ADC_AY = {4, .Absolute_Y},
	.ADC_IX = {6, .Indirect_X},
	.ADC_IY = {5, .Indirect_Y},
	.AND_IM = {2, .Immediate},
	.AND_ZP = {3, .ZeroPage},
	.AND_ZPX = {4, .ZeroPage_X},
	.AND_A = {4, .Absolute},
	.AND_AX = {4, .Absolute_X}, // + 1 if page crossed
	.AND_AY = {4, .Absolute_Y}, // + 1 if page crossed
	.AND_IX = {6, .Indirect_X},
	.AND_IY = {5, .Indirect_Y}, // + 1 if page crossed
	.BCC = {2, .Relative},
	.BCS = {2, .Relative},
	.BEQ = {2, .Relative},
	.BIT_ZP = {3, .ZeroPage},
	.BIT_A = {4, .Absolute},
	.BMI = {2, .Relative},
	.BNE = {2, .Relative},
	.BPL = {2, .Relative},
	.BVC = {2, .Relative},
	.BVS = {2, .Relative},
	.CLC = {2, .NoneAddressing},
	.CLD = {2, .NoneAddressing},
	.CLI = {2, .NoneAddressing},
	.CLV = {2, .NoneAddressing},
	.CMP_I = {2, .Immediate},
	.CMP_ZP = {3, .ZeroPage},
	.CMP_ZPX = {4, .ZeroPage_X},
	.CMP_A = {4, .Absolute},
	.CMP_AX = {4, .Absolute_X},
	.CMP_AY = {4, .Absolute_Y},
	.CMP_IX = {6, .Indirect_X},
	.CMP_IY = {5, .Indirect_Y},
	.CPX_I = {2, .Immediate},
	.CPX_ZP = {3, .ZeroPage},
	.CPX_A = {4, .Absolute},
	.CPY_I = {2, .Immediate},
	.CPY_ZP = {3, .ZeroPage},
	.CPY_A = {4, .Absolute},
	.DEC_ZP = {5, .ZeroPage},
	.DEC_ZPX = {6, .ZeroPage_X},
	.DEC_A = {6, .Absolute},
	.DEC_AX = {7, .Absolute_X},
	.DEX = {2, .NoneAddressing},
	.DEY = {2, .NoneAddressing},
}

OpCodeInfo :: struct {
	nCycles: int,
	addMode: AddressingMode,
}

AddressingMode :: enum u8 {
	Accumulator,
	Relative,
	Immediate,
	ZeroPage,
	ZeroPage_X,
	ZeroPage_Y,
	Absolute,
	Absolute_X,
	Absolute_Y,
	Indirect_X,
	Indirect_Y,
	NoneAddressing,
}

MOS6502 :: struct {
	a:      u8,
	status: u8,
	pc:     int,
	sp:     u8,
	ix:     u8,
	iy:     u8,
	ec:     int, // set for extra cycles than the default based on branch or page crossing
}

// Bits for the status byte
ZeroFlag: u8 : 0b0000_0010
NegativeFlag: u8 : 0b1000_0000
CarryFlag: u8 : 0b0000_0001
InterruptDisable: u8 : 0b0000_0100
DecimalModeFlag: u8 : 0b0000_1000
BreakCommand: u8 : 0b0001_0000
OverflowFlag: u8 : 0b0100_0000

ZeroBit :: 1
NegativeBit :: 7
CarryBit :: 0
InterruptBit :: 2
DecimalBit :: 3
BreakBit :: 4
OverflowBit :: 6

setFlags :: proc(value: u8, flagsIn: u8) -> u8 {
	return 1
}

setZeroFlag :: proc(value: u8, flagsIn: u8) -> u8 {
	flagsOut := value == 0 ? flagsIn | ZeroFlag : flagsIn &~ ZeroFlag
	return flagsOut
}

setNegativeFlag :: proc(value: u8, flagsIn: u8) -> u8 {
	negativeBit: u8 : 0b1000_0000
	flagsOut := value & negativeBit != 0 ? flagsIn | NegativeFlag : flagsIn &~ NegativeFlag
	return flagsOut
}

setOverflowFlag :: proc(val1: u8, val2: u8, flagsIn: u8) -> u8 {
	isOverflow := (val1 & 0x80) != (val2 & 0x80)
	flagsOut := isOverflow ? flagsIn | OverflowFlag : flagsIn &~ OverflowFlag
	return flagsOut
}

brk :: proc(state: ^MOS6502) {
	state.status = state.status | BreakCommand
}

adc :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {

	m := getValue8(state, memory, addMode)

	value, cy := bits.overflowing_add(state.a, m)
	value2, cy2 := bits.overflowing_add(state.a, state.status & 1)

	state.status = setNegativeFlag(value2, state.status)
	state.status = setZeroFlag(value2, state.status)
	state.status = setOverflowFlag(state.a, value2, state.status)
	state.status = cy | cy2 ? state.status | 1 : state.status &~ 1

	state.a = value2
}

and :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
	m := getValue8(state, memory, addMode)

	state.a &= m
	state.status = setZeroFlag(state.a, state.status)
	state.status = setNegativeFlag(state.a, state.status)
}

shift :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode, carry: bool, left: bool) {
	m := getValue8(state, memory, addMode)

	value: u8
	rollbit: uint

	// Whether the shift is to the left or right
	if left {
		value = m << 1
		rollbit = 0
	} else {
		value = m >> 1
		rollbit = 7
	}

	// Whether the carry bit is moved into the 0th or 7th bit
	if carry {
		val := (state.status & CarryFlag) >> CarryBit
		value = value | (val << rollbit)
	}

	bit: u8 = 1 << uint(7 - rollbit)

	state.status = (bit & m) != 0 ? state.status | CarryFlag : state.status &~ CarryFlag
	state.status = setZeroFlag(value, state.status)
	state.status = setNegativeFlag(value, state.status)
	writeValue8(value, state, memory, addMode)
}

/*
bcc :: proc(state: ^MOS6502, memory: []u8) {
	offset := readImmediate8(state, memory)
	if state.status & CarryFlag == 0 {
		state.pc += int(offset)
	}
}

bcs :: proc(state: ^MOS6502, memory: []u8) {
	offset := readImmediate8(state, memory)
	if state.status & CarryFlag != 0 {
		state.pc += int(offset)
	}
}
*/

branch :: proc(state: ^MOS6502, memory: []u8, flag: u8, eq: bool) {
	offset := readImmediate8(state, memory)

	if eq {
		if state.status & flag == 0 {
			state.pc += int(offset)
			state.ec += 1
		}
	} else {
		if state.status & flag != 0 {
			state.pc += int(offset)
			state.ec += 1
		}
	}
}

bit :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
	value := state.a & getValue8(state, memory, addMode)
	state.status = setZeroFlag(value, state.status)

	//bit 6 is set to overflow flag
	//bit 7 is set to negative flag

	bit6 :: 0b0100_0000

	state.status = bit6 & value != 0 ? state.status | OverflowFlag : state.status &~ OverflowFlag
	state.status = setNegativeFlag(value, state.status)
}

clear :: proc(state: ^MOS6502, flag: u8) {
	state.status = state.status &~ flag
}

compare :: proc(state: ^MOS6502, register: ^u8, memory: []u8, addMode: AddressingMode) {
	value := register^ - getValue8(state, memory, addMode)

	state.status = value >= 0 ? state.status | CarryFlag : state.status &~ CarryFlag
	state.status = setZeroFlag(value, state.status)
	state.status = setNegativeFlag(value, state.status)
}

dec :: proc(state: ^MOS6502, register: ^u8, memory: []u8, addMode: AddressingMode) {
	value: u8

	// Different branches for when decrementing x/y-registers and memory locations
	if addMode == .NoneAddressing {
		register^ -= 1
		value = register^
	} else {
		value = getValue8(state, memory, addMode) - 1
		writeValue8(value, state, memory, addMode)
	}

	state.status = setZeroFlag(value, state.status)
	state.status = setNegativeFlag(value, state.status)
}

eor :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
	state.a = state.a ~ getValue8(state, memory, addMode)

	state.status = setZeroFlag(state.a, state.status)
	state.status = setNegativeFlag(state.a, state.status)
}

inc :: proc(state: ^MOS6502, register: ^u8, memory: []u8, addMode: AddressingMode) {
	value: u8

	// Different branches for when decrementing x/y-registers and memory locations
	if addMode == .NoneAddressing {
		register^ += 1
		value = register^
	} else {
		value = getValue8(state, memory, addMode) + 1
		writeValue8(value, state, memory, addMode)
	}

	state.status = setZeroFlag(value, state.status)
	state.status = setNegativeFlag(value, state.status)
}

jump :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode, sub: bool) {
	value := getOffset(state, memory, addMode)

	// If jump to subroutine, push the address (minus one) of the return point on the stack
	// TODO: Says it pushes address-1 of the next operation
	if sub {
		// pc should already be location of next instruction
		pc_curr := u16(state.pc - 1)
		high, low := getHighLow(pc_curr)
		pushR(high, low, state, getStack(memory))
	}

	state.pc = int(value)
}

lda :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
	state.a = getValue8(state, memory, addMode)
	state.status = setZeroFlag(state.a, state.status)
	state.status = setNegativeFlag(state.a, state.status)
}

ldx :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
	state.ix = getValue8(state, memory, addMode)
	state.status = setZeroFlag(state.a, state.status)
	state.status = setNegativeFlag(state.a, state.status)
}

ldy :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
	state.iy = getValue8(state, memory, addMode)
	state.status = setZeroFlag(state.a, state.status)
	state.status = setNegativeFlag(state.a, state.status)
}

lsr :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
	m := getValue8(state, memory, addMode)

	value := m >> 1

	bit0: u8 : 1 << 0
	state.status = state.status | ((bit0 & m) << CarryBit)
	state.status = setZeroFlag(value, state.status)
	state.status = setNegativeFlag(value, state.status)

	writeValue8(value, state, memory, addMode)

}

nop :: proc() {}

ora :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
	state.a = getValue8(state, memory, addMode) | state.a

	state.status = setZeroFlag(state.a, state.status)
	state.status = setNegativeFlag(state.a, state.status)
}

/*
pha :: proc(state: ^MOS6502, memory: []u8) {
	push8(state.a, state, getStack(memory))
}
*/

rti :: proc(state: ^MOS6502, memory: []u8) {
	log.error("RTI Not Implemented")
}

rts :: proc(state: ^MOS6502, memory: []u8) {
	high, low: u8
	popR(&high, &low, state, getStack(memory))

	pc := getCombined(high, low)
	state.pc = int(pc)
}

sbc :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
	m := getValue8(state, memory, addMode)

	value, cy := bits.overflowing_sub(state.a, m)
	//onemC := 1 - (state.status & 1)
	onemC := 1 - ((state.status & CarryFlag) >> CarryBit)

	value2, cy2 := bits.overflowing_sub(state.a, onemC)

	state.status = setNegativeFlag(value2, state.status)
	state.status = setZeroFlag(value2, state.status)
	state.status = setOverflowFlag(state.a, value2, state.status)
	state.status = (cy | cy2) ? state.status &~ 1 : state.status | 1

	state.a = value2
}

setFlag :: proc(state: ^MOS6502, flag: u8) {
	state.status = state.status | flag
}

store :: proc(register: u8, state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
	offset := getOffset(state, memory, addMode)
	memory[offset] = register

	/*
	// Since writeValue8 assumes we have already advanced the pc past
	// the address
	tmp := getValue8(state, memory, addMode)
	writeValue8(register, state, memory, addMode)
	*/
}

transfer :: proc(dest: ^u8, init: ^u8, state: ^MOS6502) {
	dest^ = init^

	state.status = setZeroFlag(dest^, state.status)
	state.status = setNegativeFlag(dest^, state.status)
}

tax :: proc(state: ^MOS6502) {
	state.ix = state.a
	state.status = setZeroFlag(state.ix, state.status)
	state.status = setNegativeFlag(state.ix, state.status)
}

inx :: proc(state: ^MOS6502) {
	state.ix += 1
	state.status = setZeroFlag(state.ix, state.status)
	state.status = setNegativeFlag(state.ix, state.status)
}

getOffset :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) -> u16 {
	switch addMode {
	case .Accumulator:
		log.error("Can't get offset for accumulator")
	case .Relative:
		log.error("Call getValue8 for Relative")
	case .Immediate:
		log.error("Call getValue8 for Immediate")
	case .Absolute:
		return readImmediate16(state, memory)
	case .Absolute_X:
		offset := readImmediate16(state, memory)
		return u16(state.ix) + offset
	case .Absolute_Y:
		offset := readImmediate16(state, memory)
		return u16(state.iy) + offset
	case .ZeroPage:
		return u16(readImmediate8(state, memory))
	case .ZeroPage_X:
		return u16(readImmediate8(state, memory) + state.ix)
	case .ZeroPage_Y:
		return u16(readImmediate8(state, memory) + state.iy)
	case .Indirect_X:
		addr := state.ix + readImmediate8(state, memory)
		low := memory[addr]
		high := memory[addr + 1]
		return getCombined(high, low)
	case .Indirect_Y:
		base := readImmediate8(state, memory)
		low := memory[base]
		high := memory[base + 1]
		return getCombined(high, low) + u16(state.iy)
	case .NoneAddressing:
		log.error("Trying to read operand with NoneAddressing")
		return 0
	}

	log.error("Somehow made it past the switch statement which should always return")
	return 0
}

getValue8 :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) -> u8 {

	switch addMode {
	case .Accumulator:
		return state.a
	case .Relative:
		return readImmediate8(state, memory)
	case .Immediate:
		return readImmediate8(state, memory)
	case .Absolute:
		return memory[readImmediate16(state, memory)]
	case .Absolute_X:
		offset := readImmediate16(state, memory)
		return memory[u16(state.ix) + offset]
	case .Absolute_Y:
		offset := readImmediate16(state, memory)
		return memory[u16(state.iy) + offset]
	case .ZeroPage:
		return memory[readImmediate8(state, memory)]
	case .ZeroPage_X:
		return memory[readImmediate8(state, memory) + state.ix]
	case .ZeroPage_Y:
		return memory[readImmediate8(state, memory) + state.iy]
	case .Indirect_X:
		addr := state.ix + readImmediate8(state, memory)
		low := memory[addr]
		high := memory[addr + 1]
		return memory[getCombined(high, low)]
	case .Indirect_Y:
		base := readImmediate8(state, memory)
		low := memory[base]
		high := memory[base + 1]
		return memory[getCombined(high, low) + u16(state.iy)]
	case .NoneAddressing:
		log.error("Trying to read operand with NoneAddressing")
		return 0
	}

	log.error("Somehow made it past the switch statement which should always return")
	return 0
}

// Fome some instructions that act straight on the memory locations (i.e. ASL). We
// undo the increment of the program counter and then read in the offset again in order
// to figure out where to store the value
writeValue8 :: proc(value: u8, state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
	#partial switch addMode {
	case .Accumulator:
		state.a = value
	case .Immediate:
		writeImmediate8(value, state, memory)
	case .ZeroPage:
		state.pc -= 1
		offset := readImmediate8(state, memory)
		memory[offset] = value
	case .ZeroPage_X:
		state.pc -= 1
		offset := readImmediate8(state, memory) + state.ix
		memory[offset] = value
	case .Absolute:
		state.pc -= 2
		offset := readImmediate16(state, memory)
		memory[offset] = value
	case .Absolute_X:
		state.pc -= 2
		offset := readImmediate16(state, memory) + u16(state.ix)
		memory[offset] = value
	case:
		log.error("Trying to write data with unimplemented addressing mode.")
	}
}

push8 :: proc(reg1: u8, state: ^MOS6502, stack: []u8) {
	stack[state.sp - 1] = reg1
	state.sp -= 1
}

pop8 :: proc(state: ^MOS6502, stack: []u8) -> u8 {
	state.sp += 1
	return stack[state.sp - 1]
}

pushR :: proc(reg1: u8, reg2: u8, state: ^MOS6502, stack: []u8) {
	stack[state.sp - 2] = reg2
	stack[state.sp - 1] = reg1
	state.sp -= 2
}

popR :: proc(reg1: ^u8, reg2: ^u8, state: ^MOS6502, stack: []u8) {
	reg2^ = stack[state.sp]
	reg1^ = stack[state.sp + 1]
	state.sp += 2
}

getHighLow :: proc(value: u16) -> (u8, u8) {
	high: u8 = auto_cast (value >> 8) & 0xff
	low: u8 = auto_cast value & 0xff

	return high, low
}

getCombined :: proc(high: u8, low: u8) -> u16 {return (u16(high) << 8) | u16(low)}

getStack :: proc(memory: []u8) -> []u8 {return memory[0x0100:0x0200]}

readImmediate8 :: proc(state: ^MOS6502, memory: []u8) -> u8 {
	state.pc += 1
	return memory[state.pc - 1]
}

writeImmediate8 :: proc(value: u8, state: ^MOS6502, memory: []u8) {
	memory[state.pc - 1] = value
}

/*
readImmediate16 :: proc(state: ^MOS6502, memory: []u8) -> u16 {
    low := readImmediate8(state, memory)
    high := readImmediate8(state, memory)
    return getCombined(high, low)
}
*/

readImmediate16 :: proc(state: ^MOS6502, memory: []u8) -> u16 {
	state.pc += 2
	return auto_cast (cast(^u16le)&memory[state.pc - 2])^
}

/*
writeImmediate16 :: proc(value: u16, state: ^MOS6502, memory: []u8) {
	high, low := getHighLow(value)
	memory[state.pc - 2] = low
	memory[state.pc - 1] = high
}
*/

emulate6502p :: proc(state: ^MOS6502, memory: []u8) -> int {
	opcode: OpCode = auto_cast readImmediate8(state, memory)

	//Page boundary
	state.ec = 0

	opCodeInfo := AddModeMap[opcode]
	nCycles := opCodeInfo.nCycles

	switch opcode {
	case .BRK:
		brk(state)
	case .LDA_IM, .LDA_ZP, .LDA_ZPX, .LDA_A, .LDA_AX, .LDA_AY, .LDA_IX, .LDA_IY:
		lda(state, memory, opCodeInfo.addMode)
	case .ADC_IM, .ADC_ZP, .ADC_ZPX, .ADC_A, .ADC_AX, .ADC_AY, .ADC_IX, .ADC_IY:
		adc(state, memory, opCodeInfo.addMode)
	case .AND_IM, .AND_ZP, .AND_ZPX, .AND_A, .AND_AX, .AND_AY, .AND_IX, .AND_IY:
		and(state, memory, opCodeInfo.addMode)
	case .ASL_ACC, .ASL_ZP, .ASL_ZPX, .ASL_A, .ASL_AX:
		shift(state, memory, opCodeInfo.addMode, false, true)
	case .BCC:
		branch(state, memory, CarryFlag, true)
	case .BCS:
		branch(state, memory, CarryFlag, false)
	case .BEQ:
		branch(state, memory, ZeroFlag, false)
	case .BIT_A, .BIT_ZP:
		bit(state, memory, opCodeInfo.addMode)
	case .BMI:
		branch(state, memory, NegativeFlag, false)
	case .BNE:
		branch(state, memory, ZeroFlag, true)
	case .BPL:
		branch(state, memory, NegativeFlag, true)
	case .BVC:
		branch(state, memory, OverflowFlag, true)
	case .BVS:
		branch(state, memory, OverflowFlag, false)
	case .CLC:
		clear(state, CarryFlag)
	case .CLD:
		clear(state, DecimalModeFlag)
	case .CLI:
		clear(state, InterruptDisable)
	case .CLV:
		clear(state, OverflowFlag)
	case .CMP_I, .CMP_ZP, .CMP_ZPX, .CMP_A, .CMP_AX, .CMP_AY, .CMP_IX, .CMP_IY:
		compare(state, &state.a, memory, opCodeInfo.addMode)
	case .CPX_I, .CPX_ZP, .CPX_A:
		compare(state, &state.ix, memory, opCodeInfo.addMode)
	case .CPY_I, .CPY_ZP, .CPY_A:
		compare(state, &state.iy, memory, opCodeInfo.addMode)
	case .DEC_ZP, .DEC_ZPX, .DEC_A, .DEC_AX:
		i: ^u8
		dec(state, i, memory, opCodeInfo.addMode)
	case .DEX:
		dec(state, &state.ix, memory, opCodeInfo.addMode)
	case .DEY:
		dec(state, &state.iy, memory, opCodeInfo.addMode)
	case .INX:
		//inx(state)
		inc(state, &state.ix, memory, opCodeInfo.addMode)
	case .TAX:
		tax(state)
	}

	// Check if it is always +1 for a page boundary crossing
	nCycles += state.ec

	return nCycles
}
