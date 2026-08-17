cmake_minimum_required(VERSION 3.14)

add_subdirectory(../nios_bsp nios_bsp)

include(../nios_bsp/toolchain.cmake)

project(nios_app)

enable_language(ASM)
enable_language(C)
enable_language(CXX)

add_executable(nios_app.elf)

target_sources(nios_app.elf
    PRIVATE
        main.c
)

target_include_directories(nios_app.elf
    PRIVATE
    PUBLIC
)

target_link_libraries(nios_app.elf
    PRIVATE
        -T "${BspLinkerScript}" -nostdlib
        "${ExtraArchiveLibraries}"
        -Wl,--start-group "${BspLibraryName}" -lc -lstdc++ -lgcc -lm -Wl,--end-group
)

# Create objdump from ELF.
set(objdump nios_app.elf.objdump)
add_custom_command(
    OUTPUT "${objdump}"
    DEPENDS nios_app.elf
    COMMAND "${ToolchainObjdump}" "${ToolchainObjdumpFlags}" nios_app.elf >
            "${objdump}"
    COMMENT "Creating ${objdump}."
    VERBATIM
)
add_custom_target(create-objdump ALL DEPENDS "${objdump}")

# Report space free for stack + heap. Note that the file below is never created
# so the report is always output on build.
set(stack_report_file nios_app.elf.stack_report)
add_custom_command(
    OUTPUT "${stack_report_file}"
    DEPENDS nios_app.elf
    COMMAND niosv-stack-report -p "${ToolchainPrefix}" nios_app.elf
    COMMENT "Reporting memory available for stack + heap in nios_app.elf."
    VERBATIM
)
add_custom_target(niosv-stack-report ALL DEPENDS "${stack_report_file}")

# Generate HEX file(s) from nios_app.elf using elf2hex tool.
# Note : If ECC Full is enabled, width of 39 is set for NiosV TCM. Otherwise, 32.
add_custom_command(
    OUTPUT "intel_onchip_memory.hex"
    DEPENDS nios_app.elf
    COMMAND elf2hex nios_app.elf -o intel_onchip_memory.hex -b 0x00000000 -w 32 -e 0x0007FFFF -r 4
    COMMENT "Creating intel_onchip_memory.hex."
    VERBATIM
)
add_custom_target(create-hex ALL DEPENDS "intel_onchip_memory.hex")
