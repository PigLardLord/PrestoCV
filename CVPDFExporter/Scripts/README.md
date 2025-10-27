# CVPDFExporter Scripts

Utility scripts for maintaining and managing the CVPDFExporter package.

## Available Scripts

### update_template_manifests.py

Updates .mcvt template files to ensure all required manifest fields are present. This is useful when:
- The `TemplateManifest` structure changes and new required fields are added
- Bundled templates need to be updated with missing fields
- Creating new templates and want to ensure they have all required fields

**Required TemplateManifest fields:**
- `id: String` - Unique template identifier
- `name: String` - Display name
- `description: String` - Template description
- `author: String` - Template author
- `version: String` - Semantic version (e.g., "1.0.0")
- `previewImage: String` - Preview image filename
- `price: Double` - Template price (0.0 for free templates)
- `previewImageBase64: String?` - Optional base64-encoded preview

**Usage:**

```bash
# Update all bundled templates (default behavior)
python3 update_template_manifests.py

# Update specific template
python3 update_template_manifests.py ../Resources/Templates/Bundled/professional.mcvt

# Update multiple templates
python3 update_template_manifests.py template1.mcvt template2.mcvt
```

**Example output:**

```
======================================================================
Template Manifest Update Utility
======================================================================

Found 3 bundled template(s)...

📝 Updating professional.mcvt (id: professional)...
  ✅ Added missing field: author = 'PrestoCV'
  ✅ Added missing field: previewImage = 'preview.png'
  ✅ Added missing field: price = 0.0
✅ Successfully updated professional.mcvt

======================================================================
Summary: 3/3 templates updated successfully
======================================================================
```

**Default values added:**
- `author`: "PrestoCV"
- `previewImage`: "preview.png"
- `price`: 0.0

**Note:** The script only adds missing fields - it never modifies existing fields.

## Adding New Scripts

When adding new utility scripts:

1. Create the script file in this directory
2. Make it executable: `chmod +x script_name.py`
3. Add documentation to this README
4. Use clear, descriptive names
5. Include a shebang line (`#!/usr/bin/env python3`)
6. Add comprehensive help/usage documentation in the script
