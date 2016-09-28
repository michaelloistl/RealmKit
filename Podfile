use_frameworks!

def shared_pods
    pod 'RealmSwift', '~> 1.1'
    pod 'Alamofire', '~> 4.0'
end

target 'iOS' do
    platform :ios, '9.0'
    shared_pods
end

target 'iOSTests' do
    platform :ios, '9.0'
    shared_pods
end

target 'macOS' do
    platform :osx, '10.11'
    shared_pods
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0'
        end
    end
end
