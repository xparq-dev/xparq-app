import os
try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    import sys
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow"])
    from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_logo():
    # 1024x1024 image
    size = 1024
    circle_color = (10, 31, 58, 255) # Dark blue/black for the circle
    bolt_color = (29, 155, 240, 255) # #1D9BF0
    
    # Bolt points (Recalculated for perfect centering and symmetry)
    # Target center is (512, 512)
    # Bolt width is ~300, height is ~500
    bolt_points = [
        (562, 262),  # Top point (pushed right)
        (362, 562),  # Left middle
        (487, 562),  # Mid indent
        (462, 762),  # Bottom point (pushed left)
        (662, 462),  # Right middle
        (537, 462),  # Mid indent
    ]

    os.makedirs('assets/images', exist_ok=True)

    def generate_variant(name, background_color, include_circle=True):
        img = Image.new('RGBA', (size, size), background_color)
        draw = ImageDraw.Draw(img)
        
        if include_circle:
            # Draw the circle background
            # 800x800 circle, centered (starts at 112)
            margin = 112
            draw.ellipse([margin, margin, size - margin, size - margin], fill=circle_color)

        # Draw the bolt with some glow
        glow_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        glow_draw = ImageDraw.Draw(glow_layer)
        glow_draw.polygon(bolt_points, fill=bolt_color)
        glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=10))
        img.alpha_composite(glow_layer)

        # Final bolt
        draw.polygon(bolt_points, fill=bolt_color)
        img.save(f'assets/images/{name}.png')

    # 1. Splash Screen Logo (Transparent background, circular bolt)
    generate_variant('perfect_splash_logo', (0, 0, 0, 0), include_circle=True)

    # 2. iOS App Icon (Solid circle color as background background)
    generate_variant('perfect_ios_logo', circle_color, include_circle=True)

    # 3. Android Adaptive Foreground (Transparent bg, JUST bolt or bolt in circle)
    # For adaptive, we'll keep the circle as it's part of the new requested design
    generate_variant('perfect_android_fg', (0, 0, 0, 0), include_circle=True)
    
    # 4. Update legacy name
    generate_variant('perfect_thunder_logo', (0, 0, 0, 0), include_circle=True)

    print("All Logo variants (Circular Bolt) saved successfully.")

if __name__ == "__main__":
    create_logo()
