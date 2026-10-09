import re

def fix_games():
    with open('lib/screens/games_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()
    
    end_part = """              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}"""
    replacement = """              ),
            ),
          ],
        ),
      ),
    ],
  ),
));
  }
}"""
    if end_part in content:
        content = content.replace(end_part, replacement)
    else:
        # try regex fallback
        content = re.sub(r'\s*\),\s*\),\s*\),\s*],\s*\),\s*\),\s*\);\s*}\s*}', '\n              ),\n            ),\n          ],\n        ),\n      ),\n    ],\n  ),\n));\n  }\n}', content)
    
    with open('lib/screens/games_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

def fix_daily():
    with open('lib/screens/daily_run_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()
        
    content = re.sub(r'              \],\n              \],\n            \),\n          \),\n        \),\n      \),\n    \);', 
                     '              ],\n            ),\n          ),\n        ],\n      ),\n    ),\n  );', content)
                     
    with open('lib/screens/daily_run_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

def fix_leader():
    with open('lib/screens/leaderboard_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()
        
    content = re.sub(r'          \],\n            \),\n          \],\n        \),\n      \),\n    \)\);',
                     '          ],\n        ),\n      ),\n    ],\n  ),\n));', content)
                     
    with open('lib/screens/leaderboard_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

fix_games()
fix_daily()
fix_leader()
print("Fixed.")
