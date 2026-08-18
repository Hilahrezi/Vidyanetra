"""Generate dataset sintetis benchmark: 8 crop jawaban + ground truth.

usage: python scripts/benchmark/prepare_dataset.py [--out data]
"""

import argparse
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT_DIR = Path("C:/Windows/Fonts")
HAND_FONTS = [
    ("Segoe Script", FONT_DIR / "segoesc.ttf"),
    ("Ink Free", FONT_DIR / "Inkfree.ttf"),
    ("Comic Sans MS", FONT_DIR / "comic.ttf"),
    ("Bradley Hand ITC", FONT_DIR / "BRADHITC.TTF"),
]


def load_font(name_or_path, size):
    return ImageFont.truetype(str(name_or_path), size)


def render_text(text: str, size: tuple[int, int], font_path, font_size: int) -> Image.Image:
    img = Image.new("RGB", size, "white")
    draw = ImageDraw.Draw(img)
    font = load_font(font_path, font_size)
    draw.text((size[0] // 2, size[1] // 2), text, fill=(30, 30, 30), font=font, anchor="mm")
    return img


def wrap_lines(text: str, max_chars: int) -> list[str]:
    lines, current = [], ""
    for word in text.split():
        if len(current) + len(word) + 1 > max_chars:
            lines.append(current)
            current = word
        else:
            current = f"{current} {word}".strip()
    if current:
        lines.append(current)
    return lines


def render_essay(text: str, size: tuple[int, int], font_path, font_size: int) -> Image.Image:
    img = Image.new("RGB", size, "white")
    draw = ImageDraw.Draw(img)
    font = load_font(font_path, font_size)
    lines = wrap_lines(text, 22)
    line_height = font_size + 18
    y = (size[1] - line_height * len(lines)) // 2
    for line in lines:
        draw.text((size[0] // 2, y), line, fill=(30, 30, 30), font=font, anchor="ma")
        y += line_height
    return img


def render_mcq_option(
    key: str,
    font_path=None,
    box_w_mm=14,
    box_h_mm=16,
    extra_x: str | None = None,
    no_mark: bool = False,
    font_index: int = 0,
) -> Image.Image:
    """Render baris soal MCQ: 4 kotak a/b/c/d + tanda X pada opsi benar.

    Ukuran sesuai template: kotak 14x16mm @300dpi = 165x189px, gap 6mm=71px.
    - extra_x: X kedua (simulasi ambigu)
    - no_mark: tanpa tanda sama sekali
    - font_index: pilih font tulisan tangan dari HAND_FONTS
    """
    px = 300 / 25.4
    w = int(76 * px)  # area baris sesuai template (76mm)
    h = int(16 * px)
    img = Image.new("RGB", (w, h), "white")
    draw = ImageDraw.Draw(img)
    if font_path is None:
        font_path = HAND_FONTS[font_index % len(HAND_FONTS)][1]
    label_font = load_font(font_path, 30)

    for i, opt in enumerate(("a", "b", "c", "d")):
        x0 = int((6 + i * (14 + 6)) * px)  # offset kiri 6mm agar crop terpusat
        y0 = 0
        bw, bh = int(box_w_mm * px), int(box_h_mm * px)
        draw.rectangle((x0, y0, x0 + bw, y0 + bh), outline=(40, 40, 40), width=3)
        # huruf opsi kecil di tengah kotak
        draw.text((x0 + bw // 2, y0 + bh // 2), opt, fill=(60, 60, 60), font=label_font, anchor="mm")
        if (not no_mark) and (opt == key or opt == extra_x):
            # tanda X: dua garis diagonal
            m = 18
            draw.line((x0 + m, y0 + m, x0 + bw - m, y0 + bh - m), fill=(20, 20, 20), width=8)
            draw.line((x0 + bw - m, y0 + m, x0 + m, y0 + bh - m), fill=(20, 20, 20), width=8)
    return img


ITEMS = [
    # (id, task, key, text_siswa, expected_text, score_range, expected_correct, keywords_esai)
    # MCQ: key = huruf opsi (a/b/c/d) yang disilang siswa
    ("mcq1", "mcq", "b", "", "b", (100, 100), True, []),
    ("mcq2", "mcq", "c", "", "c", (100, 100), True, []),
    ("mcq3", "mcq", "a", "", "a", (100, 100), True, []),
    ("short1", "short", "4 | akar kuadrat dari 16", "4", "4", (90, 100), True, []),
    ("short2", "short", "Jakarta", "jakarta", "jakarta", (90, 100), True, []),
    ("short3", "short", "fotosintesis", "fotosintesis", "fotosintesis", (90, 100), True, []),
    (
        "essay1",
        "essay",
        "Langkah pemfaktoran: ubah persamaan menjadi bentuk (x+p)(x+q)=0 dengan p dan q adalah dua bilangan "
        "yang jika dikali menghasilkan c dan jika dijumlah menghasilkan b. Lalu setiap kurung disamakan dengan nol "
        "sehingga diperoleh dua nilai x.",
        "Pertama faktorkan persamaan menjadi dua kurung, misal x kuadrat tambah lima x tambah enam menjadi "
        "kurung x tambah dua dikali kurung x tambah tiga. Kemudian samakan setiap kurung dengan nol, jadi x "
        "sama dengan minus dua atau x sama dengan minus tiga.",
        "",
        (75, 100),
        True,
        ["faktorkan", "kurung", "nol"],
    ),
    (
        "essay2",
        "essay",
        "Fotosintesis adalah proses tumbuhan membuat makanan dengan bantuan cahaya matahari, air, dan karbon "
        "dioksida. Hasilnya berupa glukosa dan oksigen.",
        "Fotosintesis adalah proses pembuatan makanan pada tumbuhan menggunakan cahaya matahari, air, dan "
        "karbon dioksida. Hasil dari proses ini adalah glukosa dan oksigen.",
        "",
        (75, 100),
        True,
        ["cahaya", "makanan", "glukosa"],
    ),
]

# ukuran crop: mcq = baris 4 opsi (76x16mm), short sedang, essay besar
SIZES = {"mcq": (898, 189), "short": (720, 180), "essay": (960, 560)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="data")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    data_dir = Path(__file__).resolve().parent / args.out
    (data_dir / "images").mkdir(parents=True, exist_ok=True)

    ground_truth = []
    for idx, (item_id, task, key, student_text, expected_text, score_range, expected_correct, keywords) in enumerate(ITEMS):
        font_name, font_path = HAND_FONTS[idx % len(HAND_FONTS)]
        font_size = {"mcq": 130, "short": 90, "essay": 46}[task]
        size = SIZES[task]
        if task == "mcq":
            img = render_mcq_option(key, font_path)
        elif task == "essay":
            img = render_essay(student_text, size, font_path, font_size)
        else:
            img = render_text(student_text, size, font_path, font_size)
        img = img.rotate(rng.uniform(-3, 3), expand=False, fillcolor="white", resample=Image.BICUBIC)

        filename = f"{item_id}.jpg"
        img.save(data_dir / "images" / filename, quality=85)

        ground_truth.append(
            {
                "id": item_id,
                "task": task,
                "key": key,
                "student_text": student_text,
                "expected_text": expected_text,
                "score_range": score_range,
                "expected_correct": expected_correct,
                "keywords": keywords,
                "image": f"images/{filename}",
            }
        )

    gt_path = data_dir / "ground_truth.json"
    gt_path.write_text(json.dumps(ground_truth, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Dataset siap: {len(ground_truth)} item -> {data_dir}")
    for g in ground_truth:
        print(f"  {g['id']:8s} [{g['task']:5s}] key='{g['key'][:40]}'")


if __name__ == "__main__":
    main()
