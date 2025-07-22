# Version.cmake - Generate version header with Git information and build flags
#
# This module provides functions to generate a version header file with:
# - Project version information
# - Git commit hash, branch, and tag information
# - Build timestamp and compiler information
# - Build flags and configuration
#
# Usage:
#   include(Version)
#   generate_version_header()
#

# Function to get Git information
function(get_git_info)
    # Find Git executable
    find_package(Git QUIET)
    
    if(NOT GIT_FOUND)
        message(WARNING "Git not found, version information will be incomplete")
        set(GIT_COMMIT_HASH "unknown" PARENT_SCOPE)
        set(GIT_BRANCH "unknown" PARENT_SCOPE)
        set(GIT_TAG "unknown" PARENT_SCOPE)
        set(GIT_DIRTY "FALSE" PARENT_SCOPE)
        return()
    endif()
    
    # Get current commit hash (short)
    execute_process(
        COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_COMMIT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    
    # Get current branch name
    execute_process(
        COMMAND ${GIT_EXECUTABLE} rev-parse --abbrev-ref HEAD
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_BRANCH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    
    # Get current tag (if any)
    execute_process(
        COMMAND ${GIT_EXECUTABLE} describe --tags --exact-match
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_TAG
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    
    # Check if working directory is dirty
    execute_process(
        COMMAND ${GIT_EXECUTABLE} diff-index --quiet HEAD --
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        RESULT_VARIABLE GIT_DIRTY_RESULT
        ERROR_QUIET
    )
    
    # Set default values if commands failed
    if(NOT GIT_COMMIT_HASH)
        set(GIT_COMMIT_HASH "unknown")
    endif()
    
    if(NOT GIT_BRANCH)
        set(GIT_BRANCH "unknown")
    endif()
    
    if(NOT GIT_TAG)
        set(GIT_TAG "")
    endif()
    
    if(GIT_DIRTY_RESULT EQUAL 0)
        set(GIT_DIRTY "FALSE")
    else()
        set(GIT_DIRTY "TRUE")
    endif()
    
    # Set parent scope variables
    set(GIT_COMMIT_HASH ${GIT_COMMIT_HASH} PARENT_SCOPE)
    set(GIT_BRANCH ${GIT_BRANCH} PARENT_SCOPE)
    set(GIT_TAG ${GIT_TAG} PARENT_SCOPE)
    set(GIT_DIRTY ${GIT_DIRTY} PARENT_SCOPE)
    
    message(STATUS "Git info: ${GIT_COMMIT_HASH} on ${GIT_BRANCH}${GIT_TAG}")
endfunction()

# Function to get build timestamp
function(get_build_timestamp)
    string(TIMESTAMP BUILD_TIMESTAMP "%Y-%m-%d %H:%M:%S UTC" UTC)
    set(BUILD_TIMESTAMP ${BUILD_TIMESTAMP} PARENT_SCOPE)
endfunction()

# Function to format compiler flags for display
function(format_flags FLAGS_VAR)
    string(REPLACE ";" " " FORMATTED_FLAGS "${${FLAGS_VAR}}")
    set(${FLAGS_VAR} "${FORMATTED_FLAGS}" PARENT_SCOPE)
endfunction()

# Main function to generate version header
function(generate_version_header)
    # Parse optional arguments
    set(options "")
    set(oneValueArgs INPUT_FILE OUTPUT_FILE)
    set(multiValueArgs "")
    cmake_parse_arguments(VERSION_GEN "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Set default input and output files
    if(NOT VERSION_GEN_INPUT_FILE)
        set(VERSION_GEN_INPUT_FILE "${PROJECT_SOURCE_DIR}/cmake/version.h.in")
    endif()
    
    if(NOT VERSION_GEN_OUTPUT_FILE)
        set(VERSION_GEN_OUTPUT_FILE "${PROJECT_BINARY_DIR}/version_generated.h")
    endif()
    
    # Check if input file exists
    if(NOT EXISTS "${VERSION_GEN_INPUT_FILE}")
        message(FATAL_ERROR "Version template file not found: ${VERSION_GEN_INPUT_FILE}")
    endif()
    
    # Get Git information
    get_git_info()
    
    # Get build timestamp
    get_build_timestamp()
    
    # Set version variables
    if(NOT DEFINED VERSION_MAJOR)
        set(VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
    endif()
    
    if(NOT DEFINED VERSION_MINOR)
        set(VERSION_MINOR ${PROJECT_VERSION_MINOR})
    endif()
    
    if(NOT DEFINED VERSION_PATCH)
        set(VERSION_PATCH ${PROJECT_VERSION_PATCH})
    endif()
    
    if(NOT DEFINED VERSION_TWEAK)
        if(PROJECT_VERSION_TWEAK)
            set(VERSION_TWEAK ${PROJECT_VERSION_TWEAK})
        else()
            set(VERSION_TWEAK 0)
        endif()
    endif()
    
    # Create version string
    set(VERSION_STRING "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
    if(VERSION_TWEAK GREATER 0)
        set(VERSION_STRING "${VERSION_STRING}.${VERSION_TWEAK}")
    endif()
    
    # Set build type
    if(NOT CMAKE_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE "Debug")
    endif()
    
    # Format compiler flags
    set(CMAKE_CXX_FLAGS_FORMATTED "${CMAKE_CXX_FLAGS}")
    set(CMAKE_CXX_FLAGS_DEBUG_FORMATTED "${CMAKE_CXX_FLAGS_DEBUG}")
    set(CMAKE_CXX_FLAGS_RELEASE_FORMATTED "${CMAKE_CXX_FLAGS_RELEASE}")
    
    format_flags(CMAKE_CXX_FLAGS_FORMATTED)
    format_flags(CMAKE_CXX_FLAGS_DEBUG_FORMATTED)
    format_flags(CMAKE_CXX_FLAGS_RELEASE_FORMATTED)
    
    # Configure the file
    configure_file(
        "${VERSION_GEN_INPUT_FILE}"
        "${VERSION_GEN_OUTPUT_FILE}"
        @ONLY
    )
    
    # Set variables for configure_file
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS_FORMATTED}")
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG_FORMATTED}")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE_FORMATTED}")
    
    # Re-configure with formatted flags
    configure_file(
        "${VERSION_GEN_INPUT_FILE}"
        "${VERSION_GEN_OUTPUT_FILE}"
        @ONLY
    )
    
    message(STATUS "Generated version header: ${VERSION_GEN_OUTPUT_FILE}")
    message(STATUS "Version: ${VERSION_STRING}")
    message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
    message(STATUS "Compiler: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
    
    # Note: Include directories will be added to specific targets rather than project-wide
endfunction()


# Macro to automatically generate version header (for convenience)
macro(auto_generate_version_header)
    generate_version_header()
endmacro()
