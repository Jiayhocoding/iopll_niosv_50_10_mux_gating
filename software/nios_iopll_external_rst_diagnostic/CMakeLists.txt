cmake_minimum_required(VERSION 3.14)

add_subdirectory(../nios_bsp nios_bsp)
include(../nios_bsp/toolchain.cmake)
project(nios_iopll_external_rst_diagnostic)

enable_language(ASM)
enable_language(C)
enable_language(CXX)

add_executable(nios_iopll_external_rst_diagnostic.elf main.c)
target_link_libraries(nios_iopll_external_rst_diagnostic.elf PRIVATE
    -T "${BspLinkerScript}" -nostdlib
    "${ExtraArchiveLibraries}"
    -Wl,--start-group "${BspLibraryName}" -lc -lstdc++ -lgcc -lm -Wl,--end-group)

add_custom_command(TARGET nios_iopll_external_rst_diagnostic.elf POST_BUILD
    COMMAND "${ToolchainObjdump}" "${ToolchainObjdumpFlags}"
            nios_iopll_external_rst_diagnostic.elf
            > nios_iopll_external_rst_diagnostic.elf.objdump
    VERBATIM)
