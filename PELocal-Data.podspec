Pod::Spec.new do |s|
  s.name         = "PELocal-Data"
  s.version      = "0.0.1"
  s.license      = "MIT"
  s.summary      = "An iOS static library facilitating the maintenance of a sync-able, SQLite database instance."
  s.author       = { "Paul Evans" => "evansp2@gmail.com" }
  s.homepage     = "https://github.com/evanspa/#{s.name}"
  s.source       = { :git => "https://github.com/evanspa/#{s.name}.git", :tag => "#{s.name}-v#{s.version}" }
  s.platform     = :ios, '8.4'
  s.source_files = '**/*.{h,m}'
  s.public_header_files = '**/*.h'
  s.exclude_files = "**/*Tests/*.*"
  s.requires_arc = true
  s.dependency 'PEObjc-Commons', '~> 1.0.100'
  s.dependency 'FMDB', '~> 2.5'
  s.dependency 'PEHateoas-Client', '~> 1.0.8'
  s.dependency 'CocoaLumberjack', '~> 1.9'
  s.library = 'sqlite3'
end
