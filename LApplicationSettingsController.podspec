Pod::Spec.new do |s|
  s.name         = "LApplicationSettingsController"
  s.version      = "1.0"
  s.platform     = :ios, '6.0'
  s.source       = { :git => 'https://github.com/lukagabric/LApplicationSettingsController'}
  s.source_files = "LApplicationSettingsController/LApplicationSettingsController/Classes/Core/LApplicationSettingsController/*.{h,m}"
  s.dependency 'ASIHTTPRequest'
  s.requires_arc = true
end