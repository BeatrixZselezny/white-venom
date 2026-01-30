cmake_minimum_required(VERSION 3.10)
project(WhiteVenom)

# Modern C++ szabvány (RxCpp miatt kell a 17)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# -------------------------------------------------------------
# ÚTVONALAK DEFINIÁLÁSA
# -------------------------------------------------------------
set(SKELETON_DIR "${CMAKE_SOURCE_DIR}/debian_skeleton")
set(INCLUDE_DIR "${SKELETON_DIR}/include")
set(SRC_DIR "${SKELETON_DIR}/src")

# Debug infó kiírása (hogy lássuk a logban, mit csinál)
message(STATUS "White-Venom Skeleton Dir: ${SKELETON_DIR}")

# -------------------------------------------------------------
# FEJLÉCEK (HEADERS)
# -------------------------------------------------------------
# Ez teszi lehetővé, hogy a kódban így hivatkozz: #include "core/VenomBus.hpp"
# És megtalálja az rxcpp-t is.
include_directories(${INCLUDE_DIR})

# -------------------------------------------------------------
# FORRÁSFÁJLOK (SOURCES)
# -------------------------------------------------------------
# 1. Begyűjtjük az összes .cpp fájlt a skeletonból
file(GLOB_RECURSE SKELETON_SOURCES "${SRC_DIR}/*.cpp")

# 2. !!! KRITIKUS LÉPÉS !!!
# Kivesszük a listából a belső main.cpp-t, mert a gyökeret használjuk!
# Ha ez benne maradna, "multiple definition of main" hibát kapnánk.
list(REMOVE_ITEM SKELETON_SOURCES "${SRC_DIR}/main.cpp")

# 3. Hozzáadjuk a gyökér main.cpp-t (Az Új Vezérlőt)
set(ALL_SOURCES 
    main.cpp 
    ${SKELETON_SOURCES}
)

# -------------------------------------------------------------
# FORDÍTÁS ÉS LINKELÉS
# -------------------------------------------------------------
add_executable(white-venom ${ALL_SOURCES})

# Szálkezelés (Threading) támogatás - ez kell a Schedulerhez
set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
set(THREADS_PREFER_PTHREAD_FLAG TRUE)
find_package(Threads REQUIRED)

target_link_libraries(white-venom Threads::Threads)

# Opcionális: Ha Linuxon vagyunk, a 'dl' lib kellhet dinamikus betöltéshez
if(UNIX)
    target_link_libraries(white-venom dl)
endif()
