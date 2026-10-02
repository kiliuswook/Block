# -*- coding: utf-8 -*-
"""리소스/CATTRIS_Hidden_Sheet.png(히든 파츠 시트) → 게임 에셋.

히든 파츠 = 디자인 냥이 6종과 별개로 **꾸미기 전용**으로 그려진 소품 세트.
시트는 캐릭터 시트와 같은 열 구성(Full Set + Layer 85 … Layer 0)이고,
행 하나 = 세트 하나(HiddenSetA_01 …)다. 한 행은 그 세트의 파츠를 기본 냥이 위에
얹은 완성 렌더(Full Set) + 파츠 레이어 셀들로 되어 있고, 그림이 있는 레이어만 채워져 있다.

  shared/assets/cats/parts/<set id>/<Layer>.png   세트별 파츠 레이어 (캐릭터 파츠와 같은 규격)
  shared/assets/cats/parts/<set id>/layout.json
  core/scripts/hidden_layouts.gd                  배치표 (cat_layouts.gd와 같은 모양, cat_sprite.gd가 합쳐 읽는다)

정합 방식은 extract_cat_sheet.py와 같다 — Full Set 렌더를 정답지 삼아 각 레이어 자리를
찾는다. 캔버스 좌표계는 캐릭터 시트와 **같다**(278×293, 셀 원점 기준 (3, -34)) — 그래서
나만의 캐릭터가 CatSprite.paint_mix()로 디자인 냥이 레이어와 그대로 겹쳐 그릴 수 있다.

시트 구조: 셀 256×256, 열 피치 342, 행 피치 387, 좌상단 셀 (33, 413). 열 0 = Full Set,
열 1~22 = 레이어(캐릭터 시트의 열 4~25와 같은 순서).

실행: python tools/extract_hidden_sheet.py   (2~3분)
"""
import json, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cat_layout
import extract_cat_sheet as E

SRC = '리소스/CATTRIS_Hidden_Sheet.png'
OUT = 'shared/assets/cats'
ROWS = 12
CELL_X = [33 + 342 * i for i in range(23)]
CELL_Y = [413 + 387 * i for i in range(ROWS)]
CANVAS_ORG = (3, -34)  # 캐릭터 시트가 쓴 캔버스 원점 (셀 원점 기준)
CANVAS = (278, 293)
# 행 → 세트 id. 시트 라벨 HiddenSetA_01 … HiddenSetD_03.
SET_IDS = ['hidden_%s%02d' % (g, n) for g in 'abcd' for n in (1, 2, 3)]
# 열 index → (레이어 번호, 이름): 캐릭터 시트와 같은 순서, 열만 3칸 앞이다.
LAYERS = [(ci - 3, num, name) for ci, num, name in E.LAYERS]

_src = np.asarray(Image.open(SRC).convert('RGB')).astype(float)
A = np.empty((_src.shape[0] + E.MARGIN * 2, _src.shape[1] + E.MARGIN * 2, 3), float)
A[:, :] = E.BG
A[E.MARGIN:E.MARGIN + _src.shape[0], E.MARGIN:E.MARGIN + _src.shape[1]] = _src
E.A = A  # extract_cat_sheet의 cut()이 이 시트를 읽게 바꿔치기
CELL_X = [x + E.MARGIN for x in CELL_X]
CELL_Y = [y + E.MARGIN for y in CELL_Y]


# 기본 냥이 = char01의 본체 레이어를 흰색으로. 자리는 char01 배치표 그대로.
BASE_SRC = '%s/parts/char01' % OUT
BASE_NAMES = ['Cat_Body_Outline', 'Cat_Body_SkinFill', 'Cat_Feet_Outline', 'Cat_Feet_SkinFill',
		'Cat_Feet_Pawpad', 'Cat_Cheek', 'Cat_Whiskers']
BASE_TINT = {'Cat_Body_SkinFill': (251, 251, 248), 'Cat_Feet_SkinFill': (251, 251, 248),
		'Cat_Feet_Pawpad': (254, 133, 109), 'Cat_Cheek': (254, 184, 173)}
_bl = json.load(open(BASE_SRC + '/layout.json'))
BASE_POS = {n: (_bl[n]['x'], _bl[n]['y']) for n in BASE_NAMES}


def _base_layers(hidden):
	out = {}
	for n in BASE_NAMES:
		px = np.asarray(Image.open('%s/%s.png' % (BASE_SRC, n)).convert('RGBA')).copy()
		if n in BASE_TINT:
			px[:, :, :3] = (px[:, :, :3].astype(float) * np.array(BASE_TINT[n]) / 255.0).astype(np.uint8)
		out[n] = {'px': px, 'layer': _bl[n]['layer'], 'colored': True}
	# 세트가 눈·입을 안 주면 기본 냥이의 것이 보인다 — 그것도 고정 레이어로.
	has_eyes = any(h.startswith('Cat_Eyes') for h in hidden)
	for n in ('Cat_Eyes_Color', 'Cat_Eyes_Highlight', 'Cat_Mouse'):
		if (has_eyes if n.startswith('Cat_Eyes') else 'Cat_Mouse' in hidden):
			continue
		if True:
			px = np.asarray(Image.open('%s/%s.png' % (BASE_SRC, n)).convert('RGBA')).copy()
			t = _bl[n]['tint']
			if t:
				px[:, :, :3] = (px[:, :, :3].astype(float) * np.array(
						[int(t[i:i + 2], 16) for i in (0, 2, 4)]) / 255.0).astype(np.uint8)
			out[n] = {'px': px, 'layer': _bl[n]['layer'], 'colored': True}
			BASE_POS[n] = (_bl[n]['x'], _bl[n]['y'])
	return out


def _fit_overflow(fit, px, pos, base):
	"""Full Set 셀 밖으로 잘려 나간 소품(피자 상자)의 자리.

	Fitter.fit()은 렌더 밖으로 나가는 자리를 크게 벌하므로 상자를 몸 뒤로 구겨 넣는다.
	여기서는 "보이는 부분만" 비교한다 — 기본 냥이가 덮지 않은 렌더 화소 중 소품 알파가
	있는 자리의 색 오차 평균이 가장 작은 (x, y). 캔버스 밖은 그냥 무시.
	"""
	H, W = fit.shape
	h, w = px.shape[:2]
	am = px[:, :, 3] > 200
	art = px[:, :, :3].astype(float)
	covered = np.zeros(fit.shape, bool)
	for n in base:
		if fit.layers[n]['layer'] > 0:
			covered |= cat_layout.mask_at(base[n]['px'], pos[n], fit.shape)
	usable = fit.opaque & ~covered
	best = None
	for y in range(-h // 2, H - 20):
		for x in range(0, W - 20):
			y0, x0 = max(0, y), max(0, x)
			y1, x1 = min(H, y + h), min(W, x + w)
			if y1 - y0 < 20 or x1 - x0 < 20:
				continue
			sub_am = am[y0 - y:y1 - y, x0 - x:x1 - x]
			vis = sub_am & usable[y0:y1, x0:x1]
			nv = int(vis.sum())
			if nv < 400:
				continue
			d = np.abs(fit.R[y0:y1, x0:x1] - art[y0 - y:y1 - y, x0 - x:x1 - x]).max(2)[vis]
			# 소품이 있어야 할 자리에 렌더가 비어 있으면(투명) 그것도 오차
			miss = int((sub_am & ~fit.opaque[y0:y1, x0:x1] & ~covered[y0:y1, x0:x1]).sum())
			err = (d > 40).mean() + miss / max(nv, 1)
			if best is None or err < best[0]:
				best = (err, x, y)
	return (best[1], best[2])


# 기본 냥이의 검은 눈 위에 흰 하이라이트만 얹는 세트 — 눈 슬롯이 이 세트를 빌리면
# 검은 눈이 함께 가야 하므로 char01의 Cat_Eyes_Color를 Cat_Eyes_Base로 복사해 넣는다.
BORROW_BASE_EYES = {'hidden_a01'}


def _borrow_base_eyes(sid, d, layout):
	px = np.asarray(Image.open(BASE_SRC + '/Cat_Eyes_Color.png').convert('RGBA')).copy()
	px[:, :, :3] = 0
	Image.fromarray(px, 'RGBA').save('%s/Cat_Eyes_Base.png' % d)
	b = _bl['Cat_Eyes_Color']
	layout['Cat_Eyes_Base'] = {'layer': 60, 'x': b['x'], 'y': b['y'], 'w': b['w'], 'h': b['h'],
			'tint': None, 'recolor': False, 'tiers': [0, 1, 2, 3]}


def main(rows=None) -> None:
	all_layouts = {}
	for ri in (rows if rows is not None else range(ROWS)):
		sid = SET_IDS[ri]
		full = E.cut(CELL_X[0], CELL_Y[ri], False)[0]
		ox, oy = CANVAS_ORG
		ref = full[E.PAD_T + oy:E.PAD_T + oy + CANVAS[1], E.PAD_L + ox:E.PAD_L + ox + CANVAS[0]]
		layers = {}
		for ci, num, name in LAYERS:
			r = E.cut(CELL_X[ci], CELL_Y[ri], True)
			if r is None:
				continue
			layers[name] = {'px': r[0], 'layer': num, 'colored': E.flat_color(r[0]) is None}
		# Full Set은 "흰 기본 냥이(char01 몸통, 무늬 없음) + 이 세트의 소품"이다.
		# 기본 냥이 레이어를 자리 고정으로 같이 넣어야 소품 자리가 정확히 잡힌다
		# (없으면 어긋난 화소가 온통이라 정련이 방향을 잃는다).
		base = _base_layers(layers)
		fit = cat_layout.Fitter(ref, {**base, **layers})
		pos = {n: BASE_POS[n] for n in base}
		claimed = np.zeros(fit.shape, bool)
		for n in base:
			claimed |= cat_layout.mask_at(base[n]['px'], pos[n], fit.shape)
		for n in fit.order:  # 위 → 아래, 소품만 새로 놓는다
			if n in base:
				continue
			par = cat_layout.CONTAIN.get(n)
			allow = None
			if par in pos:
				allow = cat_layout.grow(cat_layout.filled(cat_layout.mask_at(
						fit.layers[par]['px'], pos[par], fit.shape)), np.ones(fit.shape, bool), 4)
			pos[n] = fit.fit(n, claimed, allow, None, fit.prior_window(n, pos))
			claimed |= cat_layout.mask_at(fit.layers[n]['px'], pos[n], fit.shape)
		for _ in range(2):  # 정련: 지금 스택이 렌더와 어긋나는 자리를 메우는 쪽으로
			for n in fit.order:
				if n in base:
					continue
				above = np.zeros(fit.shape, bool)
				for o in fit.order:
					if o != n and fit.layers[o]['layer'] > fit.layers[n]['layer']:
						above |= cat_layout.mask_at(fit.layers[o]['px'], pos[o], fit.shape)
				rgb, a = fit.render({k: v for k, v in pos.items() if k != n})
				wrong = fit.opaque & ((a < 200) | (np.abs(rgb - fit.R).max(2) > 24))
				pos[n] = fit.fit(n, above, None, wrong, fit.prior_window(n, pos))
		back = None
		if 'Prop_Back' in layers:  # 캔버스 밖으로 삐져나가는 소품 — 밖을 벌하지 않는 정합
			back = _fit_overflow(fit, layers['Prop_Back']['px'], pos, base)
			pos.pop('Prop_Back')  # tints()/quality()는 캔버스 밖을 못 다룬다 (소품이라 틴트도 없다)
			fit.layers.pop('Prop_Back'); fit.order.remove('Prop_Back')
		tints = fit.tints(pos)
		q = fit.quality(pos)
		if back is not None:
			pos['Prop_Back'] = back
			tints['Prop_Back'] = None
			q['Prop_Back'] = (0, 0)
		for n in base:
			pos.pop(n); tints.pop(n)
		d = '%s/parts/%s' % (OUT, sid)
		os.makedirs(d, exist_ok=True)
		layout = {}
		for name, p in layers.items():
			Image.fromarray(p['px'], 'RGBA').save('%s/%s.png' % (d, name))
			t = tints[name]
			layout[name] = {
				'layer': p['layer'], 'x': pos[name][0], 'y': pos[name][1],
				'w': p['px'].shape[1], 'h': p['px'].shape[0],
				'tint': None if t is None else '%02x%02x%02x' % tuple(
						int(round(min(255.0, max(0.0, v)))) for v in t),
				'recolor': name in E.RECOLOR and E._light_mask(p['px']),
				'tiers': [0, 1, 2, 3],
			}
		if sid in BORROW_BASE_EYES:
			_borrow_base_eyes(sid, d, layout)
		json.dump(layout, open('%s/layout.json' % d, 'w'), indent=1, sort_keys=True)
		Image.fromarray(ref, 'RGBA').save('.tmp_shots/hidden_ref_%s.png' % sid)
		all_layouts[sid] = layout
		print('%s  레이어 %d장  %s' % (sid, len(layers),
				' '.join('%s@(%d,%d) q=%.2f' % (n, pos[n][0], pos[n][1], q[n][0]) for n in pos)))
	if rows is not None:  # 일부 행만 돌렸으면 나머지는 지난 결과(layout.json)를 그대로 쓴다
		for sid in SET_IDS:
			f = '%s/parts/%s/layout.json' % (OUT, sid)
			if sid not in all_layouts and os.path.exists(f):
				all_layouts[sid] = json.load(open(f))
	write_gd(all_layouts)


def write_gd(all_layouts) -> None:
	L = ['# 자동 생성 — `python tools/extract_hidden_sheet.py` 가 만든다. 직접 고치지 말 것.',
		'## 히든 파츠 시트(리소스/CATTRIS_Hidden_Sheet.png)에서 뽑은 세트별 파츠 레이어 배치표.',
		'## 모양은 cat_layouts.gd와 같고 캔버스 좌표계도 같다 — cat_sprite.gd가 둘을 합쳐 읽는다.',
		'extends RefCounted', '', 'const LAYOUTS := {']
	for cid in sorted(all_layouts):
		L.append('	"%s": [' % cid)
		lay = all_layouts[cid]
		for n in sorted(lay, key=lambda k: lay[k]['layer']):
			v = lay[n]
			tint = 'Color(0, 0, 0, 0)' if v['tint'] is None else 'Color("%s")' % v['tint']
			L.append('		{"n": "%s", "layer": %d, "at": Vector2(%d, %d), "tint": %s,'
					% (n, v['layer'], v['x'], v['y'], tint))
			L.append('			"recolor": %s, "tiers": [0, 1, 2, 3]},'
					% ('true' if v['recolor'] else 'false'))
		L.append('	],')
	L += ['}', '']
	open('core/scripts/hidden_layouts.gd', 'w', encoding='utf-8').write('\n'.join(L))
	print('배치표 → core/scripts/hidden_layouts.gd (%d세트)' % len(all_layouts))


if __name__ == '__main__':
	main([int(a) for a in sys.argv[1:]] if len(sys.argv) > 1 else None)
