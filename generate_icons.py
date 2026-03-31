#!/usr/bin/env python3
"""
Script to copy edicion-de-fotos.png as PWA icons
Since PIL might not be available, we'll just copy the file
"""
import os
import shutil

def generate_icons():
    # Path to the source image
    source_path = os.path.join('assets', 'images', 'edicion-de-fotos.png')
    web_icons_path = os.path.join('web', 'icons')

    # Create icons directory if it doesn't exist
    os.makedirs(web_icons_path, exist_ok=True)

    # Copy the source image as different icon sizes
    # Note: In a real PWA, you'd want properly sized icons, but for now we'll use the same image
    sizes = ['192', '512']

    for size in sizes:
        # Copy regular icon
        icon_path = os.path.join(web_icons_path, f'Icon-{size}.png')
        shutil.copy2(source_path, icon_path)
        print(f'Generated {icon_path}')

        # Copy maskable icon
        maskable_path = os.path.join(web_icons_path, f'Icon-maskable-{size}.png')
        shutil.copy2(source_path, maskable_path)
        print(f'Generated {maskable_path}')

if __name__ == '__main__':
    generate_icons()