#!/usr/bin/env ruby
require 'xcodeproj'

# Open the Xcode project
project_path = 'Heirloom.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'Heirloom' }

# Find the Resources group (where Info.plist lives)
resources_group = project.main_group.find_subpath('Heirloom/Resources', true)

# Check if PrivacyInfo.xcprivacy already exists
privacy_manifest_path = 'Heirloom/PrivacyInfo.xcprivacy'
existing_file = resources_group.files.find { |f| f.path == 'PrivacyInfo.xcprivacy' }

if existing_file
  puts "✅ PrivacyInfo.xcprivacy is already in the project"
else
  # Add the file reference
  file_ref = resources_group.new_reference('PrivacyInfo.xcprivacy')
  file_ref.source_tree = '<group>'

  # Add to the target's resources build phase
  target.resources_build_phase.add_file_reference(file_ref)

  puts "✅ Added PrivacyInfo.xcprivacy to Xcode project"

  # Save the project
  project.save
  puts "✅ Saved project changes"
end

puts "\n📋 Privacy Manifest Status:"
puts "  Location: Heirloom/PrivacyInfo.xcprivacy"
puts "  Target: Heirloom"
puts "  Build Phase: Copy Bundle Resources"
