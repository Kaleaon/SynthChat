"""
Avatar generator for SynthChat characters.

Provides multiple methods for generating character avatars:
1. Procedural generation using PIL
2. AI-based generation using OpenAI DALL-E (if available)
"""

import os
import hashlib
import random
from typing import Optional, Tuple

try:
    from PIL import Image, ImageDraw, ImageFont
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False


# Color palettes for procedural avatars
AVATAR_COLORS = [
    ('#6366f1', '#8b5cf6'),  # Purple gradient
    ('#3b82f6', '#06b6d4'),  # Blue gradient
    ('#10b981', '#34d399'),  # Green gradient
    ('#f59e0b', '#fbbf24'),  # Amber gradient
    ('#ef4444', '#f87171'),  # Red gradient
    ('#ec4899', '#f472b6'),  # Pink gradient
    ('#8b5cf6', '#a78bfa'),  # Violet gradient
    ('#14b8a6', '#2dd4bf'),  # Teal gradient
]

BACKGROUND_COLORS = [
    '#1a1a2e',
    '#16213e',
    '#0f3460',
    '#1f2937',
    '#111827',
]


def generate_procedural_avatar(
    name: str,
    size: Tuple[int, int] = (256, 256),
    output_path: Optional[str] = None
) -> Optional[str]:
    """
    Generate a procedural avatar based on the character name.
    
    Args:
        name: Character name (used for consistent color generation)
        size: Image size tuple (width, height)
        output_path: Optional path to save the image
        
    Returns:
        Path to the generated avatar, or None if PIL is not available
    """
    if not PIL_AVAILABLE:
        return None
    
    # Use name hash for consistent colors
    name_hash = int(hashlib.md5(name.encode()).hexdigest()[:8], 16)
    random.seed(name_hash)
    
    # Select colors
    primary, secondary = random.choice(AVATAR_COLORS)
    bg_color = random.choice(BACKGROUND_COLORS)
    
    # Create image
    img = Image.new('RGB', size, bg_color)
    draw = ImageDraw.Draw(img)
    
    width, height = size
    center_x, center_y = width // 2, height // 2
    
    # Draw gradient circle background
    for i in range(min(width, height) // 2, 0, -1):
        ratio = i / (min(width, height) // 2)
        r1, g1, b1 = int(primary[1:3], 16), int(primary[3:5], 16), int(primary[5:7], 16)
        r2, g2, b2 = int(secondary[1:3], 16), int(secondary[3:5], 16), int(secondary[5:7], 16)
        
        r = int(r1 * ratio + r2 * (1 - ratio))
        g = int(g1 * ratio + g2 * (1 - ratio))
        b = int(b1 * ratio + b2 * (1 - ratio))
        
        draw.ellipse(
            [center_x - i, center_y - i, center_x + i, center_y + i],
            fill=f'#{r:02x}{g:02x}{b:02x}'
        )
    
    # Draw initial letter(s)
    initials = ''.join(word[0].upper() for word in name.split()[:2])
    if len(initials) == 0:
        initials = name[0].upper() if name else '?'
    
    # Use a large font size
    font_size = width // 3
    
    try:
        # Try to use a nice font
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", font_size)
    except (OSError, IOError):
        try:
            font = ImageFont.truetype("arial.ttf", font_size)
        except (OSError, IOError):
            # Fallback to default font
            font = ImageFont.load_default()
    
    # Get text bounding box
    bbox = draw.textbbox((0, 0), initials, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    # Center the text
    x = (width - text_width) // 2
    y = (height - text_height) // 2 - bbox[1]
    
    # Draw text with slight shadow
    draw.text((x + 2, y + 2), initials, fill='#00000044', font=font)
    draw.text((x, y), initials, fill='white', font=font)
    
    # Add some decorative elements based on name hash
    if name_hash % 3 == 0:
        # Add sparkles
        for _ in range(5):
            sx = random.randint(0, width)
            sy = random.randint(0, height)
            sr = random.randint(2, 5)
            draw.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill='#ffffff44')
    
    if output_path:
        img.save(output_path, 'PNG', optimize=True)
        return output_path
    
    return None


def create_default_avatar(output_path: str) -> bool:
    """
    Create the default avatar image.
    
    Args:
        output_path: Path to save the default avatar
        
    Returns:
        True if successful, False otherwise
    """
    if not PIL_AVAILABLE:
        return False
    
    try:
        size = (256, 256)
        img = Image.new('RGB', size, '#1a1a2e')
        draw = ImageDraw.Draw(img)
        
        center_x, center_y = size[0] // 2, size[1] // 2
        radius = 80
        
        # Draw gradient circle
        for i in range(radius, 0, -1):
            ratio = i / radius
            r = int(99 * ratio + 139 * (1 - ratio))
            g = int(102 * ratio + 92 * (1 - ratio))
            b = int(241 * ratio + 246 * (1 - ratio))
            draw.ellipse(
                [center_x - i, center_y - i, center_x + i, center_y + i],
                fill=f'#{r:02x}{g:02x}{b:02x}'
            )
        
        # Draw a simple face outline
        # Eyes
        eye_y = center_y - 15
        draw.ellipse([center_x - 30, eye_y - 8, center_x - 14, eye_y + 8], fill='white')
        draw.ellipse([center_x + 14, eye_y - 8, center_x + 30, eye_y + 8], fill='white')
        draw.ellipse([center_x - 25, eye_y - 4, center_x - 17, eye_y + 4], fill='#1a1a2e')
        draw.ellipse([center_x + 17, eye_y - 4, center_x + 25, eye_y + 4], fill='#1a1a2e')
        
        # Smile
        draw.arc([center_x - 25, center_y, center_x + 25, center_y + 30], 
                 start=20, end=160, fill='white', width=3)
        
        img.save(output_path, 'PNG', optimize=True)
        return True
    except Exception as e:
        print(f"Error creating default avatar: {e}")
        return False


def generate_ai_avatar(
    prompt: str,
    output_path: str,
    api_key: Optional[str] = None
) -> Optional[str]:
    """
    Generate an avatar using OpenAI's DALL-E.
    
    Args:
        prompt: Description of the character for image generation
        output_path: Path to save the generated image
        api_key: OpenAI API key (optional, uses env var if not provided)
        
    Returns:
        Path to the generated avatar, or None if failed
    """
    try:
        from openai import OpenAI
        import requests
        
        api_key = api_key or os.getenv('OPENAI_API_KEY')
        if not api_key:
            return None
        
        client = OpenAI(api_key=api_key)
        
        # Enhance prompt for avatar generation
        full_prompt = f"Character avatar portrait, {prompt}, digital art, vibrant colors, clean lines, suitable for profile picture, square aspect ratio"
        
        response = client.images.generate(
            model="dall-e-3",
            prompt=full_prompt,
            size="1024x1024",
            quality="standard",
            n=1,
        )
        
        # Download and save the image
        image_url = response.data[0].url
        image_response = requests.get(image_url)
        
        if image_response.status_code == 200:
            with open(output_path, 'wb') as f:
                f.write(image_response.content)
            
            # Resize to 512x512
            if PIL_AVAILABLE:
                img = Image.open(output_path)
                img.thumbnail((512, 512), Image.Resampling.LANCZOS)
                img.save(output_path, quality=85, optimize=True)
            
            return output_path
        
    except Exception as e:
        print(f"Error generating AI avatar: {e}")
    
    return None


if __name__ == '__main__':
    # Test avatar generation
    import tempfile
    
    # Generate procedural avatar
    with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as f:
        path = generate_procedural_avatar("Alice", output_path=f.name)
        print(f"Generated procedural avatar: {path}")
    
    # Create default avatar
    default_path = os.path.join(os.path.dirname(__file__), 'static', 'avatars', 'default.png')
    if create_default_avatar(default_path):
        print(f"Created default avatar: {default_path}")
