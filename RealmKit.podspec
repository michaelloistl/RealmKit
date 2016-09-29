Pod::Spec.new do |s|
    s.name = 'RealmKit'
    s.version = '1.0.0'
    s.license = 'MIT'
    s.summary = 'Networking & JSON Serializer for Realm in Swift'
    s.authors = { 'Michael Loistl' => 'michael@aplo.co' }
    s.homepage = "https://github.com/michaelloistl/RealmKit"
    s.source = { :git => 'https://github.com/michaelloistl/RealmKit.git', :tag => s.version }

    s.ios.deployment_target = '9.0'
    s.osx.deployment_target = '10.11'
    s.watchos.deployment_target = '2.0'

    s.source_files = 'Source/*.{swift}'

    s.requires_arc = true

    s.dependency 'RealmSwift', '~> 1.1'
    s.dependency 'Alamofire', '~> 4.0'
end
