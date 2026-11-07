from __future__ import annotations

import argparse
import shutil
from pathlib import Path
from typing import Sequence

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
APP_ICON = ROOT / "docs/assets/dsh-harmony-app-icon-1024.png"
REPOSITORY = "github.com/stlin256/DSH-Harmony"
CURATED_OUTPUTS = (
    ("01-conversation-light", "01-conversation"),
    ("02-process-light", "02-process"),
    ("03-lineage-light", "03-plan-subagent"),
    ("04-preview-light", "04-file-preview"),
    ("05-approval-light", "05-approval"),
    ("11-paired-appearance", "06-appearance-light-dark"),
    ("09-automation-dark", "07-automation"),
    ("10-plugins-dark", "08-plugins"),
    ("12-desktop-cards", "09-desktop-cards"),
    ("13-open-source", "10-open-source"),
)

PORTRAIT_PHONE_Y = 640
PORTRAIT_PHONE_HEIGHT = 1040
PORTRAIT_FOOTER_Y = 1814

CAPTURES = (
    (
        "01-conversation-light.png",
        "01-conversation-light",
        "会话",
        "一个想法\n一处完成",
        "从需求澄清到代码落地，会话、计划与实时进度都在同一工作空间里。",
        ("原生会话", "浮动计划", "自动恢复"),
        False,
    ),
    (
        "02-process-light.png",
        "02-process-light",
        "工作过程",
        "过程清楚\n结果直接",
        "读取、执行与改动按真实顺序展开，需要细看的时候再展开。",
        ("真实顺序", "结构化工具", "紧凑展开"),
        False,
    ),
    (
        "03-lineage-light.png",
        "03-lineage-light",
        "计划与子代理",
        "并行推进\n上下文相连",
        "把任务拆给子代理，状态、身份和父子关系始终保持可见。",
        ("计划模式", "子代理谱系", "继续会话"),
        False,
    ),
    (
        "04-preview-light.png",
        "04-preview-light",
        "文件预览",
        "文件就在\n工作区里",
        "配置、表格、Markdown、代码和图片都可以在工作区里直接阅读。",
        ("多格式预览", "表格适配", "只读浏览"),
        False,
    ),
    (
        "05-approval-light.png",
        "05-approval-light",
        "权限与审批",
        "该确认时\n只确认一次",
        "高风险写入清楚展示范围与影响，确认后继续当前操作。",
        ("权限预设", "单次审批", "风险边界"),
        False,
    ),
    (
        "06-conversation-dark.png",
        "06-conversation-dark",
        "暗色会话",
        "暗色工作\n依然清楚",
        "计划、消息与工具状态在深色界面里保持安静而准确的层级。",
        ("原生暗色", "浮动计划", "状态清晰"),
        True,
    ),
    (
        "07-process-dark.png",
        "07-process-dark",
        "深色工作过程",
        "复杂过程\n依然清楚",
        "思考顺序、命令结果与文件变化保持层级，深色界面也能快速扫读。",
        ("思考顺序", "命令结果", "差异查看"),
        True,
    ),
    (
        "08-subagent-dark.png",
        "08-subagent-dark",
        "子代理",
        "继续检查\n不离开上下文",
        "从标题进入子代理会话，查看结果并继续发送，父子关系始终清楚。",
        ("子代理会话", "模式标识", "继续发送"),
        True,
    ),
    (
        "09-automation-dark.png",
        "09-automation-dark",
        "自动化",
        "重复工作\n按时完成",
        "每日巡检、每周整理与发布同步，在同一处查看状态和下一次执行。",
        ("定时任务", "运行状态", "集中管理"),
        True,
    ),
    (
        "10-plugins-dark.png",
        "10-plugins-dark",
        "插件",
        "工具随需\n工作不乱",
        "浏览已安装能力、确认运行状态，并在同一处完成启用与管理。",
        ("插件列表", "运行组件", "按需扩展"),
        True,
    ),
    (
        "11-settings-light.png",
        "11-settings-light",
        "设置",
        "细节可调\n体验一致",
        "外观、通知、权限与工作区，在统一的原生界面中完成。",
        ("外观与动效", "分级通知", "权限默认值"),
        False,
    ),
)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    names = ("msyhbd.ttc", "msyh.ttc") if bold else ("msyh.ttc", "msyhbd.ttc")
    for name in names:
        path = Path(r"C:\Windows\Fonts") / name
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def text_width(draw: ImageDraw.ImageDraw, text: str, face: ImageFont.FreeTypeFont) -> int:
    box = draw.textbbox((0, 0), text, font=face)
    return box[2] - box[0]


def fit_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    face: ImageFont.FreeTypeFont,
    max_width: int,
) -> str:
    if text_width(draw, text, face) <= max_width:
        return text
    ellipsis = "…"
    while text and text_width(draw, text + ellipsis, face) > max_width:
        text = text[:-1]
    return text + ellipsis


def wrap_pixels(
    draw: ImageDraw.ImageDraw,
    text: str,
    face: ImageFont.FreeTypeFont,
    max_width: int,
) -> list[str]:
    no_line_start = "，。！？；：、）》】」』”’"
    lines: list[str] = []
    for paragraph in text.splitlines():
        current = ""
        for char in paragraph:
            candidate = current + char
            if current and text_width(draw, candidate, face) > max_width:
                if char in no_line_start:
                    lines.append(candidate.rstrip())
                    current = ""
                else:
                    lines.append(current.rstrip())
                    current = char.lstrip()
            else:
                current = candidate
        if current:
            lines.append(current.rstrip())
    return lines


def fill_gradient(dark: bool, width: int, height: int) -> Image.Image:
    top = (12, 15, 21) if dark else (247, 249, 253)
    bottom = (23, 28, 39) if dark else (222, 232, 247)
    image = Image.new("RGB", (width, height), top)
    pixels = ImageDraw.Draw(image)
    for y in range(height):
        mix = y / max(1, height - 1)
        color = tuple(round(top[i] * (1 - mix) + bottom[i] * mix) for i in range(3))
        pixels.line((0, y, width, y), fill=color)

    grid = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid)
    grid_color = (255, 255, 255, 9) if dark else (41, 68, 111, 8)
    step = round(min(width, height) * 0.065)
    for x in range(0, width, step):
        gd.line((x, 0, x, height), fill=grid_color, width=1)
    for y in range(0, height, step):
        gd.line((0, y, width, y), fill=grid_color, width=1)
    image = Image.alpha_composite(image.convert("RGBA"), grid)

    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        (round(width * 0.54), -round(height * 0.30), round(width * 1.08), round(height * 0.74)),
        fill=(61, 107, 254, 82 if dark else 48),
    )
    gd.ellipse(
        (round(width * 0.70), round(height * 0.56), round(width * 1.10), round(height * 1.18)),
        fill=(77, 226, 180, 34 if dark else 40),
    )
    gd.ellipse(
        (-round(width * 0.16), round(height * 0.58), round(width * 0.28), round(height * 1.10)),
        fill=(89, 126, 246, 28 if dark else 22),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(round(min(width, height) * 0.10)))
    return Image.alpha_composite(image, glow).convert("RGB")


def rounded_phone(source: Image.Image) -> Image.Image:
    source = source.convert("RGB")
    source = source.crop(
        (
            0,
            round(source.height * 0.045),
            source.width,
            source.height - round(source.height * 0.012),
        )
    )
    radius = round(source.width * 0.072)
    mask = Image.new("L", source.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, source.width - 1, source.height - 1),
        radius=radius,
        fill=255,
    )
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    result.paste(source, (0, 0), mask)
    return result


def scaled_phone(raw: Path, target_height: int) -> Image.Image:
    with Image.open(raw) as opened:
        if opened.width >= opened.height:
            raise ValueError(f"Expected a portrait device capture: {raw}")
        phone = rounded_phone(opened)
    height = target_height
    width = round(phone.width * height / phone.height)
    return phone.resize((width, height), Image.Resampling.LANCZOS)


def framed_phone(phone: Image.Image, dark: bool) -> Image.Image:
    pad = max(10, round(phone.width * 0.024))
    frame = Image.new(
        "RGBA",
        (phone.width + pad * 2, phone.height + pad * 2),
        (19, 21, 26, 255) if dark else (255, 255, 255, 255),
    )
    mask = Image.new("L", frame.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, frame.width - 1, frame.height - 1),
        radius=round(phone.width * 0.10),
        fill=255,
    )
    frame.putalpha(mask)
    frame.paste(phone, (pad, pad), phone)
    return frame


def paste_device(
    canvas: Image.Image,
    raw: Path,
    dark: bool,
    x: int,
    y: int,
    target_height: int,
) -> Image.Image:
    frame = framed_phone(scaled_phone(raw, target_height), dark)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x + 18, y + 24, x + frame.width + 26, y + frame.height + 30),
        radius=round(frame.width * 0.10),
        fill=(0, 0, 0, 96),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow)
    canvas.paste(frame, (x, y), frame)
    return canvas


def paste_device_centered(
    canvas: Image.Image,
    raw: Path,
    dark: bool,
    center_x: int,
    y: int,
    target_height: int,
) -> Image.Image:
    phone = scaled_phone(raw, target_height)
    frame = framed_phone(phone, dark)
    return paste_device(canvas, raw, dark, center_x - frame.width // 2, y, target_height)


def rounded_icon(size: int) -> Image.Image:
    with Image.open(APP_ICON) as opened:
        icon = opened.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1),
        radius=round(size * 0.23),
        fill=255,
    )
    icon.putalpha(mask)
    return icon


# AppGallery product identity. The store variant ships as "DSH Mobile", so the
# composed sheets must not fall back to the community build name.
BRAND_NAME = "DSH Mobile"
BRAND_TAGLINE = "DeepSeek Harness · HarmonyOS"


def draw_brand(
    canvas: Image.Image,
    x: int,
    y: int,
    dark: bool,
    icon_size: int,
    name_size: int,
    sub_size: int,
) -> None:
    draw = ImageDraw.Draw(canvas)
    foreground = (249, 250, 252) if dark else (15, 17, 21)
    muted = (196, 203, 216) if dark else (83, 91, 105)
    icon = rounded_icon(icon_size)
    canvas.paste(icon, (x, y), icon)
    draw.text(
        (x + icon_size + round(icon_size * 0.26), y + max(0, round(icon_size * 0.04))),
        BRAND_NAME,
        font=font(name_size, True),
        fill=foreground,
    )
    draw.text(
        (x + icon_size + round(icon_size * 0.28), y + round(icon_size * 0.65)),
        BRAND_TAGLINE,
        font=font(sub_size),
        fill=muted,
    )


def draw_feature(
    canvas: Image.Image,
    x: int,
    y: int,
    width: int,
    label: str,
    dark: bool,
    compact: bool = False,
) -> None:
    draw = ImageDraw.Draw(canvas)
    height = 74 if compact else 82
    fill = (28, 32, 42, 208) if dark else (255, 255, 255, 220)
    edge = (72, 83, 105, 170) if dark else (198, 207, 220, 220)
    text = (240, 244, 250) if dark else (29, 34, 43)
    accent = (94, 142, 255) if dark else (58, 105, 220)
    ellipse = (50, 80, 170) if dark else (228, 237, 255)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        (x, y, x + width, y + height),
        radius=18,
        fill=fill,
        outline=edge,
        width=1,
    )
    canvas.alpha_composite(layer)
    draw = ImageDraw.Draw(canvas)
    cy = y + height // 2
    draw.ellipse((x + 18, cy - 6, x + 30, cy + 6), fill=ellipse)
    draw.ellipse((x + 21, cy - 3, x + 27, cy + 3), fill=accent)
    draw.text(
        (x + 42, cy - (13 if compact else 15)),
        label,
        font=font(20 if compact else 22, True),
        fill=text,
    )


def validate_editorial_layout() -> None:
    # The phone frame grows by a small pad around its target height. Reserve
    # enough room below it for the dedicated portrait footer band.
    if PORTRAIT_PHONE_Y + PORTRAIT_PHONE_HEIGHT + 48 >= PORTRAIT_FOOTER_Y:
        raise ValueError("Portrait footer overlaps the device frame")


def draw_scene(
    raw: Path,
    out: Path,
    eyebrow: str,
    title: str,
    subtitle: str,
    features: Sequence[str],
    dark: bool,
    portrait: bool,
) -> None:
    width, height = (1080, 1920) if portrait else (1920, 1080)
    canvas = fill_gradient(dark, width, height).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    foreground = (249, 250, 252) if dark else (15, 17, 21)
    muted = (196, 203, 216) if dark else (79, 87, 101)
    accent = (102, 148, 255) if dark else (55, 105, 225)

    if portrait:
        draw_brand(canvas, 62, 56, dark, 76, 34, 18)
        draw.text((64, 180), eyebrow.upper(), font=font(24, True), fill=accent)
        title_face = font(68, True)
        title_y = 226
        for line in title.splitlines():
            draw.text((62, title_y), line, font=title_face, fill=foreground)
            title_y += 84
        subtitle_face = font(30)
        subtitle_y = title_y + 14
        for line in wrap_pixels(draw, subtitle, subtitle_face, 900):
            draw.text((64, subtitle_y), line, font=subtitle_face, fill=muted)
            subtitle_y += 46
        feature_y = min(530, subtitle_y + 24)
        gap = 12
        feature_width = (1080 - 128 - gap * 2) // 3
        for index, label in enumerate(features):
            draw_feature(
                canvas,
                64 + index * (feature_width + gap),
                feature_y,
                feature_width,
                label,
                dark,
                compact=True,
            )
        canvas = paste_device_centered(canvas, raw, dark, 540,
          PORTRAIT_PHONE_Y, PORTRAIT_PHONE_HEIGHT)
        draw = ImageDraw.Draw(canvas)
        draw.line((64, PORTRAIT_FOOTER_Y, 1016, PORTRAIT_FOOTER_Y),
          fill=(205, 214, 228) if not dark else (63, 72, 88), width=1)
        draw.text((64, PORTRAIT_FOOTER_Y + 26), "简洁 · 流畅 · 功能完备",
          font=font(24, True), fill=accent)
    else:
        draw_brand(canvas, 96, 72, dark, 84, 38, 20)
        draw.text((98, 214), eyebrow.upper(), font=font(24, True), fill=accent)
        title_face = font(74, True)
        title_y = 260
        for line in title.splitlines():
            draw.text((96, title_y), line, font=title_face, fill=foreground)
            title_y += 86
        subtitle_face = font(31)
        subtitle_y = title_y + 18
        for line in wrap_pixels(draw, subtitle, subtitle_face, 840):
            draw.text((98, subtitle_y), line, font=subtitle_face, fill=muted)
            subtitle_y += 48
        feature_y = min(584, subtitle_y + 26)
        gap = 16
        feature_width = (850 - gap * 2) // 3
        for index, label in enumerate(features):
            draw_feature(
                canvas,
                96 + index * (feature_width + gap),
                feature_y,
                feature_width,
                label,
                dark,
            )
        draw.text((98, 930), "简洁 · 流畅 · 功能完备", font=font(26, True), fill=accent)
        canvas = paste_device(canvas, raw, dark, 1270, 50, 1000)

    canvas.convert("RGB").save(out, "PNG", optimize=True)


def draw_pair_art(raw_dir: Path, out: Path, portrait: bool) -> None:
    width, height = (1080, 1920) if portrait else (1920, 1080)
    canvas = fill_gradient(False, width, height).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    dark_text = (15, 17, 21)
    muted = (79, 87, 101)
    accent = (55, 105, 225)
    light_raw = raw_dir / "01-conversation-light.png"
    dark_raw = raw_dir / "06-conversation-dark.png"

    if portrait:
        draw_brand(canvas, 62, 60, False, 76, 34, 18)
        draw.text((64, 184), "APPEARANCE", font=font(22, True), fill=accent)
        draw.text((62, 232), "亮暗之间\n自然切换", font=font(68, True), fill=dark_text, spacing=10)
        draw.multiline_text(
            (64, 410),
            "跟随系统，也可以随时选择亮色或暗色。\n每个控件都保持清晰、克制和一致。",
            font=font(30),
            fill=muted,
            spacing=12,
        )
        canvas = paste_device(canvas, light_raw, False, 36, 610, 1050)
        canvas = paste_device(canvas, dark_raw, True, 556, 610, 1050)
        draw = ImageDraw.Draw(canvas)
        draw.text((62, 1742), "LIGHT", font=font(21, True), fill=(132, 137, 145))
        draw.text((582, 1742), "DARK", font=font(21, True), fill=(132, 137, 145))
        draw.line((64, 1810, 1016, 1810), fill=(205, 214, 228), width=1)
        draw.text((62, 1832), "同一套 DSH 视觉语言", font=font(22, True), fill=accent)
    else:
        draw_brand(canvas, 92, 70, False, 84, 38, 20)
        draw.text((96, 216), "APPEARANCE", font=font(22, True), fill=accent)
        draw.text((94, 266), "亮暗之间\n自然切换", font=font(72, True), fill=dark_text, spacing=12)
        draw.multiline_text(
            (98, 456),
            "跟随系统，也可以随时选择亮色或暗色。\n每个控件都保持清晰、克制和一致。",
            font=font(30),
            fill=muted,
            spacing=14,
        )
        draw_feature(canvas, 98, 638, 230, "亮色", False)
        draw_feature(canvas, 348, 638, 230, "暗色", False)
        draw_feature(canvas, 598, 638, 230, "跟随系统", False)
        draw.text((98, 924), "同一套 DSH 视觉语言", font=font(25, True), fill=accent)
        canvas = paste_device(canvas, light_raw, False, 1010, 92, 916)
        canvas = paste_device(canvas, dark_raw, True, 1428, 92, 916)

    canvas.convert("RGB").save(out, "PNG", optimize=True)


CARD_THEMES = {
    False: {
        "background": "#FFFFFF",
        "primary": "#0F1115",
        "secondary": "#61666B",
        "action": "#F5F6F7",
        "border": "#E6E8EB",
    },
    True: {
        "background": "#2C2C2E",
        "primary": "#F9FAFB",
        "secondary": "#CFD3D6",
        "action": "#353638",
        "border": "#45464A",
    },
}


def draw_overview_card(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    dark: bool,
) -> None:
    x, y, width, height = box
    colors = CARD_THEMES[dark]
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (x, y, x + width, y + height),
        radius=24,
        fill=colors["background"],
        outline=colors["border"],
        width=1,
    )
    pad = 16
    draw.text((x + pad, y + pad), "DSH Harmony", font=font(15, True), fill=colors["primary"])
    sync = "刚刚同步"
    sync_face = font(11)
    draw.text(
        (x + width - pad - text_width(draw, sync, sync_face), y + pad + 2),
        sync,
        font=sync_face,
        fill=colors["secondary"],
    )
    metrics = (("2", "待确认"), ("1", "运行中"), ("6", "完成"), ("0", "失败"))
    metric_y = y + 48
    metric_width = (width - pad * 2) // 4
    for index, (value, label) in enumerate(metrics):
        mx = x + pad + index * metric_width
        draw.text((mx, metric_y), value, font=font(24, True), fill=colors["primary"])
        draw.text((mx, metric_y + 30), label, font=font(10), fill=colors["secondary"])
    tasks = (
        ("发布准备与商店检查", "确认"),
        ("工作区文件预览", "完成"),
        ("分级通知与桌面卡片", "运行"),
        ("手机端交互适配", "完成"),
    )
    task_y = y + 104
    for title, state in tasks:
        draw.text(
            (x + pad, task_y + 5),
            fit_text(draw, title, font(12), width - pad * 2 - 42),
            font=font(12),
            fill=colors["primary"],
        )
        draw.text(
            (x + width - pad - 24, task_y + 5),
            state,
            font=font(10),
            fill=colors["secondary"],
        )
        draw.line(
            (x + pad, task_y + 25, x + width - pad, task_y + 25),
            fill=colors["border"],
            width=1,
        )
        task_y += 30
    button_y = y + height - 56
    gap = 8
    button_width = (width - pad * 2 - gap) // 2
    for index, label in enumerate(("打开工作空间", "同步状态")):
        bx = x + pad + index * (button_width + gap)
        draw.rounded_rectangle(
            (bx, button_y, bx + button_width, button_y + 40),
            radius=12,
            fill=colors["action"],
        )
        face = font(12, True)
        draw.text(
            (bx + (button_width - text_width(draw, label, face)) // 2, button_y + 12),
            label,
            font=face,
            fill=colors["primary"],
        )


def draw_quick_card(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    dark: bool,
    waiting: bool,
) -> None:
    x, y, width, height = box
    colors = CARD_THEMES[dark]
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (x, y, x + width, y + height),
        radius=24,
        fill=colors["background"],
        outline=colors["border"],
        width=1,
    )
    icon = rounded_icon(34)
    canvas.paste(icon, (x + 18, y + 18), icon)
    number = "2" if waiting else "1"
    draw.text((x + width - 42, y + 20), number, font=font(22, True), fill=colors["primary"])
    headline = "2 个待确认" if waiting else "1 个运行中"
    draw.text((x + 18, y + 92), headline, font=font(24, True), fill=colors["primary"])
    detail = (
        "发布检查等待确认，完成后继续同步。"
        if waiting
        else "商店检查正在执行，结果会实时同步。"
    )
    detail_y = y + 138
    for line in wrap_pixels(draw, detail, font(14), width - 36):
        draw.text((x + 18, detail_y), line, font=font(14), fill=colors["secondary"])
        detail_y += 22
    draw.text((x + 18, y + height - 30), "DSH Harmony", font=font(11), fill=colors["secondary"])


def draw_cards_art(out: Path, portrait: bool) -> None:
    width, height = (1080, 1920) if portrait else (1920, 1080)
    canvas = fill_gradient(False, width, height).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    primary = (15, 17, 21)
    muted = (79, 87, 101)
    accent = (55, 105, 225)

    if portrait:
        draw_brand(canvas, 62, 60, False, 76, 34, 18)
        draw.text((64, 184), "DESKTOP CARDS", font=font(22, True), fill=accent)
        draw.text((62, 232), "任务状态\n一瞥即知", font=font(68, True), fill=primary, spacing=10)
        draw.multiline_text(
            (64, 410),
            "待确认、运行中与近期完成同步到桌面卡片。\n亮色和暗色都保持清晰的信息层级。",
            font=font(27),
            fill=muted,
            spacing=12,
        )
        card_w, card_h = 472, 340
        positions = (
            (38, 550, card_w, card_h),
            (570, 550, card_w, card_h),
            (38, 926, card_w, card_h),
            (570, 926, card_w, card_h),
        )
        draw_overview_card(canvas, positions[0], False)
        draw_overview_card(canvas, positions[1], True)
        draw_quick_card(canvas, positions[2], False, True)
        draw_quick_card(canvas, positions[3], True, True)
        draw.rounded_rectangle(
            (52, 1348, 1028, 1770),
            radius=30,
            fill=(25, 30, 42, 242),
            outline=(73, 86, 108, 255),
        )
        icon = rounded_icon(126)
        canvas.paste(icon, (82, 1390), icon)
        draw.text((236, 1396), "任务状态，一处掌握", font=font(42, True), fill=(249, 250, 252))
        draw.text(
            (238, 1460),
            "待确认、运行中与近期完成同步到桌面。",
            font=font(22),
            fill=(196, 203, 216),
        )
        summary = (("2", "待确认"), ("1", "运行中"), ("6", "近期完成"))
        for index, (value, label) in enumerate(summary):
            sx = 90 + index * 305
            draw.text((sx, 1570), value, font=font(44, True), fill=(249, 250, 252))
            draw.text((sx, 1634), label, font=font(19), fill=(167, 180, 201))
        draw.text(
            (82, 1712),
            "多尺寸 · 亮暗适配 · 直接打开会话",
            font=font(22, True),
            fill=(111, 154, 255),
        )
    else:
        draw_brand(canvas, 92, 70, False, 84, 38, 20)
        draw.text((96, 216), "DESKTOP CARDS", font=font(22, True), fill=accent)
        draw.text((94, 266), "任务状态\n一瞥即知", font=font(72, True), fill=primary, spacing=12)
        draw.multiline_text(
            (98, 456),
            "待确认、运行中与近期完成同步到桌面卡片。\n亮色和暗色都保持清晰的信息层级。",
            font=font(30),
            fill=muted,
            spacing=14,
        )
        draw_feature(canvas, 98, 638, 230, "待确认", False)
        draw_feature(canvas, 348, 638, 230, "运行中", False)
        draw_feature(canvas, 598, 638, 230, "直接打开", False)
        draw.text((98, 916), "多种尺寸 · 同步状态 · 隐私可控", font=font(25, True), fill=accent)

        card_w, card_h = 430, 292
        positions = (
            (944, 128, card_w, card_h),
            (1402, 128, card_w, card_h),
            (944, 448, card_w, card_h),
            (1402, 448, card_w, card_h),
        )
        draw_overview_card(canvas, positions[0], False)
        draw_overview_card(canvas, positions[1], True)
        draw_quick_card(canvas, positions[2], False, True)
        draw_quick_card(canvas, positions[3], True, True)

    canvas.convert("RGB").save(out, "PNG", optimize=True)


def draw_code_window(canvas: Image.Image, box: tuple[int, int, int, int], dark: bool) -> None:
    x, y, width, height = box
    draw = ImageDraw.Draw(canvas)
    bg = "#181B22" if dark else "#FFFFFF"
    edge = "#343A45" if dark else "#DCE2EC"
    primary = "#E8EDF5" if dark else "#20242D"
    muted = "#8790A0" if dark else "#7A8190"
    accent = "#78A0FF"
    draw.rounded_rectangle(
        (x, y, x + width, y + height),
        radius=28,
        fill=bg,
        outline=edge,
        width=1,
    )
    draw.rounded_rectangle(
        (x, y, x + width, y + 48),
        radius=28,
        fill="#242832" if dark else "#F4F6F9",
    )
    draw.rectangle(
        (x, y + 20, x + width, y + 48),
        fill="#242832" if dark else "#F4F6F9",
    )
    for index, color in enumerate(("#FF6B6B", "#F5C451", "#57C46F")):
        draw.ellipse(
            (x + 18 + index * 20, y + 17, x + 28 + index * 20, y + 27),
            fill=color,
        )
    draw.text((x + width - 158, y + 14), "DSH-Harmony", font=font(13), fill=muted)
    lines = (
        ("# 可追踪上游的移动分支", muted),
        ("", primary),
        ("git remote -v", primary),
        ("origin  github.com/stlin256/DSH-Harmony", accent),
        ("", primary),
        ("npm run build:store", primary),
        ("✓ build complete", "#69D29A"),
    )
    line_y = y + 74
    face = font(16)
    for text, color in lines:
        draw.text((x + 24, line_y), text, font=face, fill=color)
        line_y += 28


def draw_open_source_art(out: Path, portrait: bool) -> None:
    width, height = (1080, 1920) if portrait else (1920, 1080)
    dark = True
    canvas = fill_gradient(dark, width, height).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    foreground = (249, 250, 252)
    muted = (191, 199, 214)
    accent = (105, 151, 255)

    if portrait:
        draw_brand(canvas, 62, 60, dark, 76, 34, 18)
        draw.text((64, 184), "OPEN SOURCE", font=font(22, True), fill=accent)
        draw.text(
            (62, 232),
            "开放构建\n共同维护",
            font=font(68, True),
            fill=foreground,
            spacing=10,
        )
        draw.multiline_text(
            (64, 410),
            "移动分支保持上游可追踪，构建过程可复现。\n欢迎提交问题、建议和改进。",
            font=font(27),
            fill=muted,
            spacing=12,
        )
        draw_code_window(canvas, (62, 590, 956, 360), False)
        icon = rounded_icon(270)
        canvas.paste(icon, (72, 1040), icon)
        draw.text((382, 1084), "DSH Harmony", font=font(54, True), fill=foreground)
        draw.text((384, 1160), "为 DeepSeek Harness 打造的", font=font(26), fill=muted)
        draw.text((384, 1202), "HarmonyOS 原生客户端", font=font(26), fill=muted)
        draw.rounded_rectangle(
            (62, 1390, 1018, 1510),
            radius=24,
            fill=(29, 34, 46, 230),
            outline=(74, 86, 108, 255),
        )
        draw.text((92, 1415), "源代码仓库", font=font(18, True), fill=accent)
        draw.text((92, 1452), REPOSITORY, font=font(27, True), fill=foreground)
        draw.text((64, 1780), "上游同步 · 可复现构建 · 问题反馈", font=font(24, True), fill=accent)
    else:
        draw_brand(canvas, 92, 70, dark, 84, 38, 20)
        draw.text((96, 216), "OPEN SOURCE", font=font(22, True), fill=accent)
        draw.text(
            (94, 266),
            "开放构建\n共同维护",
            font=font(72, True),
            fill=foreground,
            spacing=12,
        )
        draw.multiline_text(
            (98, 456),
            "移动分支保持上游可追踪，构建过程可复现。\n欢迎提交问题、建议和改进。",
            font=font(30),
            fill=muted,
            spacing=14,
        )
        draw_feature(canvas, 98, 638, 230, "上游同步", True)
        draw_feature(canvas, 348, 638, 230, "可复现构建", True)
        draw_feature(canvas, 598, 638, 230, "问题反馈", True)
        draw.rounded_rectangle(
            (98, 758, 860, 878),
            radius=24,
            fill=(29, 34, 46, 235),
            outline=(74, 86, 108, 255),
        )
        draw.text((126, 780), "源代码仓库", font=font(18, True), fill=accent)
        draw.text((126, 816), REPOSITORY, font=font(27, True), fill=foreground)
        draw.text((98, 936), "HarmonyOS · 手机触控 · 原生体验", font=font(24, True), fill=accent)
        icon = rounded_icon(250)
        canvas.paste(icon, (988, 136), icon)
        draw_code_window(canvas, (1000, 438, 820, 420), True)

    canvas.convert("RGB").save(out, "PNG", optimize=True)


def validate_outputs(out_dir: Path) -> None:
    expected = {(1920, 1080), (1080, 1920)}
    for path in sorted(out_dir.glob("*.png")):
        if path.stat().st_size >= 5 * 1024 * 1024:
            raise ValueError(f"PNG exceeds 5 MB: {path}")
        with Image.open(path) as image:
            if image.size not in expected:
                raise ValueError(f"Unexpected dimensions {image.size}: {path}")


def write_curated_outputs(out_dir: Path) -> None:
    targets = (
        (out_dir / "appgallery-landscape", "1920x1080"),
        (out_dir / "appgallery-portrait", "1080x1920"),
    )
    for directory, dimension in targets:
        directory.mkdir(parents=True, exist_ok=True)
        for stale in directory.glob("*.png"):
            stale.unlink()
        for source_stem, destination_stem in CURATED_OUTPUTS:
            source = out_dir / f"{source_stem}-{dimension}.png"
            if not source.exists():
                raise FileNotFoundError(source)
            shutil.copy2(source, directory / f"{destination_stem}-{dimension}.png")


def main() -> None:
    global BRAND_NAME, BRAND_TAGLINE
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--brand", default=BRAND_NAME, help="product name drawn on every sheet")
    parser.add_argument("--tagline", default=BRAND_TAGLINE, help="tagline drawn under the product name")
    args = parser.parse_args()
    BRAND_NAME = args.brand
    BRAND_TAGLINE = args.tagline
    raw_dir = Path(args.raw)
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    validate_editorial_layout()
    for stale in out_dir.glob("*.png"):
        stale.unlink()

    for source_name, output_name, eyebrow, title, subtitle, features, dark in CAPTURES:
        source = raw_dir / source_name
        if not source.exists():
            raise FileNotFoundError(source)
        draw_scene(
            source,
            out_dir / f"{output_name}-1920x1080.png",
            eyebrow,
            title,
            subtitle,
            features,
            dark,
            False,
        )
        draw_scene(
            source,
            out_dir / f"{output_name}-1080x1920.png",
            eyebrow,
            title,
            subtitle,
            features,
            dark,
            True,
        )

    draw_pair_art(raw_dir, out_dir / "11-paired-appearance-1920x1080.png", False)
    draw_pair_art(raw_dir, out_dir / "11-paired-appearance-1080x1920.png", True)
    draw_cards_art(out_dir / "12-desktop-cards-1920x1080.png", False)
    draw_cards_art(out_dir / "12-desktop-cards-1080x1920.png", True)
    draw_open_source_art(out_dir / "13-open-source-1920x1080.png", False)
    draw_open_source_art(out_dir / "13-open-source-1080x1920.png", True)
    validate_outputs(out_dir)
    write_curated_outputs(out_dir)

    for path in sorted(out_dir.glob("*.png")):
        print(f"{path}\t{path.stat().st_size}")


if __name__ == "__main__":
    main()
