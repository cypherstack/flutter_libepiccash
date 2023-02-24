#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_libepiccash.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_libepiccash'
  s.version          = '0.0.2'
  s.summary          = 'An Epic Cash plugin in Dart for Flutter'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://cypherstack.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Cypher Stack team' => 'heyo@cypherstack.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
