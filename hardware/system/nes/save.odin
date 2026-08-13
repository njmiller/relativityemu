package nes

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:fmt"

save_path_for_rom :: proc(rom_fn: string) -> string {
    filename := filepath.base(rom_fn)

    path, err := os.get_executable_directory(context.allocator)

    if err != nil {
        log.warn("Could not determine executable directory.")
        return ""
    }

    save_path, err2 := os.join_path({path, "save"}, context.allocator)
    
    if err2 != nil {
        log.warn("Could not construct path to save directory")
        return ""
    }

    if !os.is_dir(save_path) {
        err3 := os.make_directory(save_path)
        if err3 != nil {
            log.warn("Could not create save directory")
            return ""
        }
    }

    save_file, err4 := os.join_filename(os.stem(filename), "sav", context.allocator)

    save_fn, err5 := os.join_path({save_path, save_file}, context.allocator)

    fmt.println("Save file at", save_fn)

    return save_fn
}

load_sram :: proc(bus: ^Bus) {

    if bus.save_path == "" do return

    data, err := os.read_entire_file_from_path(bus.save_path, context.allocator)
    if err != nil do return

    copy_slice(bus.prg_ram, data)

    if len(data) != len(bus.prg_ram) {
        log.warn("Length of save data != length of prg_ram")
    }

    bus.prg_ram_dirty = false
    delete(data)
}

save_sram :: proc(bus: ^Bus) {
    if bus.save_path == "" || !bus.prg_ram_dirty do return

    err := os.write_entire_file(bus.save_path, bus.prg_ram)

    if err != nil{
        log.error("Error writing save file.")
    } else {
        bus.prg_ram_dirty = false
    }
}