# Scripts

## update_template_manifests.py

Adds to the manifest of a `.mcvt` package the fields it lacks, with these values: `author` "PrestoCV", `previewImage` "preview.png" and `price` 0.0. A field the manifest already has is never changed. Use it when `TemplateManifest` gains a required field, or on a new package.

```bash
# every package in ../Resources/Templates/Bundled (found from the script's own folder)
python3 update_template_manifests.py

# only the packages given
python3 update_template_manifests.py ../Resources/Templates/Bundled/professional.mcvt
```

The package format and its rules are in [TEMPLATE_SYSTEM_ARCHITECTURE.md](../TEMPLATE_SYSTEM_ARCHITECTURE.md#the-mcvt-package).
