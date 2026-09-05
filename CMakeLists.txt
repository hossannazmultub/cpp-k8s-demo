cmake_minimum_required(VERSION 3.20)
project(cpp_k8s_demo VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Source executable
add_executable(cpp_app src/main.cpp)

# Install target location
install(TARGETS cpp_app DESTINATION bin)