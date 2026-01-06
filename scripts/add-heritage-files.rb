#!/usr/bin/env ruby

require 'xcodeproj'

project_path = '/Users/matthanson/Heirloom/Heirloom.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'Heirloom' }

# Files to add
files_to_add = [
  {
    path: 'Heirloom/Core/Services/HeritageRecipeSeeder.swift',
    group_path: ['Heirloom', 'Core', 'Services']
  },
  {
    path: 'Heirloom/Features/Collections/CollectionsListView.swift',
    group_path: ['Heirloom', 'Features', 'Collections']
  },
  {
    path: 'Heirloom/Features/Collections/CollectionDetailView.swift',
    group_path: ['Heirloom', 'Features', 'Collections']
  }
]

files_to_add.each do |file_info|
  # Navigate to the correct group
  group = project.main_group
  file_info[:group_path].each do |group_name|
    group = group.groups.find { |g| g.name == group_name || g.path == group_name }
    if group.nil?
      puts "Warning: Could not find group #{group_name}"
      break
    end
  end

  next if group.nil?

  # Check if file already exists in project
  existing_file = group.files.find { |f| f.path == File.basename(file_info[:path]) }
  if existing_file
    puts "File already exists in project: #{file_info[:path]}"
    next
  end

  # Add file reference
  file_ref = group.new_file(file_info[:path])

  # Add to build phase
  target.source_build_phase.add_file_reference(file_ref)

  puts "Added: #{file_info[:path]}"
end

# Also add the JSON file as a resource
resources_group = project.main_group['Heirloom']['Resources']
if resources_group
  heritage_group = resources_group['HeritageCollections'] || resources_group.new_group('HeritageCollections')

  json_file = heritage_group.files.find { |f| f.path == 'heritage-recipes.json' }
  unless json_file
    json_ref = heritage_group.new_file('Heirloom/Resources/HeritageCollections/heritage-recipes.json')
    target.resources_build_phase.add_file_reference(json_ref)
    puts "Added: heritage-recipes.json"
  end
end

# Save project
project.save

puts "Project updated successfully!"
