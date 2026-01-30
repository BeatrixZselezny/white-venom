cmake_minimum_required(VERSION 3.10)
project(WhiteVenom)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- ÚTVONALAK ---
set(SKELETON_DIR "${CMAKE_SOURCE_DIR}/debian_skeleton")
set(INCLUDE_DIR "${SKELETON_DIR}/include")
set(SRC_DIR "${SKELETON_DIR}/src")

# --- OKOS INCLUDE RENDSZER ---
# Itt adjuk meg a fordítónak az összes lehetséges helyet, ahol header lehet
include_directories(${INCLUDE_DIR})
include_directories(${INCLUDE_DIR}/core)
include_directories(${INCLUDE_DIR}/modules)
include_directories(${INCLUDE_DIR}/utils)
include_directories(${INCLUDE_DIR}/telemetry)

# --- FORRÁSOK ---
file(GLOB_RECURSE SKELETON_SOURCES "${SRC_DIR}/*.cpp")

# --- FORDÍTÁS ---
add_executable(white-venom ${SKELETON_SOURCES})

# --- DEPENDENCIES ---
set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
find_package(Threads REQUIRED)
target_link_libraries(white-venom Threads::Threads)

if(UNIX)
    target_link_libraries(white-venom dl)
endif()
