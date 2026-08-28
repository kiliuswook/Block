# -*- coding: utf-8 -*-
"""파츠 레이어 → 완성 렌더 정합.

시트의 파츠 셀은 파츠를 셀 한가운데 그려 놓은 것이라 배치 좌표 정보가 없다.
그래서 완성 렌더(charNN_t3.png)를 정답지 삼아 각 레이어를 놓을 자리를 찾는다:

  1) 위 레이어부터 차례로, "덮는 자리가 렌더의 한 가지 색으로 채워져 있고
     실루엣 바깥 링은 그 색이 아닌" 자리를 FFT 상관으로 전수 탐색한다.
  2) 그 다음 정련 라운드에서 "지금 스택이 렌더와 어긋나는 픽셀"을 메우는 쪽으로
     각 레이어를 다시 놓는다 — 전체 합성이 완성 렌더와 같아지는 방향.

`tools/extract_cat_sheet.py`가 이 모듈을 쓴다.
"""
import numpy as np
from numpy.fft import rfft2, irfft2

PAD = 5  # 실루엣 바깥 링을 볼 여백

# 이 레이어는 저 레이어의 실루엣 안에 들어간다 (시트의 anchor 관계).
CONTAIN = {
	'Cat_Eyes_Highlight': 'Cat_Eyes_Color',
	'Cat_Eyes_Color': 'Cat_Eyes_Base',
	'Cat_Body_Pattern': 'Cat_Body_Outline',
	'Cat_Body_SkinFill': 'Cat_Body_Outline',
	'Cat_Feet_Pawpad': 'Cat_Feet_Outline',
	'Cat_Feet_SkinFill': 'Cat_Feet_Outline',
	'Cat_Tail_Pattern': 'Cat_Tail_Outline',
	'Cat_Tail_SkinFill': 'Cat_Tail_Outline',
}

# 반대 방향 — 이 레이어는 저 레이어를 품는다 (지금은 쓰는 곳이 없다).
CONTAIN_REV = {}


# 6종이 모두 같은 몸통 템플릿 위에 그려져 있어서, 고양이 본체 파츠는 자리가 거의
# 같다. char01에서 정합해 검증한 몸통 기준 오프셋을 나머지 캐릭터의 사전값으로 쓰고
# 그 둘레(PRIOR_R)만 탐색한다. 소품(Prop_*)은 캐릭터마다 달라 사전값이 없다.
PRIOR = {
	'Cat_Eyes_Highlight': (54, 92), 'Cat_Eyes_Color': (50, 90), 'Cat_Eyes_Base': (50, 90),
	'Cat_Nose': (80, 115), 'Cat_Mouse': (80, 115), 'Cat_Whiskers': (15, 108),
	'Cat_Cheek': (43, 120), 'Cat_Feet_Outline': (-5, 173), 'Cat_Feet_Pawpad': (12, 191),
	'Cat_Feet_SkinFill': (-3, 179), 'Cat_Body_Pattern': (3, 5), 'Cat_Body_SkinFill': (1, 14),
}  # 꼬리는 캐릭터마다 모양·위치가 크게 달라 사전값을 두지 않는다
PRIOR_R = 16  # 사전값 둘레 탐색 반경 (px)
CAND = 250  # 소품 정합에서 정밀 비교할 후보 자리 수


def corr(big, h, w, tmpl):
	"""out[y,x] = Σ tmpl * big[y:y+h, x:x+w] (제로 패딩 FFT 상관)."""
	H, W = big.shape
	s = (H + h, W + w)
	return irfft2(rfft2(big, s) * rfft2(tmpl[::-1, ::-1], s), s)[h - 1:H, w - 1:W]


def grow(mask, limit, rounds=1):
	out = mask.copy()
	for _ in range(rounds):
		g = out.copy()
		for dy in (-1, 0, 1):
			for dx in (-1, 0, 1):
				g |= np.roll(np.roll(out, dy, 0), dx, 1)
		out = g & limit
	return out


def filled(mask):
	"""외곽선 마스크 안쪽까지 채운 실루엣."""
	free = ~mask
	seed = np.zeros_like(mask)
	seed[0, :] = free[0, :]; seed[-1, :] = free[-1, :]
	seed[:, 0] = free[:, 0]; seed[:, -1] = free[:, -1]
	while True:
		g = grow(seed, free)
		if g.sum() == seed.sum():
			return ~seed
		seed = g


def palette(R, alpha):
	"""완성 렌더의 평평한 색 목록 (면적 큰 순)."""
	q = (R[alpha > 250] / 8).round().astype(int) * 8
	cols, cnt = np.unique(q, axis=0, return_counts=True)
	out = []
	for i in np.argsort(-cnt):
		if cnt[i] < 40:
			break
		c = np.clip(cols[i].astype(float), 0, 255)
		if not any(np.abs(c - o).max() <= 16 for o in out):
			out.append(c)
	return out


def mask_at(px, pos, shape):
	m = np.zeros(shape, bool)
	h, w = px.shape[:2]
	m[pos[1]:pos[1] + h, pos[0]:pos[0] + w] = px[:, :, 3] > 200
	return m


class Fitter:
	"""한 캐릭터의 완성 렌더 위에 레이어를 정합한다."""

	def __init__(self, ref, layers):
		self.R = ref[:, :, :3].astype(float)
		self.alpha = ref[:, :, 3].astype(float)
		self.shape = self.alpha.shape
		self.opaque = self.alpha > 200
		self.pal = palette(self.R, self.alpha)
		self.layers = layers  # {이름: {'px':RGBA, 'layer':int, 'colored':bool}}
		self.order = sorted(layers, key=lambda n: -layers[n]['layer'])  # 위 → 아래

	# --- 한 레이어 탐색 ---------------------------------------------------
	def _tmpl(self, name):
		px = self.layers[name]['px']
		h0, w0 = px.shape[:2]
		h, w = h0 + PAD * 2, w0 + PAD * 2
		m = np.zeros((h, w))
		m[PAD:PAD + h0, PAD:PAD + w0] = px[:, :, 3] > 200
		ring = m.copy()
		for dy in range(-PAD, PAD + 1):
			for dx in range(-PAD, PAD + 1):
				ring = np.maximum(ring, np.roll(np.roll(m, dy, 0), dx, 1))
		return m, ring - m, h, w

	def _art(self, name, h, w):
		px = self.layers[name]['px']
		c = np.zeros((h, w, 3))
		c[PAD:PAD + px.shape[0], PAD:PAD + px.shape[1]] = px[:, :, :3]
		return c

	def _lsq(self, name, k, U, m, h, w):
		"""채널 k에서 Σ(R - t·c)² 를 최소화하는 곱 틴트 t 계산용 상관 3종."""
		c = self._art(name, h, w)[:, :, k]
		return (corr(U * self.R[:, :, k] ** 2, h, w, m),
				corr(U * self.R[:, :, k], h, w, m * c),
				corr(U, h, w, m * c ** 2))

	def prior_window(self, name, pos):
		"""몸통 기준 사전값 둘레만 남기는 마스크 (사전값이 없으면 None)."""
		if name not in PRIOR or 'Cat_Body_Outline' not in pos:
			return None
		bx, by = pos['Cat_Body_Outline']
		m, _, h, w = self._tmpl(name)
		H, W = self.shape
		win = np.zeros((max(H - h + 1, 1), max(W - w + 1, 1)), bool)
		cx = bx + PRIOR[name][0] - PAD
		cy = by + PRIOR[name][1] - PAD
		x0, x1 = max(0, cx - PRIOR_R), min(win.shape[1], cx + PRIOR_R + 1)
		y0, y1 = max(0, cy - PRIOR_R), min(win.shape[0], cy + PRIOR_R + 1)
		if x0 >= x1 or y0 >= y1:
			return None
		win[y0:y1, x0:x1] = True
		return win

	def cover_window(self, name, pos):
		"""품어야 할 레이어를 실제로 덮는 자리만 남기는 마스크."""
		child = CONTAIN_REV.get(name)
		if child not in self.layers or child not in pos:
			return None
		m, _, h, w = self._tmpl(name)
		cm = mask_at(self.layers[child]['px'], pos[child], self.shape).astype(float)
		if cm.sum() < 4:
			return None
		return corr(cm, h, w, filled(m > 0).astype(float)) >= cm.sum() * 0.97

	def fit(self, name, claimed, allow=None, need=None, win=None):
		"""(x, y) — 이 레이어를 놓을 자리."""
		px = self.layers[name]['px']
		m, ring, h, w = self._tmpl(name)
		H, W = self.shape
		if h > H or w > W:
			return (max(0, (W - w) // 2), max(0, (H - h) // 2))
		sm, sr = m.sum(), max(ring.sum(), 1.0)
		U = (self.opaque & ~claimed).astype(float)
		nv = corr(U, h, w, m)
		ok = nv >= np.maximum(20.0, sm * 0.15)
		if not ok.any():
			ok = nv >= max(6.0, sm * 0.03)
		if allow is not None:
			inside = corr(allow.astype(float), h, w, m) >= sm * 0.97
			if (ok & inside).any():
				ok &= inside
		if win is not None and (ok & win).any():
			ok &= win
		nvz = np.maximum(nv, 1e-6)

		out_pen = corr(1.0 - self.opaque.astype(float), h, w, m) / max(sm, 1.0)
		if self.layers[name]['colored']:  # 소품 — 원본 그림에 곱 틴트를 허용해 비교
			err = np.zeros(nv.shape)
			for k in range(3):
				a, b, cc = self._lsq(name, k, U, m, h, w)
				# 곱 틴트는 어둡게만 만들 수 있다 — t를 0~1로 묶지 않으면 노란 눈이
				# "흰색으로 보정돼" 엉뚱한 흰 배경 위에 가서 붙는다.
				t = np.clip(b / np.maximum(cc, 1e-6), 0.0, 1.0)
				err += a - 2.0 * t * b + t ** 2 * cc
			# 렌더 밖으로 삐져나간 자리는 크게, 위 레이어에 가려지는 건 약하게 손해
			score = err / nvz + 4000.0 * out_pen + 300.0 * (sm - nv) / max(sm, 1.0)
			if need is not None:  # 지금 스택이 못 채우고 있는 자리를 메운다
				score -= 3000.0 * corr(need.astype(float), h, w, m) / max(sm, 1.0)
			score = np.where(ok, score, 1e12)
			return self._pick_colored(name, score, claimed, need)

		dark = px[:, :, :3][px[:, :, 3] > 200].mean() <= 24
		best = None
		for c in self.pal:
			if dark and c.mean() > 40:  # 검은 마스크는 검은 색만 낼 수 있다
				continue
			d = np.abs(self.R - c).max(2)
			same = (d <= 30) & self.opaque
			g = corr((same & ~claimed).astype(float), h, w, m) / max(sm, 1.0)
			b = corr(((d > 40) & self.opaque & ~claimed).astype(float), h, w, m) / max(sm, 1.0)
			r = corr(same.astype(float), h, w, ring) / sr
			score = -g + 2.0 * b + 3.0 * r + 3.0 * out_pen
			if need is not None:  # 지금 스택이 이 색을 못 내고 있는 자리를 메운다
				score -= 2.0 * corr((need & same).astype(float), h, w, m) / max(sm, 1.0)
			score = np.where(ok, score, 1e12)
			y, x = np.unravel_index(np.argmin(score), score.shape)
			if best is None or score[y, x] < best[2]:
				best = (int(x) + PAD, int(y) + PAD, float(score[y, x]))
		return best[0], best[1]

	def _pick_colored(self, name, score, claimed, need):
		"""제곱오차 상위 후보만 정확한 화소 비교로 다시 재본다.

		제곱오차는 위 레이어에 일부 가려진 소품(눈동자에 덮인 눈 바탕 등)에서
		크게 틀어지므로, 후보를 추린 뒤 "색이 확실히 다른 화소 수"로 고른다.
		"""
		px = self.layers[name]['px']
		h0, w0 = px.shape[:2]
		art = px[:, :, :3].astype(float)
		am = px[:, :, 3] > 200
		flat = score.ravel()
		k = min(CAND, flat.size)
		cands = np.argpartition(flat, k - 1)[:k]
		H, W = self.shape
		best = None
		for idx in cands:
			if flat[idx] >= 1e11:
				continue
			yy, xx = divmod(int(idx), score.shape[1])
			y, x = yy + PAD, xx + PAD
			if y < 0 or x < 0 or y + h0 > H or x + w0 > W:
				continue
			sub_op = self.opaque[y:y + h0, x:x + w0]
			vis = am & sub_op & ~claimed[y:y + h0, x:x + w0]
			if vis.sum() < 8:
				continue
			ref = self.R[y:y + h0, x:x + w0]
			t = np.array([np.clip((art[:, :, c][vis] * ref[:, :, c][vis]).sum()
					/ max((art[:, :, c][vis] ** 2).sum(), 1e-6), 0.0, 1.0) for c in range(3)])
			bad = int((np.abs(ref - art * t).max(2)[vis] > 40).sum())
			out = int((am & ~sub_op).sum())
			gain = int((am & need[y:y + h0, x:x + w0]).sum()) if need is not None else 0
			cost = bad + 3.0 * out - 1.5 * gain
			if best is None or cost < best[0]:
				best = (cost, x, y)
		if best is None:
			yy, xx = np.unravel_index(np.argmin(score), score.shape)
			return int(xx) + PAD, int(yy) + PAD
		return best[1], best[2]

	# --- 전체 배치 --------------------------------------------------------
	def solve(self, refine=2):
		pos = self._first_pass()
		for _ in range(refine):
			pos = self._refine(pos)
		return pos, self.tints(pos)

	def _first_pass(self):
		pos, claimed = {}, np.zeros(self.shape, bool)
		todo = list(self.order)
		while todo:
			moved = False
			for n in list(todo):
				par = CONTAIN.get(n)
				if par in self.layers and par not in pos:
					continue
				sub = CONTAIN_REV.get(n)
				if sub in self.layers and sub not in pos:
					continue
				allow = None
				if par in pos:
					allow = grow(filled(mask_at(self.layers[par]['px'], pos[par], self.shape)),
							np.ones(self.shape, bool), 4)
				win = self.prior_window(n, pos)
				cov = self.cover_window(n, pos)
				if cov is not None:
					win = cov if win is None else (win & cov if (win & cov).any() else cov)
				pos[n] = self.fit(n, claimed, allow, None, win)
				claimed |= mask_at(self.layers[n]['px'], pos[n], self.shape)
				todo.remove(n)
				moved = True
			if not moved:  # 순환 참조 — 남은 건 제약 없이
				for n in list(todo):
					pos[n] = self.fit(n, claimed)
					claimed |= mask_at(self.layers[n]['px'], pos[n], self.shape)
					todo.remove(n)
		return pos

	def _refine(self, pos):
		pos = dict(pos)
		for n in self.order:
			above = np.zeros(self.shape, bool)
			for o in self.order:
				if o != n and self.layers[o]['layer'] > self.layers[n]['layer']:
					above |= mask_at(self.layers[o]['px'], pos[o], self.shape)
			rgb, a = self.render({k: v for k, v in pos.items() if k != n})
			wrong = self.opaque & ((a < 200) | (np.abs(rgb - self.R).max(2) > 24))
			par = CONTAIN.get(n)
			allow = None
			if par in pos:
				allow = grow(filled(mask_at(self.layers[par]['px'], pos[par], self.shape)),
						np.ones(self.shape, bool), 4)
			win = self.prior_window(n, pos)
			cov = self.cover_window(n, pos)
			if cov is not None:
				win = cov if win is None else (win & cov if (win & cov).any() else cov)
			pos[n] = self.fit(n, above, allow, wrong, win)
		return pos

	# --- 합성·틴트 --------------------------------------------------------
	def tints(self, pos):
		"""각 레이어가 최상단으로 보이는 자리의 렌더 색 = 그 레이어의 기본 틴트."""
		H, W = self.shape
		up = sorted(pos, key=lambda n: self.layers[n]['layer'])
		top = np.full((H, W), -1, int)
		for i, n in enumerate(up):
			px = self.layers[n]['px']
			h, w = px.shape[:2]
			a = np.zeros((H, W), bool)
			a[pos[n][1]:pos[n][1] + h, pos[n][0]:pos[n][0] + w] = px[:, :, 3] > 250
			top[a] = i
		out = {}
		for i, n in enumerate(up):
			px = self.layers[n]['px']
			if self.layers[n]['colored']:
				out[n] = self._colored_tint(n, pos[n], (top == i) & (self.alpha > 250))
				continue
			if px[:, :, :3][px[:, :, 3] > 200].mean() <= 24:
				out[n] = np.zeros(3)  # 검은 마스크는 색이 안 먹는다
				continue
			vis = (top == i) & (self.alpha > 250)
			er = vis.copy()
			for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
				er &= np.roll(np.roll(vis, dy, 0), dx, 1)
			use = er if er.sum() >= 12 else vis
			out[n] = np.median(self.R[use], axis=0) if use.sum() >= 4 else np.full(3, 255.0)
		return out

	def _colored_tint(self, name, pos, vis):
		"""소품 레이어에 곱해야 완성 렌더와 같아지는 색 (거의 흰색이면 None)."""
		px = self.layers[name]['px']
		h, w = px.shape[:2]
		sub = vis[pos[1]:pos[1] + h, pos[0]:pos[0] + w]
		if sub.shape != (h, w) or sub.sum() < 30:
			return None
		art = px[:, :, :3].astype(float)[sub]
		ref = self.R[pos[1]:pos[1] + h, pos[0]:pos[0] + w][sub]
		t = np.array([float((art[:, k] * ref[:, k]).sum() / max((art[:, k] ** 2).sum(), 1e-6))
				for k in range(3)])
		t = np.clip(t, 0.0, 1.0) * 255.0
		return None if np.abs(t - 255.0).max() <= 6.0 else t

	def quality(self, pos):
		"""레이어별 (드러난 화소 수, 그 중 색이 어긋난 화소 수).

		이 렌더가 그 레이어를 정합하기에 좋은 판이었는지 재는 데 쓴다.
		"""
		out = {}
		for n in self.order:
			above = np.zeros(self.shape, bool)
			for o in self.order:
				if o != n and self.layers[o]['layer'] > self.layers[n]['layer']:
					above |= mask_at(self.layers[o]['px'], pos[o], self.shape)
			px = self.layers[n]['px']
			h0, w0 = px.shape[:2]
			x, y = pos[n]
			am = px[:, :, 3] > 200
			sub = np.zeros((h0, w0), bool)
			H, W = self.shape
			yy0, xx0 = max(0, -y), max(0, -x)
			yy1, xx1 = min(h0, H - y), min(w0, W - x)
			if yy1 <= yy0 or xx1 <= xx0:
				out[n] = (0, 0)
				continue
			sl = (slice(y + yy0, y + yy1), slice(x + xx0, x + xx1))
			sub[yy0:yy1, xx0:xx1] = self.opaque[sl] & ~above[sl]
			vis = am & sub
			if vis.sum() < 8:
				out[n] = (0, 0)
				continue
			ref = np.zeros((h0, w0, 3))
			ref[yy0:yy1, xx0:xx1] = self.R[sl]
			if self.layers[n]['colored']:
				art = px[:, :, :3].astype(float)
				t = np.array([np.clip((art[:, :, c][vis] * ref[:, :, c][vis]).sum()
						/ max((art[:, :, c][vis] ** 2).sum(), 1e-6), 0.0, 1.0) for c in range(3)])
				bad = int((np.abs(ref - art * t).max(2)[vis] > 40).sum())
			else:
				med = np.median(ref[vis], axis=0)
				bad = int((np.abs(ref - med).max(2)[vis] > 40).sum())
			out[n] = (int(vis.sum()), bad)
		return out

	def render(self, pos, tints=None, only=None):
		"""레이어를 아래에서부터 알파 합성 (RGB, alpha)."""
		if tints is None:
			tints = self.tints(pos)
		H, W = self.shape
		rgb = np.zeros((H, W, 3))
		acc = np.zeros((H, W))
		for n in sorted(pos, key=lambda n: self.layers[n]['layer']):
			if only is not None and n not in only:
				continue
			px = self.layers[n]['px'].astype(float)
			h, w = px.shape[:2]
			x, y = pos[n]
			src = px[:, :, :3].copy()
			t = tints.get(n)
			if t is not None:
				src *= np.asarray(t) / 255.0
			sa = px[:, :, 3] / 255.0
			sub_rgb = rgb[y:y + h, x:x + w]
			sub_a = acc[y:y + h, x:x + w]
			na = sa + sub_a * (1.0 - sa)
			with np.errstate(invalid='ignore', divide='ignore'):
				nc = np.where(na[:, :, None] > 0,
						(src * sa[:, :, None] + sub_rgb * sub_a[:, :, None] * (1.0 - sa[:, :, None]))
						/ np.maximum(na[:, :, None], 1e-6), 0.0)
			rgb[y:y + h, x:x + w] = nc
			acc[y:y + h, x:x + w] = na
		return rgb, acc * 255.0

	def mismatch(self, pos, tints=None, only=None):
		rgb, a = self.render(pos, tints, only)
		both = self.opaque | (a > 8)
		bad = ((np.abs(rgb - self.R).max(2) > 24) | (np.abs(a - self.alpha) > 96)) & both
		return int(bad.sum()), int(both.sum())
