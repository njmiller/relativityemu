package cpu

import "core:fmt"
import "core:log"
import "core:math/bits"

OpCode :: enum u8 {
	BRK     = 0x00,
	ORA_IX  = 0x01,
	ORA_ZP  = 0x05,
	ASL_ZP  = 0x06,
	PHP     = 0x08,
	ORA_IM  = 0x09,
	ASL_ACC = 0x0A,
	ORA_A   = 0x0D,
	ASL_A   = 0x0E,
	BPL     = 0x10,
	ORA_IY  = 0x11,
	ORA_ZPX = 0x15,
	ASL_ZPX = 0x16,
	CLC     = 0x18,
	ORA_AY  = 0x19,
	ORA_AX  = 0x1D,
	ASL_AX  = 0x1E,
	JSR     = 0x20,
	AND_IX  = 0x21,
	BIT_ZP  = 0x24,
	AND_ZP  = 0x25,
	ROL_ZP  = 0x26,
	PLP     = 0x28,
	AND_IM  = 0x29,
	ROL_ACC = 0x2A,
	BIT_A   = 0x2C,
	AND_A   = 0x2D,
	ROL_A   = 0x2E,
	BMI     = 0x30,
	AND_IY  = 0x31,
	AND_ZPX = 0x35,
	ROL_ZPX = 0x36,
	SEC     = 0x38,
	AND_AY  = 0x39,
	AND_AX  = 0x3D,
	ROL_AX  = 0x3E,
	RTI     = 0x40,
	EOR_IX  = 0x41,
	EOR_ZP  = 0x45,
	LSR_ZP  = 0x46,
	PHA     = 0x48,
	EOR_IM  = 0x49,
	LSR_ACC = 0x4A,
	JMP_A   = 0x4C,
	EOR_A   = 0x4D,
	LSR_A   = 0x4E,
	BVC     = 0x50,
	EOR_IY  = 0x51,
	EOR_ZPX = 0x55,
	LSR_ZPX = 0x56,
	CLI     = 0x58,
	EOR_AY  = 0x59,
	EOR_AX  = 0x5D,
	LSR_AX  = 0x5E,
	RTS     = 0x60,
	ADC_IX  = 0x61,
	ADC_ZP  = 0x65,
	ROR_ZP  = 0x66,
	PLA     = 0x68,
	ADC_IM  = 0x69,
	ROR_ACC = 0x6A,
	JMP_I   = 0x6C,
	ADC_A   = 0x6D,
	ROR_A   = 0x6E,
	BVS     = 0x70,
	ADC_IY  = 0x71,
	ADC_ZPX = 0x75,
	ROR_ZPX = 0x76,
	SEI     = 0x78,
	ADC_AY  = 0x79,
	ADC_AX  = 0x7D,
	ROR_AX  = 0x7E,
	STA_IX  = 0x81,
	STY_ZP  = 0x84,
	STA_ZP  = 0x85,
	STX_ZP  = 0x86,
	DEY     = 0x88,
	TXA     = 0x8A,
	STY_A   = 0x8C,
	STA_A   = 0x8D,
	STX_A   = 0x8E,
	BCC     = 0x90,
	STA_IY  = 0x91,
	STY_ZPX = 0x94,
	STA_ZPX = 0x95,
	STX_ZPY = 0x96,
	TYA     = 0x98,
	STA_AY  = 0x99,
	TXS     = 0x9A,
	STA_AX  = 0x9D,
	LDY_IM  = 0xA0,
	LDA_IX  = 0xA1,
	LDX_IM  = 0xA2,
	LDY_ZP  = 0xA4,
	LDA_ZP  = 0xA5,
	LDX_ZP  = 0xA6,
	TAY     = 0xA8,
	LDA_IM  = 0xA9,
	TAX     = 0xAA,
	LDY_A   = 0xAC,
	LDA_A   = 0xAD,
	LDX_A   = 0xAE,
	BCS     = 0xB0,
	LDA_IY  = 0xB1,
	LDY_ZPX = 0xB4,
	LDA_ZPX = 0xB5,
	LDX_ZPY = 0xB6,
	CLV     = 0xB8,
	LDA_AY  = 0xB9,
	TSX     = 0xBA,
	LDY_AX  = 0xBC,
	LDA_AX  = 0xBD,
	LDX_AY  = 0xBE,
	CPY_IM  = 0xC0,
	CMP_IX  = 0xC1,
	CPY_ZP  = 0xC4,
	CMP_ZP  = 0xC5,
	DEC_ZP  = 0xC6,
	INY     = 0xC8,
	CMP_IM  = 0xC9,
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
	CPX_IM  = 0xE0,
	SBC_IX  = 0xE1,
	CPX_ZP  = 0xE4,
	SBC_ZP  = 0xE5,
	INC_ZP  = 0xE6,
	INX     = 0xE8,
	SBC_IM  = 0xE9,
	NOP     = 0xEA,
	CPX_A   = 0xEC,
	SBC_A   = 0xED,
	INC_A   = 0xEE,
	BEQ     = 0xF0,
	SBC_IY  = 0xF1,
	SBC_ZPX = 0xF5,
	INC_ZPX = 0xF6,
	SED     = 0xF8,
	SBC_AY  = 0xF9,
	SBC_AX  = 0xFD,
	INC_AX  = 0xFE,
}

AddModeMap := map[OpCode]OpCodeInfo {
	.BRK = {7, .NoneAddressing},
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
	.AND_AX = {4, .Absolute_X},
	.AND_AY = {4, .Absolute_Y},
	.AND_IX = {6, .Indirect_X},
	.AND_IY = {5, .Indirect_Y},
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
	.CMP_IM = {2, .Immediate},
	.CMP_ZP = {3, .ZeroPage},
	.CMP_ZPX = {4, .ZeroPage_X},
	.CMP_A = {4, .Absolute},
	.CMP_AX = {4, .Absolute_X},
	.CMP_AY = {4, .Absolute_Y},
	.CMP_IX = {6, .Indirect_X},
	.CMP_IY = {5, .Indirect_Y},
	.CPX_IM = {2, .Immediate},
	.CPX_ZP = {3, .ZeroPage},
	.CPX_A = {4, .Absolute},
	.CPY_IM = {2, .Immediate},
	.CPY_ZP = {3, .ZeroPage},
	.CPY_A = {4, .Absolute},
	.DEC_ZP = {5, .ZeroPage},
	.DEC_ZPX = {6, .ZeroPage_X},
	.DEC_A = {6, .Absolute},
	.DEC_AX = {7, .Absolute_X},
	.DEX = {2, .NoneAddressing},
	.DEY = {2, .NoneAddressing},
	.EOR_IM = {2, .Immediate},
	.EOR_ZP = {3, .ZeroPage},
	.EOR_ZPX = {4, .ZeroPage_X},
	.EOR_A = {4, .Absolute},
	.EOR_AX = {4, .Absolute_X},
	.EOR_IX = {6, .Indirect_X},
	.EOR_IY = {5, .Indirect_Y},
	.INC_ZP = {5, .ZeroPage},
	.INC_ZPX = {6, .ZeroPage_X},
	.INC_A = {6, .Absolute},
	.INC_AX = {7, .Absolute_X},
	.INX = {2, .NoneAddressing},
	.INY = {2, .NoneAddressing},
	.JMP_A = {3, .Absolute},
	.JMP_I = {5, .Indirect},
	.JSR = {6, .Absolute},
	.LDA_IM = {2, .Immediate},
	.LDA_ZP = {3, .ZeroPage},
	.LDA_ZPX = {4, .ZeroPage_X},
	.LDA_A = {4, .Absolute},
	.LDA_AX = {4, .Absolute_X},
	.LDA_AY = {4, .Absolute_Y},
	.LDA_IX = {6, .Indirect_X},
	.LDA_IY = {5, .Indirect_Y},
	.LDX_IM = {2, .Immediate},
	.LDX_ZP = {3, .ZeroPage},
	.LDX_ZPY = {4, .ZeroPage_Y},
	.LDX_A = {4, .Absolute},
	.LDX_AY = {4, .Absolute_Y},
	.LDY_IM = {2, .Immediate},
	.LDY_ZP = {3, .ZeroPage},
	.LDY_ZPX = {4, .ZeroPage_X},
	.LDY_A = {4, .Absolute},
	.LDY_AX = {4, .Absolute_X},
	.LSR_ACC = {2, .Accumulator},
	.LSR_ZP = {5, .ZeroPage},
	.LSR_ZPX = {6, .ZeroPage_X},
	.LSR_A = {6, .Absolute},
	.LSR_AX = {7, .Absolute_X},
	.NOP = {1, .NoneAddressing},
	.ORA_IM = {2, .Immediate},
	.ORA_ZP = {3, .ZeroPage},
	.ORA_ZPX = {4, .ZeroPage_X},
	.ORA_A = {4, .Absolute},
	.ORA_AX = {4, .Absolute_X},
	.ORA_AY = {4, .Absolute_Y},
	.ORA_IX = {6, .Indirect_X},
	.ORA_IY = {5, .Indirect_Y},
	.PHA = {3, .NoneAddressing},
	.PHP = {3, .NoneAddressing},
	.PLA = {4, .NoneAddressing},
	.PLP = {4, .NoneAddressing},
	.ROL_ACC = {2, .Accumulator},
	.ROL_ZP = {5, .ZeroPage},
	.ROL_ZPX = {6, .ZeroPage_X},
	.ROL_A = {6, .Absolute},
	.ROL_AX = {7, .Absolute_X},
	.ROR_ACC = {2, .Accumulator},
	.ROR_ZP = {5, .ZeroPage},
	.ROR_ZPX = {6, .ZeroPage_X},
	.ROR_A = {6, .Absolute},
	.ROR_AX = {7, .Absolute_X},
	.RTI = {6, .NoneAddressing},
	.RTS = {6, .NoneAddressing},
	.SBC_IM = {2, .Immediate},
	.SBC_ZP = {3, .ZeroPage},
	.SBC_ZPX = {4, .ZeroPage_X},
	.SBC_A = {4, .Absolute},
	.SBC_AX = {4, .Absolute_X},
	.SBC_AY = {4, .Absolute_Y},
	.SBC_IX = {6, .Indirect_X},
	.SBC_IY = {5, .Indirect_Y},
	.SEC = {2, .NoneAddressing},
	.SED = {2, .NoneAddressing},
	.SEI = {2, .NoneAddressing},
	.STA_ZP = {3, .ZeroPage},
	.STA_ZPX = {4, .ZeroPage_X},
	.STA_A = {4, .Absolute},
	.STA_AX = {5, .Absolute_X},
	.STA_AY = {5, .Absolute_Y},
	.STA_IX = {6, .Indirect_X},
	.STA_IY = {6, .Indirect_Y},
	.STX_ZP = {3, .ZeroPage},
	.STX_ZPY = {4, .ZeroPage_Y},
	.STX_A = {4, .Absolute},
	.STY_ZP = {3, .ZeroPage},
	.STY_ZPX = {4, .ZeroPage_X},
	.STY_A = {4, .Absolute},
	.TAX = {2, .NoneAddressing},
	.TAY = {2, .NoneAddressing},
	.TSX = {2, .NoneAddressing},
	.TXA = {2, .NoneAddressing},
	.TXS = {2, .NoneAddressing},
	.TYA = {2, .NoneAddressing},
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
	Indirect,
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

	if state.status & DecimalModeFlag != 0 {
		m = fromBCD(m)
	}

	value, cy := bits.overflowing_add(state.a, m)

	carry := state.status & CarryFlag != 0 ? 1 : 0
	value2, cy2 := bits.overflowing_add(value, carry)

	state.status = setNegativeFlag(value2, state.status)
	state.status = setZeroFlag(value2, state.status)
	state.status = setOverflowFlag(state.a, value2, state.status)
	state.status = cy | cy2 ? state.status | 1 : state.status &~ 1

	if state.status & DecimalModeFlag != 0 {
		value2 = toBCD(value2)
	}

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

branch :: proc(state: ^MOS6502, memory: []u8, flag: u8, eq: bool) {
	// Offset if from the end of the instruction so the way I increment everything
	// should be fine

	offset := readImmediate8(state, memory)
	rel_offset: i8 = auto_cast offset // since offset is signed
	// rel_offset := offset

	if eq {
		if state.status & flag == 0 {
			state.pc += int(rel_offset)
			state.ec += 1
		}
	} else {
		if state.status & flag != 0 {
			state.pc += int(rel_offset)
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

loadRegister :: proc(state: ^MOS6502, register: ^u8, memory: []u8, addMode: AddressingMode) {
	register^ = getValue8(state, memory, addMode)
	state.status = setZeroFlag(register^, state.status)
	state.status = setNegativeFlag(register^, state.status)
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

	// TODO: Check. Added one because I store location of next instruction - 1 on the stack
	// so I must increment it
	state.pc = int(pc) + 1
}

sbc :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
	m := getValue8(state, memory, addMode)

	if state.status & DecimalModeFlag != 0 {
		m = fromBCD(m)
	}
	value, cy := bits.overflowing_sub(state.a, m)
	//onemC := 1 - (state.status & 1)
	carry := state.status & CarryFlag != 0 ? 0 : 1
	//onemC := 1 - ((state.status & CarryFlag) >> CarryBit)

	value2, cy2 := bits.overflowing_sub(value, carry)

	state.status = setNegativeFlag(value2, state.status)
	state.status = setZeroFlag(value2, state.status)
	state.status = setOverflowFlag(state.a, value2, state.status)
	state.status = (cy | cy2) ? state.status &~ 1 : state.status | 1

	if state.status & DecimalModeFlag != 0 {
		value2 = toBCD(value2)
	}

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

/*
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
*/

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
	case .Indirect:
		offset1 := readImmediate16(state, memory)
		low := memory[offset1]
		high := memory[offset1 + 1]
		return getCombined(high, low)
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
	case .Indirect:
		log.error("Should never be trying to get memory value with Indirect addressing mode")
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

// Routines to convert a BCD number to normal u8 values for addition and subtraction
fromBCD :: proc(value: u8) -> u8 {
	low4 := value & 0b0000_1111
	high4 := (value & 0b1111_0000) >> 4

	if low4 >= 10 || high4 >= 10 do log.error("Each digit in BCD can only be between 0 and 9")

	return 10 * high4 + low4
}

toBCD :: proc(value: u8) -> u8 {

	if value > 99 do log.error("BCD must be between 0 and 99.")

	lowD: u8 = value % 10
	highD: u8 = value / 10

	return (highD << 4) | lowD
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
	case .CMP_IM, .CMP_ZP, .CMP_ZPX, .CMP_A, .CMP_AX, .CMP_AY, .CMP_IX, .CMP_IY:
		compare(state, &state.a, memory, opCodeInfo.addMode)
	case .CPX_IM, .CPX_ZP, .CPX_A:
		compare(state, &state.ix, memory, opCodeInfo.addMode)
	case .CPY_IM, .CPY_ZP, .CPY_A:
		compare(state, &state.iy, memory, opCodeInfo.addMode)
	case .DEC_ZP, .DEC_ZPX, .DEC_A, .DEC_AX:
		i: ^u8
		dec(state, i, memory, opCodeInfo.addMode)
	case .DEX:
		dec(state, &state.ix, memory, opCodeInfo.addMode)
	case .DEY:
		dec(state, &state.iy, memory, opCodeInfo.addMode)
	case .EOR_IM, .EOR_ZP, .EOR_ZPX, .EOR_A, .EOR_AX, .EOR_AY, .EOR_IX, .EOR_IY:
		eor(state, memory, opCodeInfo.addMode)
	case .INC_ZP, .INC_ZPX, .INC_A, .INC_AX:
		tmp: ^u8
		inc(state, tmp, memory, opCodeInfo.addMode)
	case .INX:
		inc(state, &state.ix, memory, opCodeInfo.addMode)
	case .INY:
		inc(state, &state.iy, memory, opCodeInfo.addMode)
	case .JMP_A, .JMP_I:
		jump(state, memory, opCodeInfo.addMode, false)
	case .JSR:
		jump(state, memory, opCodeInfo.addMode, true)
	case .LDA_IM, .LDA_ZP, .LDA_ZPX, .LDA_A, .LDA_AX, .LDA_AY, .LDA_IX, .LDA_IY:
		//lda(state, memory, opCodeInfo.addMode)
		loadRegister(state, &state.a, memory, opCodeInfo.addMode)
	case .LDX_IM, .LDX_ZP, .LDX_ZPY, .LDX_A, .LDX_AY:
		loadRegister(state, &state.ix, memory, opCodeInfo.addMode)
	case .LDY_IM, .LDY_ZP, .LDY_ZPX, .LDY_A, .LDY_AX:
		loadRegister(state, &state.iy, memory, opCodeInfo.addMode)
	case .LSR_ACC, .LSR_ZP, .LSR_ZPX, .LSR_A, .LSR_AX:
		shift(state, memory, opCodeInfo.addMode, false, false)
	case .NOP:
		nop()
	case .ORA_IM, .ORA_ZP, .ORA_ZPX, .ORA_A, .ORA_AX, .ORA_AY, .ORA_IX, .ORA_IY:
		ora(state, memory, opCodeInfo.addMode)
	case .PHA:
		push8(state.a, state, getStack(memory))
	case .PHP:
		push8(state.status, state, getStack(memory))
	case .PLA:
		state.a = pop8(state, getStack(memory))
	case .PLP:
		state.status = pop8(state, getStack(memory))
	case .ROL_ACC, .ROL_ZP, .ROL_ZPX, .ROL_A, .ROL_AX:
		shift(state, memory, opCodeInfo.addMode, true, true)
	case .ROR_ACC, .ROR_ZP, .ROR_ZPX, .ROR_A, .ROR_AX:
		shift(state, memory, opCodeInfo.addMode, true, false)
	case .RTI:
		rti(state, memory)
	case .RTS:
		rts(state, memory)
	case .SBC_IM, .SBC_ZP, .SBC_ZPX, .SBC_A, .SBC_AX, .SBC_AY, .SBC_IX, .SBC_IY:
		sbc(state, memory, opCodeInfo.addMode)
	case .SEC:
		setFlag(state, CarryFlag)
	case .SED:
		setFlag(state, DecimalModeFlag)
	case .SEI:
		setFlag(state, InterruptDisable)
	case .STA_ZP, .STA_ZPX, .STA_A, .STA_AX, .STA_AY, .STA_IX, .STA_IY:
		store(state.a, state, memory, opCodeInfo.addMode)
	case .STX_ZP, .STX_ZPY, .STX_A:
		store(state.ix, state, memory, opCodeInfo.addMode)
	case .STY_ZP, .STY_ZPX, .STY_A:
		store(state.iy, state, memory, opCodeInfo.addMode)
	case .TAX:
		transfer(&state.ix, &state.a, state)
	case .TAY:
		transfer(&state.iy, &state.a, state)
	case .TSX:
		transfer(&state.ix, &state.sp, state)
	case .TXA:
		transfer(&state.a, &state.ix, state)
	case .TXS:
		transfer(&state.sp, &state.ix, state)
	case .TYA:
		transfer(&state.a, &state.iy, state)
	}

	// Check if it is always +1 for a page boundary crossing
	nCycles += state.ec

	return nCycles
}
