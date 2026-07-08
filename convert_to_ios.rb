require 'xcodeproj'

project_path = 'ReadingTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['SDKROOT'] = 'iphoneos'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
  end
end

project.save
puts "Converted to iOS project!"
