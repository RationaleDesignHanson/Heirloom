#!/usr/bin/env python3
"""
Quick script to add missing Swift files to Xcode project.
This modifies the project.pbxproj file directly.
"""
import uuid
import sys

# Files to add
files_to_add = [
    ("Heirloom/Core/Design/Components/CustomizationOverlayView.swift", "CustomizationOverlayView.swift"),
    ("Heirloom/Core/Design/Components/RecipeCardBackPreview.swift", "RecipeCardBackPreview.swift"),
    ("Heirloom/Core/Design/Components/FlipAffordanceBadge.swift", "FlipAffordanceBadge.swift"),
    ("Heirloom/Features/Settings/HeritageRecipeCleanupView.swift", "HeritageRecipeCleanupView.swift"),
]

def generate_uuid():
    """Generate a UUID in Xcode format (24 uppercase hex chars)"""
    return uuid.uuid4().hex.upper()[:24]

def add_files_to_xcode():
    project_path = "Heirloom.xcodeproj/project.pbxproj"

    # Read the project file
    with open(project_path, 'r') as f:
        content = f.read()

    # Generate UUIDs for each file (we need 2 per file: PBXFileReference and PBXBuildFile)
    file_refs = []
    build_files = []

    for file_path, file_name in files_to_add:
        # Check if file is already in project
        if file_name in content:
            print(f"✅ {file_name} already in project")
            continue

        file_ref_uuid = generate_uuid()
        build_file_uuid = generate_uuid()

        file_refs.append((file_ref_uuid, file_path, file_name))
        build_files.append((build_file_uuid, file_ref_uuid, file_name))

        print(f"📝 Adding {file_name}...")
        print(f"   FileRef: {file_ref_uuid}")
        print(f"   BuildFile: {build_file_uuid}")

    if not file_refs:
        print("✅ All files already in project!")
        return

    # Find the PBXFileReference section
    pbx_file_ref_marker = "/* Begin PBXFileReference section */"
    pbx_file_ref_end = "/* End PBXFileReference section */"

    # Find the PBXBuildFile section
    pbx_build_file_marker = "/* Begin PBXBuildFile section */"
    pbx_build_file_end = "/* End PBXBuildFile section */"

    # Find the PBXSourcesBuildPhase section to add to sources
    pbx_sources_marker = "/* Begin PBXSourcesBuildPhase section */"

    # Insert PBXFileReference entries
    file_ref_index = content.find(pbx_file_ref_end)
    if file_ref_index == -1:
        print("❌ Could not find PBXFileReference section")
        return

    for file_ref_uuid, file_path, file_name in file_refs:
        file_ref_entry = f"\t\t{file_ref_uuid} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_name}; sourceTree = \"<group>\"; }};\n"
        content = content[:file_ref_index] + file_ref_entry + content[file_ref_index:]
        file_ref_index += len(file_ref_entry)

    # Insert PBXBuildFile entries
    build_file_index = content.find(pbx_build_file_end)
    if build_file_index == -1:
        print("❌ Could not find PBXBuildFile section")
        return

    for build_file_uuid, file_ref_uuid, file_name in build_files:
        build_file_entry = f"\t\t{build_file_uuid} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {file_name} */; }};\n"
        content = content[:build_file_index] + build_file_entry + content[build_file_index:]
        build_file_index += len(build_file_entry)

    # Find the PBXSourcesBuildPhase files array and add our build files
    sources_index = content.find(pbx_sources_marker)
    if sources_index == -1:
        print("❌ Could not find PBXSourcesBuildPhase section")
        return

    # Find the first "files = (" after the marker
    files_array_start = content.find("files = (", sources_index)
    if files_array_start == -1:
        print("❌ Could not find files array in PBXSourcesBuildPhase")
        return

    # Find the position right after "files = (\n"
    insert_pos = content.find("\n", files_array_start) + 1

    for build_file_uuid, _, file_name in build_files:
        build_ref_entry = f"\t\t\t\t{build_file_uuid} /* {file_name} in Sources */,\n"
        content = content[:insert_pos] + build_ref_entry + content[insert_pos:]
        insert_pos += len(build_ref_entry)

    # Write back
    with open(project_path, 'w') as f:
        f.write(content)

    print(f"\n✅ Added {len(file_refs)} file(s) to Xcode project")
    print("⚠️  You may need to close and reopen Xcode for changes to take effect")

if __name__ == "__main__":
    add_files_to_xcode()
