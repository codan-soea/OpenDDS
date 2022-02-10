# Distributed under the OpenDDS License. See accompanying LICENSE
# file or http://www.opendds.org/license.html for details.

#.rst:
# OpenDDS CMake Config-File Package
# ---------------------------------
#
# Finds OpenDDS MPC-Compiled libraries and imports them as CMake targets.
#
# The following imported targets will be defined if the corresponding libraries
# were compiled with OpenDDS (using MPC):
#
#   OpenDDS::OpenDDS - Convenience target which will loop-in most targets required
#                      for a typical OpenDDS scenario:
#                        * OpenDDS::Dcps
#                        * OpenDDS::Multicast
#                        * OpenDDS::Rtps
#                        * OpenDDS::Rtps_Udp
#                        * OpenDDS::InfoRepoDiscovery
#                        * OpenDDS::Shmem
#                        * OpenDDS::Tcp
#                        * OpenDDS::Udp
#                        * OpenDDS::Security if OpenDDS is built with security
#
#   OpenDDS::<LIB>   - Target for specific library dependency that was generated by
#                      compiling OpenDDS. These will generally be located in the
#                      $DDS_ROOT/lib directory. For example, OpenDDS_Dcps(d).so/.dll
#                      will be imported as the OpenDDS::Dcps CMake target.
#
#   ACE::ACE         - Target for the core ACE library.
#
#   ACE::<LIB>       - Similar to OpenDDS::<LIB> except typically these sit in the
#                      $ACE_ROOT/lib directory with files like ACE_XML_Utils(d).so/.dll
#                      getting imported as ACE::XML_Utils.
#
#   TAO::TAO         - Target for the core TAO library.
#
#   TAO::<LIB>       - Similar to OpenDDS::<LIB> except typically these sit in the
#                      $ACE_ROOT/lib directory (note: not $TAO_ROOT/lib) with files like
#                      TAO_PortableServer(d).so/.dll getting imported as TAO::PortableServer.
#
# In addition to the imported targets above the following macro will be important
# for adding IDL sources to a given target.
#
# OPENDDS_TARGET_SOURCES(target
#   [items...]
#   [<INTERFACE|PUBLIC|PRIVATE> items...]
#   [TAO_IDL_OPTIONS options...]
#   [OPENDDS_IDL_OPTIONS options...])
#
# This macro behaves similarly to target_sources(...) with the following
# differences:
#   1) Items are IDL sources instead of C/C++ sources.
#   2) The scope-qualifier (PUBLIC, PRIVATE, INTERFACE) is not required.
#      When it is omitted, PRIVATE is used by default.
#   3) Command-line options can be supplied to the TAO/OpenDDS IDL compilers
#      using TAO_IDL_OPTIONS and/or OPENDDS_IDL_OPTIONS (if the default be-
#      havior is not suitable).
#
# When IDL sources are supplied, custom commands are generated which will
# be invoked to compile the IDL sources into their component cpp/h files.
#
# NOTE: C/C++ items can also be accepted and added to the target, but passing
# non-IDL sources was deprecated in OpenDDS 3.15.
#
# A custom command will also be added to generate the required IDL export
# header file (*target*_export.h) to add the required export macros. This
# file is then added as a dependency for the supplied target.
#

cmake_minimum_required(VERSION 3.3.2)

if(OpenDDS_FOUND)
  return()
endif()

include(${CMAKE_CURRENT_LIST_DIR}/init.cmake)

set(_dds_bin_hints ${OPENDDS_BIN_DIR})
set(_ace_bin_hints ${ACE_BIN_DIR})
set(_tao_bin_hints ${TAO_BIN_DIR})

find_program(PERL perl)

find_program(OPENDDS_IDL
  NAMES
    opendds_idl
  HINTS
    ${_dds_bin_hints}
)

find_program(TAO_IDL
  NAMES
    tao_idl
  HINTS
    ${_tao_bin_hints}
)

find_program(ACE_GPERF
  NAMES
    ace_gperf
  HINTS
    ${_ace_bin_hints}
)

enable_language(C)
set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

if(OPENDDS_XERCES3)
  find_package(XercesC PATHS "${OPENDDS_XERCES3}" NO_DEFAULT_PATH)
  if (NOT XercesC_FOUND)
    find_package(XercesC)
  endif()
  if (NOT XercesC_FOUND)
    message(FATAL_ERROR "Could not find XercesC")
  endif()
endif()

if(OPENDDS_SECURITY)
  find_package(OpenSSL PATHS "${OPENDDS_OPENSSL}" NO_DEFAULT_PATH)
  if (NOT OpenSSL_FOUND)
    set(OPENSSL_ROOT_DIR "${OPENDDS_OPENSSL}")
    find_package(OpenSSL)
  endif()
  if (NOT OpenSSL_FOUND)
    message(FATAL_ERROR "Could not find OpenSSL")
  endif()
endif()

set(_ace_libs
  ACE_XML_Utils
  ACE
)

set(_tao_libs
  TAO_IORManip
  TAO_ImR_Client
  TAO_Svc_Utils
  TAO_IORTable
  TAO_IDL_FE
  TAO_PortableServer
  TAO_BiDirGIOP
  TAO_PI
  TAO_CodecFactory
  TAO_AnyTypeCode
  TAO
)

set(_opendds_libs
  OpenDDS_Dcps
  OpenDDS_FACE
  OpenDDS_Federator
  OpenDDS_InfoRepoDiscovery
  OpenDDS_InfoRepoLib
  OpenDDS_InfoRepoServ
  OpenDDS_Model
  OpenDDS_monitor
  OpenDDS_Multicast
  OpenDDS_QOS_XML_XSC_Handler
  OpenDDS_Rtps
  OpenDDS_Rtps_Udp
  OpenDDS_Security
  OpenDDS_Shmem
  OpenDDS_Tcp
  OpenDDS_Udp
)

list(APPEND _all_libs ${_opendds_libs} ${_ace_libs} ${_tao_libs})

set(ACE_DEPS
  Threads::Threads
)

macro(_OPENDDS_SYSTEM_LIBRARY name)
  list(APPEND ACE_DEPS ${name})
  string(TOUPPER "${name}" _cap_name)
  if((${ARGC} GREATER 1) AND ("${ARGV1}" STREQUAL "NO_CHECK"))
    set(${_cap_name}_LIBRARY ${name})
  else()
    find_library(${_cap_name}_LIBRARY ${name})
  endif()
  list(APPEND _opendds_required_deps ${_cap_name}_LIBRARY)
endmacro()

if(UNIX)
  _OPENDDS_SYSTEM_LIBRARY(dl)
  if(NOT APPLE)
    _OPENDDS_SYSTEM_LIBRARY(rt)
  endif()
elseif(MSVC)
  # For some reason CMake can't find this in some cases, but we know it should
  # be there, so just link to it without a check.
  _OPENDDS_SYSTEM_LIBRARY(iphlpapi NO_CHECK)
endif()

if(OPENDDS_XERCES3)
  set(ACE_XML_UTILS_DEPS
    ACE::ACE
    XercesC::XercesC
  )
endif()

set(OPENDDS_IDL_DEPS
  TAO::IDL_FE
  ACE::ACE
)

set(OPENDDS_DCPS_DEPS
  TAO::PortableServer
  TAO::BiDirGIOP
  TAO::PI
  TAO::CodecFactory
  TAO::AnyTypeCode
  TAO::TAO
  ACE::ACE
)

set(OPENDDS_FACE_DEPS
  OpenDDS::Dcps
)

set(OPENDDS_FEDERATOR_DEPS
  OpenDDS::InfoRepoLib
)

set(OPENDDS_INFOREPODISCOVERY_DEPS
  OpenDDS::Tcp
  OpenDDS::Dcps
)

set(OPENDDS_INFOREPOLIB_DEPS
  OpenDDS::InfoRepoDiscovery
  TAO::Svc_Utils
  TAO::ImR_Client
  TAO::IORManip
  TAO::IORTable
)

set(OPENDDS_INFOREPOSERV_DEPS
  OpenDDS::Federator
)

set(OPENDDS_MODEL_DEPS
  OpenDDS::Dcps
)

set(OPENDDS_MONITOR_DEPS
  OpenDDS::Dcps
)

set(OPENDDS_MULTICAST_DEPS
  OpenDDS::Dcps
)

set(OPENDDS_QOS_XML_XSC_HANDLER_DEPS
  OpenDDS::Dcps
  ACE::XML_Utils
)

set(OPENDDS_RTPS_DEPS
  OpenDDS::Dcps
)

set(OPENDDS_RTPS_UDP_DEPS
  OpenDDS::Rtps
)

set(OPENDDS_SECURITY_DEPS "")
if(OPENDDS_SECURITY)
  list(APPEND OPENDDS_SECURITY_DEPS
    OpenDDS::Rtps
    ACE::XML_Utils
    OpenSSL::SSL
    OpenSSL::Crypto
  )
endif()

set(OPENDDS_SHMEM_DEPS
  OpenDDS::Dcps
)

set(OPENDDS_TCP_DEPS
  OpenDDS::Dcps
)

set(OPENDDS_UDP_DEPS
  OpenDDS::Dcps
)

set(_dds_lib_hints  ${OPENDDS_LIB_DIR})
set(_ace_lib_hints  ${ACE_LIB_DIR})
set(_tao_lib_hints  ${TAO_LIB_DIR})

macro(opendds_vs_force_static)
  # See https://gitlab.kitware.com/cmake/community/wikis/FAQ#dynamic-replace
  foreach(flag_var
          CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_DEBUG CMAKE_CXX_FLAGS_RELEASE
          CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_RELWITHDEBINFO)
    if(${flag_var} MATCHES "/MD")
      string(REGEX REPLACE "/MD" "/MT" ${flag_var} "${${flag_var}}")
    endif()
  endforeach()
endmacro()

set(_suffix_RELEASE "")
set(_suffix_DEBUG d)

if(MSVC AND OPENDDS_STATIC)
  opendds_vs_force_static()

  set(_suffix_RELEASE s${_suffix_RELEASE})
  set(_suffix_DEBUG s${_suffix_DEBUG})
endif()

foreach(_cfg  RELEASE  DEBUG)
  set(_sfx ${_suffix_${_cfg}})

  foreach(_lib ${_ace_libs})
    string(TOUPPER ${_lib} _LIB_VAR)

    find_library(${_LIB_VAR}_LIBRARY_${_cfg}
      ${_lib}${_sfx}
      HINTS ${_ace_lib_hints}
    )
  endforeach()

  foreach(_lib ${_tao_libs})
    string(TOUPPER ${_lib} _LIB_VAR)

    find_library(${_LIB_VAR}_LIBRARY_${_cfg}
      ${_lib}${_sfx}
      HINTS ${_tao_lib_hints}
    )
  endforeach()

  foreach(_lib ${_opendds_libs})
    string(TOUPPER ${_lib} _LIB_VAR)

    find_library(${_LIB_VAR}_LIBRARY_${_cfg}
      ${_lib}${_sfx}
      HINTS ${_dds_lib_hints}
    )
  endforeach()

endforeach()

include(SelectLibraryConfigurations)

foreach(_lib ${_all_libs})
  string(TOUPPER ${_lib} _LIB_VAR)
  select_library_configurations(${_LIB_VAR})

  # These paths might be symlinks and IMPORTED_RUNTIME_ARTIFACTS seems to not
  # work correctly with symlinks, so resolve them now.
  if(${_LIB_VAR}_LIBRARY)
    get_filename_component(${_LIB_VAR}_LIBRARY "${${_LIB_VAR}_LIBRARY}" REALPATH)
  endif()
  if(${_LIB_VAR}_LIBRARY_DEBUG)
    get_filename_component(${_LIB_VAR}_LIBRARY_DEBUG "${${_LIB_VAR}_LIBRARY_DEBUG}" REALPATH)
  endif()
  if(${_LIB_VAR}_LIBRARY_RELEASE)
    get_filename_component(${_LIB_VAR}_LIBRARY_RELEASE "${${_LIB_VAR}_LIBRARY_RELEASE}" REALPATH)
  endif()
endforeach()

list(APPEND _opendds_required_deps
  OPENDDS_DCPS_LIBRARY
  OPENDDS_IDL
  ACE_LIBRARY
  ACE_GPERF
  TAO_LIBRARY
  TAO_IDL
  PERL
)

foreach(_dep ${_opendds_required_deps})
  if(NOT ${_dep})
    list(APPEND _opendds_missing_deps ${_dep})
  endif()
endforeach()

if(_opendds_missing_deps)
  _OPENDDS_RETURN_ERR("Missing required dependencies ${_opendds_missing_deps}")

else()
  set(OPENDDS_FOUND TRUE)
endif()

macro(_OPENDDS_ADD_TARGET_BINARY  target  path)
  if (NOT TARGET ${target} AND EXISTS "${path}")
    add_executable(${target} IMPORTED)
    set_target_properties(${target}
      PROPERTIES
        IMPORTED_LOCATION "${path}"
    )
  endif()
endmacro()

macro(_OPENDDS_ADD_TARGET_LIB target var_prefix include_dirs)
  set(_debug_lib "${${var_prefix}_LIBRARY_DEBUG}")
  set(_release_lib "${${var_prefix}_LIBRARY_RELEASE}")
  set(_deps "${${var_prefix}_DEPS}")

  if (NOT TARGET ${target} AND
      (EXISTS "${_debug_lib}" OR EXISTS "${_release_lib}"))

    add_library(${target} ${OPENDDS_LIBRARY_TYPE} IMPORTED)
    set_target_properties(${target}
      PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${include_dirs}"
        INTERFACE_LINK_LIBRARIES "${_deps}"
        INTERFACE_COMPILE_DEFINITIONS "${OPENDDS_DCPS_COMPILE_DEFS}"
    )

    if (EXISTS "${_release_lib}")
      set_property(TARGET ${target}
        APPEND PROPERTY
        IMPORTED_CONFIGURATIONS RELEASE
      )
      set_target_properties(${target}
        PROPERTIES
          IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
          IMPORTED_LOCATION_RELEASE "${_release_lib}"
      )
    endif()

    if (EXISTS "${_debug_lib}")
      set_property(TARGET ${target}
        APPEND PROPERTY
        IMPORTED_CONFIGURATIONS DEBUG
      )
      set_target_properties(${target}
        PROPERTIES
          IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
          IMPORTED_LOCATION_DEBUG "${_debug_lib}"
      )
    endif()

    list(APPEND OPENDDS_LIBRARIES ${target})
  endif()
endmacro()

function(opendds_get_library_var_prefix scoped_name var_prefix_var)
  if(scoped_name STREQUAL "ACE::ACE")
    set(var_prefix "ACE")
  elseif(scoped_name STREQUAL "TAO::TAO")
    set(var_prefix "TAO")
  else()
    string(TOUPPER ${scoped_name} var_prefix)
    string(REPLACE "::" "_" var_prefix "${var_prefix}")
  endif()

  set(${var_prefix_var} ${var_prefix} PARENT_SCOPE)
endfunction()

function(opendds_get_library_dependencies deps_var lib)
  set(libs "${lib}")
  list(APPEND libs ${ARGN})
  set(deps "${${deps_var}}")
  foreach(lib ${libs})
    if(NOT ${lib} IN_LIST deps)
      string(REGEX MATCH "^(OpenDDS|ACE|TAO)::" re_out "${lib}")
      if (CMAKE_MATCH_1)
        set(ace_tao_opendds ${CMAKE_MATCH_1})
        opendds_get_library_var_prefix(${lib} var_prefix)
        set(dep_list_name "${var_prefix}_DEPS")
        if(DEFINED ${dep_list_name})
          opendds_get_library_dependencies(deps ${${dep_list_name}})
        endif()
        list(APPEND deps ${lib})
      endif()
    endif()
  endforeach()

  list(REMOVE_DUPLICATES deps)
  set(${deps_var} "${deps}" PARENT_SCOPE)
endfunction()

if(OPENDDS_FOUND)
  include("${CMAKE_CURRENT_LIST_DIR}/options.cmake")

  _OPENDDS_ADD_TARGET_BINARY(opendds_idl "${OPENDDS_IDL}")
  _OPENDDS_ADD_TARGET_BINARY(tao_idl "${TAO_IDL}")
  _OPENDDS_ADD_TARGET_BINARY(ace_gperf "${ACE_GPERF}")
  _OPENDDS_ADD_TARGET_BINARY(perl "${PERL}")

  foreach(_lib ${_ace_libs})
    string(TOUPPER ${_lib} _VAR_PREFIX)

    if("${_lib}" STREQUAL "ACE")
      set(_target "ACE::ACE")
    else()
      string(REPLACE "ACE_" "ACE::" _target ${_lib})
    endif()

    _OPENDDS_ADD_TARGET_LIB(${_target} ${_VAR_PREFIX} "${ACE_INCLUDE_DIR}")
  endforeach()

  foreach(_lib ${_tao_libs})
    string(TOUPPER ${_lib} _VAR_PREFIX)

    if("${_lib}" STREQUAL "TAO")
      set(_target "TAO::TAO")
    else()
      string(REPLACE "TAO_" "TAO::" _target ${_lib})
    endif()

    _OPENDDS_ADD_TARGET_LIB(${_target} ${_VAR_PREFIX} "${TAO_INCLUDE_DIRS}")
  endforeach()

  foreach(_lib ${_opendds_libs})
    string(TOUPPER ${_lib} _VAR_PREFIX)
    string(REPLACE "OpenDDS_" "OpenDDS::" _target ${_lib})

    if(NOT DEFINED "${_VAR_PREFIX}_DEPS")
      message(FATAL_ERROR "OpenDDS lib ${_lib} is missing a dependency list! (${_VAR_PREFIX}_DEPS)")
    endif()

    _OPENDDS_ADD_TARGET_LIB(${_target} ${_VAR_PREFIX} "${OPENDDS_INCLUDE_DIR}")

  endforeach()

  if(NOT TARGET OpenDDS::OpenDDS)
    add_library(OpenDDS::OpenDDS INTERFACE IMPORTED)

    set(_opendds_core_libs
      OpenDDS::Dcps
      OpenDDS::Multicast
      OpenDDS::Rtps
      OpenDDS::Rtps_Udp
      OpenDDS::InfoRepoDiscovery
      OpenDDS::Shmem
      OpenDDS::Tcp
      OpenDDS::Udp)

    if(OPENDDS_SECURITY)
      list(APPEND _opendds_core_libs OpenDDS::Security)
    endif()

    set_target_properties(OpenDDS::OpenDDS
      PROPERTIES
        INTERFACE_LINK_LIBRARIES "${_opendds_core_libs}")

  endif()

  include(${CMAKE_CURRENT_LIST_DIR}/api_macros.cmake)

  if(OPENDDS_CMAKE_VERBOSE)
    message(STATUS "Loaded OpenDDS targets:")
    foreach(_target ${OPENDDS_LIBRARIES})
      get_target_property(_target_location ${_target} LOCATION)
      message(STATUS "${_target} -> ${_target_location}")
    endforeach()
  endif()
endif()
