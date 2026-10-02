"""생성 컨셉 이미지(한 장에 4단계 가로 배치) → 게임 스프라이트.

`리소스/new_chars/charNN_<이름>.png` 한 장 = Default · 1st · 2nd · 3rd 네 판이
마젠타 배경에 가로로 선 그림이다 (docs/new_cats_10.md). 레이어가 나뉘어 있지 않아
`extract_cat_sheet.py`로는 뽑을 수 없으므로, 완성 렌더만 만든다:

  shared/assets/cats/charNN_tT.png       완성 렌더 (캔버스 + 사방 PAD 여백)
  shared/assets/cats/gray/charNN_tT.png  회청색 램프 (잠금·사망)

몸통 자리는 기존 6종과 같은 캔버스 좌표계(`cat_layouts.gd`의 BODY)에 맞춘다 —
판마다 몸통 가로폭·왼쪽 변·앞발 바닥을 재서 BODY에 겹치도록 늘이고 옮긴다.
모자·꼬리·등 소품이 기존 캔버스(278×293) 밖으로 나가므로 사방에 PAD만큼 여백을
두고, `cat_sprite.gd`가 텍스처 크기와 CANVAS의 차이로 여백을 알아서 뺀다.

사용: python tools/import_gen_cats.py   (끝나면 --import 후 .import의 mipmaps 확인)
"""
import glob
import os
import re

import numpy as np
from PIL import Image


# extract_cat_sheet.py의 grayscale()과 같은 램프 (그 모듈은 import만 해도 시트를 읽는다).
GRAY_LO = np.array([143.0, 152.0, 166.0])
GRAY_HI = np.array([223.0, 228.0, 234.0])


def grayscale(px):
	rgb = px[:, :, :3].astype(float)
	luma = (rgb * np.array([0.299, 0.587, 0.114])).sum(2)[:, :, None] / 255.0
	out = px.copy()
	out[:, :, :3] = (GRAY_LO + (GRAY_HI - GRAY_LO) * luma).astype(np.uint8)
	return out

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, '리소스', 'new_chars')
OUT = os.path.join(ROOT, 'shared', 'assets', 'cats')

CANVAS = (278, 293)      # cat_layouts.gd CANVAS
BODY_X0, BODY_W = 28, 194  # 몸통 아웃라인 왼쪽 변 · 가로폭
FOOT_Y = 284             # 앞발 바닥 (기존 완성 렌더의 알파 바닥)
PAD = 72                 # 사방 여백 — cat_sprite.gd가 (텍스처 - CANVAS) / 2로 읽는다
H_PER_W = 246.0 / 194.0  # 귀 끝~발 바닥 / 몸통 폭 (기존 렌더 비율)


def alpha_of(rgb):
	"""마젠타 배경 → 알파. 배경은 R·B가 높고 G가 낮다."""
	r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
	m = np.minimum(r, b) - g
	return np.clip(1.0 - (m - 45.0) / 150.0, 0.0, 1.0)


def unmix(rgb, a, bg):
	af = np.clip(a, 1e-3, 1.0)[..., None]
	return np.clip((rgb - (1.0 - af) * bg) / af, 0, 255)


def panels(fg):
	"""열 투영으로 판 네 개의 x 구간을 찾는다."""
	cols = fg.sum(0) > 3
	segs, s = [], None
	for x, v in enumerate(cols):
		if v and s is None:
			s = x
		if not v and s is not None:
			segs.append([s, x])
			s = None
	if s is not None:
		segs.append([s, len(cols)])
	merged = []
	for sg in segs:
		if merged and sg[0] - merged[-1][1] < 40:
			merged[-1][1] = sg[1]
		else:
			merged.append(sg)
	return [g for g in merged if g[1] - g[0] > 80]


def body_fit(fg, x0, x1, w_guess):
	"""판 하나에서 (몸통 왼쪽 변, 몸통 폭, 발 바닥 y)."""
	sub = fg[:, x0:x1]
	rows = np.where(sub.sum(1) > 3)[0]
	foot = int(rows.max())
	h = w_guess * H_PER_W
	best = None
	for y in range(int(foot - 0.62 * h), int(foot - 0.32 * h)):
		xs = np.where(sub[y])[0]
		if len(xs) < 2:
			continue
		span = xs.max() - xs.min() + 1
		if best is None or span < best[1]:
			best = (x0 + int(xs.min()), int(span))
	return best[0], best[1], foot


def main() -> None:
	os.makedirs(os.path.join(OUT, 'gray'), exist_ok=True)
	cw, ch = CANVAS[0] + 2 * PAD, CANVAS[1] + 2 * PAD
	for path in sorted(glob.glob(os.path.join(SRC, 'char*_*.png'))):
		cid = re.match(r'(char\d\d)_', os.path.basename(path)).group(1)
		rgb = np.asarray(Image.open(path).convert('RGB')).astype(float)
		bg = np.median(rgb[:20, :20].reshape(-1, 3), 0)
		a = alpha_of(rgb)
		fg = a > 0.5
		segs = panels(fg)
		assert len(segs) == 4, (path, len(segs))
		# 판 0(소품 없음)의 폭을 나머지 판의 띠 높이 추정에 쓴다.
		w0 = body_fit(fg, *segs[0], (segs[0][1] - segs[0][0]) * 0.9)[1]
		# 세로 비율: 판 0의 귀 끝~발 바닥이 기존 렌더(246)와 같아지게 살짝 눌러 준다
		# (생성 그림은 냥이마다 키가 들쭉날쭉하다). 찌그러짐이 보이지 않게 ±10%까지만.
		rows0 = np.where(fg[:, segs[0][0]:segs[0][1]].sum(1) > 3)[0]
		fy = float(np.clip(H_PER_W * w0 / (rows0.max() - rows0.min() + 1), 0.9, 1.1))
		px = np.dstack([unmix(rgb, a, bg), a * 255.0]).astype(np.uint8)
		src = Image.fromarray(px, 'RGBA')
		for t, (x0, x1) in enumerate(segs):
			bx, bw, foot = body_fit(fg, x0, x1, w0)
			k = BODY_W / bw
			# 이웃 판이 끼어들지 않게 판 사이 한가운데에서 자른다.
			l = (segs[t - 1][1] + x0) // 2 if t > 0 else 0
			r = (x1 + segs[t + 1][0]) // 2 if t < 3 else src.width
			piece = src.crop((l, 0, r, src.height))
			# 원본 좌표 → 캔버스(+PAD) 좌표: bx → BODY_X0, foot → FOOT_Y
			ox = PAD + BODY_X0 - (bx - l) * k
			oy = PAD + FOOT_Y - foot * k * fy
			big = piece.resize((round(piece.width * k), round(piece.height * k * fy)),
					Image.LANCZOS)
			can = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
			can.alpha_composite(big, (round(ox), round(oy)))
			arr = np.asarray(can).copy()
			arr[arr[..., 3] < 6] = 0
			Image.fromarray(arr, 'RGBA').save(os.path.join(OUT, '%s_t%d.png' % (cid, t)))
			Image.fromarray(grayscale(arr), 'RGBA').save(
					os.path.join(OUT, 'gray', '%s_t%d.png' % (cid, t)))
			ys, xs = np.where(arr[..., 3] > 20)
			clip = xs.min() == 0 or ys.min() == 0 or xs.max() == cw - 1 or ys.max() == ch - 1
			print('%s t%d  scale %.3f  fy %.2f  bbox x%d~%d y%d~%d%s' % (cid, t, k, fy,
					xs.min() - PAD, xs.max() - PAD, ys.min() - PAD, ys.max() - PAD,
					'  !! CLIPPED' if clip else ''))


if __name__ == '__main__':
	main()
