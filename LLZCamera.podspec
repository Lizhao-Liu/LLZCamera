#
# Be sure to run `pod lib lint YMMImagePicker.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'LLZCamera'
  s.version          = '0.1.0'
  s.summary          = '自定义相机'
  s.description      = <<-DESC
  ios custom camera component
                       DESC
  s.homepage         = 'http://code.amh-group.com/iOSYMM/YMMImagePicker'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '周刚涛' => 'zhejun.shen@ymm56.com' }
  s.source           = { :git => 'git@code.amh-group.com:iOSYmm/YMMImagePicker.git', :tag => s.version.to_s }
  s.ios.deployment_target = '10.0'
  s.resource_bundles = {
    'CameraResources' => ['LLZCamera/Assets/LLZCamera.xcassets']
  }
  s.source_files = 'LLZCamera/Classes/**/*.{h,m}'
  
  s.pod_target_xcconfig = { 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
end
