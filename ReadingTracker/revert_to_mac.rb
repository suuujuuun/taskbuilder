require 'xcodeproj'

project_path = 'ReadingTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['SDKROOT'] = 'macosx'
    config.build_settings.delete('TARGETED_DEVICE_FAMILY')
    config.build_settings['SUPPORTED_PLATFORMS'] = 'macosx'
  end
end

project.save
puts "Reverted to macOS project!"
