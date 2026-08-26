# -*- coding: utf-8 -*-
"""리소스/1.png(마젠타 크로마키 캐릭터 시트) → 게임 에셋.

  shared/assets/cats/char01_t0.png ~ char06_t3.png  캐릭터 6종 × 파츠 단계 4장 (완성 렌더)
  shared/assets/cats/parts/char01/<Layer>.png       Char01의 파츠 레이어 (틴트 대상은 흰색 마스크)
  shared/assets/cats/parts/char01/layout.json       레이어별 배치 좌표 (시트 메타데이터 실측 검증본)

시트 구조: 셀 256×256, 열 피치 342, 행 피치 387, 좌상단 셀 (329, 417).
열 0~3 = 디폴트/1st/2nd/3rd 파츠 완성본, 열 4~25 = 파츠 레이어(Char01 행만 채워져 있음).
실행: python tools/extract_cat_sheet.py
"""
from PIL import Image
from collections import deque
import numpy as np, json, os

SRC = '리소스/1.png'
OUT = 'shared/assets/cats'
CELL_X = [329 + 342 * i for i in range(26)]
CELL_Y = [417 + 387 * i for i in range(11)]
PAD_L, PAD_T, PAD_R, PAD_B = 120, 140, 340, 330  # 셀 원점 기준 작업 창
BG = np.array([255.0, 0.0, 255.0])
GUIDE = np.array([51.0, 255.0, 0.0])  # Figma 슬라이스 가이드선

# 열 index → (레이어 번호, 이름). 번호가 클수록 위에 겹친다.
LAYERS = [
	(4, 85, 'Prop_Head'), (5, 80, 'Prop_Face'), (6, 70, 'Deco_Forehead'),
	(7, 62, 'Cat_Eyes_Highlight'), (8, 61, 'Cat_Eyes_Color'), (9, 60, 'Cat_Eyes_Base'),
	(10, 53, 'Cat_Nose'), (11, 52, 'Cat_Mouse'), (12, 51, 'Cat_Whiskers'),
	(13, 50, 'Cat_Cheek'), (14, 42, 'Cat_Feet_Outline'), (15, 41, 'Cat_Feet_Pawpad'),
	(16, 40, 'Cat_Feet_SkinFill'), (17, 35, 'Cat_Prop_Chest'), (18, 30, 'Cat_Prop_Belly'),
	(19, 22, 'Cat_Body_Outline'), (20, 21, 'Cat_Body_Pattern'), (21, 20, 'Cat_Body_SkinFill'),
	(22, 12, 'Cat_Tail_Outline'), (23, 11, 'Cat_Tail_Pattern'), (24, 10, 'Cat_Tail_SkinFill'),
	(25, 0, 'Prop_Back'),
]

# 시트에 적힌 레이어 메타데이터. anchor = 배치 기준 레이어(''이면 자기 자신),
# ox/oy = 그 기준의 좌상단에서의 오프셋, tint = 기본 색상(None이면 원본 색 그대로),
# recolor = 커스터마이징으로 색을 바꿀 수 있는가.
SPEC = {
	'Prop_Head':          {'anchor': 'Cat_Body_Outline', 'ox': 56, 'oy': -31, 'tint': None, 'recolor': False},
	'Prop_Face':          {'anchor': 'Cat_Body_Outline', 'ox': 0, 'oy': 0, 'tint': None, 'recolor': False},
	'Deco_Forehead':      {'anchor': 'Cat_Body_Outline', 'ox': 0, 'oy': 0, 'tint': None, 'recolor': False},
	'Cat_Eyes_Highlight': {'anchor': 'Cat_Eyes_Color', 'ox': 4, 'oy': 3, 'tint': 'ffffff', 'recolor': False},
	'Cat_Eyes_Color':     {'anchor': 'Cat_Body_Outline', 'ox': 47, 'oy': 87, 'tint': '000000', 'recolor': True},
	'Cat_Eyes_Base':      {'anchor': 'Cat_Body_Outline', 'ox': 0, 'oy': 0, 'tint': 'ffffff', 'recolor': True},
	'Cat_Nose':           {'anchor': 'Cat_Body_Outline', 'ox': 0, 'oy': 0, 'tint': '000000', 'recolor': True},
	'Cat_Mouse':          {'anchor': 'Cat_Body_Outline', 'ox': 80, 'oy': 115, 'tint': '000000', 'recolor': True},
	'Cat_Whiskers':       {'anchor': 'Cat_Body_Outline', 'ox': 15, 'oy': 108, 'tint': '000000', 'recolor': True},
	'Cat_Cheek':          {'anchor': 'Cat_Body_Outline', 'ox': 40, 'oy': 117, 'tint': 'feb8ad', 'recolor': True},
	'Cat_Feet_Outline':   {'anchor': 'Cat_Body_Outline', 'ox': -5, 'oy': 173, 'tint': '000000', 'recolor': False},
	'Cat_Feet_Pawpad':    {'anchor': 'Cat_Body_Outline', 'ox': 9, 'oy': 188, 'tint': 'fe856d', 'recolor': True},
	'Cat_Feet_SkinFill':  {'anchor': 'Cat_Body_Outline', 'ox': -5, 'oy': 173, 'tint': 'fbfbf8', 'recolor': True},
	'Cat_Prop_Chest':     {'anchor': 'Cat_Body_Outline', 'ox': 0, 'oy': 0, 'tint': None, 'recolor': False},
	'Cat_Prop_Belly':     {'anchor': 'Cat_Body_Outline', 'ox': 60, 'oy': 169, 'tint': None, 'recolor': False},
	'Cat_Body_Outline':   {'anchor': '', 'ox': 0, 'oy': 0, 'tint': '000000', 'recolor': False},
	'Cat_Body_Pattern':   {'anchor': 'Cat_Body_Outline', 'ox': 0, 'oy': 1, 'tint': 'fdbe03', 'recolor': True},
	'Cat_Body_SkinFill':  {'anchor': 'Cat_Body_Outline', 'ox': -1, 'oy': 2, 'tint': 'fbfbf8', 'recolor': True},
	'Cat_Tail_Outline':   {'anchor': 'Cat_Body_Outline', 'ox': 158, 'oy': 152, 'tint': '000000', 'recolor': False},
	'Cat_Tail_Pattern':   {'anchor': 'Cat_Body_Outline', 'ox': 200, 'oy': 155, 'tint': 'fdbe03', 'recolor': True},
	'Cat_Tail_SkinFill':  {'anchor': 'Cat_Body_Outline', 'ox': 162, 'oy': 156, 'tint': 'fbfbf8', 'recolor': True},
	'Prop_Back':          {'anchor': 'Cat_Body_Outline', 'ox': 0, 'oy': 0, 'tint': None, 'recolor': False},
}

A = np.asarray(Image.open(SRC).convert('RGB')).astype(float)


def coverage(c):
	"""마젠타 배경이 섞인 비율. 아트 팔레트엔 min(R,B) > G 인 색이 없다."""
	R, G, B = c[:, :, 0], c[:, :, 1], c[:, :, 2]
	return np.clip((np.minimum(R, B) - G) / 255.0, 0.0, 1.0)


def strip_guides(c):
	"""가이드선(초록 1px)을 가장 가까운 비-가이드 이웃으로 메운다."""
	g = np.abs(c - GUIDE).sum(2) < 60
	if not g.any():
		return c
	c = c.copy()
	h, w, _ = c.shape
	for y, x in zip(*np.where(g)):
		for d in range(1, 8):
			hit = None
			if y - d >= 0 and not g[y - d, x]: hit = c[y - d, x]
			elif y + d < h and not g[y + d, x]: hit = c[y + d, x]
			elif x - d >= 0 and not g[y, x - d]: hit = c[y, x - d]
			elif x + d < w and not g[y, x + d]: hit = c[y, x + d]
			if hit is not None:
				c[y, x] = hit
				break
		else:
			c[y, x] = BG
	return c


def keep_blobs(mask, inner):
	"""셀 안쪽에 걸치는 연결 성분만 남긴다 — 시트 라벨·메타데이터 텍스트 제거용."""
	h, w = mask.shape
	seen = np.zeros_like(mask)
	out = np.zeros_like(mask)
	x0, y0, x1, y1 = inner
	for sy in range(h):
		for sx in range(w):
			if not mask[sy, sx] or seen[sy, sx]:
				continue
			q = deque([(sy, sx)])
			seen[sy, sx] = True
			pts = []
			hit = False
			while q:
				py, px = q.popleft()
				pts.append((py, px))
				if x0 <= px <= x1 and y0 <= py <= y1:
					hit = True
				for ny in (py - 1, py, py + 1):
					for nx in (px - 1, px, px + 1):
						if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
							seen[ny, nx] = True
							q.append((ny, nx))
			if hit:
				for py, px in pts:
					out[py, px] = True
	return out


def bleed(px, rounds=3):
	"""투명 픽셀의 RGB를 이웃 색으로 채운다 — 확대/축소 시 마젠타 번짐 방지."""
	rgb = px[:, :, :3].astype(np.int32)
	a = px[:, :, 3] > 8
	for _ in range(rounds):
		src = a.copy()
		acc = np.zeros_like(rgb)
		cnt = np.zeros(a.shape, np.int32)
		for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
			sh = np.roll(np.roll(src, dy, 0), dx, 1)
			shv = np.roll(np.roll(rgb, dy, 0), dx, 1)
			m = sh & ~src
			acc[m] += shv[m]
			cnt += m
		fill = (cnt > 0)
		rgb[fill] = acc[fill] // cnt[fill, None]
		a |= fill
	out = px.copy()
	out[:, :, :3] = rgb.astype(np.uint8)
	return out


GRAY_LO = np.array([143.0, 152.0, 166.0])  # 잠긴 냥이 실루엣 / 사망 연출용 램프
GRAY_HI = np.array([223.0, 228.0, 234.0])


def grayscale(px):
	"""명도만 남겨 회청색 램프로 옮긴다 — 잠금 실루엣·사망 상태 공용."""
	rgb = px[:, :, :3].astype(float)
	luma = (rgb * np.array([0.299, 0.587, 0.114])).sum(2)[:, :, None] / 255.0
	out = px.copy()
	out[:, :, :3] = (GRAY_LO + (GRAY_HI - GRAY_LO) * luma).astype(np.uint8)
	return out


def cut(cx, cy, tight):
	"""셀 하나를 잘라 RGBA로. tight면 알파 bbox까지 좁히고 (원점, 크기)를 함께 준다."""
	c = strip_guides(A[cy - PAD_T:cy + PAD_B, cx - PAD_L:cx + PAD_R])
	m = keep_blobs(coverage(c) <= 0.94, (PAD_L + 6, PAD_T + 6, PAD_L + 250, PAD_T + 250))
	if not m.any():
		return None
	alpha = np.where(m, 1.0 - coverage(c), 0.0)
	af = np.clip(alpha, 1e-6, 1.0)[:, :, None]
	px = np.zeros(c.shape[:2] + (4,), np.uint8)
	px[:, :, :3] = np.clip((c - (1.0 - af) * BG) / af, 0, 255).astype(np.uint8)
	px[:, :, 3] = (alpha * 255).round().astype(np.uint8)
	px = bleed(px)
	if not tight:
		return px, (-PAD_L, -PAD_T)
	ys, xs = np.where(px[:, :, 3] > 8)
	x0, x1, y0, y1 = int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1
	return px[y0:y1, x0:x1], (x0 - PAD_L, y0 - PAD_T)


def main() -> None:
	os.makedirs(OUT + '/parts/char01', exist_ok=True)
	# --- 완성 렌더 24장: 6종 × 4단계, 공통 캔버스에 정렬 ---
	cells = {}
	bb = [9999, 9999, -9999, -9999]
	for ri in range(6):
		for ci in range(4):
			px, org = cut(CELL_X[ci], CELL_Y[ri], False)
			cells[(ri, ci)] = px
			ys, xs = np.where(px[:, :, 3] > 8)
			bb[0] = min(bb[0], int(xs.min()) + org[0]); bb[1] = min(bb[1], int(ys.min()) + org[1])
			bb[2] = max(bb[2], int(xs.max()) + org[0]); bb[3] = max(bb[3], int(ys.max()) + org[1])
	cx0, cy0, cx1, cy1 = bb[0] - 2, bb[1] - 2, bb[2] + 3, bb[3] + 3
	os.makedirs(OUT + '/gray', exist_ok=True)
	for (ri, ci), px in cells.items():
		crop = px[PAD_T + cy0:PAD_T + cy1, PAD_L + cx0:PAD_L + cx1]
		Image.fromarray(crop, 'RGBA').save('%s/char%02d_t%d.png' % (OUT, ri + 1, ci))
		Image.fromarray(grayscale(crop), 'RGBA').save(
				'%s/gray/char%02d_t%d.png' % (OUT, ri + 1, ci))
	print('완성 렌더 24장  캔버스 %d×%d (셀 원점 기준 %d, %d)' % (cx1 - cx0, cy1 - cy0, cx0, cy0))

	# --- Char01 파츠 레이어 ---
	layout = {}
	for ci, num, name in LAYERS:
		r = cut(CELL_X[ci], CELL_Y[0], True)
		if r is None:
			continue
		px, org = r
		Image.fromarray(px, 'RGBA').save('%s/parts/char01/%s.png' % (OUT, name))
		layout[name] = {'layer': num, 'x': org[0], 'y': org[1],
				'w': px.shape[1], 'h': px.shape[0]}
	for name, v in layout.items():
		v.update(SPEC[name])
	json.dump(layout, open('%s/parts/char01/layout.json' % OUT, 'w'), indent=1, sort_keys=True)
	print('Char01 레이어 %d장' % len(layout))
	_verify(layout, cx0, cy0)


def _verify(layout, cx0, cy0):
	"""레이어를 스펙대로 합성해 완성 렌더(char01_t3)와 대조한다."""
	ref = np.asarray(Image.open(OUT + '/char01_t3.png').convert('RGBA')).astype(int)
	canvas = Image.new('RGBA', (ref.shape[1], ref.shape[0]), (0, 0, 0, 0))
	body = layout['Cat_Body_Outline']
	def anchor_at(name):
		v = layout[name]
		if v['anchor'] == '' or v['anchor'] not in layout:
			return (v['ox'], v['oy'])
		b = anchor_at(v['anchor'])
		return (b[0] + v['ox'], b[1] + v['oy'])
	at = {n: anchor_at(n) for n in layout}
	for name in sorted(layout, key=lambda n: layout[n]['layer']):
		v = layout[name]
		im = Image.open('%s/parts/char01/%s.png' % (OUT, name)).convert('RGBA')
		if v['tint']:
			t = np.array([int(v['tint'][i:i + 2], 16) for i in (0, 2, 4)], float) / 255.0
			a = np.asarray(im).astype(float)
			a[:, :, :3] *= t
			im = Image.fromarray(a.astype(np.uint8), 'RGBA')
		canvas.alpha_composite(im, (body['x'] + at[name][0] - cx0,
				body['y'] + at[name][1] - cy0))
	got = np.asarray(canvas).astype(int)
	both = (ref[:, :, 3] > 8) | (got[:, :, 3] > 8)
	bad = (np.abs(ref - got)[:, :, :3].max(2) > 24) & both
	print('검증: 완성 렌더와 다른 픽셀 %d / %d' % (bad.sum(), both.sum()))


if __name__ == '__main__':
	main()
