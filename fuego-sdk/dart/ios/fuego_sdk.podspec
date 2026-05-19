Pod::Spec.new do |s|
  s.name             = 'fuego_sdk'
  s.version          = '1.0.0'
  s.summary          = 'Fuego SDK Flutter plugin'
  s.homepage         = 'https://fuego.money'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Fuego' => 'dev@fuego.money' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
