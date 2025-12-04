# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "flutter_libepiccash")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_libepiccash_plugin")

# Any new source files that you add to the plugin should be added here.
# No plugin sources for FFI-only plugin.

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} INTERFACE)

# Ensure .lib file is generated alongside .dll
# No export symbols for interface target.

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
# No standard settings required for an interface-only target.

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
# No compile properties for interface-only target.

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
# No includes or link libraries for FFI-only plugin.

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(flutter_libepiccash_bundled_libraries
  ""
  PARENT_SCOPE
)
