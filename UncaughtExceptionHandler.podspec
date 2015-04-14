Pod::Spec.new do |s|
  s.name         = "UncaughtExceptionHandler"
  s.version      = "1.0.1"
  s.summary      = "Handle iOS uncaught exceptions"

  s.description  = <<-DESC
                    http://www.cocoawithlove.com/2010/05/handling-unhandled-exceptions-and.html
                   DESC

  s.homepage     = "https://github.com/thanhtrdang/UncaughtExceptionHandler"
  s.license      = 'MIT'
  s.author       = { "Thanh Dang" => "thanhtrdang@gmail.com" }
  s.platform     = :ios, '7.0'
  s.source       = { :git => "https://github.com/thanhtrdang/UncaughtExceptionHandler.git", :branch => "master" }
  s.source_files  = 'UncaughtExceptionHandler/UncaughtExceptionHandler.{h,m}'
  s.requires_arc = true
end