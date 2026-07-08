require 'xcodeproj'

project_path = 'ReadingTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'ReadingTracker' }

# Group to add files
group = project.main_group.find_subpath(File.join('ReadingTracker'), true)
models_group = group.find_subpath('Models', true)
views_group = group.find_subpath('Views', true)

# Remove old files from target and group
['Persistence.swift', 'ReadingTracker.xcdatamodeld'].each do |file_name|
  file_ref = group.children.find { |c| c.path == file_name }
  if file_ref
    target.source_build_phase.files_references.delete(file_ref)
    file_ref.remove_from_project
  end
end

# Add Models
models_file = models_group.new_file('Models.swift')
target.source_build_phase.add_file_reference(models_file) unless target.source_build_phase.files_references.include?(models_file)

# Add Views
views = [
  'ContentView.swift',
  'DetailsView.swift',
  'OverviewView.swift',
  'PapersView.swift',
  'PlanningView.swift',
  'KnowledgeGraphView.swift'
]

# For ContentView, it's in the root ReadingTracker folder, not Views folder!
content_view_ref = group.children.find { |c| c.path == 'ContentView.swift' }
unless content_view_ref
  content_view_ref = group.new_file('ContentView.swift')
end
target.source_build_phase.add_file_reference(content_view_ref) unless target.source_build_phase.files_references.include?(content_view_ref)

# Other views are in Views folder
views[1..-1].each do |view_file|
  file_ref = views_group.new_file(view_file)
  target.source_build_phase.add_file_reference(file_ref) unless target.source_build_phase.files_references.include?(file_ref)
end

project.save
puts "Xcode project updated successfully!"
