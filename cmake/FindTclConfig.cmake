# FindTclConfig.cmake
#
# Locates tclConfig.sh and extracts Tcl build configuration.
#
# User-settable variables:
#   TCLCONFIG - path to tclConfig.sh (override auto-detection)
#
# Exported variables:
#   TclConfig_FOUND
#   TCL_VERSION
#   TCL_INCLUDE_SPEC
#   TCL_LIB_SPEC
#   TCL_STUB_LIB_SPEC

# If not provided, try to find tclConfig.sh automatically
if(NOT TCLCONFIG)
  # Try to find tclsh and derive the path
  find_program(_TCLSH NAMES tclsh9.0 tclsh8.6 tclsh)
  if(_TCLSH)
    execute_process(
      COMMAND "${_TCLSH}" "${CMAKE_CURRENT_LIST_DIR}/tcl_config_path.tcl"
      OUTPUT_VARIABLE _TCL_CONFIG_DIR
      OUTPUT_STRIP_TRAILING_WHITESPACE
      RESULT_VARIABLE _TCLSH_RESULT
    )
    if(_TCLSH_RESULT EQUAL 0 AND EXISTS "${_TCL_CONFIG_DIR}/tclConfig.sh")
      set(TCLCONFIG "${_TCL_CONFIG_DIR}/tclConfig.sh")
    endif()
  endif()

  # Fallback: search common locations
  if(NOT TCLCONFIG)
    find_file(TCLCONFIG tclConfig.sh
      PATHS
        /usr/lib/tcl8.6
        /usr/lib64
        /usr/lib
        /usr/local/lib
        /opt/homebrew/lib
      NO_DEFAULT_PATH
    )
  endif()
endif()

if(NOT TCLCONFIG OR NOT EXISTS "${TCLCONFIG}")
  set(TclConfig_FOUND FALSE)
  if(TclConfig_FIND_REQUIRED)
    message(FATAL_ERROR
      "Could not find tclConfig.sh. Set -DTCLCONFIG=/path/to/tclConfig.sh")
  endif()
  return()
endif()

message(STATUS "Using tclConfig.sh: ${TCLCONFIG}")

# Helper: source tclConfig.sh and extract a variable
function(_tcl_config_var VAR_NAME OUT_VAR)
  execute_process(
    COMMAND bash -c "source \"${TCLCONFIG}\" && echo \"\${${VAR_NAME}}\""
    OUTPUT_VARIABLE _val
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE _rc
  )
  if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "Failed to read ${VAR_NAME} from ${TCLCONFIG}")
  endif()
  set(${OUT_VAR} "${_val}" PARENT_SCOPE)
endfunction()

_tcl_config_var(TCL_VERSION          TCL_VERSION)
_tcl_config_var(TCL_INCLUDE_SPEC     TCL_INCLUDE_SPEC)
_tcl_config_var(TCL_LIB_SPEC        TCL_LIB_SPEC)
_tcl_config_var(TCL_STUB_LIB_SPEC   TCL_STUB_LIB_SPEC)

message(STATUS "Tcl version: ${TCL_VERSION}")
message(STATUS "Tcl include: ${TCL_INCLUDE_SPEC}")
message(STATUS "Tcl lib:     ${TCL_LIB_SPEC}")
message(STATUS "Tcl stubs:   ${TCL_STUB_LIB_SPEC}")

set(TclConfig_FOUND TRUE)
