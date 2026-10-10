"""Render the approved reverse SariSupply symbol into Android launcher icons.

Requires ImageMagick's `convert`; preserves the supplied symbol geometry.
"""

from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "packages/sarisupply_design_system/assets/brand"
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def main():
    renderer = shutil.which("convert")
    if not renderer:
        raise SystemExit("Install ImageMagick to render launcher icons.")
    symbol = ET.parse(BRAND / "sarisupply_symbol.svg").getroot()
    for group in symbol.iter("{http://www.w3.org/2000/svg}g"):
        group.set("fill", "#FFFFFF")
    icon = ET.Element("svg", xmlns="http://www.w3.org/2000/svg",
                      viewBox="0 0 1024 1024", width="1024", height="1024")
    ET.SubElement(icon, "rect", width="1024", height="1024", rx="192", fill="#C84A00")
    # Use a group transform: SVG renderers differ in nested-SVG positioning.
    placement = ET.SubElement(icon, "g", transform="translate(180 230)")
    for child in symbol:
        if child.tag.endswith("}g"):
            placement.append(child)
    source = ET.tostring(icon)
    images = {density: subprocess.run(
        [renderer, "-background", "none", "svg:-", "-resize", str(size), "png:-"],
        input=source, stdout=subprocess.PIPE, check=True).stdout
        for density, size in SIZES.items()}
    for app in ("pos", "admin", "driver"):
        for density, image in images.items():
            target = ROOT / f"apps/{app}/android/app/src/main/res/mipmap-{density}/ic_launcher.png"
            target.write_bytes(image)
    print("Rendered 15 Android launcher icons from the approved symbol.")


if __name__ == "__main__":
    main()
