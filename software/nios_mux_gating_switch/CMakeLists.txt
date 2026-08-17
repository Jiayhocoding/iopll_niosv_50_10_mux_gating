cmake_minimum_required(VERSION 3.14)

add_subdirectory(../nios_bsp nios_bsp)
include(../nios_bsp/toolchain.cmake)
project(nios_mux_gating_switch)

enable_language(ASM)
enable_language(C)
enable_language(CXX)

add_executable(nios_mux_gating_switch.elf main.c)
target_link_libraries(nios_mux_gating_switch.elf PRIVATE
    -T "${BspLinkerScript}" -nostdlib
    "${ExtraArchiveLibraries}"
    -Wl,--start-group "${BspLibraryName}" -lc -lstdc++ -lgcc -lm -Wl,--end-group)

add_custom_command(TARGET nios_mux_gating_switch.elf POST_BUILD
    COMMAND "${ToolchainObjdump}" "${ToolchainObjdumpFlags}"
            nios_mux_gating_switch.elf
            > nios_mux_gating_switch.elf.objdump
    VERBATIM)
