cmake_minimum_required(VERSION 3.10)
project(WhiteVenom)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- A TE EREDETI STRUKTÚRÁD ---
set(SKELETON_DIR "${CMAKE_SOURCE_DIR}/debian_skeleton")
set(INCLUDE_DIR "${SKELETON_DIR}/include")
set(SRC_DIR "${SKELETON_DIR}/src")

# --- HEADEREK ---
include_directories(${INCLUDE_DIR})

# --- FORRÁSOK ---
# Most már mindent beveszünk, a belső main.cpp-t is!
# Mert ez a valódi belépési pont.
file(GLOB_RECURSE SKELETON_SOURCES "${SRC_DIR}/*.cpp")

# --- FORDÍTÁS ---
add_executable(white-venom ${SKELETON_SOURCES})

# --- DEPENDENCIES ---
set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
set(THREADS_PREFER_PTHREAD_FLAG TRUE)
find_package(Threads REQUIRED)
target_link_libraries(white-venom Threads::Threads)

if(UNIX)
    target_link_libraries(white-venom dl)
endif()
