cmake_minimum_required(VERSION 3.10)
project(WhiteVenom)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- ÚTVONALAK ---
set(SKELETON_DIR "${CMAKE_SOURCE_DIR}/debian_skeleton")
set(INCLUDE_DIR "${SKELETON_DIR}/include")
set(SRC_DIR "${SKELETON_DIR}/src")

# --- HEADEREK ---
# Itt vannak a .hpp fájljaid (core, modules, stb.)
include_directories(${INCLUDE_DIR})

# --- FORRÁSOK ---
# Begyűjtjük az összes .cpp-t a skeletonból (a main.cpp-t IS!)
file(GLOB_RECURSE SKELETON_SOURCES "${SRC_DIR}/*.cpp")

# --- FORDÍTÁS ---
# Az eredeti kódodból építjük a binárist
add_executable(white-venom ${SKELETON_SOURCES})

# --- DEPENDENCIES ---
set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
set(THREADS_PREFER_PTHREAD_FLAG TRUE)
find_package(Threads REQUIRED)
target_link_libraries(white-venom Threads::Threads)

# Ha kell dl (dynamic loader) Linuxon
if(UNIX)
    target_link_libraries(white-venom dl)
endif()
