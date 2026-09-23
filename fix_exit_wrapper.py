import os
import glob
import re

games_dir = r"c:\Users\MONSTER\Documents\Flutter Projeler\daily_games\lib\games"
dart_files = glob.glob(os.path.join(games_dir, "**/*.dart"), recursive=True)

for file in dart_files:
    game_id = os.path.basename(os.path.dirname(file))
    if not game_id or game_id == 'games' or 'widgets' in file or 'models' in file or 'utils' in file:
        continue
    
    # We map folder names to gameIds if needed, usually they match
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if "GameExitWrapper(child:" in content:
        # Some have "GameExitWrapper(child:"
        # Replace "GameExitWrapper(" with "GameExitWrapper(gameId: 'game_id', isDailyMode: widget.isDailyMode, "
        # BUT only if it hasn't been added yet
        if "isDailyMode: widget.isDailyMode" not in content:
            # Note: sound_screen uses widget.isDailyMode too? Yes, almost all use widget.isDailyMode.
            # Let's replace GameExitWrapper(child: with GameExitWrapper(gameId: '{game_id}', isDailyMode: widget.isDailyMode, child:
            new_content = content.replace("GameExitWrapper(child:", f"GameExitWrapper(gameId: '{game_id}', isDailyMode: widget.isDailyMode, child:")
            new_content = new_content.replace("GameExitWrapper(\n", f"GameExitWrapper(\n      gameId: '{game_id}',\n      isDailyMode: widget.isDailyMode,\n")
            
            with open(file, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Updated {file}")
