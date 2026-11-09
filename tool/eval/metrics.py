"""리소 결과 품질 지표(털색 그룹별 평균).

  dart compile exe tool/riso_cli.dart -o riso_cli
  for f in tool/eval/data/cut/*.png; do ./riso_cli $f tool/eval/data/out/$(basename $f .png) 7 --plates; done
  python tool/eval/metrics.py tool/eval/data out

- dark: 몸 안에서 명도 0.35 미만(남보라 덩어리) 비율 — 높을수록 뭉개짐
- detail: 몸 안 출력 명도의 대역 통과(σ3-σ9) 평균 크기 — 망점 주기보다 큰 구조(눈·털결)
- range: 몸 안 σ6 블러 명도의 5~95 백분위 폭 — 명암 단계가 살아 있는지
"""
import sys, json
import numpy as np
from PIL import Image, ImageFilter
root, sub = sys.argv[1], sys.argv[2]
meta = json.load(open(f'{root}/meta.json'))
def L(im): return np.asarray(im.convert('L'), dtype=np.float32) / 255
rows = {}
for m in meta:
    d = f"{root}/{sub}/{m['idx']}"
    out = Image.open(f'{d}/sticker_paper.png').convert('RGB')
    body = L(Image.open(f'{d}/mask.png')) > 0.9
    # 실루엣 가장자리(윤곽선) 8px는 빼고 안쪽만
    body = np.asarray(Image.fromarray((body * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(17))) > 0
    lum = L(out)
    g3 = L(out.filter(ImageFilter.GaussianBlur(3))); g9 = L(out.filter(ImageFilter.GaussianBlur(9)))
    g6 = L(out.filter(ImageFilter.GaussianBlur(6)))
    v = g6[body]
    rows.setdefault(m['group'], []).append((
        float((lum[body] < 0.35).mean()),
        float(np.abs(g3 - g9)[body].mean()),
        float(np.percentile(v, 95) - np.percentile(v, 5)),
    ))
print(f'{"그룹":6} {"n":>3} {"dark":>6} {"detail":>7} {"range":>6}')
for g, r in rows.items():
    a = np.array(r)
    print(f'{g:6} {len(r):3d} {a[:,0].mean():6.3f} {a[:,1].mean():7.4f} {a[:,2].mean():6.3f}')
