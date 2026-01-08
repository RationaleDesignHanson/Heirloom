#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/matthanson/Heirloom/Heirloom.xcodeproj'
file_path = 'Heirloom/Core/Services/LanguageDetectionService.swift'

puts "Opening Xcode project..."
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'Heirloom' }

# Find the Services group
services_group = project.main_group.find_subpath('Heirloom/Core/Services', true)

# Add the file reference
file_ref = services_group.new_reference(file_path)

# Add to build phase
target.add_file_references([file_ref])

puts "Saving project..."
project.save

puts "✅ Added LanguageDetectionService.swift to Xcode project"
