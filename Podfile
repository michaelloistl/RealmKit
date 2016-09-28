platform :ios, '9.0'
platform :osx, '10.11'

use_frameworks!

target 'RealmKit' do
    pod 'RealmSwift', '~> 1.1'
    pod 'Alamofire', '~> 4.0'
end

target 'RealmKitTests' do
    pod 'RealmSwift', '~> 1.1'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0'
        end
    end
end
