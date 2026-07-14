#!/usr/bin/env python3
"""高亮 + 智慧刷新版「左打碼、右即時預覽」——workshop 一條龍 demo 的收尾。

餵任何『單檔自包含 HTML』（CSS/JS inline），左邊逐字打並語法高亮，右邊即時長出網頁。
打 CSS 時右邊等「一條規則打完（}）」才刷新；打 HTML 標籤逐字刷新。

用法:
    type_hl.py <你的頁面.html> [live_editor_hl.html]

環境變數:
    PW_HEADLESS=1     不開視窗（純錄影/截圖）；不設則彈瀏覽器邊打邊長
    CHARS_PER_TICK=2  每拍打幾個字（調大 = 更快）
    TICK_MS=14        每拍間隔毫秒（調大 = 更慢，現場好講）

依賴：python playwright（`python3 -m pip install playwright && python3 -m playwright install chromium`）。
"""
import os
import sys

try:
    from playwright.sync_api import sync_playwright
except ModuleNotFoundError:
    sys.exit("需要 python playwright：python3 -m pip install --user playwright && python3 -m playwright install chromium")

if len(sys.argv) < 2:
    sys.exit("用法: type_hl.py <你的頁面.html> [live_editor_hl.html]")

HERE = os.path.dirname(os.path.abspath(__file__))
SRC_PAGE = os.path.abspath(sys.argv[1])
# 預設編輯器 = 跟本腳本同目錄的 live_editor_hl.html（不管你從哪個 cwd 跑都找得到）
EDITOR = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else os.path.join(HERE, "live_editor_hl.html")
URL = "file://" + EDITOR
HEADLESS = os.environ.get("PW_HEADLESS") == "1"
CHARS_PER_TICK = int(os.environ.get("CHARS_PER_TICK", "2"))
TICK_MS = int(os.environ.get("TICK_MS", "14"))
STEM = os.path.splitext(os.path.basename(SRC_PAGE))[0]
OUT_DIR = os.path.dirname(SRC_PAGE)
VIDEO_DIR = os.path.join(OUT_DIR, f"video_{STEM}_hl")
SHOT_DIR = os.path.join(OUT_DIR, f"shots_{STEM}_hl")
os.makedirs(SHOT_DIR, exist_ok=True)

with open(SRC_PAGE, encoding="utf-8") as f:
    FULL = f.read()


def main():
    print(f"[hl] 來源頁面: {SRC_PAGE}（{len(FULL)} 字）")
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=HEADLESS, args=["--window-size=1440,880"])
        context = browser.new_context(
            viewport={"width": 1360, "height": 800},
            record_video_dir=VIDEO_DIR,
            record_video_size={"width": 1360, "height": 800},
        )
        page = context.new_page()
        page.goto(URL)
        page.evaluate("(full) => window.T.load(full)", FULL)
        page.wait_for_timeout(400)

        total = len(FULL)
        k = 0
        shot_at = max(1, total // 5)
        next_shot = shot_at
        while k < total:
            k = min(total, k + CHARS_PER_TICK)
            page.evaluate("(k) => window.T.to(k)", k)
            page.wait_for_timeout(TICK_MS)
            if k >= next_shot:
                page.screenshot(path=os.path.join(SHOT_DIR, f"{STEM}-{k:04d}.png"))
                next_shot += shot_at

        page.wait_for_timeout(1500)
        page.screenshot(path=os.path.join(SHOT_DIR, f"{STEM}-final.png"))

        if not HEADLESS:
            print("[hl] 打完了——關掉瀏覽器視窗即結束。")
            try:
                page.wait_for_event("close", timeout=0)
            except Exception:
                pass

        context.close()
        browser.close()
        print(f"[hl] 影片 → {VIDEO_DIR}")
        print(f"[hl] 截圖 → {SHOT_DIR}")


if __name__ == "__main__":
    main()
