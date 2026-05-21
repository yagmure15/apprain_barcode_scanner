Pod::Spec.new do |s|
  s.name             = 'apprain_barcode_scanner_ios'
  s.version          = '1.0.0'
  s.summary          = 'iOS implementation of Apprain Barcode Scanner plugin.'
  s.description      = 'AVFoundation + Vision framework barcode scanner for Flutter.'
  s.homepage         = 'https://github.com/yagmure15/apprain_barcode_scanner'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = { 'yagmure15' => 'yagmure15@github.com' }
  s.source           = { :http => 'https://github.com/yagmure15/apprain_barcode_scanner' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.5'
  s.swift_version    = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
