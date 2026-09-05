# flutter_libepiccash_example

## Requirements

- Flutter 3.47 or newer (Dart 3.13 or newer)
- Rust and the platform prerequisites in the [package README](../README.md)
- Linux: `libsecret-1` and `jsoncpp`

On Debian/Ubuntu:
```sh
sudo apt install libsecret-1-dev libjsoncpp-dev
```

Run `flutter pub get` from this directory, then `flutter run` for your target
platform. Android release builds declare Internet permission in the main app
manifest, and the desktop projects install the Native Assets libraries with
the application.
