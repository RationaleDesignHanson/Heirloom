#!/usr/bin/env ruby
# Script to add test helper files to Xcode project

require 'xcodeproj'

PROJECT_PATH = 'Heirloom.xcodeproj'
FILES_TO_ADD = [
  {
    path: 'HeirloomTests/Helpers/ServiceContainer+Testing.swift',
    target: 'HeirloomTests'
  },
  {
    path: 'HeirloomTests/Helpers/HeirloomTestCase.swift',
    target: 'HeirloomTests'
  }
]

puts "🔧 Adding test helper files to Xcode project..."

# Open the project
project = Xcodeproj::Project.open(PROJECT_PATH)

# Find the test target
test_target = project.targets.find { |t| t.name == 'HeirloomTests' }

unless test_target
  puts "❌ Could not find HeirloomTests target"
  exit 1
end

# Find the Helpers group
helpers_group = project.main_group['HeirloomTests']&.[]('Helpers')

unless helpers_group
  puts "❌ Could not find Helpers group in HeirloomTests"
  exit 1
end

FILES_TO_ADD.each do |file_info|
  file_path = file_info[:path]
  file_name = File.basename(file_path)

  # Check if file already exists in project
  existing_file = helpers_group.files.find { |f| f.path == file_name }

  if existing_file
    puts "✅ #{file_name} already in project"
    next
  end

  # Add file to project
  file_ref = helpers_group.new_file(file_path)

  # Add to target
  test_target.add_file_references([file_ref])

  puts "✅ Added #{file_name} to project and target"
end

# Save the project
project.save

puts "✅ Successfully added all test helper files to Xcode project"
