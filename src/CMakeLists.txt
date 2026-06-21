cmake_minimum_required(VERSION 3.10)
project(nitro_type_coverage_library VERSION 0.0.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(NITRO_NATIVE "${CMAKE_CURRENT_SOURCE_DIR}/native")
# NITRO_LINK_SPEC_CHECKSUM 5343065fca6d2b3e
set(GENERATED_CPP "${CMAKE_CURRENT_SOURCE_DIR}/../lib/src/generated/cpp")

add_library(nitro_type_coverage SHARED
  "nitro_type_coverage.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../lib/src/generated/cpp/nitro_type_coverage.bridge.g.cpp"
  "dart_api_dl.c"
)

target_include_directories(nitro_type_coverage PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${GENERATED_CPP}"
  "${NITRO_NATIVE}"
)

target_compile_definitions(nitro_type_coverage PUBLIC DART_SHARED_LIB)

if(ANDROID)
  target_link_libraries(nitro_type_coverage PRIVATE android log)
  target_link_options(nitro_type_coverage PRIVATE "-Wl,-z,max-page-size=16384")
endif()
