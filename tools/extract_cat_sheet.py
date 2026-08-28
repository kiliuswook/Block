# -*- coding: utf-8 -*-
"""리소스/CATTRIS_Char_Sheet.png(마젠타 크로마키 캐릭터 시트) → 게임 에셋.

  shared/assets/cats/char01_t0.png ~ char06_t3.png  캐릭터 6종 × 파츠 단계 4장 (완성 렌더)
  shared/assets/cats/gray/char0N_tT.png             같은 그림의 회청색 램프 (잠금·사망)
  shared/assets/cats/parts/char0N/<Layer>.png       캐릭터별 파츠 레이어 (틴트 대상은 단색 마스크)
  shared/assets/cats/parts/char0N/layout.json       레이어별 캔버스 좌표·기본색·해금 단계
  core/scripts/cat_layouts.gd                       그 배치표를 GDScript 상수로 구운 것

시트 구조: 셀 256×256, 열 피치 342, 행 피치 387, 좌상단 셀 (52, 421).
열 0~3 = 디폴트/1st/2nd/3rd 파츠 완성본, 열 4~25 = 파츠 레이어(6행 모두 채워져 있음).

파츠 셀은 파츠를 셀 한가운데 그려 둔 것이라 배치 좌표가 없다. 그래서 좌표·기본
틴트·해금 단계를 전부 완성 렌더와 대조해 **실측**한다:
  - 좌표: `cat_layout.Fitter`가 완성 렌더 위로 레이어를 미끄러뜨려 맞는 자리를 찾는다.
  - 판(t0~t3)마다 따로 정합하고 레이어별로 "가장 잘 드러난 판"의 자리를 채택한다
    (char02는 t2부터 선글라스가 눈을 가려서 t3만 보면 눈을 못 맞춘다).
  - 틴트: 단색 마스크는 그 레이어가 최상단인 픽셀의 렌더 색, 소품은 원본 색.
  - 단계: 단계마다 "빼면 렌더에 더 가까워지는 소품"을 제외한다.

10분쯤 걸린다. 끝에 캐릭터별 "어긋난 px"을 찍는데 대부분 안티에일리어싱 경계라
2~6k면 정상 — 그보다 크면 어떤 레이어가 엉뚱한 데 붙은 것이다.

실행: python tools/extract_cat_sheet.py
"""
from PIL import Image
import numpy as np, json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cat_layout

SRC = '리소스/CATTRIS_Char_Sheet.png'
OUT = 'shared/assets/cats'
ROWS = 6
CELL = 256
CELL_X = [52 + 342 * i for i in range(26)]
CELL_Y = [421 + 387 * i for i in range(ROWS)]
PAD_L, PAD_T, PAD_R, PAD_B = 120, 140, 340, 330  # 셀 원점 기준 작업 창
MARGIN = 400  # 작업 창이 시트 밖으로 나가지 않도록 두르는 여백
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

# 커스터마이징으로 색을 바꿀 수 있는 레이어 (외곽선·소품은 불가).
RECOLOR = {
	'Cat_Eyes_Color', 'Cat_Eyes_Base', 'Cat_Nose', 'Cat_Mouse', 'Cat_Whiskers', 'Cat_Cheek',
	'Cat_Feet_Pawpad', 'Cat_Feet_SkinFill', 'Cat_Body_Pattern', 'Cat_Body_SkinFill',
	'Cat_Tail_Pattern', 'Cat_Tail_SkinFill',
}

# 해금 단계 후보 — 나머지는 무조건 0단계(디폴트 비주얼)에 포함한다.
TIERABLE = {
	'Prop_Head', 'Prop_Face', 'Prop_Back', 'Deco_Forehead',
	'Cat_Prop_Chest', 'Cat_Prop_Belly',
	'Cat_Tail_Outline', 'Cat_Tail_Pattern', 'Cat_Tail_SkinFill',
}
# 같은 단계에서 함께 붙어야 하는 묶음.
TIER_GROUPS = [{'Cat_Tail_Outline', 'Cat_Tail_Pattern', 'Cat_Tail_SkinFill'}]

_src = np.asarray(Image.open(SRC).convert('RGB')).astype(float)
A = np.empty((_src.shape[0] + MARGIN * 2, _src.shape[1] + MARGIN * 2, 3), float)
A[:, :] = BG
A[MARGIN:MARGIN + _src.shape[0], MARGIN:MARGIN + _src.shape[1]] = _src
CELL_X = [x + MARGIN for x in CELL_X]
CELL_Y = [y + MARGIN for y in CELL_Y]


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
	"""셀 안쪽에 걸치는 연결 성분만 남긴다 — 시트 라벨·셀 테두리 제거용."""
	x0, y0, x1, y1 = inner
	seed = np.zeros_like(mask)
	seed[y0:y1 + 1, x0:x1 + 1] = mask[y0:y1 + 1, x0:x1 + 1]
	if not seed.any():
		return seed
	while True:  # 8-이웃 팽창을 마스크 안에서 수렴할 때까지
		grown = seed.copy()
		for dy in (-1, 0, 1):
			for dx in (-1, 0, 1):
				grown |= np.roll(np.roll(seed, dy, 0), dx, 1)
		grown &= mask
		if grown.sum() == seed.sum():
			return seed
		seed = grown


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


def flat_color(px):
	"""단색 마스크면 그 색, 아니면 None (색이 살아 있는 소품 그림)."""
	m = px[:, :, 3] > 200
	if m.sum() < 8:
		return None
	v = px[:, :, :3][m].astype(float)
	return None if v.std(0).max() > 6.0 else v.mean(0)


def _light_mask(px):
	"""곱셈 틴트로 색을 바꿀 수 있는 그림인가 — 밝은 단색 마스크만 가능."""
	c = flat_color(px)
	return c is not None and float(np.mean(c)) > 24.0


def assign_tiers(fit, pos, tints, refs):
	"""단계별로 어떤 레이어가 그려지는지 고른다.

	파츠는 대체로 쌓이지만 (char04의 베개처럼) 디폴트에만 있다가 빠지는 소품도
	있어서, 단계마다 독립적으로 "빼면 완성 렌더에 더 가까워지는 소품"을 제외한다.
	"""
	names = list(pos)
	sets = {}
	for T in range(4):
		fit.R = refs[T][:, :, :3].astype(float)
		fit.alpha = refs[T][:, :, 3].astype(float)
		fit.opaque = fit.alpha > 200
		best = set(names)
		score = fit.mismatch(pos, tints, best)[0]
		improved = True
		while improved:
			improved = False
			for grp in TIER_GROUPS + [{n} for n in TIERABLE]:
				if not (grp & best):
					continue
				cand = best - grp
				s2 = fit.mismatch(pos, tints, cand)[0]
				if s2 < score:
					best, score, improved = cand, s2, True
		sets[T] = best
	fit.R = refs[3][:, :, :3].astype(float)
	fit.alpha = refs[3][:, :, 3].astype(float)
	fit.opaque = fit.alpha > 200
	tiers = {n: [T for T in range(4) if n in sets[T]] for n in names}
	return tiers, sets


def rescue(layers, pos, tints, tiers, refs):
	"""어느 단계에도 못 들어간 레이어를 그 레이어가 실제로 보이는 판에 다시 맞춘다.

	char04의 베개처럼 t3에는 없고 디폴트에만 있는 소품은 t3 기준 정합이 통하지 않는다.
	"""
	moved = []
	for name in list(pos):
		if tiers[name]:
			continue
		best = None
		for T in (0, 1, 2):
			f2 = cat_layout.Fitter(refs[T], layers)
			above = np.zeros(f2.shape, bool)
			for o in pos:
				if layers[o]['layer'] > layers[name]['layer']:
					above |= cat_layout.mask_at(layers[o]['px'], pos[o], f2.shape)
			rgb, a = f2.render({k: v for k, v in pos.items() if k != name}, tints)
			wrong = f2.opaque & ((a < 200) | (np.abs(rgb - f2.R).max(2) > 24))
			p2 = f2.fit(name, above, None, wrong)
			base = f2.mismatch({k: v for k, v in pos.items() if k != name}, tints)[0]
			cand = dict(pos); cand[name] = p2
			gain = base - f2.mismatch(cand, tints)[0]
			if best is None or gain > best[0]:
				best = (gain, p2, T)
		if best and best[0] > 0:
			pos[name] = best[1]
			moved.append((name, best[2]))
	return moved


def main() -> None:
	# --- 완성 렌더 24장: 6종 × 4단계, 공통 캔버스에 정렬 ---
	cells = {}
	bb = [9999, 9999, -9999, -9999]
	for ri in range(ROWS):
		for ci in range(4):
			px, org = cut(CELL_X[ci], CELL_Y[ri], False)
			cells[(ri, ci)] = px
			ys, xs = np.where(px[:, :, 3] > 8)
			bb[0] = min(bb[0], int(xs.min()) + org[0]); bb[1] = min(bb[1], int(ys.min()) + org[1])
			bb[2] = max(bb[2], int(xs.max()) + org[0]); bb[3] = max(bb[3], int(ys.max()) + org[1])
	cx0, cy0, cx1, cy1 = bb[0] - 2, bb[1] - 2, bb[2] + 3, bb[3] + 3
	os.makedirs(OUT + '/gray', exist_ok=True)
	renders = {}
	for (ri, ci), px in cells.items():
		crop = px[PAD_T + cy0:PAD_T + cy1, PAD_L + cx0:PAD_L + cx1]
		renders[(ri, ci)] = np.asarray(crop).astype(int)
		Image.fromarray(crop, 'RGBA').save('%s/char%02d_t%d.png' % (OUT, ri + 1, ci))
		Image.fromarray(grayscale(crop), 'RGBA').save(
				'%s/gray/char%02d_t%d.png' % (OUT, ri + 1, ci))
	print('완성 렌더 24장  캔버스 %d×%d (셀 원점 기준 %d, %d)' % (cx1 - cx0, cy1 - cy0, cx0, cy0))

	# --- 캐릭터별 파츠 레이어 ---
	all_layouts = {}
	for ri in range(ROWS):
		cid = 'char%02d' % (ri + 1)
		d = '%s/parts/%s' % (OUT, cid)
		os.makedirs(d, exist_ok=True)
		layers = {}
		for ci, num, name in LAYERS:
			r = cut(CELL_X[ci], CELL_Y[ri], True)
			if r is None:
				continue
			px = r[0]
			layers[name] = {'px': px, 'layer': num, 'colored': flat_color(px) is None}
		refs = {t: renders[(ri, t)].astype(np.uint8) for t in range(4)}
		# 판마다 따로 정합해 보고, 레이어별로 "가장 잘 드러난 판"의 자리를 채택한다.
		# (char02는 t2부터 선글라스가 눈을 가려서 t3만 보면 눈을 못 맞춘다.)
		fits, sols = {}, {}
		for t in range(4):
			fits[t] = cat_layout.Fitter(refs[t], layers)
			p, ti = fits[t].solve()
			sols[t] = (p, ti, fits[t].quality(p))
		pos, tints, src = {}, {}, {}
		for name in layers:
			best = max(range(4), key=lambda t: sols[t][2][name][0] - 4 * sols[t][2][name][1])
			pos[name] = sols[best][0][name]
			src[name] = best
		fit = fits[3]
		for name in layers:  # 채택한 자리 기준으로 그 판에서 틴트를 다시 뽑는다
			tints[name] = fits[src[name]].tints(pos)[name]
		tiers, sets = assign_tiers(fit, pos, tints, refs)
		moved = rescue(layers, pos, tints, tiers, refs)
		if moved:
			for name, T in moved:
				tints[name] = cat_layout.Fitter(refs[T], layers).tints(pos)[name]
			tiers, sets = assign_tiers(fit, pos, tints, refs)

		layout = {}
		for name, p in layers.items():
			Image.fromarray(p['px'], 'RGBA').save('%s/%s.png' % (d, name))
			t = tints[name]
			layout[name] = {
				'layer': p['layer'], 'x': pos[name][0], 'y': pos[name][1],
				'w': p['px'].shape[1], 'h': p['px'].shape[0],
				'tint': None if t is None else '%02x%02x%02x' % tuple(
						int(round(min(255.0, max(0.0, v)))) for v in t),
				# 색을 갈아끼울 수 있으려면 원본이 "밝은 단색 마스크"여야 한다
				# (곱셈 틴트라 검은 그림은 무슨 색을 곱해도 검다).
				'recolor': name in RECOLOR and _light_mask(p['px']),
				'tiers': tiers[name],
			}
		json.dump(layout, open('%s/layout.json' % d, 'w'), indent=1, sort_keys=True)
		all_layouts[cid] = layout

		bad = []
		for t in range(4):
			fit.R = refs[t][:, :, :3].astype(float)
			fit.alpha = refs[t][:, :, 3].astype(float)
			fit.opaque = fit.alpha > 200
			bad.append(fit.mismatch(pos, tints, sets[t])[0])
		steps = {t: sorted(n for n in layers if tiers[n] != [0, 1, 2, 3] and t in tiers[n])
				for t in range(4)}
		dropped = sorted(n for n in layers if not tiers[n])
		print('%s  레이어 %2d장  단계별 소품 %s%s%s' % (cid, len(layers), steps,
				'  재정합 ' + ','.join('%s@t%d' % m for m in moved) if moved else '',
				'  버림 ' + ','.join(dropped) if dropped else ''))
		print('        검증(어긋난 px, t0~t3) %s / 전체 %d' % (bad, fit.mismatch(pos, tints)[1]))

	body = all_layouts['char01']['Cat_Body_Outline']
	write_gd(all_layouts, (cx1 - cx0, cy1 - cy0),
			(body['x'], body['y'], body['w'], body['h']))


def write_gd(all_layouts, canvas, body) -> None:
	"""게임이 읽는 배치표를 GDScript 상수로 굽는다 (익스포트·파싱 부담 없음)."""
	L = ['# 자동 생성 — `python tools/extract_cat_sheet.py` 가 만든다. 직접 고치지 말 것.',
		'## 컨셉 시트에서 뽑은 캐릭터별 파츠 레이어 배치표 (cat_sprite.gd가 쓴다).',
		'##',
		'## at   = 완성 렌더 캔버스 좌표(좌상단)',
		'## tint = 곱할 기본 색 (알파 0이면 원본 색 그대로)',
		'## recolor = 커스터마이징으로 색을 바꿀 수 있는 레이어',
		'## tiers = 이 레이어가 그려지는 해금 단계 목록',
		'extends RefCounted', '',
		'const CANVAS := Vector2(%d, %d)' % canvas,
		'const BODY := Rect2(%d, %d, %d, %d)' % body, '',
		'const LAYOUTS := {']
	for cid in sorted(all_layouts):
		L.append('	"%s": [' % cid)
		lay = all_layouts[cid]
		for n in sorted(lay, key=lambda k: lay[k]['layer']):
			v = lay[n]
			tint = 'Color(0, 0, 0, 0)' if v['tint'] is None else 'Color("%s")' % v['tint']
			L.append('		{"n": "%s", "layer": %d, "at": Vector2(%d, %d), "tint": %s,'
					% (n, v['layer'], v['x'], v['y'], tint))
			L.append('			"recolor": %s, "tiers": [%s]},'
					% ('true' if v['recolor'] else 'false',
						', '.join(str(t) for t in v['tiers'])))
		L.append('	],')
	L += ['}', '']
	open('core/scripts/cat_layouts.gd', 'w', encoding='utf-8').write('\n'.join(L))
	print('배치표 → core/scripts/cat_layouts.gd (%d종)' % len(all_layouts))


if __name__ == '__main__':
	main()
