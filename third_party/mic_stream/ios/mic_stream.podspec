#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
# Vendored patch: sources live in the Swift Package Manager layout
# (mic_stream/Sources/mic_stream) so SPM and CocoaPods builds share one file.
Pod::Spec.new do |s|
  s.name             = 'mic_stream'
  s.version          = '0.0.1'
  s.summary          = 'Provides a tool to get the microphone input as Byte Stream'
  s.description      = <<-DESC
Provides a tool to get the microphone input as Byte Stream
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'mic_stream/Sources/mic_stream/**/*.swift'
  s.dependency 'Flutter'
  s.swift_version = '5.0'

  s.ios.deployment_target = '13.0'
end
