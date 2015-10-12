Pod::Spec.new do |s|
    s.name = 'RealmKit'
    s.version = '0.0.0'
    s.license = 'MIT'
    s.summary = 'Sync & JSON Serializer for Realm in Swift'
    s.authors = { 'Michael Loistl' => 'michael.loistl@mobext.com' }
    s.source = { :git => 'https://michaelloistl@bitbucket.org/aplo/realmkit.git', :tag => s.version }

    s.ios.deployment_target = '8.0'
    s.osx.deployment_target = '10.9'
    s.watchos.deployment_target = '2.0'

    s.source_files = 'RealmKit/*.{swift}'

    s.requires_arc = true

    s.dependency 'RealmSwift', '~> 0.95'
end