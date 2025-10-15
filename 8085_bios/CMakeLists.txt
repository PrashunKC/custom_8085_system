cmake_minimum_required(VERSION 3.10)
project(8085_BIOS_System)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

# Find Qt5
find_package(Qt5 COMPONENTS Widgets REQUIRED)

# Build the BIOS binary first
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/build/bios.bin
    COMMAND mkdir -p ${CMAKE_CURRENT_SOURCE_DIR}/build
    COMMAND echo "Building BIOS requires 'asl' assembler - skipping if not available"
    COMMAND which asl > /dev/null 2>&1 && make -C ${CMAKE_CURRENT_SOURCE_DIR} || echo "BIOS build skipped (asl not found)"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Building BIOS ROM"
    VERBATIM
)

add_custom_target(bios_rom ALL
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/build/bios.bin
)

# Emulator executable
add_executable(8085_bios_system
    bios_gui.cpp
    cpu8085.cpp
)

target_link_libraries(8085_bios_system Qt5::Widgets)

add_dependencies(8085_bios_system bios_rom)

# Copy BIOS to build directory for runtime
add_custom_command(TARGET 8085_bios_system POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_CURRENT_SOURCE_DIR}/build/bios.bin
        ${CMAKE_CURRENT_BINARY_DIR}/build/bios.bin
)
