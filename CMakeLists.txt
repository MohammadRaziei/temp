cmake_minimum_required(VERSION 3.21)
project(${SKBUILD_PROJECT_NAME})
# Set Python module name (should match the .pyx filename)
string(REPLACE "-" "_" MODULE_NAME ${SKBUILD_PROJECT_NAME})

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
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=native -mtune=native -fomit-frame-pointer -fno-stack-protector")
endif()

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
cython_transpile(src/doxybook2_python.pyx LANGUAGE CXX OUTPUT_VARIABLE doxybook2_cpp_file)

# Create Python module
python_add_library(${doxybook2_python} MODULE "${doxybook2_cpp_file}" WITH_SOABI)

set_target_properties(${MODULE_NAME} PROPERTIES
    INSTALL_RPATH "$ORIGIN/cpp/lib"
    BUILD_RPATH "$ORIGIN/cpp/lib"
    SKIP_RPATH FALSE
    INSTALL_RPATH_USE_LINK_PATH TRUE
)


include(ExternalProject)
# Set whisper.cpp install directory
set(WHISPER_CPP_INSTALL_DIR ${CMAKE_BINARY_DIR}/whisper_cpp/install)

# Define external project for whisper.cpp
ExternalProject_Add(install_whisper_cpp
    SOURCE_DIR ${CMAKE_SOURCE_DIR}/src/third_party/whisper.cpp
    BINARY_DIR ${CMAKE_BINARY_DIR}/whisper_cpp/build
    INSTALL_DIR ${WHISPER_CPP_INSTALL_DIR}

    CMAKE_ARGS
        -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
        -DCMAKE_INSTALL_LIBDIR=lib         
        -DBUILD_SHARED_LIBS=ON
        -DWHISPER_BUILD_TESTS=OFF
        -DWHISPER_BUILD_EXAMPLES=OFF
        -DWHISPER_BUILD_SERVER=OFF

    BUILD_ALWAYS OFF
    UPDATE_DISCONNECTED TRUE
    STEP_TARGETS build install
    LOG_CONFIGURE OFF
    LOG_BUILD OFF
    LOG_INSTALL OFF
    COMMENT "Building and installing whisper.cpp"
)
# add_custom_target(install_whisper_cpp
#     COMMAND ${CMAKE_COMMAND} -B ${CMAKE_BINARY_DIR}/whisper_cpp
#         -DCMAKE_INSTALL_PREFIX=${WHISPER_CPP_INSTALL_DIR}
#         -DBUILD_SHARED_LIBS=ON 
#         -DWHISPER_BUILD_TESTS=OFF 
#         -DWHISPER_BUILD_EXAMPLES=OFF 
#         -DWHISPER_BUILD_SERVER=OFF 
#     COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR}/whisper_cpp -j4 --target install
#     WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/third_party/whisper.cpp
#     COMMENT "Installing whisper.cpp to ${WHISPER_CPP_INSTALL_DIR}"
# )

# Add dependency so whisper.cpp installation happens during build
add_dependencies(${MODULE_NAME} install_whisper_cpp)





# Create interface library for whisper.cpp
add_library(whisper_interface INTERFACE)

target_include_directories(whisper_interface INTERFACE
    ${WHISPER_CPP_INSTALL_DIR}/include
)

target_link_directories(whisper_interface INTERFACE
    ${WHISPER_CPP_INSTALL_DIR}/lib
)

target_link_libraries(whisper_interface INTERFACE
    ggml-base ggml-cpu ggml whisper
)

# Link whisper interface to the main module
target_link_libraries(${MODULE_NAME} PRIVATE whisper_interface)

# Install the Python module
install(TARGETS ${MODULE_NAME}
    DESTINATION ${SKBUILD_PROJECT_NAME}/whisper
)

# Copy whisper.cpp installation to Python module directory
install(DIRECTORY ${WHISPER_CPP_INSTALL_DIR}/
    DESTINATION ${SKBUILD_PROJECT_NAME}/whisper/cpp
)
