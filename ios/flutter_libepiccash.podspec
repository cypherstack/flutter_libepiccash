#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_libepiccash.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_libepiccash'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://cypherstack.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Joshua Babb' => 'sneurlax@gmail.com' }
  s.source           = { :path => '.' }
  s.public_header_files = 'Classes**/*.h'
  s.source_files = 'Classes/**/*'
  s.static_framework = true
  s.vendored_libraries = 'libs/*.a'
  s.dependency 'Flutter'
  s.library = 'sqlite3', 'c++'
  s.platform = :ios, '9.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
  s.swift_version = '5.0'

  # Start Cargokit:
  s.source       = { :path => '.' }
  s.source_files = 'Classes/**/*'

  s.script_phase = [
    {
      :name => 'Build Rust library',
      # First argument: relative path to Rust folder, second: Rust library name.
      :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../rust epic_cash_wallet',
      :execution_position => :before_compile,
      :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
      # Let Xcode know the static lib output of this script (for linking).
      :output_files => ["${BUILT_PRODUCTS_DIR}/libepic_cash_wallet.a"],
    },
    {
      :name => 'Merge RandomX library',
      :script => <<~SCRIPT,
        set -e
        # Find and merge librandomx.a with libepic_cash_wallet.a
        MAIN_LIB="${BUILT_PRODUCTS_DIR}/libepic_cash_wallet.a"
        if [ -f "$MAIN_LIB" ]; then
          RANDOMX_LIB=$(find "${TARGET_TEMP_DIR}" -name "librandomx.a" 2>/dev/null | head -n 1)
          if [ -f "$RANDOMX_LIB" ]; then
            echo "Found RandomX library at: $RANDOMX_LIB"
            # Merge the libraries using libtool
            libtool -static -o "${BUILT_PRODUCTS_DIR}/libepic_cash_wallet_combined.a" \\
              "$MAIN_LIB" \\
              "$RANDOMX_LIB"
            # Replace the original library with the combined one
            mv "${BUILT_PRODUCTS_DIR}/libepic_cash_wallet_combined.a" "$MAIN_LIB"
            echo "Successfully merged RandomX library"
          else
            echo "Warning: librandomx.a not found, skipping merge"
          fi
        else
          echo "Warning: libepic_cash_wallet.a not found"
        fi
      SCRIPT
      :execution_position => :before_compile
    }
  ]
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Exclude 32-bit iOS simulator arch which Flutter doesn't support.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # Force-load the Rust static library at link time.
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/libepic_cash_wallet.a',
  }
  # End Cargokit.
end
