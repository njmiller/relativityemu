package nes

import "core:fmt"
import "core:os"
import "core:time"
import "core:log"

import "hardware:cpu"

NES :: struct {
    cpu6502 : cpu.MOS6502,
    memory : []u8,
}

loadRom :: proc(file: string, memory: []u8) {
    source, success := os.read_entire_file_from_filename(file)

    copy(memory[0x8000:], source)
    memory[0xFFFC] = 0x00
    memory[0xFFFD] = 0x80
}

reset :: proc(state: ^cpu.MOS6502, memory: []u8) {
    state.a = 0
    state.ix = 0
    state.iy = 0
    state.status = 0
    state.pc = auto_cast memory[0xFFFC]
    state.sp = 0xFF
}

loadAndRun :: proc(file: string, nes: ^NES) {
    loadRom(file, nes.memory)
    reset(&nes.cpu6502, nes.memory)
}

run :: proc(nes: ^NES) {
    totCycles : int

    for {
        totCycles += cpu.emulate6502p(&nes.cpu6502, nes.memory)
    }
}

main :: proc() {
    context.logger = log.create_console_logger()
    
    memory : []u8
    state : cpu.MOS6502
    sw : time.Stopwatch

    memory = make([]u8, 0xFFFF)

    memory[0] = 0xA9
    memory[1] = 0xC0
    memory[2] = 0xAA
    memory[3] = 0xE8
    memory[4] = 00

    pc := 0
    for i in 0..<4 {
        pc += cpu.disassemble6502p(memory, pc)
        cpu.emulate6502p(&state, memory)
    }

    fmt.printf("%02x", state.ix)
}