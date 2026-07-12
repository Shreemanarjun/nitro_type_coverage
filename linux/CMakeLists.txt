set(NITRO_NATIVE "${CMAKE_CURRENT_SOURCE_DIR}/../src/native")

# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "nitro_type_coverage")
project(${PROJECT_NAME} LANGUAGES CXX)

# Compile Linux's own HybridNitroTypeCoverage.cpp instead of sharing the one
# Windows uses — src/CMakeLists.txt still provides the generated bridge code
# (bridge.g.cpp, dart_api_dl.c) via add_subdirectory below; only the
# hand-maintained impl file is Linux-specific.
set(NITRO_IMPL_SRC_nitro_type_coverage "${CMAKE_CURRENT_SOURCE_DIR}/src/HybridNitroTypeCoverage.cpp")

# Invoke the build for native code shared with the other target platforms.
# This can be changed to accommodate different builds.
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(nitro_type_coverage_bundled_libraries
  # Defined in ../src/CMakeLists.txt.
  # This can be changed to accommodate different builds.
  $<TARGET_FILE:nitro_type_coverage>
  PARENT_SCOPE
)

