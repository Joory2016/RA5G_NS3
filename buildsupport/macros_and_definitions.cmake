#Fixed definitions
unset(CMAKE_LINK_LIBRARY_SUFFIX)

#Output folders
set(CMAKE_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}/build)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_OUTPUT_DIRECTORY}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_OUTPUT_DIRECTORY}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_OUTPUT_DIRECTORY}/bin)
set(CMAKE_HEADER_OUTPUT_DIRECTORY  ${CMAKE_OUTPUT_DIRECTORY}/ns3)
add_definitions(-DNS_TEST_SOURCEDIR="${CMAKE_OUTPUT_DIRECTORY}/test")

#process all options passed in main cmakeLists
macro(process_options)
    #Copy all header files to outputfolder/include/
    FILE(GLOB_RECURSE include_files ${PROJECT_SOURCE_DIR}/*.h) #just copying every single header into ns3 include folder
    file(COPY ${include_files} DESTINATION ${CMAKE_HEADER_OUTPUT_DIRECTORY})

    #Set common include folder
    include_directories( ${CMAKE_OUTPUT_DIRECTORY})
    include_directories(${CMAKE_OUTPUT_DIRECTORY})

    #Set C++ standard
    add_definitions(-std=c++11 -fPIC)

    #find required dependencies

    #BoostC++
    if(${NS3_BOOST})
        find_package(Boost)
        if(${BOOST_FOUND})
            link_directories(${BOOST_LIBRARY_DIRS})
            include_directories( ${BOOST_INCLUDE_DIR})
        endif()
    endif()

    #GTK2
    if(${NS3_GTK2})
        find_package(GTK2)
        if(${GTK2_FOUND})
            link_directories(${GTK2_LIBRARY_DIRS})
            include_directories( ${GTK2_INCLUDE_DIRS})
            add_definitions(${GTK2_DEFINITIONS})
        endif()
    endif()

    #LibXml2
    if(${NS3_LIBXML2})
        find_package(LibXml2)
        if(${LIBXML2_FOUND})
            link_directories(${LIBXML2_LIBRARY_DIRS})
            include_directories( ${LIBXML2_INCLUDE_DIR})
            add_definitions(${LIBXML2_DEFINITIONS})
        endif()
    endif()

    #LibRT
    if(${NS3_LIBRT})
        find_library(LIBRT rt)
        if(${LIBRT_FOUND})
            add_definitions(-lrt)
            add_definitions(-DHAVE_RT)
        endif()
    endif()

    #if(${NS3_PTHREAD})
        set(THREADS_PREFER_PTHREAD_FLAG)
        find_package(Threads REQUIRED)
        if(${THREADS_FOUND})
            include_directories(${THREADS_PTHREADS_INCLUDE_DIR})
            add_definitions(-DHAVE_PTHREAD_H)
        endif()
    #endif()

    if(${NS3_MPI})
        find_package(MPI)
        if(${MPI_FOUND}})
            include_directories( ${MPI_INCLUDE_PATH})
            add_definitions(${MPI_COMPILE_FLAGS} ${MPI_LINK_FLAGS})
        endif()
    endif()

    if(${NS3_GSL})
        find_package(GSL)
        if(${GSL_FOUND})
            include_directories( ${GSL_INCLUDE_DIRS})
            link_directories(${GSL_LIBRARY})
        endif()
    endif()

    #process debug switch
    if(${NS3_DEBUG})
        add_definitions(-g)
        set(build_type "debug")
        set (CMAKE_SKIP_RULE_DEPENDENCY TRUE)
    else()
        add_definitions(-O3)
        set(build_type "release")
        set (CMAKE_SKIP_RULE_DEPENDENCY FALSE)
    endif()

    #Process core-config
    set(INT64X64 128)

    if(INT64X64 EQUAL 128)
        add_definitions(-DHAVE___UINT128_T)
        add_definitions(-DINT64X64_USE_128)
    elseif(INT64X64 EQUAL DOUBLE)
        add_definitions(-DINT64X64_USE_DOUBLE)
    elseif(INT64X64 EQUAL CAIRO)
        add_definitions(-DINT64X64_USE_CAIRO)
    else()
    endif()
    add_definitions(-DHAVE_STDINT_H)
    add_definitions(-DHAVE_INTTYPES_H)
    #undef HAVE_SYS_INT_TYPES_H */
    add_definitions(-DHAVE_SYS_TYPES_H)
    add_definitions(-DHAVE_SYS_STAT_H)
    add_definitions(-DHAVE_DIRENT_H)
    add_definitions(-DHAVE_STDLIB_H)
    add_definitions(-DHAVE_GETENV)
    add_definitions(-DHAVE_SIGNAL_H)
    add_definitions(-DNS3_LOG_ENABLE)

    #Process config-store-config
    add_definitions(-DPYTHONDIR="/usr/local/lib/python2.7/dist-packages")
    add_definitions(-DPYTHONARCHDIR="/usr/local/lib/python2.7/dist-packages")
    add_definitions(-DHAVE_PYEMBED)
    add_definitions(-DHAVE_PYEXT)
    add_definitions(-DHAVE_PYTHON_H)


    #Create library names to solve dependency problems with macros that will be called at each lib subdirectory
    set(ns3-libs )
    foreach(libname ${libs_to_build})
        #TODO: add 3rd-party library dependency check
        set(lib${libname} ns${NS3_VER}-${libname}-${build_type})
        set(ns3-libs "${ns3-libs}" ${lib${libname}})
    endforeach()

endmacro()
#----------------------------------------------
macro (write_module_header name header_files)
    string(TOUPPER ${name} uppercase_name)
    string(REPLACE "-" "_" final_name ${uppercase_name} )
    #Common module_header
    set(contents "#ifdef NS3_MODULE_COMPILATION ")
    set(contents ${contents} "
    error \"Do not include ns3 module aggregator headers from other modules; these are meant only for end user scripts.\" ")
    set(contents ${contents} "
#endif ")
    set(contents ${contents} "
#ifndef NS3_MODULE_")
    set(contents ${contents} ${final_name})
    set(contents ${contents} "
    // Module headers: ")

    #Write each header listed to the contents variable
    foreach(header ${header_files})
        get_filename_component(head ${header} NAME)
        set(contents
                "${contents}
    #include \"${head}\"")
    endforeach()

    #Common module footer
    set(contents ${contents} "
#endif ")
    file(WRITE ${CMAKE_HEADER_OUTPUT_DIRECTORY}/${name}-module.h ${contents})
endmacro()


macro (build_lib name source_files header_files libraries_to_link test_sources)
    #Create shared library with sources and headers
    add_library(${lib${name}} SHARED "${source_files}" "${header_files}")

    #Link the shared library with the libraries passed
    target_link_libraries(${lib${name}} ${libraries_to_link})

    #Write a module header that includes all headers from that module
    write_module_header("${name}" "${header_files}")

    #Build tests if requested
    if(${NS3_TESTS})
        list(LENGTH test_sources test_source_len)
        if (${test_source_len} GREATER 0)
            #Create name of output library test of module
            set(test${name} ns${NS3_VER}-${name}-test-${build_type})

            #Create shared library containing tests of the module
            add_library(${test${name}} SHARED "${test_sources}")

            #Link test library to the module library
            target_link_libraries(${test${name}} ${lib${name}})
        endif()
    endif()

    #Build pybindings  if requested
    if(${NS3_PYTHON})
        set(arch gcc_ILP32)
        add_custom_command(
                OUTPUT
                ${PROJECT_SOURCE_DIR}/src/${name}/bindings/modulegen_${arch}.py
                COMMAND
                ${PROJECT_SOURCE_DIR}/bindings/python/ns3modulegen-modular.py
                ${PROJECT_SOURCE_DIR}/src/${name}/bindings/
                ${PROJECT_SOURCE_DIR}/src/${name}/
                ${CMAKE_HEADER_OUTPUT_DIRECTORY}/${name}-module.h
                modulegen_${arch}.py
                ${CMAKE_CXX_FLAGS}
                )
    endif()
endmacro()

macro (build_example name source_files header_files libraries_to_link)
    #Create shared library with sources and headers
    add_executable(${name} "${source_files}" "${header_files}")

    #Link the shared library with the libraries passed
    target_link_libraries(${name} ${libraries_to_link})

    set_target_properties( ${name}
            PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/examples
            )
endmacro()

#Add contributions macros
include(buildsupport/contributions.cmake)