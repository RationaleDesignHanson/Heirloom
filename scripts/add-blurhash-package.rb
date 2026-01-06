#!/usr/bin/env ruby

require 'xcodeproj'

project_path = '/Users/matthanson/Heirloom/Heirloom.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'Heirloom' }

# Check if Blurhash package already exists
existing_package = project.root_object.package_references.find do |package|
  package.requirement.to_s.include?('blurhash') ||
  package.repositoryURL.include?('blurhash')
end

if existing_package
  puts "Blurhash package already exists in project"
else
  # Add Blurhash package reference
  package_ref = project.root_object.new_package(
    'https://github.com/woltapp/blurhash',
    requirement: { kind: 'upToNextMajorVersion', minimumVersion: '0.0.1' },
    name: 'Blurhash'
  )

  # Add package product to target
  package_product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  package_product.package = package_ref
  package_product.product_name = 'BlurHashKit'

  target.package_product_dependencies << package_product

  puts "Added Blurhash package to project"
end

# Save project
project.save

puts "Project updated successfully!"
