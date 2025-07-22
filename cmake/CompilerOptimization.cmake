# CompilerOptimization.cmake
# This file contains compiler-specific optimizations for faster builds

# Function to set build optimizations
function(enable_build_optimizations)
    set(oneValueArgs TARGET)
    cmake_parse_arguments(
        BUILD_OPT
        "${options}"
        "${oneValueArgs}"
        "${multiValueArgs}"
        ${ARGN})

    message(STATUS "Enabling build optimizations for: ${BUILD_OPT_TARGET}")

    # MSVC specific optimizations
    if(MSVC)
        message(STATUS "Applying MSVC build optimizations")
        
        # Enable parallel compilation
        target_compile_options(${BUILD_OPT_TARGET} PRIVATE
            /MP  # Multi-processor compilation
        )
        
        # Enable faster linking
        if(CMAKE_BUILD_TYPE STREQUAL "Debug")
            target_link_options(${BUILD_OPT_TARGET} PRIVATE
                /DEBUG:FASTLINK  # Faster incremental linking in debug
            )
        else()
            target_link_options(${BUILD_OPT_TARGET} PRIVATE
                /OPT:REF         # Remove unreferenced functions/data
                /OPT:ICF         # Enable identical COMDAT folding
            )
        endif()
        
        # Enable function-level linking
        target_compile_options(${BUILD_OPT_TARGET} PRIVATE
            /Gy  # Enable function-level linking
        )
        
    # GCC/Clang specific optimizations
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        message(STATUS "Applying GCC/Clang build optimizations")
        
        # Enable parallel compilation (handled by make -j)
        # But we can set some compiler optimizations
        target_compile_options(${BUILD_OPT_TARGET} PRIVATE
            -ffunction-sections    # Put each function in its own section
            -fdata-sections       # Put each data item in its own section
        )
        
        # Enable garbage collection of unused sections
        target_link_options(${BUILD_OPT_TARGET} PRIVATE
            -Wl,--gc-sections     # Remove unused sections
        )
        
        # Enable Link Time Optimization if requested
        if(ENABLE_LTO)
            set_property(TARGET ${BUILD_OPT_TARGET} PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE)
        endif()
    endif()
endfunction()

# Function to configure global build settings
function(configure_global_build_settings)
    message(STATUS "Configuring global build settings")
    
    # Set global MSVC options
    if(MSVC)
        # Enable parallel compilation globally
        add_compile_options(/MP)
        
        # Increase parallel compilation job count
        if(NOT DEFINED ENV{CL})
            # If CL environment variable is not set, use maximum processors
            include(ProcessorCount)
            ProcessorCount(N)
            if(NOT N EQUAL 0)
                message(STATUS "Using ${N} parallel compilation jobs")
                set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /MP${N}")
                set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /MP${N}")
            endif()
        endif()
        
        # Enable faster PDB generation
        add_compile_options(/FS)  # Force synchronous PDB writes
        
        # Reduce debug info overhead in debug builds
        if(CMAKE_BUILD_TYPE STREQUAL "Debug")
            # Use faster debug info format
            add_compile_options(/ZI)  # Enable Edit and Continue
        elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
            add_compile_options(/Zi)  # Produce PDB files
        endif()
        
    # GCC/Clang settings
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        # Enable colored diagnostics
        if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            add_compile_options(-fdiagnostics-color=always)
        elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
            add_compile_options(-fcolor-diagnostics)
        endif()
    endif()
    
    # Set reasonable cache size for ccache if available
    find_program(CCACHE_FOUND ccache)
    if(CCACHE_FOUND)
        message(STATUS "Found ccache: ${CCACHE_FOUND}")
        set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
        set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
    endif()
endfunction()

# Function to suggest using Ninja
function(suggest_ninja_generator)
    if(NOT CMAKE_GENERATOR STREQUAL "Ninja")
        message(STATUS "")
        message(STATUS "================================")
        message(STATUS "Build Performance Tip:")
        message(STATUS "Consider using Ninja generator for faster builds:")
        message(STATUS "  cmake -G Ninja -S . -B build")
        message(STATUS "Or use Ninja Multi-Config:")
        message(STATUS "  cmake -G \"Ninja Multi-Config\" -S . -B build")
        message(STATUS "================================")
        message(STATUS "")
    else()
        message(STATUS "Using Ninja generator - good choice for build speed!")
    endif()
endfunction()

# Function to enable precompiled headers
function(enable_precompiled_headers)
    set(oneValueArgs TARGET HEADER)
    cmake_parse_arguments(
        PCH
        "${options}"
        "${oneValueArgs}"
        "${multiValueArgs}"
        ${ARGN})
        
    if(NOT PCH_HEADER)
        set(PCH_HEADER "pch.h")
    endif()
    
    # Check if the header exists
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${PCH_HEADER}")
        message(STATUS "Enabling precompiled headers for ${PCH_TARGET}: ${PCH_HEADER}")
        target_precompile_headers(${PCH_TARGET} PRIVATE ${PCH_HEADER})
    else()
        message(STATUS "Precompiled header ${PCH_HEADER} not found for ${PCH_TARGET}")
    endif()
endfunction()

# Call the global configuration
configure_global_build_settings()
suggest_ninja_generator()
