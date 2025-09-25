from PIL import Image, ImageDraw
import math

def create_carbon_tracker_icon():
    # Create a 512x512 image
    size = 512
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Define colors (matching AppBar icon)
    color1 = (102, 187, 106)  # #66BB6A - Colors.green.shade400
    color2 = (46, 125, 50)    # #2E7D32 - Colors.green.shade700
    
    # Corner radius
    corner_radius = int(size * 0.2)  # 20% of size
    
    # Create rounded rectangle background with gradient effect
    # We'll simulate gradient by drawing multiple rectangles with slight color variations
    steps = 50
    for i in range(steps):
        # Calculate color interpolation
        ratio = i / (steps - 1)
        r = int(color1[0] * (1 - ratio) + color2[0] * ratio)
        g = int(color1[1] * (1 - ratio) + color2[1] * ratio)
        b = int(color1[2] * (1 - ratio) + color2[2] * ratio)
        
        # Calculate position for diagonal gradient
        offset = int(i * 2)
        draw.rounded_rectangle(
            [offset, offset, size - offset, size - offset],
            radius=corner_radius,
            fill=(r, g, b, 255)
        )
    
    # Draw eco leaf icon (simplified version)
    center_x, center_y = size // 2, size // 2
    leaf_size = int(size * 0.35)
    
    # Main leaf shape - using polygon to approximate the eco icon
    leaf_points = [
        (center_x, center_y - leaf_size),  # top
        (center_x + leaf_size * 0.6, center_y - leaf_size * 0.3),  # top right
        (center_x + leaf_size * 0.8, center_y + leaf_size * 0.2),  # right
        (center_x + leaf_size * 0.3, center_y + leaf_size * 0.6),  # bottom right
        (center_x, center_y + leaf_size * 0.4),  # bottom center
        (center_x - leaf_size * 0.3, center_y + leaf_size * 0.6),  # bottom left
        (center_x - leaf_size * 0.8, center_y + leaf_size * 0.2),  # left
        (center_x - leaf_size * 0.6, center_y - leaf_size * 0.3),  # top left
    ]
    
    # Draw leaf shape
    draw.polygon(leaf_points, fill=(255, 255, 255, 255))
    
    # Add leaf vein
    vein_points = [
        (center_x, center_y - leaf_size * 0.8),
        (center_x, center_y + leaf_size * 0.3)
    ]
    draw.line(vein_points, fill=(255, 255, 255, 200), width=6)
    
    # Add some small details to make it more eco-like
    # Small circles representing nature elements
    detail_points = [
        (center_x - leaf_size * 0.4, center_y - leaf_size * 0.1),
        (center_x + leaf_size * 0.4, center_y + leaf_size * 0.1),
        (center_x - leaf_size * 0.1, center_y + leaf_size * 0.4),
    ]
    
    for point in detail_points:
        draw.ellipse([point[0]-4, point[1]-4, point[0]+4, point[1]+4], 
                    fill=(255, 255, 255, 180))
    
    return img

# Create the icon
icon = create_carbon_tracker_icon()
icon.save('assets/icons/app_icon.png')
print('✅ Generated app icon: assets/icons/app_icon.png')
print('📏 Icon size: 512x512px')