cmake_minimum_required(VERSION 3.16)
project(extrae_demo LANGUAGES CXX)

find_package(MPI REQUIRED)

if(NOT DEFINED ENV{EXTRAE_HOME})
    message(FATAL_ERROR "EXTRAE_HOME environment variable is not set. Run 'spack load extrae@4.2.3 ^openmpi' or export it manually before configuring.")
endif()

set(EXTRAE_HOME $ENV{EXTRAE_HOME})
set(EXTRAE_INCLUDE_DIR ${EXTRAE_HOME}/include)
set(EXTRAE_LIBRARY_DIR ${EXTRAE_HOME}/lib)

add_executable(extrae_demo src/main.cpp)

set_target_properties(extrae_demo PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)

target_include_directories(extrae_demo PRIVATE ${MPI_CXX_INCLUDE_PATH} ${EXTRAE_INCLUDE_DIR})

target_link_libraries(extrae_demo PRIVATE MPI::MPI_CXX ${EXTRAE_LIBRARY_DIR}/libmpitrace.so)

configure_file(config/extrae.xml.in ${CMAKE_BINARY_DIR}/extrae.xml @ONLY)

install(TARGETS extrae_demo RUNTIME DESTINATION bin)
