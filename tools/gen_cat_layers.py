# -*- coding: utf-8 -*-
"""신규 냥이 10종(char07~16)의 파츠 레이어 — Higgsfield로 부위를 떼어 낸 그림 → 게임 에셋.

신규 10종은 생성 이미지라 완성 렌더(`shared/assets/cats/charNN_tT.png`)밖에 없다.
레이어가 필요해서, 완성 렌더를 Higgsfield(GPT Image 2.5 편집)에 넣고 부위마다
"이것만 남기고 나머지는 마젠타로 지워라"로 한 장씩 뽑았다:

  리소스/new_chars/layers/charNN_body.png   몸통만 (얼굴·앞발·소품 제거, 가려진 곳은 몸 색으로 메움)
  리소스/new_chars/layers/charNN_feet.png   앞발 두 개만
  리소스/new_chars/layers/charNN_face.png   얼굴 이목구비만 (눈·코·입·볼·수염)
  리소스/new_chars/layers/charNN_<Layer>.png 소품 하나만 (Prop_Head, Cat_Prop_Belly, tail …)

생성 편집은 자리·크기를 조금씩 흘린다 — 그래서 그림마다 **완성 렌더에 다시 정합**한다
(배율 × 위치 전수 탐색, 색 군집별 일치 화소 수를 FFT 상관으로 센다). 자리를 찾은 뒤
시트 레이어 규칙대로 쪼갠다:
  몸통 → Cat_Body_Outline(검은 테) · Cat_Body_SkinFill(채운 실루엣, 몸 색 틴트) · Cat_Body_Pattern(나머지 색)
  앞발 → Cat_Feet_Outline · Cat_Feet_SkinFill · Cat_Feet_Pawpad
  얼굴 → 성분별로 Cat_Eyes_Color(눈의 어두운 몫) + Cat_Eyes_Highlight(눈의 나머지 색) ·
         Cat_Nose · Cat_Mouse · Cat_Whiskers · Cat_Cheek
  꼬리 → Cat_Tail_Outline · Cat_Tail_SkinFill · Cat_Tail_Pattern
  소품 → 원본 색 그대로 한 장

결과: shared/assets/cats/parts/charNN/*.png + layout.json, 배치표 core/scripts/gen_layouts.gd
(자동 생성), 점검 그림 .tmp_shots/gen_cat_layers.png (렌더 | 레이어 합성 | 차이, 4단계).

사용:
  python tools/gen_cat_layers.py prep            Higgsfield에 넣을 정사각 입력 → .tmp_shots/gen_in/
  python tools/gen_cat_layers.py prompts         그림마다 쓸 프롬프트 목록 (JSON)
  python tools/gen_cat_layers.py [charNN ...]    레이어 추출 (인자 없으면 전부)
끝나면 --import 후 .import의 mipmaps/generate=true 확인.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cat_layout import corr  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATS = os.path.join(ROOT, 'shared', 'assets', 'cats')
SRC = os.path.join(ROOT, '리소스', 'new_chars', 'layers')
SHOTS = os.path.join(ROOT, '.tmp_shots')
PAD = 72            # import_gen_cats.py의 사방 여백 (배치표 좌표는 여백을 뺀 캔버스 기준)
SQ = 1024           # Higgsfield 입력 한 변
CENTER_X = 28 + 194 / 2 + PAD  # 몸통 가운데 x (렌더 좌표)

# 소품: (레이어 이름, 처음 붙는 단계, 그림 설명, 원본 판)
# 원본 판 = 편집에 넣은 완성 렌더(0 = 디폴트, 3 = 소품이 다 붙은 판).
# "complete" = 가려진 부분까지 그려 달라고 한다 (몸 뒤로 들어가는 꼬리·등 소품 등).
SPEC = {
	'char07': {'body': 'cream body with caramel ears and caramel forehead stripes', 'props': [
		('Prop_Head', 1, 'the white chef hat', 3, False),
		('Cat_Prop_Belly', 2, 'the pink cupcake with a cherry on top', 3, True),
		('tail', 3, 'the fluffy curled caramel tail on the right', 3, True)]},
	'char08': {'body': 'brown tabby body with darker brown stripes', 'face_note':
			'The eyepatch covers the left eye: remove the eyepatch and its strap, and draw the hidden eye '
			'as a mirror copy of the visible eye.', 'props': [
		('Prop_Face', 0, 'the black eyepatch together with its strap', 0, False),
		('Prop_Head', 1, 'the black pirate tricorn hat with the skull emblem', 3, False),
		('Cat_Prop_Belly', 2, 'the golden treasure chest', 3, True),
		('tail', 3, 'the striped tabby tail on the right', 3, True)]},
	'char09': {'body': 'blue-grey body with darker blue-grey ears', 'props': [
		('Deco_Forehead', 0, 'the small yellow star on the forehead', 0, False),
		('Prop_Head', 1, 'the headband with two star antennae', 3, False),
		('Cat_Prop_Belly', 2, 'the small white and red rocket', 3, True),
		('tail', 3, 'the curled blue-grey tail on the right', 3, True)]},
	'char10': {'body': 'dark charcoal navy body', 'props': [
		('Prop_Head', 1, 'the red headband with its knot tails', 3, False),
		('Prop_Back', 2, 'the katana sword behind the cat (hilt sticking out at the top right)', 3, True),
		('tail', 3, 'the zigzag dark tail on the right', 3, True)]},
	'char11': {'body': 'white body with an orange patch on the left ear and a black patch on the right ear', 'props': [
		('Deco_Forehead', 0, 'the small blue paint splash on the cheek', 0, False),
		('Prop_Head', 1, 'the red beret', 3, False),
		('Cat_Prop_Belly', 2, 'the paint palette with the brush', 3, True),
		('tail', 3, 'the striped orange, black and white tail on the right', 3, True)]},
	'char12': {'body': 'pastel pink body with darker pink ears', 'props': [
		('Deco_Forehead', 0, 'the small red heart on the forehead', 0, False),
		('Prop_Head', 1, 'the red strawberry knit beanie with green leaves', 3, False),
		('Cat_Prop_Belly', 2, 'the strawberry milk carton with a straw', 3, True),
		('tail', 3, 'the curled pink tail with the red ribbon', 3, True)]},
	'char13': {'body': 'lilac body with darker purple ears', 'props': [
		('Prop_Head', 1, 'the golden crown', 3, False),
		('Cat_Prop_Chest', 2, 'the red royal cape with the white fur trim and the red brooch, exactly as it is '
			'visible (do not draw the parts hidden behind the body)', 3, False),
		('tail', 3, 'the long curvy lilac tail on the right', 3, True)]},
	'char14': {'body': 'sandy golden body covered with brown leopard spots', 'props': [
		('Cat_Prop_Chest', 1, 'the colorful flower lei necklace', 3, False),
		('Cat_Prop_Belly', 2, 'the watermelon slice', 3, True),
		('tail', 3, 'the spotted leopard tail on the right', 3, True)]},
	'char15': {'body': 'grey body with a white face and white chest area', 'props': [
		('Prop_Head', 1, 'the yellow rain hat that the cat wears on its head (the round hat with a brim) — '
			'erase the open umbrella completely', 3, False),
		('Prop_Back', 2, 'the yellow umbrella behind the cat', 3, True),
		('tail', 3, 'the curled grey tail on the right', 3, True)]},
	'char16': {'body': 'white body with black cow spots and one black ear', 'props': [
		('Cat_Prop_Chest', 1, 'the red collar with the golden bell', 3, False),
		('Prop_Head', 2, 'the green bucket hat with a daisy', 3, False),
		('tail', 3, 'the white tail with black spots and a black tuft at the tip', 3, True)]},
}

PRE = ('Edit the reference image. Keep the exact same square canvas, framing, position, scale and flat '
	'cartoon line style; do not move or resize anything that is kept. The background must be flat pure '
	'magenta #FF00FF.\n\n')


def prompts():
	"""그림 한 장 = 프롬프트 한 줄. {파일 이름: (원본 판, 프롬프트)}."""
	out = {}
	for cid, sp in SPEC.items():
		props = ', '.join(p[2] for p in sp['props'] if p[3] == 0)
		out['%s_body' % cid] = (0, PRE + (
			'Remove ALL facial features (both eyes, mouth, nose, pink cheeks, whiskers), BOTH front paws%s. '
			'Keep only the square cat body with its two ears and thick black outline: %s. Fill the areas where '
			'the face, paws and accessories were with the matching fur color and pattern, and continue the '
			"body's straight bottom edge and black outline where the paws used to cover it. Result: a "
			'blank-faced cat body with no paws, no face and no accessories.') % (
				(' and ' + props) if props else '', sp['body']))
		out['%s_feet' % cid] = (0, PRE + (
			'Keep ONLY the two round front paws at the bottom (thick black outline, pale fill and pink paw pads), '
			'in exactly the same place and size. Erase everything else to flat magenta #FF00FF.'))
		out['%s_face' % cid] = (0, PRE + (
			'Keep ONLY the facial features floating in their exact places: the two eyes, the nose, the mouth, the '
			'two pink blush cheeks and the black whiskers on both sides. %sErase the body, ears, fur pattern, '
			'paws%s completely to flat magenta #FF00FF, so only the face features remain.') % (
				sp.get('face_note', '') + ' ' if sp.get('face_note') else '',
				(', ' + props) if props else ''))
		for name, _tier, desc, src, complete in sp['props']:
			out['%s_%s' % (cid, name)] = (src, PRE + (
				'Keep ONLY %s, in exactly the same place and size. Erase the cat itself (body, ears, face, paws) '
				'and every other accessory to flat magenta #FF00FF.%s') % (desc, (
					' Complete the parts that were hidden behind the cat or its paws, with the same thick black '
					'outline, as if the cat were not there.') if complete else ''))
	return out


# ---------------------------------------------------------------------------------------------
def key_out(path):
	"""마젠타 배경 → RGBA (배경색을 알파로 풀어 낸다)."""
	rgb = np.asarray(Image.open(path).convert('RGB')).astype(float)
	edge = np.concatenate([rgb[:8].reshape(-1, 3), rgb[-8:].reshape(-1, 3),
			rgb[:, :8].reshape(-1, 3), rgb[:, -8:].reshape(-1, 3)])
	bg = np.median(edge, 0)
	m = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
	mb = min(bg[0], bg[2]) - bg[1]
	a = np.clip(1.0 - (m - mb * 0.25) / (mb * 0.6), 0.0, 1.0)
	af = np.clip(a, 1e-3, 1.0)[..., None]
	col = np.clip((rgb - (1.0 - af) * bg) / af, 0, 255)
	a[a < 0.04] = 0.0
	# 부스러기 제거 — 작은 연결 성분(생성 노이즈)은 버린다
	lab, n = ndimage.label(a > 0.35, np.ones((3, 3)))
	if n:
		size = ndimage.sum(np.ones_like(a), lab, range(1, n + 1))
		keep = np.isin(lab, 1 + np.where(size >= 60)[0])
		keep = ndimage.binary_dilation(keep, iterations=2)
		a = np.where(keep, a, 0.0)
	return np.dstack([col, a * 255.0])


def crop(px):
	ys, xs = np.where(px[..., 3] > 8)
	x0, y0 = xs.min(), ys.min()
	return px[y0:ys.max() + 1, x0:xs.max() + 1], (int(x0), int(y0))


def resize(px, k):
	"""프리멀티플라이 후 리샘플 — 투명 화소의 색이 번지지 않게."""
	h, w = px.shape[:2]
	W, H = max(1, round(w * k)), max(1, round(h * k))
	a = px[..., 3:4] / 255.0
	pm = Image.fromarray(np.clip(px[..., :3] * a, 0, 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)
	al = Image.fromarray(px[..., 3].astype(np.uint8)).resize((W, H), Image.LANCZOS)
	A = np.asarray(al).astype(float)
	C = np.asarray(pm).astype(float) / np.maximum(A[..., None] / 255.0, 1e-3)
	return np.dstack([np.clip(C, 0, 255), A])


def clusters(rgb, k=6, it=8):
	"""불투명 화소 색 군집 (간단한 k-means)."""
	pts = rgb.reshape(-1, 3)
	if len(pts) > 6000:
		pts = pts[np.random.default_rng(0).choice(len(pts), 6000, replace=False)]
	cen = pts[np.linspace(0, len(pts) - 1, k).astype(int)]
	for _ in range(it):
		lab = np.argmin(((pts[:, None] - cen[None]) ** 2).sum(2), 1)
		cen = np.array([pts[lab == j].mean(0) if (lab == j).any() else cen[j] for j in range(k)])
	return cen


class Ref:
	"""완성 렌더 한 장 (정합 과녁)."""

	def __init__(self, cid, t):
		px = np.asarray(Image.open(os.path.join(CATS, '%s_t%d.png' % (cid, t))).convert('RGBA')).astype(float)
		self.px = px
		self.R = px[..., :3]
		self.O = px[..., 3] > 200
		self.shape = self.O.shape


def register(ref, part, guess, win=70):
	"""그림 한 장을 렌더 위에 맞춘다 → (배율 k, 렌더 좌표 좌상단 x, y, 점수)."""
	part, off = crop(part)
	base = (ref.shape[0]) / SQ  # 정사각 입력의 한 변 = 렌더 높이
	gx, gy = guess(off)
	best = None

	def score_at(k):
		tp = resize(part, k)
		m = tp[..., 3] > 150
		if m.sum() < 20:
			return None
		cen = clusters(tp[..., :3][m])
		lab = np.argmin(((tp[..., :3][..., None, :] - cen[None, None]) ** 2).sum(3), 2)
		h, w = m.shape
		H, W = ref.shape
		if h >= H or w >= W:
			return None
		matched = 0.0
		for j, c in enumerate(cen):
			tm = (m & (lab == j)).astype(float)
			if tm.sum() < 4:
				continue
			M = ((np.abs(ref.R - c).max(2) < 48) & ref.O).astype(float)
			matched = matched + corr(M, h, w, tm)
		tot = corr(ref.O.astype(float), h, w, m.astype(float))
		area = m.sum()
		s = matched - 0.35 * (tot - matched) - 1.0 * (area - tot)
		# 추정 자리 둘레만 본다 (생성 그림은 대체로 제자리 근처에 있다)
		ex, ey = int(round(gx)), int(round(gy))
		yy, xx = np.mgrid[0:s.shape[0], 0:s.shape[1]]
		s = np.where((np.abs(xx - ex) <= win) & (np.abs(yy - ey) <= win), s, -1e12)
		y, x = np.unravel_index(np.argmax(s), s.shape)
		return float(s[y, x]), int(x), int(y), tp

	for rel in np.arange(0.80, 1.26, 0.03):
		r = score_at(base * rel)
		if r and (best is None or r[0] > best[0]):
			best = (r[0], base * rel, r[1], r[2], r[3])
	k0 = best[1]
	for k in np.arange(k0 - 0.02 * base, k0 + 0.021 * base, 0.005 * base):
		r = score_at(k)
		if r and r[0] > best[0]:
			best = (r[0], k, r[1], r[2], r[3])
	return best[4], (best[2], best[3]), best[1] / base


def guess_fn(ref):
	"""생성 그림 좌표 → 렌더 좌표 (정사각 입력이 렌더를 가운데 두고 늘린 것이므로)."""
	H, W = ref.shape
	side = max(H, W)
	ox = (side - W) // 2
	oy = (side - H) // 2

	def g(off):
		# off = 생성 그림(1024)에서 잘라 낸 좌상단 → 렌더 좌표 (편집이 제자리를 지켰다고 가정)
		return off[0] * side / SQ - ox, off[1] * side / SQ - oy
	return g


# --- 레이어 쪼개기 ---------------------------------------------------------------------------
def luma(rgb):
	return (rgb * np.array([0.299, 0.587, 0.114])).sum(-1)


def layer(px, mask, kind, color=None):
	"""mask 영역만 남긴 한 장. kind: 'mask'(흰 그림 + 틴트) / 'ink'(검정) / 'art'(원본 색)."""
	out = np.zeros(px.shape, float)
	a = px[..., 3] * mask
	if kind == 'mask':
		out[..., :3] = 255.0
	elif kind == 'ink':
		out[..., :3] = 0.0
	else:
		out[..., :3] = px[..., :3]
	out[..., 3] = a
	return out


def split_shape(px, prefix):
	"""몸통·꼬리 → Outline(검은 테) / SkinFill(채운 실루엣) / Pattern(나머지 색)."""
	rgb, a = px[..., :3], px[..., 3] / 255.0
	sil = ndimage.binary_fill_holes(a > 0.5)
	inner = ndimage.binary_erosion(sil, iterations=3)
	fill = np.median(rgb[ndimage.binary_erosion(sil, iterations=12)], 0) if ndimage.binary_erosion(
			sil, iterations=12).any() else np.median(rgb[inner], 0)
	thr = min(70.0, luma(fill) * 0.62)
	dark = luma(rgb) < thr
	band = sil & ~ndimage.binary_erosion(sil, iterations=11)
	outline = dark & band
	outline = ndimage.binary_dilation(outline, iterations=1) & (a > 0.02) & (luma(rgb) < thr + 40)
	dist = np.abs(rgb - fill).max(2)
	pattern = sil & ~outline & (dist > 34)
	pattern = ndimage.binary_opening(pattern, iterations=1)
	out = {}
	out[prefix + '_Outline'] = (layer(px, outline, 'ink'), '000000', False)
	fillm = ndimage.binary_erosion(sil, iterations=2).astype(float)
	fillm = ndimage.gaussian_filter(fillm, 0.6)
	sk = np.zeros(px.shape)
	sk[..., :3] = 255.0
	sk[..., 3] = fillm * 255.0
	out[prefix + '_SkinFill'] = (sk, hexc(fill), True)
	if pattern.sum() > 40:
		pv = rgb[pattern]
		if pv.std(0).max() < 20:
			out[prefix + '_Pattern'] = (layer(px, pattern, 'mask'), hexc(np.median(pv, 0)), True)
		else:
			out[prefix + '_Pattern'] = (layer(px, pattern, 'art'), None, False)
	return out, fill


def split_feet(px):
	rgb, a = px[..., :3], px[..., 3] / 255.0
	sil = ndimage.binary_fill_holes(a > 0.5)
	fill = np.median(rgb[ndimage.binary_erosion(sil, iterations=6)], 0)
	dark = luma(rgb) < 70
	pad = sil & ~dark & (np.abs(rgb - fill).max(2) > 40)
	pad = ndimage.binary_opening(pad, iterations=1)
	sk = np.zeros(px.shape)
	sk[..., :3] = 255.0
	sk[..., 3] = ndimage.gaussian_filter(ndimage.binary_erosion(sil, iterations=2).astype(float), 0.6) * 255
	return {
		'Cat_Feet_Outline': (layer(px, dark & (a > 0.02), 'ink'), '000000', False),
		'Cat_Feet_SkinFill': (sk, hexc(fill), True),
		'Cat_Feet_Pawpad': (layer(px, pad, 'mask'), hexc(np.median(rgb[pad], 0)), True),
	}, fill


def split_face(px, org):
	"""얼굴 성분을 눈·코·입·수염·볼로 나눈다 (자리·색·모양으로 가른다)."""
	rgb, a = px[..., :3], px[..., 3] / 255.0
	solid = a > 0.3
	lab, n = ndimage.label(solid, np.ones((3, 3)))
	comps = []
	for i in range(1, n + 1):
		m = lab == i
		if m.sum() < 12:
			continue
		ys, xs = np.where(m)
		c = rgb[m]
		dk = float((luma(c) < 80).mean())
		pinkish = float(((c[:, 0] > c[:, 1] + 35) & (c[:, 0] > 150) & (luma(c) > 110)).mean())
		bw, bh = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
		comps.append({'m': m, 'cx': xs.mean() + org[0], 'cy': ys.mean() + org[1], 'area': int(m.sum()),
			'dark': dk, 'pink': pinkish, 'thin': m.sum() / float(bw * bh) < 0.42 and bw > 2.2 * bh,
			'w': int(bw), 'h': int(bh)})
	central = [c for c in comps if abs(c['cx'] - CENTER_X) < 24]
	# 코 = 가운데 성분 중 분홍이 가장 많은 것 (없으면 가장 위의 것)
	nose = max(central, key=lambda c: (c['pink'] > 0.3, -c['cy'])) if central else None
	ny = nose['cy'] if nose else np.median([c['cy'] for c in comps])
	groups = {k: np.zeros(a.shape, bool) for k in ('eyes', 'nose', 'mouth', 'whisk', 'cheek')}
	for c in comps:
		dx = abs(c['cx'] - CENTER_X)
		if c is nose:
			g = 'nose'
		elif dx < 24:
			g = 'mouth'
		elif c['dark'] > 0.55 and (dx > 62 or (c['thin'] and dx > 52)):
			g = 'whisk'
		elif c['cy'] < ny - 4 and c['pink'] < 0.6:
			g = 'eyes'
		elif c['pink'] > 0.35:
			g = 'cheek'
		elif c['dark'] > 0.6 and dx > 52:
			g = 'whisk'
		else:
			g = 'eyes'
		c['g'] = g
		if g == 'nose':  # 야옹입이 코에 붙어 한 성분이면 어두운 몫을 입으로 뗀다
			dk = c['m'] & (luma(rgb) < 90)
			if dk.sum() > 20:
				groups['mouth'] |= ndimage.binary_dilation(dk, iterations=1) & c['m']
				groups['nose'] |= c['m'] & ~groups['mouth']
				continue
		groups[g] |= c['m']
	# 볼이 눈에 붙어 한 성분이 된 경우 — 눈의 어두운 몫보다 아래에 있는 분홍 화소를 볼로 뗀다
	lab2, n2 = ndimage.label(groups['eyes'], np.ones((3, 3)))
	pinkpx = (rgb[..., 0] > rgb[..., 1] + 35) & (rgb[..., 0] > 150) & (luma(rgb) > 110)
	for i in range(1, n2 + 1):
		m = lab2 == i
		dk = m & (luma(rgb) < 90)
		if dk.sum() < 10:
			continue
		ys = np.where(dk)[0]
		yy = np.arange(m.shape[0])[:, None]
		low = m & pinkpx & (yy > ys.max() - 2)
		if low.sum() > 30:
			low = ndimage.binary_dilation(low, iterations=1) & m & ~dk
			groups['cheek'] |= low
			groups['eyes'] &= ~low
	out = {}
	eyes = groups['eyes']
	if eyes.any():
		ed = eyes & (luma(rgb) < 90)
		el = eyes & ~ed
		out['Cat_Eyes_Color'] = (layer(px, ed, 'mask'), hexc(np.median(rgb[ed], 0)) if ed.any() else '241f28', True)
		if el.sum() > 6:
			out['Cat_Eyes_Highlight'] = (layer(px, ndimage.binary_dilation(el, iterations=1) & eyes, 'art'), None,
					False)
	for g, name in (('nose', 'Cat_Nose'), ('mouth', 'Cat_Mouse'), ('whisk', 'Cat_Whiskers'), ('cheek', 'Cat_Cheek')):
		if groups[g].any():
			out[name] = (layer(px, groups[g], 'art'), None, False)
	return out, comps


def hexc(c):
	return '%02x%02x%02x' % tuple(int(round(min(255, max(0, v)))) for v in c)


def bleed(px, rounds=3):
	rgb = px[..., :3].copy()
	a = px[..., 3] > 8
	for _ in range(rounds):
		acc = np.zeros_like(rgb)
		cnt = np.zeros(a.shape)
		for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
			sh = np.roll(np.roll(a, dy, 0), dx, 1)
			sv = np.roll(np.roll(rgb, dy, 0), dx, 1)
			m = sh & ~a
			acc[m] += sv[m]
			cnt += m
		f = cnt > 0
		rgb[f] = acc[f] / cnt[f, None]
		a = a | f
	out = px.copy()
	out[..., :3] = rgb
	return out


RECOLOR = {'Cat_Body_SkinFill', 'Cat_Feet_Pawpad', 'Cat_Eyes_Color'}

LAYER_NUM = {
	'Prop_Head': 85, 'Prop_Face': 80, 'Deco_Forehead': 70, 'Cat_Eyes_Highlight': 62, 'Cat_Eyes_Color': 61,
	'Cat_Eyes_Base': 60, 'Cat_Nose': 53, 'Cat_Mouse': 52, 'Cat_Whiskers': 51, 'Cat_Cheek': 50,
	'Cat_Feet_Outline': 42, 'Cat_Feet_Pawpad': 41, 'Cat_Feet_SkinFill': 40, 'Cat_Prop_Chest': 35,
	'Cat_Prop_Belly': 30, 'Cat_Body_Outline': 22, 'Cat_Body_Pattern': 21, 'Cat_Body_SkinFill': 20,
	'Cat_Tail_Outline': 12, 'Cat_Tail_Pattern': 11, 'Cat_Tail_SkinFill': 10, 'Prop_Back': 0,
}


def place(ref, name):
	path = os.path.join(SRC, name + '.png')
	if not os.path.exists(path):
		return None
	part = key_out(path)
	tp, pos, rel = register(ref, part, guess_fn(ref))
	print('  %-26s 배율 %.3f  자리 (%d, %d)' % (name, rel, pos[0] - PAD, pos[1] - PAD))
	return tp, pos


def build(cid):
	sp = SPEC[cid]
	refs = {t: Ref(cid, t) for t in range(4)}
	print(cid)
	layers = {}  # 이름 → (px, pos, tint, recolor, tiers)
	all_t = [0, 1, 2, 3]
	r = place(refs[0], cid + '_body')
	if r:
		parts, _ = split_shape(r[0], 'Cat_Body')
		for n, (px, tint, rc) in parts.items():
			layers[n] = (px, r[1], tint, rc, all_t)
	r = place(refs[0], cid + '_feet')
	if r:
		parts, _ = split_feet(r[0])
		for n, (px, tint, rc) in parts.items():
			layers[n] = (px, r[1], tint, rc, all_t)
	r = place(refs[0], cid + '_face')
	if r:
		parts, comps = split_face(r[0], r[1])
		print('    얼굴 성분: ' + ', '.join('%s(%d,%d)' % (c['g'], c['cx'] - PAD, c['cy'] - PAD) for c in comps))
		for n, (px, tint, rc) in parts.items():
			layers[n] = (px, r[1], tint, rc, all_t)
	for name, tier, _d, src, _c in sp['props']:
		r = place(refs[src], '%s_%s' % (cid, name))
		if not r:
			continue
		tiers = list(range(tier, 4))
		if name == 'tail':
			parts, _ = split_shape(r[0], 'Cat_Tail')
			for n, (px, tint, rc) in parts.items():
				layers[n] = (px, r[1], tint, rc, tiers)
		else:
			layers[name] = (r[0], r[1], None, False, tiers)

	d = os.path.join(CATS, 'parts', cid)
	os.makedirs(d, exist_ok=True)
	for f in os.listdir(d):
		if f.endswith('.png') or f == 'layout.json':
			os.remove(os.path.join(d, f))
	layout = {}
	for n, (px, pos, tint, rc, tiers) in layers.items():
		c, off = crop(px)
		c = bleed(c)
		Image.fromarray(np.clip(c, 0, 255).astype(np.uint8), 'RGBA').save(os.path.join(d, n + '.png'))
		layout[n] = {'layer': LAYER_NUM[n], 'x': pos[0] + off[0] - PAD, 'y': pos[1] + off[1] - PAD,
			'w': c.shape[1], 'h': c.shape[0], 'tint': tint, 'recolor': rc, 'tiers': tiers}
	# 색을 갈아끼울 수 있는 레이어는 셋뿐이다 — 몸 색·발바닥·눈동자. 나머지(발·꼬리·무늬)는
	# 이 냥이의 색을 그대로 들고 다녀야 나만의 캐릭터에 "원본 냥이"로 불러왔을 때 원본과 같다
	# (custom_cat.gd의 apply_sel()이 몸 색을 고르면 발 색을 몸 색 밝힌 것으로 바꾸기 때문).
	for n, v in layout.items():
		v['recolor'] = bool(v['recolor']) and n in RECOLOR
	json.dump(layout, open(os.path.join(d, 'layout.json'), 'w'), indent=1, sort_keys=True)
	return layout, refs


def compose(cid, layout, t, shape):
	"""배치표대로 레이어를 겹친 그림 (게임의 paint_mix와 같은 규칙)."""
	H, W = shape
	acc = np.zeros((H, W, 4))
	for n in sorted(layout, key=lambda k: layout[k]['layer']):
		v = layout[n]
		if t not in v['tiers']:
			continue
		px = np.asarray(Image.open(os.path.join(CATS, 'parts', cid, n + '.png')).convert('RGBA')).astype(float)
		col = px[..., :3]
		if v['tint']:
			col = col * np.array([int(v['tint'][i:i + 2], 16) for i in (0, 2, 4)]) / 255.0
		x, y = v['x'] + PAD, v['y'] + PAD
		h, w = px.shape[:2]
		x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
		if x1 <= x0 or y1 <= y0:
			continue
		sa = px[y0 - y:y1 - y, x0 - x:x1 - x, 3:4] / 255.0
		sc = col[y0 - y:y1 - y, x0 - x:x1 - x]
		da = acc[y0:y1, x0:x1, 3:4]
		dc = acc[y0:y1, x0:x1, :3]
		na = sa + da * (1 - sa)
		acc[y0:y1, x0:x1, :3] = (sc * sa + dc * da * (1 - sa)) / np.maximum(na, 1e-6)
		acc[y0:y1, x0:x1, 3:4] = na
	acc[..., 3] *= 255.0
	return acc


def check(results):
	"""렌더 | 레이어 합성 | 차이 — 캐릭터 한 줄에 4단계."""
	rows = []
	for cid, (layout, refs) in results.items():
		tiles = []
		bad = []
		for t in range(4):
			ref = refs[t].px
			comp = compose(cid, layout, t, refs[t].shape)
			both = (ref[..., 3] > 200) | (comp[..., 3] > 200)
			diff = (np.abs(ref[..., :3] - comp[..., :3]).max(2) > 40) | (np.abs(ref[..., 3] - comp[..., 3]) > 120)
			diff &= both
			bad.append(int(diff.sum()))
			dimg = np.zeros(ref.shape)
			dimg[..., :3] = 255
			dimg[..., 3] = 255
			dimg[both] = [220, 220, 220, 255]
			dimg[diff] = [230, 40, 40, 255]
			for img in (ref, comp, dimg):
				bg = np.zeros(ref.shape)
				bg[..., :3] = 255
				bg[..., 3] = 255
				al = img[..., 3:4] / 255.0
				bg[..., :3] = img[..., :3] * al + bg[..., :3] * (1 - al)
				tiles.append(bg)
		print('%s  어긋난 px t0~t3 %s' % (cid, bad))
		rows.append(np.concatenate(tiles, 1))
	img = np.concatenate(rows, 0)
	os.makedirs(SHOTS, exist_ok=True)
	im = Image.fromarray(img.astype(np.uint8)[..., :3])
	im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
	im.save(os.path.join(SHOTS, 'gen_cat_layers.png'))


def write_gd():
	L = ['# 자동 생성 — `python tools/gen_cat_layers.py` 가 만든다. 직접 고치지 말 것.',
		'## 신규 냥이 10종(char07~16)의 파츠 레이어 배치표 — Higgsfield로 부위를 떼어 낸 그림을',
		'## 완성 렌더에 정합한 것. 모양은 cat_layouts.gd와 같고 캔버스 좌표계도 같다',
		'## (cat_sprite.gd가 셋을 합쳐 읽는다).',
		'extends RefCounted', '', 'const LAYOUTS := {']
	for cid in sorted(SPEC):
		p = os.path.join(CATS, 'parts', cid, 'layout.json')
		if not os.path.exists(p):
			continue
		lay = json.load(open(p))
		L.append('	"%s": [' % cid)
		for n in sorted(lay, key=lambda k: lay[k]['layer']):
			v = lay[n]
			tint = 'Color(0, 0, 0, 0)' if v['tint'] is None else 'Color("%s")' % v['tint']
			L.append('		{"n": "%s", "layer": %d, "at": Vector2(%d, %d), "tint": %s,'
					% (n, v['layer'], v['x'], v['y'], tint))
			L.append('			"recolor": %s, "tiers": [%s]},' % ('true' if v['recolor'] else 'false',
					', '.join(str(t) for t in v['tiers'])))
		L.append('	],')
	L += ['}', '']
	open(os.path.join(ROOT, 'core', 'scripts', 'gen_layouts.gd'), 'w', encoding='utf-8').write('\n'.join(L))


def prep():
	out = os.path.join(SHOTS, 'gen_in')
	os.makedirs(out, exist_ok=True)
	for cid in SPEC:
		for t in range(4):
			im = Image.open(os.path.join(CATS, '%s_t%d.png' % (cid, t))).convert('RGBA')
			side = max(im.size)
			bg = Image.new('RGBA', (side, side), (255, 0, 255, 255))
			bg.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
			bg.convert('RGB').resize((SQ, SQ), Image.LANCZOS).save(os.path.join(out, '%s_t%d.png' % (cid, t)))
	print('→', out)


def main():
	args = sys.argv[1:]
	if args and args[0] == 'prep':
		return prep()
	if args and args[0] == 'prompts':
		print(json.dumps(prompts(), ensure_ascii=False, indent=1))
		return
	ids = args or sorted(SPEC)
	res = {}
	for cid in ids:
		res[cid] = build(cid)
	check(res)
	write_gd()


if __name__ == '__main__':
	main()
