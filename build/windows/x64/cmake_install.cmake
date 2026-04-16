# Install script for directory: C:/XPARQ/xparq-app/windows

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "$<TARGET_FILE_DIR:xparq_mobile>")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/flutter/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/runner/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/plugins/app_links/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/plugins/connectivity_plus/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/plugins/dargon2_flutter_desktop/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/plugins/file_selector_windows/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/plugins/firebase_core/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/plugins/flutter_secure_storage_windows/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/plugins/gal/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/plugins/geolocator_windows/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/plugins/local_auth_windows/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/plugins/permission_handler_windows/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/plugins/share_plus/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/XPARQ/xparq-app/build/windows/x64/plugins/url_launcher_windows/cmake_install.cmake")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/xparq_mobile.exe")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug" TYPE EXECUTABLE FILES "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/xparq_mobile.exe")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/xparq_mobile.exe")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile" TYPE EXECUTABLE FILES "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/xparq_mobile.exe")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Release/xparq_mobile.exe")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Release" TYPE EXECUTABLE FILES "C:/XPARQ/xparq-app/build/windows/x64/runner/Release/xparq_mobile.exe")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/data/icudtl.dat")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/data" TYPE FILE FILES "C:/XPARQ/xparq-app/windows/flutter/ephemeral/icudtl.dat")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/data/icudtl.dat")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/data" TYPE FILE FILES "C:/XPARQ/xparq-app/windows/flutter/ephemeral/icudtl.dat")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Release/data/icudtl.dat")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Release/data" TYPE FILE FILES "C:/XPARQ/xparq-app/windows/flutter/ephemeral/icudtl.dat")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/flutter_windows.dll")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug" TYPE FILE FILES "C:/XPARQ/xparq-app/windows/flutter/ephemeral/flutter_windows.dll")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/flutter_windows.dll")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile" TYPE FILE FILES "C:/XPARQ/xparq-app/windows/flutter/ephemeral/flutter_windows.dll")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Release/flutter_windows.dll")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Release" TYPE FILE FILES "C:/XPARQ/xparq-app/windows/flutter/ephemeral/flutter_windows.dll")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/app_links_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/connectivity_plus_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/dargon2_flutter_desktop_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/argon2.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/file_selector_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/firebase_core_plugin.lib;C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/flutter_secure_storage_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/gal_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/geolocator_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/local_auth_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/permission_handler_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/share_plus_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/url_launcher_windows_plugin.dll")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug" TYPE FILE FILES
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/app_links/Debug/app_links_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/connectivity_plus/Debug/connectivity_plus_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/dargon2_flutter_desktop/Debug/dargon2_flutter_desktop_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/dargon2_flutter_desktop/native/Debug/argon2.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/file_selector_windows/Debug/file_selector_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/firebase_core/Debug/firebase_core_plugin.lib"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/flutter_secure_storage_windows/Debug/flutter_secure_storage_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/gal/Debug/gal_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/geolocator_windows/Debug/geolocator_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/local_auth_windows/Debug/local_auth_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/permission_handler_windows/Debug/permission_handler_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/share_plus/Debug/share_plus_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/url_launcher_windows/Debug/url_launcher_windows_plugin.dll"
      )
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/app_links_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/connectivity_plus_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/dargon2_flutter_desktop_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/argon2.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/file_selector_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/firebase_core_plugin.lib;C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/flutter_secure_storage_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/gal_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/geolocator_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/local_auth_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/permission_handler_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/share_plus_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/url_launcher_windows_plugin.dll")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile" TYPE FILE FILES
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/app_links/Profile/app_links_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/connectivity_plus/Profile/connectivity_plus_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/dargon2_flutter_desktop/Profile/dargon2_flutter_desktop_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/dargon2_flutter_desktop/native/Profile/argon2.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/file_selector_windows/Profile/file_selector_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/firebase_core/Profile/firebase_core_plugin.lib"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/flutter_secure_storage_windows/Profile/flutter_secure_storage_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/gal/Profile/gal_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/geolocator_windows/Profile/geolocator_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/local_auth_windows/Profile/local_auth_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/permission_handler_windows/Profile/permission_handler_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/share_plus/Profile/share_plus_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/url_launcher_windows/Profile/url_launcher_windows_plugin.dll"
      )
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Release/app_links_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Release/connectivity_plus_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Release/dargon2_flutter_desktop_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Release/argon2.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Release/file_selector_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Release/firebase_core_plugin.lib;C:/XPARQ/xparq-app/build/windows/x64/runner/Release/flutter_secure_storage_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Release/gal_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Release/geolocator_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Release/local_auth_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Release/permission_handler_windows_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Release/share_plus_plugin.dll;C:/XPARQ/xparq-app/build/windows/x64/runner/Release/url_launcher_windows_plugin.dll")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Release" TYPE FILE FILES
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/app_links/Release/app_links_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/connectivity_plus/Release/connectivity_plus_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/dargon2_flutter_desktop/Release/dargon2_flutter_desktop_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/dargon2_flutter_desktop/native/Release/argon2.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/file_selector_windows/Release/file_selector_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/firebase_core/Release/firebase_core_plugin.lib"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/flutter_secure_storage_windows/Release/flutter_secure_storage_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/gal/Release/gal_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/geolocator_windows/Release/geolocator_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/local_auth_windows/Release/local_auth_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/permission_handler_windows/Release/permission_handler_windows_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/share_plus/Release/share_plus_plugin.dll"
      "C:/XPARQ/xparq-app/build/windows/x64/plugins/url_launcher_windows/Release/url_launcher_windows_plugin.dll"
      )
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug" TYPE DIRECTORY FILES "C:/XPARQ/xparq-app/build/native_assets/windows/")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile" TYPE DIRECTORY FILES "C:/XPARQ/xparq-app/build/native_assets/windows/")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Release/")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Release" TYPE DIRECTORY FILES "C:/XPARQ/xparq-app/build/native_assets/windows/")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    
  file(REMOVE_RECURSE "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/data/flutter_assets")
  
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    
  file(REMOVE_RECURSE "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/data/flutter_assets")
  
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    
  file(REMOVE_RECURSE "C:/XPARQ/xparq-app/build/windows/x64/runner/Release/data/flutter_assets")
  
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/data/flutter_assets")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Debug/data" TYPE DIRECTORY FILES "C:/XPARQ/xparq-app/build//flutter_assets")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/data/flutter_assets")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/data" TYPE DIRECTORY FILES "C:/XPARQ/xparq-app/build//flutter_assets")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Release/data/flutter_assets")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Release/data" TYPE DIRECTORY FILES "C:/XPARQ/xparq-app/build//flutter_assets")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Runtime" OR NOT CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/data/app.so")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Profile/data" TYPE FILE FILES "C:/XPARQ/xparq-app/build/windows/app.so")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/XPARQ/xparq-app/build/windows/x64/runner/Release/data/app.so")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
      message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    file(INSTALL DESTINATION "C:/XPARQ/xparq-app/build/windows/x64/runner/Release/data" TYPE FILE FILES "C:/XPARQ/xparq-app/build/windows/app.so")
  endif()
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "C:/XPARQ/xparq-app/build/windows/x64/install_local_manifest.txt"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
if(CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_COMPONENT MATCHES "^[a-zA-Z0-9_.+-]+$")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
  else()
    string(MD5 CMAKE_INST_COMP_HASH "${CMAKE_INSTALL_COMPONENT}")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INST_COMP_HASH}.txt")
    unset(CMAKE_INST_COMP_HASH)
  endif()
else()
  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "C:/XPARQ/xparq-app/build/windows/x64/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
