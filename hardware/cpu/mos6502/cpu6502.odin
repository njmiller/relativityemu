#+feature dynamic-literals
package cpu6502

import "core:fmt"
import "core:log"
import "core:math/bits"

// TODO: Maybe move bus definition here instead of in a separate file as the bus is how the
// CPU interacts with the rest of the system and any system could still extend that structure
// like I am doing now

ReadFn :: #type proc(bus: ^Bus, addr: u16) -> u8
WriteFn :: #type proc(bus: ^Bus, addr: u16, data: u8)

Bus :: struct {
	read:    ReadFn,
	write:   WriteFn,
	ncycles: int,
}

OpCode :: enum u8 {
	BRK      = 0x00,
	ORA_IX   = 0x01,
	SLO_IX   = 0x03,
	NOP_ZP   = 0x04,
	ORA_ZP   = 0x05,
	ASL_ZP   = 0x06,
	SLO_ZP   = 0x07,
	PHP      = 0x08,
	ORA_IM   = 0x09,
	ASL_ACC  = 0x0A,
	NOP_A    = 0x0C,
	ORA_A    = 0x0D,
	ASL_A    = 0x0E,
	SLO_A    = 0x0F,
	BPL      = 0x10,
	ORA_IY   = 0x11,
	SLO_IY   = 0x13,
	NOP_ZPX  = 0x14,
	ORA_ZPX  = 0x15,
	ASL_ZPX  = 0x16,
	SLO_ZPX  = 0x17,
	CLC      = 0x18,
	ORA_AY   = 0x19,
	NOP_U1   = 0x1A,
	SLO_AY   = 0x1B,
	NOP_AX   = 0x1C,
	ORA_AX   = 0x1D,
	ASL_AX   = 0x1E,
	SLO_AX   = 0x1F,
	JSR      = 0x20,
	AND_IX   = 0x21,
	RLA_IX   = 0x23,
	BIT_ZP   = 0x24,
	AND_ZP   = 0x25,
	ROL_ZP   = 0x26,
	RLA_ZP   = 0x27,
	PLP      = 0x28,
	AND_IM   = 0x29,
	ROL_ACC  = 0x2A,
	BIT_A    = 0x2C,
	AND_A    = 0x2D,
	ROL_A    = 0x2E,
	RLA_A    = 0x2F,
	BMI      = 0x30,
	AND_IY   = 0x31,
	RLA_IY   = 0x33,
	NOP_ZPX2 = 0x34,
	AND_ZPX  = 0x35,
	ROL_ZPX  = 0x36,
	RLA_ZPX  = 0x37,
	SEC      = 0x38,
	AND_AY   = 0x39,
	NOP_U2   = 0x3A,
	RLA_AY   = 0x3B,
	NOP_AX2  = 0x3C,
	AND_AX   = 0x3D,
	ROL_AX   = 0x3E,
	RLA_AX   = 0x3F,
	RTI      = 0x40,
	EOR_IX   = 0x41,
	SRE_IX   = 0x43,
	NOP_ZP2  = 0x44,
	EOR_ZP   = 0x45,
	LSR_ZP   = 0x46,
	SRE_ZP   = 0x47,
	PHA      = 0x48,
	EOR_IM   = 0x49,
	LSR_ACC  = 0x4A,
	JMP_A    = 0x4C,
	EOR_A    = 0x4D,
	LSR_A    = 0x4E,
	SRE_A    = 0x4F,
	BVC      = 0x50,
	EOR_IY   = 0x51,
	SRE_IY   = 0x53,
	NOP_ZPX3 = 0x54,
	EOR_ZPX  = 0x55,
	LSR_ZPX  = 0x56,
	SRE_ZPX  = 0x57,
	CLI      = 0x58,
	EOR_AY   = 0x59,
	NOP_U3   = 0x5A,
	SRE_AY   = 0x5B,
	NOP_AX3  = 0x5C,
	EOR_AX   = 0x5D,
	LSR_AX   = 0x5E,
	SRE_AX   = 0x5F,
	RTS      = 0x60,
	ADC_IX   = 0x61,
	RRA_IX   = 0x63,
	NOP_ZP3  = 0x64,
	ADC_ZP   = 0x65,
	ROR_ZP   = 0x66,
	RRA_ZP   = 0x67,
	PLA      = 0x68,
	ADC_IM   = 0x69,
	ROR_ACC  = 0x6A,
	JMP_I    = 0x6C,
	ADC_A    = 0x6D,
	ROR_A    = 0x6E,
	RRA_A    = 0x6F,
	BVS      = 0x70,
	ADC_IY   = 0x71,
	RRA_IY   = 0x73,
	NOP_ZPX4 = 0x74,
	ADC_ZPX  = 0x75,
	ROR_ZPX  = 0x76,
	RRA_ZPX  = 0x77,
	SEI      = 0x78,
	ADC_AY   = 0x79,
	NOP_U4   = 0x7A,
	RRA_AY   = 0x7B,
	NOP_AX4  = 0x7C,
	ADC_AX   = 0x7D,
	ROR_AX   = 0x7E,
	RRA_AX   = 0x7F,
	NOP_I    = 0x80,
	STA_IX   = 0x81,
	NOP_I2   = 0x82,
	SAX_IX   = 0x83,
	STY_ZP   = 0x84,
	STA_ZP   = 0x85,
	STX_ZP   = 0x86,
	SAX_ZP   = 0x87,
	DEY      = 0x88,
	NOP_I3   = 0x89,
	TXA      = 0x8A,
	STY_A    = 0x8C,
	STA_A    = 0x8D,
	STX_A    = 0x8E,
	SAX_A    = 0x8F,
	BCC      = 0x90,
	STA_IY   = 0x91,
	STY_ZPX  = 0x94,
	STA_ZPX  = 0x95,
	STX_ZPY  = 0x96,
	SAX_ZPY  = 0x97,
	TYA      = 0x98,
	STA_AY   = 0x99,
	TXS      = 0x9A,
	STA_AX   = 0x9D,
	LDY_IM   = 0xA0,
	LDA_IX   = 0xA1,
	LDX_IM   = 0xA2,
	LAX_IX   = 0xA3,
	LDY_ZP   = 0xA4,
	LDA_ZP   = 0xA5,
	LDX_ZP   = 0xA6,
	LAX_ZP   = 0xA7,
	TAY      = 0xA8,
	LDA_IM   = 0xA9,
	TAX      = 0xAA,
	LDY_A    = 0xAC,
	LDA_A    = 0xAD,
	LDX_A    = 0xAE,
	LAX_A    = 0xAF,
	BCS      = 0xB0,
	LDA_IY   = 0xB1,
	LAX_IY   = 0xB3,
	LDY_ZPX  = 0xB4,
	LDA_ZPX  = 0xB5,
	LDX_ZPY  = 0xB6,
	LAX_ZPY  = 0xB7,
	CLV      = 0xB8,
	LDA_AY   = 0xB9,
	TSX      = 0xBA,
	LDY_AX   = 0xBC,
	LDA_AX   = 0xBD,
	LDX_AY   = 0xBE,
	LAX_AY   = 0xBF,
	CPY_IM   = 0xC0,
	CMP_IX   = 0xC1,
	NOP_I4   = 0xC2,
	DCP_IX   = 0xC3,
	CPY_ZP   = 0xC4,
	CMP_ZP   = 0xC5,
	DEC_ZP   = 0xC6,
	DCP_ZP   = 0xC7,
	INY      = 0xC8,
	CMP_IM   = 0xC9,
	DEX      = 0xCA,
	CPY_A    = 0xCC,
	CMP_A    = 0xCD,
	DEC_A    = 0xCE,
	DCP_A    = 0xCF,
	BNE      = 0xD0,
	CMP_IY   = 0xD1,
	DCP_IY   = 0xD3,
	NOP_ZPX5 = 0xD4,
	CMP_ZPX  = 0xD5,
	DEC_ZPX  = 0xD6,
	DCP_ZPX  = 0xD7,
	CLD      = 0xD8,
	CMP_AY   = 0xD9,
	NOP_U5   = 0xDA,
	DCP_AY   = 0xDB,
	NOP_AX5  = 0xDC,
	CMP_AX   = 0xDD,
	DEC_AX   = 0xDE,
	DCP_AX   = 0xDF,
	CPX_IM   = 0xE0,
	SBC_IX   = 0xE1,
	NOP_I5   = 0xE2,
	ISB_IX   = 0xE3,
	CPX_ZP   = 0xE4,
	SBC_ZP   = 0xE5,
	INC_ZP   = 0xE6,
	ISB_ZP   = 0xE7,
	INX      = 0xE8,
	SBC_IM   = 0xE9,
	NOP      = 0xEA,
	SBC_IM2  = 0xEB,
	CPX_A    = 0xEC,
	SBC_A    = 0xED,
	INC_A    = 0xEE,
	ISB_A    = 0xEF,
	BEQ      = 0xF0,
	SBC_IY   = 0xF1,
	ISB_IY   = 0xF3,
	NOP_ZPX6 = 0xF4,
	SBC_ZPX  = 0xF5,
	INC_ZPX  = 0xF6,
	ISB_ZPX  = 0xF7,
	SED      = 0xF8,
	SBC_AY   = 0xF9,
	NOP_U6   = 0xFA,
	ISB_AY   = 0xFB,
	NOP_AX6  = 0xFC,
	SBC_AX   = 0xFD,
	INC_AX   = 0xFE,
	ISB_AX   = 0xFF,
}

AddModeMap := map[OpCode]OpCodeInfo {
	.BRK      = {7, .NoneAddressing, false},
	.ADC_IM   = {2, .Immediate, false},
	.ADC_ZP   = {3, .ZeroPage, false},
	.ADC_ZPX  = {4, .ZeroPage_X, false},
	.ADC_A    = {4, .Absolute, false},
	.ADC_AX   = {4, .Absolute_X, false},
	.ADC_AY   = {4, .Absolute_Y, false},
	.ADC_IX   = {6, .Indirect_X, false},
	.ADC_IY   = {5, .Indirect_Y, false},
	.AND_IM   = {2, .Immediate, false},
	.AND_ZP   = {3, .ZeroPage, false},
	.AND_ZPX  = {4, .ZeroPage_X, false},
	.AND_A    = {4, .Absolute, false},
	.AND_AX   = {4, .Absolute_X, false},
	.AND_AY   = {4, .Absolute_Y, false},
	.AND_IX   = {6, .Indirect_X, false},
	.AND_IY   = {5, .Indirect_Y, false},
	.ASL_ACC  = {2, .Accumulator, false},
	.ASL_ZP   = {5, .ZeroPage, false},
	.ASL_ZPX  = {6, .ZeroPage_X, false},
	.ASL_A    = {6, .Absolute, false},
	.ASL_AX   = {7, .Absolute_X, false},
	.BCC      = {2, .Relative, false},
	.BCS      = {2, .Relative, false},
	.BEQ      = {2, .Relative, false},
	.BIT_ZP   = {3, .ZeroPage, false},
	.BIT_A    = {4, .Absolute, false},
	.BMI      = {2, .Relative, false},
	.BNE      = {2, .Relative, false},
	.BPL      = {2, .Relative, false},
	.BVC      = {2, .Relative, false},
	.BVS      = {2, .Relative, false},
	.CLC      = {2, .NoneAddressing, false},
	.CLD      = {2, .NoneAddressing, false},
	.CLI      = {2, .NoneAddressing, false},
	.CLV      = {2, .NoneAddressing, false},
	.CMP_IM   = {2, .Immediate, false},
	.CMP_ZP   = {3, .ZeroPage, false},
	.CMP_ZPX  = {4, .ZeroPage_X, false},
	.CMP_A    = {4, .Absolute, false},
	.CMP_AX   = {4, .Absolute_X, false},
	.CMP_AY   = {4, .Absolute_Y, false},
	.CMP_IX   = {6, .Indirect_X, false},
	.CMP_IY   = {5, .Indirect_Y, false},
	.CPX_IM   = {2, .Immediate, false},
	.CPX_ZP   = {3, .ZeroPage, false},
	.CPX_A    = {4, .Absolute, false},
	.CPY_IM   = {2, .Immediate, false},
	.CPY_ZP   = {3, .ZeroPage, false},
	.CPY_A    = {4, .Absolute, false},
	.DCP_A    = {6, .Absolute, true},
	.DCP_AX   = {7, .Absolute_X, true},
	.DCP_AY   = {7, .Absolute_Y, true},
	.DCP_IX   = {8, .Indirect_X, true},
	.DCP_IY   = {8, .Indirect_Y, true},
	.DCP_ZP   = {5, .ZeroPage, true},
	.DCP_ZPX  = {6, .ZeroPage_X, true},
	.DEC_ZP   = {5, .ZeroPage, false},
	.DEC_ZPX  = {6, .ZeroPage_X, false},
	.DEC_A    = {6, .Absolute, false},
	.DEC_AX   = {7, .Absolute_X, false},
	.DEX      = {2, .NoneAddressing, false},
	.DEY      = {2, .NoneAddressing, false},
	.EOR_IM   = {2, .Immediate, false},
	.EOR_ZP   = {3, .ZeroPage, false},
	.EOR_ZPX  = {4, .ZeroPage_X, false},
	.EOR_A    = {4, .Absolute, false},
	.EOR_AX   = {4, .Absolute_X, false},
	.EOR_AY   = {4, .Absolute_Y, false},
	.EOR_IX   = {6, .Indirect_X, false},
	.EOR_IY   = {5, .Indirect_Y, false},
	.INC_ZP   = {5, .ZeroPage, false},
	.INC_ZPX  = {6, .ZeroPage_X, false},
	.INC_A    = {6, .Absolute, false},
	.INC_AX   = {7, .Absolute_X, false},
	.INX      = {2, .NoneAddressing, false},
	.INY      = {2, .NoneAddressing, false},
	.ISB_A    = {6, .Absolute, true},
	.ISB_AX   = {7, .Absolute_X, true},
	.ISB_AY   = {7, .Absolute_Y, true},
	.ISB_IX   = {8, .Indirect_X, true},
	.ISB_IY   = {8, .Indirect_Y, true},
	.ISB_ZP   = {5, .ZeroPage, true},
	.ISB_ZPX  = {6, .ZeroPage_X, true},
	.JMP_A    = {3, .Absolute, false},
	.JMP_I    = {5, .Indirect, false},
	.JSR      = {6, .Absolute, false},
	.LAX_ZP   = {3, .ZeroPage, true},
	.LAX_ZPY  = {4, .ZeroPage_Y, true},
	.LAX_A    = {4, .Absolute, true},
	.LAX_AY   = {4, .Absolute_Y, true},
	.LAX_IX   = {6, .Indirect_X, true},
	.LAX_IY   = {5, .Indirect_Y, true},
	.LDA_IM   = {2, .Immediate, false},
	.LDA_ZP   = {3, .ZeroPage, false},
	.LDA_ZPX  = {4, .ZeroPage_X, false},
	.LDA_A    = {4, .Absolute, false},
	.LDA_AX   = {4, .Absolute_X, false},
	.LDA_AY   = {4, .Absolute_Y, false},
	.LDA_IX   = {6, .Indirect_X, false},
	.LDA_IY   = {5, .Indirect_Y, false},
	.LDX_IM   = {2, .Immediate, false},
	.LDX_ZP   = {3, .ZeroPage, false},
	.LDX_ZPY  = {4, .ZeroPage_Y, false},
	.LDX_A    = {4, .Absolute, false},
	.LDX_AY   = {4, .Absolute_Y, false},
	.LDY_IM   = {2, .Immediate, false},
	.LDY_ZP   = {3, .ZeroPage, false},
	.LDY_ZPX  = {4, .ZeroPage_X, false},
	.LDY_A    = {4, .Absolute, false},
	.LDY_AX   = {4, .Absolute_X, false},
	.LSR_ACC  = {2, .Accumulator, false},
	.LSR_ZP   = {5, .ZeroPage, false},
	.LSR_ZPX  = {6, .ZeroPage_X, false},
	.LSR_A    = {6, .Absolute, false},
	.LSR_AX   = {7, .Absolute_X, false},
	.NOP      = {2, .NoneAddressing, false},
	.NOP_U1   = {2, .NoneAddressing, true},
	.NOP_U2   = {2, .NoneAddressing, true},
	.NOP_U3   = {2, .NoneAddressing, true},
	.NOP_U4   = {2, .NoneAddressing, true},
	.NOP_U5   = {2, .NoneAddressing, true},
	.NOP_U6   = {2, .NoneAddressing, true},
	.NOP_I    = {2, .Immediate, true},
	.NOP_I2   = {2, .Immediate, true},
	.NOP_I3   = {2, .Immediate, true},
	.NOP_I4   = {2, .Immediate, true},
	.NOP_I5   = {2, .Immediate, true},
	.NOP_ZP   = {3, .ZeroPage, true},
	.NOP_ZP2  = {3, .ZeroPage, true},
	.NOP_ZP3  = {3, .ZeroPage, true},
	.NOP_ZPX  = {4, .ZeroPage_X, true},
	.NOP_ZPX2 = {4, .ZeroPage_X, true},
	.NOP_ZPX3 = {4, .ZeroPage_X, true},
	.NOP_ZPX4 = {4, .ZeroPage_X, true},
	.NOP_ZPX5 = {4, .ZeroPage_X, true},
	.NOP_ZPX6 = {4, .ZeroPage_X, true},
	.NOP_A    = {4, .Absolute, true},
	.NOP_AX   = {4, .Absolute_X, true},
	.NOP_AX2  = {4, .Absolute_X, true},
	.NOP_AX3  = {4, .Absolute_X, true},
	.NOP_AX4  = {4, .Absolute_X, true},
	.NOP_AX5  = {4, .Absolute_X, true},
	.NOP_AX6  = {4, .Absolute_X, true},
	.ORA_IM   = {2, .Immediate, false},
	.ORA_ZP   = {3, .ZeroPage, false},
	.ORA_ZPX  = {4, .ZeroPage_X, false},
	.ORA_A    = {4, .Absolute, false},
	.ORA_AX   = {4, .Absolute_X, false},
	.ORA_AY   = {4, .Absolute_Y, false},
	.ORA_IX   = {6, .Indirect_X, false},
	.ORA_IY   = {5, .Indirect_Y, false},
	.PHA      = {3, .NoneAddressing, false},
	.PHP      = {3, .NoneAddressing, false},
	.PLA      = {4, .NoneAddressing, false},
	.PLP      = {4, .NoneAddressing, false},
	.RLA_ZP   = {5, .ZeroPage, true},
	.RLA_ZPX  = {6, .ZeroPage_X, true},
	.RLA_A    = {6, .Absolute, true},
	.RLA_AX   = {7, .Absolute_X, true},
	.RLA_AY   = {7, .Absolute_Y, true},
	.RLA_IX   = {8, .Indirect_X, true},
	.RLA_IY   = {8, .Indirect_Y, true},
	.ROL_ACC  = {2, .Accumulator, false},
	.ROL_ZP   = {5, .ZeroPage, false},
	.ROL_ZPX  = {6, .ZeroPage_X, false},
	.ROL_A    = {6, .Absolute, false},
	.ROL_AX   = {7, .Absolute_X, false},
	.ROR_ACC  = {2, .Accumulator, false},
	.ROR_ZP   = {5, .ZeroPage, false},
	.ROR_ZPX  = {6, .ZeroPage_X, false},
	.ROR_A    = {6, .Absolute, false},
	.ROR_AX   = {7, .Absolute_X, false},
	.RRA_ZP   = {5, .ZeroPage, true},
	.RRA_ZPX  = {6, .ZeroPage_X, true},
	.RRA_A    = {6, .Absolute, true},
	.RRA_AX   = {7, .Absolute_X, true},
	.RRA_AY   = {7, .Absolute_Y, true},
	.RRA_IX   = {8, .Indirect_X, true},
	.RRA_IY   = {8, .Indirect_Y, true},
	.RTI      = {6, .NoneAddressing, false},
	.RTS      = {6, .NoneAddressing, false},
	.SAX_A    = {4, .Absolute, true},
	.SAX_ZP   = {3, .ZeroPage, true},
	.SAX_ZPY  = {4, .ZeroPage_Y, true},
	.SAX_IX   = {6, .Indirect_X, true},
	.SBC_IM   = {2, .Immediate, false},
	.SBC_IM2  = {2, .Immediate, true},
	.SBC_ZP   = {3, .ZeroPage, false},
	.SBC_ZPX  = {4, .ZeroPage_X, false},
	.SBC_A    = {4, .Absolute, false},
	.SBC_AX   = {4, .Absolute_X, false},
	.SBC_AY   = {4, .Absolute_Y, false},
	.SBC_IX   = {6, .Indirect_X, false},
	.SBC_IY   = {5, .Indirect_Y, false},
	.SEC      = {2, .NoneAddressing, false},
	.SED      = {2, .NoneAddressing, false},
	.SEI      = {2, .NoneAddressing, false},
	.SLO_A    = {6, .Absolute, true},
	.SLO_AX   = {7, .Absolute_X, true},
	.SLO_AY   = {7, .Absolute_Y, true},
	.SLO_IX   = {8, .Indirect_X, true},
	.SLO_IY   = {8, .Indirect_Y, true},
	.SLO_ZP   = {5, .ZeroPage, true},
	.SLO_ZPX  = {6, .ZeroPage_X, true},
	.SRE_ZP   = {5, .ZeroPage, true},
	.SRE_ZPX  = {6, .ZeroPage_X, true},
	.SRE_A    = {6, .Absolute, true},
	.SRE_AX   = {7, .Absolute_X, true},
	.SRE_AY   = {7, .Absolute_Y, true},
	.SRE_IX   = {8, .Indirect_X, true},
	.SRE_IY   = {8, .Indirect_Y, true},
	.STA_ZP   = {3, .ZeroPage, false},
	.STA_ZPX  = {4, .ZeroPage_X, false},
	.STA_A    = {4, .Absolute, false},
	.STA_AX   = {5, .Absolute_X, false},
	.STA_AY   = {5, .Absolute_Y, false},
	.STA_IX   = {6, .Indirect_X, false},
	.STA_IY   = {6, .Indirect_Y, false},
	.STX_ZP   = {3, .ZeroPage, false},
	.STX_ZPY  = {4, .ZeroPage_Y, false},
	.STX_A    = {4, .Absolute, false},
	.STY_ZP   = {3, .ZeroPage, false},
	.STY_ZPX  = {4, .ZeroPage_X, false},
	.STY_A    = {4, .Absolute, false},
	.TAX      = {2, .NoneAddressing, false},
	.TAY      = {2, .NoneAddressing, false},
	.TSX      = {2, .NoneAddressing, false},
	.TXA      = {2, .NoneAddressing, false},
	.TXS      = {2, .NoneAddressing, false},
	.TYA      = {2, .NoneAddressing, false},
}

OpCodeInfo :: struct {
	n_cycles:   int,
	add_mode:   AddressingMode,
	unofficial: bool,
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

//TODO: Convert the status flag to a bitset and just convert to a number when pushing/poping from
//      the stack
MOS6502 :: struct {
	a:        u8,
	status:   u8,
	pc:       int,
	sp:       u8,
	ix:       u8,
	iy:       u8,
	ec:       int, // set for extra cycles than the default based on branch or page crossing
	dm_avail: bool, // set to whether the decimal mode is available
	status2:  Status_Set,
}

Flags :: enum {
	Zero,
	Negative,
	Carry,
	InterruptDisable,
	DecimalMode,
	Overflow,
}
Status_Set :: bit_set[Flags]

// Bits for the status byte
ZeroFlag: u8 : 0b0000_0010
NegativeFlag: u8 : 0b1000_0000
CarryFlag: u8 : 0b0000_0001
InterruptDisable: u8 : 0b0000_0100
DecimalModeFlag: u8 : 0b0000_1000
BreakCommand: u8 : 0b0001_0000
BreakCommand2: u8 : 0b0010_0000
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

// Flag setting functions using the Status_Set bit_set
set_zero_flag :: proc(value: u8, status: Status_Set) -> Status_Set {
	status := status
	if value == 0 {
		status += {Flags.Zero}
	} else {
		status -= {Flags.Zero}
	}

	return status
}

set_negative_flag :: proc(value: u8, status: Status_Set) -> Status_Set {
	negative_bit: u8 = 1 << NegativeBit
	status := status

	if value & negative_bit != 0 {
		status += {Flags.Negative}
	} else {
		status -= {Flags.Negative}
	}

	return status
}

set_overflow_flag :: proc(val1: u8, val2: u8, sum: u8, status: Status_Set) -> Status_Set {
	diff1 := (val1 ~ sum) & 0x80 != 0 // checks whether last bit is different
	diff2 := (val2 ~ sum) & 0x80 != 0
	is_overflow := diff1 && diff2

	status := status

	if is_overflow {
		status += {Flags.Overflow}
	} else {
		status -= {Flags.Overflow}
	}

	return status
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

setOverflowFlag :: proc(val1: u8, val2: u8, sum: u8, flagsIn: u8) -> u8 {
	// Overflow checks for signed overflow, i.e. positive + positive=negative or
	// negative + negative = positive
	diff1 := (val1 ~ sum) & 0x80 != 0 // checks whether last bit is different
	diff2 := (val2 ~ sum) & 0x80 != 0
	isOverflow := diff1 && diff2
	flagsOut := isOverflow ? flagsIn | OverflowFlag : flagsIn &~ OverflowFlag
	return flagsOut
}

brk :: proc(state: ^MOS6502) {
	state.status = state.status | BreakCommand
}

adc :: proc(state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode) {

	m := getValue8(state, bus, add_mode)

	if state.dm_avail && (state.status & DecimalModeFlag != 0) {
		m = fromBCD(m)
	}

	value, cy := bits.overflowing_add(state.a, m)

	carry := state.status & CarryFlag != 0 ? 1 : 0
	value2, cy2 := bits.overflowing_add(value, carry)

	state.status = setNegativeFlag(value2, state.status)
	state.status = setZeroFlag(value2, state.status)
	state.status = setOverflowFlag(state.a, m, value2, state.status)
	state.status = cy | cy2 ? state.status | 1 : state.status &~ 1

	if state.dm_avail && (state.status & DecimalModeFlag != 0) {
		value2 = toBCD(value2)
	}

	state.a = value2
}

and :: proc(state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode) {
	m := getValue8(state, bus, add_mode)

	state.a &= m
	state.status = setZeroFlag(state.a, state.status)
	state.status = setNegativeFlag(state.a, state.status)
}

shift :: proc(state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode, carry: bool, left: bool) {
	m := getValue8(state, bus, add_mode)

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
	writeValue8(value, state, bus, add_mode)
}

branch :: proc(state: ^MOS6502, bus: ^Bus, flag: u8, eq: bool) {
	// Offset if from the end of the instruction so the way I increment everything
	// should be fine

	offset := readImmediate8(state, bus)
	rel_offset: i8 = auto_cast offset // since offset is signed

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

bit :: proc(state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode) {
	mem_val := getValue8(state, bus, add_mode)
	value := state.a & mem_val
	state.status = setZeroFlag(value, state.status)

	//bit 6 is set to overflow flag
	//bit 7 is set to negative flag

	bit6 :: 0b0100_0000

	state.status = bit6 & mem_val != 0 ? state.status | OverflowFlag : state.status &~ OverflowFlag

	// Can just call setNegativeFlag since mem_val being negative is also bit7 being 1
	state.status = setNegativeFlag(mem_val, state.status)
}

clear :: proc(state: ^MOS6502, flag: u8) {
	state.status = state.status &~ flag
}

compare :: proc(state: ^MOS6502, register: ^u8, bus: ^Bus, add_mode: AddressingMode) {
	m := getValue8(state, bus, add_mode)
	value := register^ - m

	state.status = register^ >= m ? state.status | CarryFlag : state.status &~ CarryFlag
	state.status = setZeroFlag(value, state.status)
	state.status = setNegativeFlag(value, state.status)
}

dec :: proc(state: ^MOS6502, register: ^u8, bus: ^Bus, add_mode: AddressingMode) {
	value: u8

	// Different branches for when decrementing x/y-registers and memory locations
	if add_mode == .NoneAddressing {
		register^ -= 1
		value = register^
	} else {
		value = getValue8(state, bus, add_mode) - 1
		writeValue8(value, state, bus, add_mode)
	}

	state.status = setZeroFlag(value, state.status)
	state.status = setNegativeFlag(value, state.status)
}

eor :: proc(state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode) {
	state.a = state.a ~ getValue8(state, bus, add_mode)
	state.status = setZeroFlag(state.a, state.status)
	state.status = setNegativeFlag(state.a, state.status)
}

inc :: proc(state: ^MOS6502, register: ^u8, bus: ^Bus, add_mode: AddressingMode) {
	value: u8

	// Different branches for when decrementing x/y-registers and memory locations
	if add_mode == .NoneAddressing {
		register^ += 1
		value = register^
	} else {
		value = getValue8(state, bus, add_mode) + 1
		writeValue8(value, state, bus, add_mode)
	}

	state.status = setZeroFlag(value, state.status)
	state.status = setNegativeFlag(value, state.status)
}

jump :: proc(state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode, sub: bool) {
	value := getOffset(state, bus, add_mode)

	// fmt.printf("JUMP: %04x %04x\n", state.pc, value)

	// If jump to subroutine, push the address (minus one) of the return point on the stack
	// TODO: Says it pushes address-1 of the next operation
	if sub {
		// pc should already be location of next instruction
		pc_curr := u16(state.pc - 1)
		high, low := getHighLow(pc_curr)
		pushR(high, low, state, bus)
	}

	state.pc = int(value)
}

loadRegister :: proc(state: ^MOS6502, register: ^u8, bus: ^Bus, add_mode: AddressingMode) {
	register^ = getValue8(state, bus, add_mode)
	state.status = setZeroFlag(register^, state.status)
	state.status = setNegativeFlag(register^, state.status)
}

lsr :: proc(state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode) {
	m := getValue8(state, bus, add_mode)

	value := m >> 1

	bit0: u8 : 1 << 0
	state.status = state.status | ((bit0 & m) << CarryBit)
	state.status = setZeroFlag(value, state.status)
	state.status = setNegativeFlag(value, state.status)

	writeValue8(value, state, bus, add_mode)

}

nop :: proc(state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode) {

	// For unofficial nops we must consume some values
	tmp := getValue8(state, bus, add_mode)
}

ora :: proc(state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode) {
	state.a = getValue8(state, bus, add_mode) | state.a

	state.status = setZeroFlag(state.a, state.status)
	state.status = setNegativeFlag(state.a, state.status)
}

rti :: proc(state: ^MOS6502, bus: ^Bus) {

	state.status = (pop8(state, bus) | 0b0010_0000) & 0b1110_1111

	high, low: u8
	popR(&high, &low, state, bus)

	state.pc = auto_cast getCombined(high, low)
}

rts :: proc(state: ^MOS6502, bus: ^Bus) {
	high, low: u8
	popR(&high, &low, state, bus)

	pc := getCombined(high, low)

	// TODO: Check. Added one because I store location of next instruction - 1 on the stack
	// so I must increment it
	state.pc = int(pc) + 1
}

sbc :: proc(state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode) {
	m := getValue8(state, bus, add_mode)

	if state.dm_avail && (state.status & DecimalModeFlag != 0) {
		m = fromBCD(m)
	}
	value, cy := bits.overflowing_sub(state.a, m)
	carry := state.status & CarryFlag != 0 ? 0 : 1

	value2, cy2 := bits.overflowing_sub(value, carry)

	state.status = setNegativeFlag(value2, state.status)
	state.status = setZeroFlag(value2, state.status)

	val_overflow: u8 = auto_cast (-(int(m) + carry))

	state.status = setOverflowFlag(state.a, val_overflow, value2, state.status)
	state.status = (cy | cy2) ? state.status &~ 1 : state.status | 1

	if state.dm_avail && (state.status & DecimalModeFlag != 0) {
		value2 = toBCD(value2)
	}

	state.a = value2
}

setFlag :: proc(state: ^MOS6502, flag: u8) {
	state.status = state.status | flag
}

store :: proc(register: u8, state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode) {
	offset := getOffset(state, bus, add_mode)
	bus.write(bus, offset, register)
}

transfer :: proc(dest: ^u8, init: ^u8, state: ^MOS6502, set_flags: bool) {
	dest^ = init^

	if set_flags {
		state.status = setZeroFlag(dest^, state.status)
		state.status = setNegativeFlag(dest^, state.status)
	}
}

getOffset :: proc(state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode) -> u16 {
	switch add_mode {
	case .Accumulator:
		log.error("Can't get offset for accumulator")
	case .Relative:
		log.error("Call getValue8 for Relative")
	case .Immediate:
		log.error("Call getValue8 for Immediate")
	case .Absolute:
		return readImmediate16(state, bus)
	case .Absolute_X:
		offset := readImmediate16(state, bus)
		return u16(state.ix) + offset
	case .Absolute_Y:
		offset := readImmediate16(state, bus)
		return u16(state.iy) + offset
	case .ZeroPage:
		return u16(readImmediate8(state, bus))
	case .ZeroPage_X:
		return u16(readImmediate8(state, bus) + state.ix)
	case .ZeroPage_Y:
		return u16(readImmediate8(state, bus) + state.iy)
	case .Indirect:
		offset1 := readImmediate16(state, bus)
		low := bus.read(bus, offset1)

		// Indirect addressing can't cross page boundary
		high_bits := offset1 & 0xFF00
		high_off := u8(offset1 & 0x00FF) + 1
		high_addr := high_bits | u16(high_off)
		high := bus.read(bus, high_addr)
		return getCombined(high, low)
	case .Indirect_X:
		addr := state.ix + readImmediate8(state, bus)
		low := bus.read(bus, auto_cast addr)
		high := bus.read(bus, auto_cast (addr + 1))
		return getCombined(high, low)
	case .Indirect_Y:
		base := readImmediate8(state, bus)
		low := bus.read(bus, auto_cast base)
		high := bus.read(bus, auto_cast (base + 1))
		return getCombined(high, low) + u16(state.iy)
	case .NoneAddressing:
		log.error("Trying to read operand with NoneAddressing")
		return 0
	}

	log.error("Somehow made it past the switch statement which should always return")
	return 0
}

getValue8 :: proc(state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode) -> u8 {

	switch add_mode {
	case .Accumulator:
		return state.a
	case .Relative:
		return readImmediate8(state, bus)
	case .Immediate:
		return readImmediate8(state, bus)
	case .Absolute:
		// return memory[readImmediate16(state, memory)]
		return bus.read(bus, readImmediate16(state, bus))
	case .Absolute_X:
		offset := readImmediate16(state, bus)
		addr := u16(state.ix) + offset
		// return memory[u16(state.ix) + offset]
		return bus.read(bus, addr)
	case .Absolute_Y:
		offset := readImmediate16(state, bus)
		addr := u16(state.iy) + offset
		// return memory[u16(state.iy) + offset]
		return bus.read(bus, addr)
	case .ZeroPage:
		// return memory[readImmediate8(state, memory)]
		addr := readImmediate8(state, bus)
		return bus.read(bus, auto_cast addr)
	case .ZeroPage_X:
		addr := readImmediate8(state, bus) + state.ix
		// return memory[readImmediate8(state, memory) + state.ix]
		return bus.read(bus, auto_cast addr)
	case .ZeroPage_Y:
		addr := readImmediate8(state, bus) + state.iy
		// return memory[readImmediate8(state, memory) + state.iy]
		return bus.read(bus, auto_cast addr)
	case .Indirect:
		log.error("Should never be trying to get memory value with Indirect addressing mode")
	case .Indirect_X:
		// addr := state.ix + readImmediate8(state, bus)
		// low := bus.read(bus, auto_cast addr)
		// high := bus.read(bus, auto_cast (addr + 1))
		addr := getOffset(state, bus, add_mode)
		// return bus.read(bus, getCombined(high, low))
		return bus.read(bus, addr)
	case .Indirect_Y:
		base := readImmediate8(state, bus)
		low := bus.read(bus, auto_cast base)
		high := bus.read(bus, auto_cast (base + 1))
		addr := getCombined(high, low) + u16(state.iy)
		return bus.read(bus, addr)
	case .NoneAddressing:
		// Commented out the error message because of unofficial opcodes we
		// might need to call this function with .NoneAddressing
		//log.error("Trying to read operand with NoneAddressing")
		return 0
	}

	log.error("Somehow made it past the switch statement which should always return")
	return 0
}

// Fome some instructions that act straight on the memory locations (i.e. ASL). We
// undo the increment of the program counter and then read in the offset again in order
// to figure out where to store the value
writeValue8 :: proc(value: u8, state: ^MOS6502, bus: ^Bus, add_mode: AddressingMode) {
	switch add_mode {
	case .Accumulator:
		state.a = value
	case .Immediate:
		log.error("Writing to immediate value is not a valid thing to do.")
	case .Indirect:
		log.error(
			"Indirect is only used in a JMP instruction and should never be used when writing to memory.",
		)
	case .Absolute, .ZeroPage, .ZeroPage_X, .Absolute_X, .Absolute_Y, .Indirect_X, .Indirect_Y:
		undo_read(state, add_mode)
		addr := getOffset(state, bus, add_mode)
		bus.write(bus, addr, value)
	case .NoneAddressing:
		log.error("Can't write with to memory with an operation that has no addressing")
	case .Relative:
		log.error("Relative mode is only for branching and not writing to memory.")
	case .ZeroPage_Y:
		log.error("Writing with Zero Page Y not implemented as no instruction implements it")
	}
}

// The stack containes the addresses from 0x0100 to 0x01FF and the stack pointer runs from 0 to FF
// so you need to add 0x0100 to the stack pointer value to get the address on the stack
push8 :: proc(reg1: u8, state: ^MOS6502, bus: ^Bus) {
	addr := u16(state.sp) + 0x0100
	// stack[state.sp - 1] = reg1
	bus.write(bus, addr, reg1)
	state.sp -= 1
}

pop8 :: proc(state: ^MOS6502, bus: ^Bus) -> u8 {
	addr := u16(state.sp + 1) + 0x0100
	state.sp += 1
	// return stack[state.sp - 1]
	return bus.read(bus, addr)
}

pushR :: proc(reg1: u8, reg2: u8, state: ^MOS6502, bus: ^Bus) {
	addr := u16(state.sp) + 0x0100
	bus.write(bus, addr, reg1)
	state.sp -= 1
	addr = u16(state.sp) + 0x0100
	// bus.write(bus, addr - 1, reg2)
	bus.write(bus, addr, reg2)
	state.sp -= 1
	// state.sp -= 2
}

popR :: proc(reg1: ^u8, reg2: ^u8, state: ^MOS6502, bus: ^Bus) {
	// addr := u16(state.sp) + 0x0100
	// reg2^ = bus.read(bus, addr + 1)
	// reg1^ = bus.read(bus, addr + 2)
	// state.sp += 2
	state.sp += 1
	addr := u16(state.sp) + 0x0100
	reg2^ = bus.read(bus, addr)
	state.sp += 1
	addr = u16(state.sp) + 0x0100
	reg1^ = bus.read(bus, addr)
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

readImmediate8 :: proc(state: ^MOS6502, bus: ^Bus) -> u8 {
	data := bus.read(bus, auto_cast state.pc)
	state.pc += 1
	//return memory[state.pc - 1]
	return data
}

writeImmediate8 :: proc(value: u8, state: ^MOS6502, bus: ^Bus) {
	bus.write(bus, auto_cast (state.pc - 1), value)
}

//TODO: Replace with two readImmediate8
readImmediate16 :: proc(state: ^MOS6502, bus: ^Bus) -> u16 {
	low := bus.read(bus, auto_cast state.pc)
	high := bus.read(bus, auto_cast state.pc + 1)

	state.pc += 2

	return getCombined(high, low)
}

undo_read :: proc(state: ^MOS6502, add_mode: AddressingMode) {
	/* Move the program back a number of steps based on the addressing mode. The
	program counter should now be like it was before consuming the opcode data.
	*/

	switch add_mode {
	case .Absolute, .Absolute_X, .Absolute_Y, .Indirect, .Relative:
		state.pc -= 2
	case .Immediate, .ZeroPage, .ZeroPage_X, .ZeroPage_Y, .Indirect_X, .Indirect_Y:
		state.pc -= 1
	case .NoneAddressing, .Accumulator:
	}
}

emulate6502p :: proc(state: ^MOS6502, bus: ^Bus) -> int {

	opcode: OpCode = auto_cast readImmediate8(state, bus)

	//Page boundary
	state.ec = 0

	opCodeInfo := AddModeMap[opcode]
	n_cycles := opCodeInfo.n_cycles

	switch opcode {
	case .BRK:
		brk(state)
	case .ADC_IM, .ADC_ZP, .ADC_ZPX, .ADC_A, .ADC_AX, .ADC_AY, .ADC_IX, .ADC_IY:
		adc(state, bus, opCodeInfo.add_mode)
	case .AND_IM, .AND_ZP, .AND_ZPX, .AND_A, .AND_AX, .AND_AY, .AND_IX, .AND_IY:
		and(state, bus, opCodeInfo.add_mode)
	case .ASL_ACC, .ASL_ZP, .ASL_ZPX, .ASL_A, .ASL_AX:
		shift(state, bus, opCodeInfo.add_mode, false, true)
	case .BCC:
		branch(state, bus, CarryFlag, true)
	case .BCS:
		branch(state, bus, CarryFlag, false)
	case .BEQ:
		branch(state, bus, ZeroFlag, false)
	case .BIT_A, .BIT_ZP:
		bit(state, bus, opCodeInfo.add_mode)
	case .BMI:
		branch(state, bus, NegativeFlag, false)
	case .BNE:
		branch(state, bus, ZeroFlag, true)
	case .BPL:
		branch(state, bus, NegativeFlag, true)
	case .BVC:
		branch(state, bus, OverflowFlag, true)
	case .BVS:
		branch(state, bus, OverflowFlag, false)
	case .CLC:
		clear(state, CarryFlag)
	case .CLD:
		clear(state, DecimalModeFlag)
	case .CLI:
		clear(state, InterruptDisable)
	case .CLV:
		clear(state, OverflowFlag)
	case .CMP_IM, .CMP_ZP, .CMP_ZPX, .CMP_A, .CMP_AX, .CMP_AY, .CMP_IX, .CMP_IY:
		compare(state, &state.a, bus, opCodeInfo.add_mode)
	case .CPX_IM, .CPX_ZP, .CPX_A:
		compare(state, &state.ix, bus, opCodeInfo.add_mode)
	case .CPY_IM, .CPY_ZP, .CPY_A:
		compare(state, &state.iy, bus, opCodeInfo.add_mode)
	case .DCP_A, .DCP_AX, .DCP_AY, .DCP_IX, .DCP_IY, .DCP_ZP, .DCP_ZPX:
		// DCP is just DEC then CMP
		i: ^u8
		dec(state, i, bus, opCodeInfo.add_mode)
		undo_read(state, opCodeInfo.add_mode)
		compare(state, &state.a, bus, opCodeInfo.add_mode)
	case .DEC_ZP, .DEC_ZPX, .DEC_A, .DEC_AX:
		i: ^u8
		dec(state, i, bus, opCodeInfo.add_mode)
	case .DEX:
		dec(state, &state.ix, bus, opCodeInfo.add_mode)
	case .DEY:
		dec(state, &state.iy, bus, opCodeInfo.add_mode)
	case .EOR_IM, .EOR_ZP, .EOR_ZPX, .EOR_A, .EOR_AX, .EOR_AY, .EOR_IX, .EOR_IY:
		eor(state, bus, opCodeInfo.add_mode)
	case .INC_ZP, .INC_ZPX, .INC_A, .INC_AX:
		tmp: ^u8
		inc(state, tmp, bus, opCodeInfo.add_mode)
	case .INX:
		inc(state, &state.ix, bus, opCodeInfo.add_mode)
	case .INY:
		inc(state, &state.iy, bus, opCodeInfo.add_mode)
	case .ISB_A, .ISB_AX, .ISB_AY, .ISB_IX, .ISB_IY, .ISB_ZP, .ISB_ZPX:
		tmp: ^u8
		inc(state, tmp, bus, opCodeInfo.add_mode)
		undo_read(state, opCodeInfo.add_mode)
		sbc(state, bus, opCodeInfo.add_mode)
	case .JMP_A, .JMP_I:
		jump(state, bus, opCodeInfo.add_mode, false)
	case .JSR:
		jump(state, bus, opCodeInfo.add_mode, true)
	case .LAX_A, .LAX_AY, .LAX_IX, .LAX_IY, .LAX_ZP, .LAX_ZPY:
		loadRegister(state, &state.a, bus, opCodeInfo.add_mode)
		state.ix = state.a
	case .LDA_IM, .LDA_ZP, .LDA_ZPX, .LDA_A, .LDA_AX, .LDA_AY, .LDA_IX, .LDA_IY:
		loadRegister(state, &state.a, bus, opCodeInfo.add_mode)
	case .LDX_IM, .LDX_ZP, .LDX_ZPY, .LDX_A, .LDX_AY:
		loadRegister(state, &state.ix, bus, opCodeInfo.add_mode)
	case .LDY_IM, .LDY_ZP, .LDY_ZPX, .LDY_A, .LDY_AX:
		loadRegister(state, &state.iy, bus, opCodeInfo.add_mode)
	case .LSR_ACC, .LSR_ZP, .LSR_ZPX, .LSR_A, .LSR_AX:
		shift(state, bus, opCodeInfo.add_mode, false, false)
	case .NOP_U1, .NOP_U2, .NOP_U3, .NOP_U4, .NOP_U5, .NOP_U6:
		fallthrough
	case .NOP_A, .NOP_AX, .NOP_AX2, .NOP_AX3, .NOP_AX4, .NOP_AX5, .NOP_AX6:
		fallthrough
	case .NOP, .NOP_ZP, .NOP_ZP2, .NOP_ZP3, .NOP_ZPX, .NOP_ZPX2, .NOP_ZPX3, .NOP_ZPX4:
		fallthrough
	case .NOP_ZPX5, .NOP_ZPX6, .NOP_I, .NOP_I2, .NOP_I3, .NOP_I4, .NOP_I5:
		nop(state, bus, opCodeInfo.add_mode)
	case .ORA_IM, .ORA_ZP, .ORA_ZPX, .ORA_A, .ORA_AX, .ORA_AY, .ORA_IX, .ORA_IY:
		ora(state, bus, opCodeInfo.add_mode)
	case .PHA:
		push8(state.a, state, bus)
	case .PHP:
		// Notes say that PHP always pushes the break flag as a 1 to the stack
		push8(state.status | BreakCommand, state, bus)
	case .PLA:
		state.a = pop8(state, bus)
		state.status = setZeroFlag(state.a, state.status)
		state.status = setNegativeFlag(state.a, state.status)
	case .PLP:
		// NOTES: From my understanding bits 4/5 (starting at 0) don't actually exist
		// in memory. The nesttest.log just pads to 8 bits with 1 and 0
		state.status = (pop8(state, bus) | 0b0010_0000) & 0b1110_1111
	case .RLA_A, .RLA_AX, .RLA_AY, .RLA_IX, .RLA_IY, .RLA_ZP, .RLA_ZPX:
		shift(state, bus, opCodeInfo.add_mode, true, true)
		undo_read(state, opCodeInfo.add_mode)
		and(state, bus, opCodeInfo.add_mode)
	case .ROL_ACC, .ROL_ZP, .ROL_ZPX, .ROL_A, .ROL_AX:
		shift(state, bus, opCodeInfo.add_mode, true, true)
	case .ROR_ACC, .ROR_ZP, .ROR_ZPX, .ROR_A, .ROR_AX:
		shift(state, bus, opCodeInfo.add_mode, true, false)
	case .RRA_A, .RRA_AX, .RRA_AY, .RRA_IX, .RRA_IY, .RRA_ZP, .RRA_ZPX:
		shift(state, bus, opCodeInfo.add_mode, true, false)
		undo_read(state, opCodeInfo.add_mode)
		adc(state, bus, opCodeInfo.add_mode)
	case .RTI:
		rti(state, bus)
	case .RTS:
		rts(state, bus)
	case .SAX_A, .SAX_IX, .SAX_ZP, .SAX_ZPY:
		store(state.ix & state.a, state, bus, opCodeInfo.add_mode)
	case .SBC_IM, .SBC_ZP, .SBC_ZPX, .SBC_A, .SBC_AX, .SBC_AY, .SBC_IX, .SBC_IY, .SBC_IM2:
		sbc(state, bus, opCodeInfo.add_mode)
	case .SEC:
		setFlag(state, CarryFlag)
	case .SED:
		setFlag(state, DecimalModeFlag)
	case .SEI:
		setFlag(state, InterruptDisable)
	case .SLO_A, .SLO_AX, .SLO_AY, .SLO_IX, .SLO_IY, .SLO_ZP, .SLO_ZPX:
		shift(state, bus, opCodeInfo.add_mode, false, true)
		undo_read(state, opCodeInfo.add_mode)
		ora(state, bus, opCodeInfo.add_mode)
	case .SRE_A, .SRE_AX, .SRE_AY, .SRE_IX, .SRE_IY, .SRE_ZP, .SRE_ZPX:
		shift(state, bus, opCodeInfo.add_mode, false, false)
		undo_read(state, opCodeInfo.add_mode)
		eor(state, bus, opCodeInfo.add_mode)
	case .STA_ZP, .STA_ZPX, .STA_A, .STA_AX, .STA_AY, .STA_IX, .STA_IY:
		store(state.a, state, bus, opCodeInfo.add_mode)
	case .STX_ZP, .STX_ZPY, .STX_A:
		store(state.ix, state, bus, opCodeInfo.add_mode)
	case .STY_ZP, .STY_ZPX, .STY_A:
		store(state.iy, state, bus, opCodeInfo.add_mode)
	case .TAX:
		transfer(&state.ix, &state.a, state, true)
	case .TAY:
		transfer(&state.iy, &state.a, state, true)
	case .TSX:
		transfer(&state.ix, &state.sp, state, true)
	case .TXA:
		transfer(&state.a, &state.ix, state, true)
	case .TXS:
		transfer(&state.sp, &state.ix, state, false)
	case .TYA:
		transfer(&state.a, &state.iy, state, true)
	}

	// Check if it is always +1 for a page boundary crossing
	n_cycles += state.ec

	return n_cycles
}
