import os

BASE_DIR = os.path.join(os.path.dirname(__file__), 'lib', 'games')

def fix_back_button(content):
    import re
    # We want to replace the complex onPressed block with () => Navigator.maybePop(context)
    # The block looks like:
    # onPressed: () async {
    #   final shouldPop = await showExitConfirmDialog(context);
    #   if (shouldPop && context.mounted) {
    #     Navigator.of(context).pop();
    #   }
    # },
    
    pattern = re.compile(r"onPressed:\s*\(\)\s*async\s*\{\s*final shouldPop = await showExitConfirmDialog\(context\);\s*if \(shouldPop && context\.mounted\)\s*\{\s*Navigator\.of\(context\)\.pop\(\);\s*\}\s*\},", re.MULTILINE)
    
    return pattern.sub("onPressed: () => Navigator.maybePop(context),", content)

def process_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    new_content = fix_back_button(content)
    
    if content != new_content:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print("Fixed back button in", path)

for root, dirs, files in os.walk(BASE_DIR):
    for file in files:
        if file.endswith('_screen.dart'):
            process_file(os.path.join(root, file))
