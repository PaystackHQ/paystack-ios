Pod::Spec.new do |s|
  s.name                           = 'Paystack'
  s.version                        = '3.0.14'
  s.summary                        = 'Paystack is a web-based API helping African Businesses accept payments online.'
  s.description                    = <<-DESC
   Paystack makes it easy for African Businesses to accept Mastercard, Visa and Verve cards from anyone, anywhere in the world.
  DESC

  s.license                        = { :type => 'MIT', :file => 'LICENSE' }
  s.homepage                       = 'https://paystack.com'
  s.authors                        = { 'Jubril Olambiwonnu' => 'jubril@paystack.com', 'Ibrahim Lawal' => 'ibrahim@paystack.com', 'Paystack' => 'support@paystack.com' }
  s.source                         = { :git => 'https://github.com/paystackhq/paystack-ios.git', :tag => "v#{s.version}" }
  s.ios.frameworks                 = 'Foundation', 'Security'
  s.ios.weak_frameworks            = 'PassKit', 'AddressBook'
  s.requires_arc                   = true
  s.ios.deployment_target          = '11.0'
  s.swift_versions = '5.0'
  ss.public_header_files = 'Paystack/Classes/PublicHeaders/*.h', 'Paystack/Classes/RSA/*.h'
  s.source_files = 'Paystack/Classes/**/*.{swift,h,m}'
  s.resources = 'Paystack/Resources/**/*'
    
end
