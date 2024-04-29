cmake_minimum_required(VERSION 3.3...3.27)
project(opendds_stock CXX)
enable_testing()

find_package(OpenDDS REQUIRED)
include(opendds_testing)

# Make sure the MPC-generated headers are gone so the CMake build will use the
# right ones. This is not needed in a real project.
# file(GLOB headers "*.h")
# list(LENGTH headers header_count)
# if(header_count GREATER 0)
#   file(REMOVE ${headers})
# endif()

# IDL TypeSupport Library
add_library(stockquoter_idl)
include_directories(
    /opt/OpenDDS/
)
opendds_target_sources(stockquoter_idl PUBLIC "StockQuoter.idl")
target_link_libraries(stockquoter_idl PUBLIC OpenDDS::Dcps)


set(opendds_libs
  OpenDDS::Dcps # Core OpenDDS Library
  OpenDDS::InfoRepoDiscovery OpenDDS::Tcp # For run_test.pl
  OpenDDS::Rtps OpenDDS::Rtps_Udp # For run_test.pl --rtps
  OpenDDS::FACE
  stockquoter_idl
)

# Publisher
add_executable(publisher
  Publisher.cpp
  StockQuoter_TS.cpp
)
target_link_libraries(publisher ${opendds_libs})

# Subscriber
add_executable(subscriber
  Subscriber.cpp
  StockQuoter_TS.cpp
)
target_link_libraries(subscriber ${opendds_libs})
