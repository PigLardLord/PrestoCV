#!/usr/bin/env python3
"""
Template Manifest Update Utility

This script updates .mcvt template files to ensure all required manifest fields are present.
Useful when the TemplateManifest structure changes or when bundled templates need updating.

Required TemplateManifest fields:
- id: String
- name: String
- description: String
- author: String
- version: String
- previewImage: String
- price: Double
- previewImageBase64: String? (optional)

Usage:
    python3 update_template_manifests.py [template_file.mcvt ...]

    If no arguments provided, updates all .mcvt files in ../Resources/Templates/Bundled/

Examples:
    # Update all bundled templates
    python3 update_template_manifests.py

    # Update specific template
    python3 update_template_manifests.py ../Resources/Templates/Bundled/professional.mcvt

    # Update multiple templates
    python3 update_template_manifests.py template1.mcvt template2.mcvt
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Optional


def update_manifest_fields(manifest: Dict, template_id: str) -> Dict:
    """
    Add missing required fields to a template manifest.

    Args:
        manifest: The manifest dictionary to update
        template_id: The template ID (used for generating defaults)

    Returns:
        Updated manifest with all required fields
    """
    # Required fields with default values
    defaults = {
        'author': 'PrestoCV',
        'previewImage': 'preview.png',
        'price': 0.0
    }

    updated = False
    for field, default_value in defaults.items():
        if field not in manifest:
            manifest[field] = default_value
            updated = True
            print(f"  ✅ Added missing field: {field} = {repr(default_value)}")

    if not updated:
        print(f"  ✓ All required fields already present")

    return manifest


def update_mcvt_file(filepath: Path) -> bool:
    """
    Update a single .mcvt file with required manifest fields.

    Args:
        filepath: Path to the .mcvt file

    Returns:
        True if successful, False otherwise
    """
    try:
        # Read the file
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)

        if 'manifest' not in data:
            print(f"❌ {filepath.name}: No 'manifest' key found")
            return False

        template_id = data['manifest'].get('id', filepath.stem)
        print(f"\n📝 Updating {filepath.name} (id: {template_id})...")

        # Update manifest
        data['manifest'] = update_manifest_fields(data['manifest'], template_id)

        # Write back to file with pretty formatting
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

        print(f"✅ Successfully updated {filepath.name}")
        return True

    except json.JSONDecodeError as e:
        print(f"❌ {filepath.name}: Invalid JSON - {e}")
        return False
    except Exception as e:
        print(f"❌ {filepath.name}: Error - {e}")
        return False


def get_bundled_templates() -> List[Path]:
    """
    Get all .mcvt files from the default bundled templates directory.

    Returns:
        List of paths to bundled template files
    """
    script_dir = Path(__file__).parent
    bundled_dir = script_dir.parent / 'Resources' / 'Templates' / 'Bundled'

    if not bundled_dir.exists():
        print(f"⚠️ Bundled templates directory not found: {bundled_dir}")
        return []

    return list(bundled_dir.glob('*.mcvt'))


def main():
    """Main entry point for the script."""
    print("=" * 70)
    print("Template Manifest Update Utility")
    print("=" * 70)

    # Determine which files to process
    if len(sys.argv) > 1:
        # Process files from command line arguments
        template_files = [Path(arg) for arg in sys.argv[1:]]
        print(f"\nProcessing {len(template_files)} template(s) from arguments...")
    else:
        # Process all bundled templates
        template_files = get_bundled_templates()
        if not template_files:
            print("\n❌ No template files found to process")
            sys.exit(1)
        print(f"\nFound {len(template_files)} bundled template(s)...")

    # Validate files exist
    missing_files = [f for f in template_files if not f.exists()]
    if missing_files:
        print(f"\n❌ The following files do not exist:")
        for f in missing_files:
            print(f"   - {f}")
        sys.exit(1)

    # Process each file
    success_count = 0
    for template_file in template_files:
        if update_mcvt_file(template_file):
            success_count += 1

    # Summary
    print("\n" + "=" * 70)
    print(f"Summary: {success_count}/{len(template_files)} templates updated successfully")
    print("=" * 70)

    sys.exit(0 if success_count == len(template_files) else 1)


if __name__ == '__main__':
    main()
