import re

def fix_gradients():
    colorful_linear_gradient = """        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E0854), // Vibrant deep purple
            Color(0xFF0F3460), // Deep blue
            Color(0xFF16213E), // Dark slate blue
          ],
        ),"""

    colorful_radial_gradient = """        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Color(0xFF2E0854), // Vibrant deep purple center
            Color(0xFF0F3460), // Deep blue edges
          ],
        ),"""

    # daily_run_screen
    with open('lib/screens/daily_run_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()
    content = re.sub(r'color: Color\(0xFF121212\),\s*gradient: LinearGradient\(\s*begin: Alignment\.topCenter,\s*end: Alignment\.bottomCenter,\s*colors: \[Color\(0xFF5E35B1\), Color\(0xFF121212\)\],\s*stops: \[0\.0, 0\.6\],\s*\),', colorful_linear_gradient, content)
    with open('lib/screens/daily_run_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

    # leaderboard_screen
    with open('lib/screens/leaderboard_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()
    content = re.sub(r'color: Color\(0xFF121212\),\s*gradient: LinearGradient\(\s*begin: Alignment\.topCenter,\s*end: Alignment\.bottomCenter,\s*colors: \[\s*Color\(0xFF5E35B1\), // Deep purple top\s*Color\(0xFF121212\), // Dark background bottom\s*\],\s*stops: \[0\.0, 0\.6\],\s*\),', colorful_linear_gradient, content)
    with open('lib/screens/leaderboard_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

    # profile_screen
    with open('lib/screens/profile_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()
    content = re.sub(r'color: Color\(0xFF050505\),\s*gradient: RadialGradient\(\s*center: Alignment\.center,\s*radius: 1\.5,\s*colors: \[\s*Color\(0xFF1A0B2E\), // Subtle dark purple center\s*Color\(0xFF050505\), // Almost black edges\s*\],\s*\),', colorful_radial_gradient, content)
    with open('lib/screens/profile_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

fix_gradients()
print("Gradients fixed.")
