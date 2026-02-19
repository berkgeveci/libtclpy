# Print the directory containing tclConfig.sh
# Used by FindTclConfig.cmake to auto-detect Tcl installation
puts [::tcl::pkgconfig get libdir,runtime]
