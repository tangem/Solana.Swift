platform :ios, '15.0'
use_frameworks!
inhibit_all_warnings!

def common
  pod 'TweetNacl', '~> 1.0.2'
  pod 'Starscream', '~> 4.0.0'
  pod 'secp256k1.swift'
end
 
target 'Solana.Swift' do
  common 
end

target 'Solana.SwiftTests' do
  common
end

# Workaround for legacy dependencies with too low deployment target
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "15.0"
    end
  end
end
