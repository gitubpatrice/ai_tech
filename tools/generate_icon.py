"""Génère l'icône d'AI Tech aux différentes résolutions Android.

Reprend la charte Files Tech :
- 4 quadrants bleu/rouge alternés
- Plaque blanche centrale arrondie
- Texte "AI Tech" en or

Lancer une fois pour produire les ic_launcher.png dans les dossiers mipmap-*.
Sortie ronde supplémentaire dans assets/icon/ pour Adaptive Icons.
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

# Couleurs charte Files Tech
BLUE = (38, 96, 199)        # bleu Files Tech (estimé d'après PDF/RFT)
RED = (203, 33, 41)         # rouge Files Tech
WHITE = (255, 255, 255)
GOLD = (212, 161, 27)       # or chaud (D4A11B)
GOLD_DARK = (160, 115, 0)   # ombre légère pour profondeur

# Tailles Android
SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Taille master pour rendu propre, puis downsample
MASTER = 1024


def find_font(size: int) -> ImageFont.ImageFont:
    """Cherche une police bold disponible sur Windows, fallback sur defaut."""
    candidates = [
        r"C:\Windows\Fonts\segoeuib.ttf",   # Segoe UI Bold
        r"C:\Windows\Fonts\arialbd.ttf",
        r"C:\Windows\Fonts\arial.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def render_master() -> Image.Image:
    """Produit l'icône master 1024x1024 — quadrants Files Tech + 'AI Tech' blanc."""
    img = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    half = MASTER // 2
    # Quadrants : top-left bleu, top-right rouge, bottom-left rouge, bottom-right bleu
    draw.rectangle([0, 0, half, half], fill=BLUE)
    draw.rectangle([half, 0, MASTER, half], fill=RED)
    draw.rectangle([0, half, half, MASTER], fill=RED)
    draw.rectangle([half, half, MASTER, MASTER], fill=BLUE)

    # "AI" sur la première ligne, "Tech" sur la seconde, en blanc gras.
    # Légère ombre portée pour décoller le texte du fond bicolore.
    line_top = "AI"
    line_bottom = "Tech"
    font_size = int(MASTER * 0.34)
    font = find_font(font_size)

    bbox_top = draw.textbbox((0, 0), line_top, font=font)
    tw_t, th_t = bbox_top[2] - bbox_top[0], bbox_top[3] - bbox_top[1]
    bbox_bot = draw.textbbox((0, 0), line_bottom, font=font)
    tw_b, th_b = bbox_bot[2] - bbox_bot[0], bbox_bot[3] - bbox_bot[1]

    line_gap = int(MASTER * 0.02)
    block_h = th_t + line_gap + th_b
    block_y = (MASTER - block_h) // 2

    tx_t = (MASTER - tw_t) / 2 - bbox_top[0]
    ty_t = block_y - bbox_top[1]
    tx_b = (MASTER - tw_b) / 2 - bbox_bot[0]
    ty_b = block_y + th_t + line_gap - bbox_bot[1]

    # Ombre portée douce.
    shadow_layer = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow_layer)
    sdraw.text((tx_t + 4, ty_t + 8), line_top, font=font, fill=(0, 0, 0, 160))
    sdraw.text((tx_b + 4, ty_b + 8), line_bottom, font=font, fill=(0, 0, 0, 160))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=8))
    img.alpha_composite(shadow_layer)

    draw.text((tx_t, ty_t), line_top, font=font, fill=WHITE)
    draw.text((tx_b, ty_b), line_bottom, font=font, fill=WHITE)

    return img


def main() -> None:
    master = render_master()

    # Écrit chaque résolution Android
    for folder, size in SIZES.items():
        out_dir = os.path.join(RES, folder)
        os.makedirs(out_dir, exist_ok=True)
        resized = master.resize((size, size), Image.LANCZOS)
        out_path = os.path.join(out_dir, "ic_launcher.png")
        resized.save(out_path, "PNG", optimize=True)
        print(f"écrit : {out_path}")

    # Master en racine assets pour cohérence Files Tech
    assets_dir = os.path.join(ROOT, "assets", "icon")
    os.makedirs(assets_dir, exist_ok=True)
    master.save(
        os.path.join(assets_dir, "ai_tech_icon.png"),
        "PNG",
        optimize=True,
    )
    print(f"master 1024 : {os.path.join(assets_dir, 'ai_tech_icon.png')}")


if __name__ == "__main__":
    main()
