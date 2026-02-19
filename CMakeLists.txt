cmake_minimum_required(VERSION 3.15)
project(tclpy VERSION 0.4 LANGUAGES C)

set(PACKAGE_VERSION "${PROJECT_VERSION}")

include(GNUInstallDirs)
include(CheckLibraryExists)

# --- Options ---
option(USE_TCL_STUBS "Link against Tcl stubs library" ON)

# --- Tcl discovery via tclConfig.sh ---
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
find_package(TclConfig REQUIRED)

# Parse include flags from TCL_INCLUDE_SPEC (e.g. "-I/usr/include/tcl8.6")
separate_arguments(_tcl_inc_flags UNIX_COMMAND "${TCL_INCLUDE_SPEC}")
set(_tcl_inc_dirs "")
foreach(_flag IN LISTS _tcl_inc_flags)
  if(_flag MATCHES "^-I(.*)")
    list(APPEND _tcl_inc_dirs "${CMAKE_MATCH_1}")
  endif()
endforeach()

# Parse lib flags
if(USE_TCL_STUBS)
  set(_tcl_link_spec "${TCL_STUB_LIB_SPEC}")
else()
  set(_tcl_link_spec "${TCL_LIB_SPEC}")
endif()
separate_arguments(_tcl_link_flags UNIX_COMMAND "${_tcl_link_spec}")

# --- Python discovery ---
find_package(Python3 REQUIRED COMPONENTS Interpreter Development)

execute_process(
  COMMAND "${Python3_EXECUTABLE}" -c
    "import sysconfig; print(sysconfig.get_config_var('LDLIBRARY'))"
  OUTPUT_VARIABLE PY_LIBFILE
  OUTPUT_STRIP_TRAILING_WHITESPACE
  RESULT_VARIABLE _py_rc
)
if(NOT _py_rc EQUAL 0 OR PY_LIBFILE STREQUAL "")
  message(FATAL_ERROR "Failed to determine Python LDLIBRARY")
endif()
message(STATUS "Python LDLIBRARY: ${PY_LIBFILE}")

# --- Library target ---
add_library(tclpy MODULE generic/tclpy.c)

# Output naming: libtclpy0.4.so (Unix) / tclpy0.4.dll (Windows)
if(WIN32)
  set(TCLPY_LIBRARY_NAME "tclpy${PACKAGE_VERSION}${CMAKE_SHARED_MODULE_SUFFIX}")
  set_target_properties(tclpy PROPERTIES
    OUTPUT_NAME "tclpy${PACKAGE_VERSION}"
    PREFIX ""
  )
else()
  set(TCLPY_LIBRARY_NAME "libtclpy${PACKAGE_VERSION}${CMAKE_SHARED_MODULE_SUFFIX}")
  set_target_properties(tclpy PROPERTIES
    OUTPUT_NAME "tclpy${PACKAGE_VERSION}"
    PREFIX "lib"
  )
endif()

set_target_properties(tclpy PROPERTIES
  C_STANDARD 99
)

# Compile definitions
target_compile_definitions(tclpy PRIVATE
  PACKAGE_VERSION="${PACKAGE_VERSION}"
  PY_LIBFILE="${PY_LIBFILE}"
)

if(USE_TCL_STUBS)
  target_compile_definitions(tclpy PRIVATE USE_TCL_STUBS)
endif()

# Include directories
target_include_directories(tclpy PRIVATE
  ${_tcl_inc_dirs}
  ${Python3_INCLUDE_DIRS}
)

# Link libraries
target_link_libraries(tclpy PRIVATE
  ${_tcl_link_flags}
  ${Python3_LIBRARIES}
)

# Compiler warnings (GCC/Clang only)
if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
  target_compile_options(tclpy PRIVATE
    -fstack-protector
    -Wformat
    -Werror=format-security
    -fno-strict-overflow
    -Wall -Wextra
    -Wstrict-aliasing -Wstrict-overflow -Wstrict-prototypes
    -Wno-unused-parameter
    -O2
  )
endif()

# Link dl on platforms that need it
if(NOT WIN32)
  check_library_exists(dl dlopen "" HAVE_LIBDL)
  if(HAVE_LIBDL)
    target_link_libraries(tclpy PRIVATE dl)
  endif()
endif()

# --- pkgIndex.tcl ---
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/pkgIndex.tcl.in"
  "${CMAKE_CURRENT_BINARY_DIR}/pkgIndex.tcl"
  @ONLY
)

# --- Install ---
set(_install_dir "${CMAKE_INSTALL_LIBDIR}/tclpy${PACKAGE_VERSION}")

install(TARGETS tclpy
  LIBRARY DESTINATION "${_install_dir}"
  RUNTIME DESTINATION "${_install_dir}"
)

install(FILES "${CMAKE_CURRENT_BINARY_DIR}/pkgIndex.tcl"
  DESTINATION "${_install_dir}"
)

# --- Tests ---
enable_testing()

# Find tclsh for running tests
find_program(TCLSH NAMES tclsh9.0 tclsh8.6 tclsh)
if(TCLSH)
  add_test(
    NAME tclpy_test
    COMMAND "${TCLSH}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/tclpy.test"
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
  )
  set_tests_properties(tclpy_test PROPERTIES
    ENVIRONMENT "TCLLIBPATH=${CMAKE_CURRENT_BINARY_DIR}"
  )
endif()
