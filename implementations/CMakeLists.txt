cmake_minimum_required(VERSION 3.12)
set(CMAKE_CXX_COMPILER mpicxx)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

project(MPiSC VERSION 1.0)

find_package(MPI REQUIRED REQUIRED)

include(ExternalProject)
ExternalProject_Add(
  caliper_ext
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/lib/benches/Caliper
  CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/Caliper -DWITH_MPI=true
             -DCMAKE_BUILD_TYPE=Release)

include_directories(
  ${MPI_INCLUDE_PATH}
  ${CMAKE_BINARY_DIR}/Caliper/include
  ${CMAKE_BINARY_DIR}/lib/bclx/bclx
  ${CMAKE_BINARY_DIR}/lib/bclx/bcl
)

add_executable(out ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp)
add_dependencies(out caliper_ext)
target_link_libraries(out ${MPI_CXX_LIBRARIES}
                      ${CMAKE_BINARY_DIR}/Caliper/lib64/libcaliper.so)

message(STATUS "MPI libraries: ${MPI_CXX_LIBRARIES}")
message(STATUS "MPI include path: ${MPI_INCLUDE_PATH}")
