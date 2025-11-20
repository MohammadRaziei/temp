cmake_minimum_required(VERSION 3.21)
project(libcurl)

# Set C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Optimize for performance
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -DNDEBUG")
else()
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")
endif()

# Additional optimization flags for GCC/Clang
# if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
#     set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=native -mtune=native -fomit-frame-pointer -fno-stack-protector")
# endif()

# Set build type to Release for better performance
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()


list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

# Find Python and Cython
find_package(Python REQUIRED COMPONENTS Interpreter Development.Module)
find_package(Cython MODULE REQUIRED VERSION 3.0)
include(UseCython)

# Configure Cython module
cython_transpile(src/libcurl/cylibcurl.pyx LANGUAGE CXX OUTPUT_VARIABLE cylibcurl_file)

# Create Python module
python_add_library(cylibcurl MODULE "${cylibcurl_file}" WITH_SOABI)

set_target_properties(cylibcurl PROPERTIES
    INSTALL_RPATH "$ORIGIN/curl/lib"
    BUILD_RPATH "$ORIGIN/curl/lib"
    SKIP_RPATH FALSE
    INSTALL_RPATH_USE_LINK_PATH TRUE
)

include(ExternalProject)
# Set curl install and build directories



# -------------------------------------------------------
# Layout
# -------------------------------------------------------
set(ROOT_DIR       "${CMAKE_SOURCE_DIR}/src/third_party")
set(BUILD_DIR      "${CMAKE_BINARY_DIR}/extern")          # use standard build directory
set(INSTALL_DIR    "${BUILD_DIR}/install")                # where everything installs

file(MAKE_DIRECTORY "${BUILD_DIR}")
file(MAKE_DIRECTORY "${INSTALL_DIR}/lib")

set(SUB_CMAKE_COMMON_ARGS
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}
  -DBUILD_SHARED_LIBS=ON
  -DCMAKE_VERBOSE_MAKEFILE=ON
  # -DCMAKE_BUILD_RPATH=${INSTALL_DIR}/lib
  # -DCMAKE_INSTALL_RPATH=${INSTALL_DIR}/lib
)

# -------------------------------------------------------
# zlib
# -------------------------------------------------------
ExternalProject_Add(zlib_ep
  SOURCE_DIR        ${ROOT_DIR}/zlib
  BINARY_DIR        ${BUILD_DIR}/zlib
  INSTALL_DIR       ${INSTALL_DIR}
  CMAKE_ARGS        ${SUB_CMAKE_COMMON_ARGS}
  # BUILD_BYPRODUCTS  ${INSTALL_DIR}/lib/libz${CMAKE_SHARED_LIBRARY_SUFFIX}
  LOG_CONFIGURE     ON
  LOG_BUILD         ON
  LOG_INSTALL       ON
)

# -------------------------------------------------------
# OpenSSL
# -------------------------------------------------------
ExternalProject_Add(openssl_ep
  DEPENDS           zlib_ep
  SOURCE_DIR        ${ROOT_DIR}/openssl
  BINARY_DIR        ${BUILD_DIR}/openssl
  INSTALL_DIR       ${INSTALL_DIR}

  CONFIGURE_COMMAND ${ROOT_DIR}/openssl/Configure
                      --prefix=${INSTALL_DIR}
                      --openssldir=${INSTALL_DIR}/ssl
                      static

  BUILD_COMMAND     make -j8
  INSTALL_COMMAND   make install_sw

  LOG_CONFIGURE     ON
  LOG_BUILD         ON
  LOG_INSTALL       ON
)


# -------------------------------------------------------
# curl
# -------------------------------------------------------
 
ExternalProject_Add(curl_ep
  DEPENDS           zlib_ep openssl_ep
  SOURCE_DIR        ${ROOT_DIR}/curl
  BINARY_DIR        ${BUILD_DIR}/curl
  INSTALL_DIR       ${INSTALL_DIR}
  CMAKE_ARGS
    ${SUB_CMAKE_COMMON_ARGS}
    -DBUILD_CURL_EXE=ON
    -DBUILD_TESTING=OFF
    -DUSE_MANUAL=OFF
    -DCURL_ZLIB=ON
    -DCURL_USE_OPENSSL=ON
    -DCURL_USE_LIBPSL=OFF

    # Tell curl where our deps are
    -DZLIB_INCLUDE_DIR=${INSTALL_DIR}/include
    -DZLIB_LIBRARY=${INSTALL_DIR}/lib/libz${CMAKE_SHARED_LIBRARY_SUFFIX}
    -DOPENSSL_ROOT_DIR=${INSTALL_DIR}
    -DOPENSSL_USE_STATIC_LIBS=OFF

    # Add RPATH settings
    -DCMAKE_BUILD_RPATH=$ORIGIN/../lib
    -DCMAKE_INSTALL_RPATH=$ORIGIN/../lib
    -DCMAKE_SKIP_BUILD_RPATH=FALSE
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=FALSE
    -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE

  BUILD_BYPRODUCTS  ${INSTALL_DIR}/bin/curl
  LOG_CONFIGURE     ON
  LOG_BUILD         ON
  LOG_INSTALL       ON
)



# Add dependency so curl installation happens during build
add_dependencies(libcurl curl_ep)

# Create interface library for curl
add_library(curl_interface INTERFACE)

target_include_directories(curl_interface INTERFACE
    ${INSTALL_DIR}/include
)

target_link_directories(curl_interface INTERFACE
    ${INSTALL_DIR}/lib
)

target_link_libraries(curl_interface INTERFACE
    curl
)

# Link curl interface to the main module
target_link_libraries(libcurl PRIVATE curl_interface)

# Install the Python module
install(DIRECTORY ${CMAKE_SOURCE_DIR}/src/libcurl
    DESTINATION .
    FILES_MATCHING 
    PATTERN 
    "*.py"
)

install(TARGETS libcurl
    DESTINATION libcurl
)

# Copy curl installation to Python module directory
install(DIRECTORY ${INSTALL_DIR}/
    DESTINATION libcurl/build
)
