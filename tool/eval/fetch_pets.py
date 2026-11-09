"""그림체 평가용 표본: Oxford-IIIT Pet(CC BY-SA 4.0) 시험 세트에서 털색별로 받아 누끼 PNG를 만든다.

  pip install pillow numpy
  python tool/eval/fetch_pets.py            # → tool/eval/data/ (git 제외)

정답 분할 마스크(1=동물, 2=배경, 그 외=경계)를 알파(255/0/128)로 바꿔 ML Kit 결과를 흉내 낸다.
데이터는 평가에만 쓰고 레포·앱에 넣지 않는다.
"""
import json, os, time, urllib.error, urllib.request
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), 'data')
BASE = ('https://datasets-server.huggingface.co/rows?dataset=dpdl-benchmark/oxford_iiit_pet'
        '&config=default&split=test')
# 라벨 번호 → 털색 그룹. 검은 털: Bombay·newfoundland·scottish_terrier,
# 흰 털: samoyed·great_pyrenees·Persian, 그 외 6품종.
WANT = {7: 'black', 22: 'black', 30: 'black', 29: 'white', 15: 'white', 23: 'white',
        25: 'mid', 32: 'mid', 31: 'mid', 27: 'mid', 9: 'mid', 34: 'mid'}
NEED = {k: (4 if v != 'mid' else 2) for k, v in WANT.items()}


def retry(fn, *args, tries=5):
    """공개 API의 일시 오류(502·시간 초과)는 대기 간격을 늘리며 재시도."""
    for k in range(tries):
        try:
            return fn(*args)
        except (urllib.error.URLError, TimeoutError) as e:
            if k == tries - 1:
                raise
            print(f'재시도 {k + 1}: {e}')
            time.sleep(2 ** k)


def main():
    os.makedirs(f'{OUT}/raw', exist_ok=True)
    os.makedirs(f'{OUT}/cut', exist_ok=True)
    got = {k: 0 for k in WANT}
    meta = []
    off = 0
    while off < 3669 and any(got[k] < NEED[k] for k in WANT):
        rows = retry(lambda u: json.load(urllib.request.urlopen(u, timeout=90)), f'{BASE}&offset={off}&length=100')['rows']
        for r in rows:
            row, lab = r['row'], int(r['row']['label'])
            if lab not in WANT or got[lab] >= NEED[lab]:
                continue
            i = r['row_idx']
            img_p, mask_p = f'{OUT}/raw/{i}_img.jpg', f'{OUT}/raw/{i}_mask.png'
            retry(urllib.request.urlretrieve, row['image']['src'], img_p)
            retry(urllib.request.urlretrieve, row['segmentation_mask']['src'], mask_p)
            img = np.array(Image.open(img_p).convert('RGB'))
            t = np.array(Image.open(mask_p))
            a = np.where(t == 1, 255, np.where(t == 2, 0, 128)).astype(np.uint8)
            Image.fromarray(np.dstack([img, a]), 'RGBA').save(f'{OUT}/cut/{i}.png')
            got[lab] += 1
            meta.append({'idx': i, 'label': lab, 'group': WANT[lab]})
        off += 100
    json.dump(meta, open(f'{OUT}/meta.json', 'w'))
    print(f'{len(meta)}장 → {OUT}')


if __name__ == '__main__':
    main()
