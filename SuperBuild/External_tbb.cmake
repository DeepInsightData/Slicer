
set(proj tbb)

# Set dependency list
set(${proj}_DEPENDENCIES "")

# Include dependent projects if any
ExternalProject_Include_Dependencies(${proj} PROJECT_VAR proj DEPENDS_VAR ${proj}_DEPENDENCIES)

if(Slicer_USE_SYSTEM_${proj})
  # When adding support for finding TBB on the system, make sure to set TBB_BIN_DIR and TBB_LIB_DIR
  message(FATAL_ERROR "Enabling Slicer_USE_SYSTEM_${proj} is not supported!")
endif()

# Sanity checks
if(DEFINED TBB_DIR AND NOT EXISTS ${TBB_DIR})
  message(FATAL_ERROR "TBB_DIR variable is defined but corresponds to nonexistent directory")
endif()
if(DEFINED TBB_BIN_DIR AND NOT EXISTS ${TBB_BIN_DIR})
  message(FATAL_ERROR "TBB_BIN_DIR variable is defined but corresponds to nonexistent directory")
endif()
if(DEFINED TBB_LIB_DIR AND NOT EXISTS ${TBB_LIB_DIR})
  message(FATAL_ERROR "TBB_LIB_DIR variable is defined but corresponds to nonexistent directory")
endif()

if((NOT DEFINED TBB_DIR
    OR NOT DEFINED TBB_BIN_DIR
    OR NOT DEFINED TBB_LIB_DIR
    )
    AND NOT Slicer_USE_SYSTEM_${proj})

  set(tbb_ver "2021.5.0")
  if (WIN32)
    set(tbb_file "oneapi-tbb-${tbb_ver}-win.zip")
    set(tbb_sha256 "096c004c7079af89fe990bb259d58983b0ee272afa3a7ef0733875bfe09fcd8e")
  elseif (APPLE)
    set(tbb_file "oneapi-tbb-${tbb_ver}-mac.tgz")
    set(tbb_sha256 "388c1c25314e3251e38c87ade2323af74cdaae2aec9b68e4c206d61c30ef9c33")
  else ()
    set(tbb_file "oneapi-tbb-${tbb_ver}-lin.tgz")
    set(tbb_sha256 "74861b1586d6936b620cdab6775175de46ad8b0b36fa6438135ecfb8fb5bdf98")
  endif ()

  # When updating the version of tbb, consider also
  # updating the soversion numbers hard-coded below in the
  # "fix_rpath" macOS external project step.
  #
  # To find out if the soversion number should be updated,
  # inspect the installed libraries and/or review the value
  # associated with
  # (1) __TBB_BINARY_VERSION in include/oneapi/tbb/version.h
  #     for libtbb
  # (2) TBBMALLOC_BINARY_VERSION variable in the top-level
  #     CMakeLists.txt for libtbbmalloc

  if(APPLE)
    set(tbb_cmake_osx_required_deployment_target "10.15") # See https://github.com/oneapi-src/oneTBB/blob/master/SYSTEM_REQUIREMENTS.md

    if(NOT DEFINED CMAKE_OSX_DEPLOYMENT_TARGET)
      message(FATAL_ERROR "CMAKE_OSX_DEPLOYMENT_TARGET is not defined")
    endif()
    if(NOT CMAKE_OSX_DEPLOYMENT_TARGET VERSION_GREATER_EQUAL ${tbb_cmake_osx_required_deployment_target})
      message(FATAL_ERROR "TBB requires macOS >= ${tbb_cmake_osx_required_deployment_target}. CMAKE_OSX_DEPLOYMENT_TARGET currently set to ${CMAKE_OSX_DEPLOYMENT_TARGET}")
    endif()
  endif()

  #------------------------------------------------------------------------------
  set(TBB_INSTALL_DIR "${CMAKE_BINARY_DIR}/${proj}-install")

  ExternalProject_Add(${proj}
    ${${proj}_EP_ARGS}
    URL https://github.com/oneapi-src/oneTBB/releases/download/v${tbb_ver}/${tbb_file}
    URL_HASH SHA256=${tbb_sha256}
    DOWNLOAD_DIR ${CMAKE_BINARY_DIR}
    SOURCE_DIR ${TBB_INSTALL_DIR}
    BUILD_IN_SOURCE 1
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ""
    )

  if(CMAKE_SIZEOF_VOID_P EQUAL 8) # 64-bit
    set(tbb_archdir intel64)
  else()
    set(tbb_archdir ia32)
  endif()

  if (WIN32)
    if (NOT MSVC_VERSION VERSION_GREATER_EQUAL 1900)
      message(FATAL_ERROR "At least Visual Studio 2015 is required")
    elseif (NOT MSVC_VERSION VERSION_GREATER 1900)
      set(tbb_vsdir vc14)
    elseif (NOT MSVC_VERSION VERSION_GREATER 1919)
      # VS2017 is expected to be binary compatible with VS2015
      set(tbb_vsdir vc14)
    elseif (NOT MSVC_VERSION VERSION_GREATER 1929)
      # VS2019 is expected to be binary compatible with VS2015
      set(tbb_vsdir vc14)
    elseif (NOT MSVC_VERSION VERSION_GREATER 1949)
      # VS2022 is expected to be binary compatible with VS2015
      # Note that VS2022 covers both MSVC versions 193x and 194x as explained in
      # https://devblogs.microsoft.com/cppblog/msvc-toolset-minor-version-number-14-40-in-vs-2022-v17-10/
      set(tbb_vsdir vc14)
    else()
      message(FATAL_ERROR "TBB does not support your Visual Studio compiler. [MSVC_VERSION: ${MSVC_VERSION}]")
    endif ()
    set(tbb_libdir lib/${tbb_archdir}/${tbb_vsdir})
    set(tbb_bindir redist/${tbb_archdir}/${tbb_vsdir})
  elseif (APPLE)
    set(tbb_libdir "lib")
    set(tbb_bindir "${tbb_libdir}")
  else ()
    set(tbb_libdir "lib/${tbb_archdir}/gcc4.8")
    set(tbb_bindir "${tbb_libdir}")
  endif ()

  if(APPLE)
    ExternalProject_Add_Step(${proj} fix_rpath
      # libtbb
      COMMAND install_name_tool
        -id ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbb.12.dylib
            ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbb.12.dylib
      COMMAND install_name_tool
        -id ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbb_debug.12.dylib
            ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbb_debug.12.dylib
      # libtbbmalloc
      COMMAND install_name_tool
        -id ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbbmalloc.2.dylib
            ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbbmalloc.2.dylib
      COMMAND install_name_tool
        -id ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbbmalloc_debug.2.dylib
            ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbbmalloc_debug.2.dylib
      # libtbbmalloc_proxy
      COMMAND install_name_tool
        -id ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbbmalloc_proxy.2.dylib
            ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbbmalloc_proxy.2.dylib
        -change @rpath/libtbbmalloc.2.dylib
                ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbbmalloc.2.dylib
      COMMAND install_name_tool
        -id ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbbmalloc_proxy_debug.2.dylib
            ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbbmalloc_proxy_debug.2.dylib
        -change @rpath/libtbbmalloc_debug.2.dylib
                ${TBB_INSTALL_DIR}/${tbb_libdir}/libtbbmalloc_debug.2.dylib
      DEPENDEES install
      )
  endif()

  #------------------------------------------------------------------------------
  # Variables used to install TBB and configure launcher

  set(TBB_BIN_DIR "${TBB_INSTALL_DIR}/${tbb_bindir}")
  set(TBB_LIB_DIR "${TBB_INSTALL_DIR}/${tbb_libdir}")

  #-----------------------------------------------------------------------------
  ExternalProject_GenerateProjectDescription_Step(${proj}
    VERSION ${tbb_ver}
    LICENSE_FILES "https://raw.githubusercontent.com/oneapi-src/oneTBB/v${tbb_ver}/LICENSE.txt"
    )

  #-----------------------------------------------------------------------------
  # Launcher setting specific to build tree

  set(${proj}_LIBRARY_PATHS_LAUNCHER_BUILD "${TBB_BIN_DIR}")
  mark_as_superbuild(
    VARS ${proj}_LIBRARY_PATHS_LAUNCHER_BUILD
    LABELS "LIBRARY_PATHS_LAUNCHER_BUILD"
    )

  set(TBB_DIR ${TBB_INSTALL_DIR}/lib/cmake/tbb)

else()
  # The project is provided using TBB_DIR, nevertheless since other project may depend on TBB,
  # let's add an 'empty' one
  ExternalProject_Add_Empty(${proj} DEPENDS ${${proj}_DEPENDENCIES})
endif()

mark_as_superbuild(
  VARS
    TBB_BIN_DIR:PATH
    TBB_LIB_DIR:PATH
  )

ExternalProject_Message(${proj} "TBB_DIR:${TBB_DIR}")
mark_as_superbuild(
  VARS TBB_DIR:PATH
  LABELS "FIND_PACKAGE"
  )
