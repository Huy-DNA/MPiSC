cmake_minimum_required(VERSION 3.12)
set(CMAKE_CXX_COMPILER mpicxx)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

project(MPiSC VERSION 1.0)

find_package(MPI REQUIRED REQUIRED)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}
                    ${CMAKE_CURRENT_SOURCE_DIR}/benchmarks ${MPI_INCLUDE_PATH})

add_executable(out ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp)
target_link_libraries(out ${MPI_CXX_LIBRARIES})

message(STATUS "MPI libraries: ${MPI_CXX_LIBRARIES}")
message(STATUS "MPI include path: ${MPI_INCLUDE_PATH}")
