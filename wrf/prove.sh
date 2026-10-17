#!/usr/bin/env bash
# Collaudo di tutto quello che si puo' provare senza far girare WRF (pochi minuti, nessuna chiave).
# Lo lancia GitHub a ogni modifica (.github/workflows/prova.yml); si puo' lanciare anche a mano:
#   bash wrf/prove.sh [CARTELLA]        (default: una cartella temporanea)
# Con PROVA_RADAR=1 prova anche il radar vero (serve internet).
set -euo pipefail
QUI=$(cd "$(dirname "$0")" && pwd)
RADICE=$(dirname "$QUI")
T=${1:-$(mktemp -d)}
mkdir -p "$T"
cd "$RADICE"
passo() { echo; echo "== $*"; }

passo "sintassi Python e nomi non definiti"
python3 -m py_compile wrf/*.py previsioni_lazio.py
python3 -m pyflakes wrf/*.py previsioni_lazio.py

passo "script bash"
shellcheck -S warning wrf/*.sh

passo "compilazione a tappe: avanzamento, tempo massimo e guardiano (comandi inventati)"
bash wrf/prova_costruzione.sh "$T/costruzione"

passo "domini e namelist (riletti con f90nml)"
python3 wrf/dominio.py
python3 - <<'EOF'
import subprocess, f90nml
def nml(*a):
    return f90nml.reads(subprocess.check_output(["python3", "wrf/config.py", *a], text=True))
w = nml("wps", "--ciclo", "2026101600", "--ore", "48", "--sst")
assert w["metgrid"]["fg_name"] == ["ECMWF", "SST"], w["metgrid"]["fg_name"]
fine = None
for da, a in ((0, 16), (16, 32), (32, 48)):
    n = nml("input", "--ciclo", "2026101600", "--da", str(da), "--a", str(a), "--obs-minuti", "530")
    tc = n["time_control"]
    assert tc["restart"] == (da > 0) and tc["run_hours"] == a - da and tc["restart_interval"] == (a - da) * 60
    inizio = (tc["start_day"][0], tc["start_hour"][0])
    assert fine is None or inizio == fine, "un segmento non riparte dove finisce il precedente"
    fine = (tc["end_day"][0], tc["end_hour"][0])
    assert n["fdda"]["fdda_end"][0] == 530.0
import importlib.util
sp = importlib.util.spec_from_file_location("config", "wrf/config.py"); cfg = importlib.util.module_from_spec(sp); sp.loader.exec_module(cfg)
for secondi in (16 * 3600, 3 * 3600, 3600):   # segmento, intervallo dei bordi, uscite orarie
    assert secondi % cfg.TIME_STEP == 0, f"il passo di {cfg.TIME_STEP} s non divide {secondi} s"
assert cfg.TIME_STEP % 9 == 0, "i nidi (rapporto 3 poi 3) vogliono un passo intero"
print("namelist ok")
EOF

passo "le mappe stanno dentro il dominio a 3 km (almeno 15 km dal bordo) e il Lazio sta dentro le mappe"
python3 - <<'EOF'
import sys
sys.path.insert(0, "wrf"); sys.path.insert(0, ".")
import dominio as D
import previsioni_lazio as pc
from pyproj import Proj, Transformer
lcc = Proj(proj="lcc", lat_1=D.TRUELAT1, lat_2=D.TRUELAT2, lat_0=D.LAT0, lon_0=D.LON0, R=6370000)
fw = Transformer.from_proj("EPSG:4326", lcc, always_xy=True)
semi = D.celle(2) * D.DX[2] / 2000.0
for lat in (pc.LAT_MIN, pc.LAT_MAX):
    for lon in (pc.LON_MIN, pc.LON_MAX):
        x, y = fw.transform(lon, lat)
        assert max(abs(x), abs(y)) / 1000 <= semi - 15, (lat, lon, x / 1000, y / 1000, semi)
# estremi del Lazio (gradi): sud, nord, ovest, est
assert pc.LAT_MIN < 40.78 and pc.LAT_MAX > 42.85 and pc.LON_MIN < 11.45 and pc.LON_MAX > 14.0
print("mappe e dominio ok")
EOF

passo "confini del Lazio e delle province: le città del Lazio dentro, quelle vicine fuori, cinque province"
python3 - <<'EOF'
import json, sys
sys.path.insert(0, ".")
import numpy as np
from matplotlib.path import Path
import previsioni_lazio as pc
d = json.load(open("dati/confini_lazio.json"))
assert d["regione"] and "CC BY" in d["fonte"], "file dei confini incompleto"
nel = sorted(p["nome"] for p in d["province"] if p["regione"] == "Lazio")
assert nel == ["Frosinone", "Latina", "Rieti", "Roma", "Viterbo"], nel
anelli = [Path(np.array(a)) for a in d["regione"]]
def nel_lazio(la, lo):
    return any(a.contains_point((lo, la)) for a in anelli)
for nome, la, lo in pc.PAESI + [pc.STAZIONE]:
    assert nel_lazio(la, lo), nome + " dovrebbe stare dentro il Lazio"
for nome, la, lo in (("Siena", 43.32, 11.33), ("L'Aquila", 42.35, 13.40), ("Caserta", 41.07, 14.33), ("Terni", 42.56, 12.64)):
    assert not nel_lazio(la, lo), nome + " dovrebbe stare fuori dal Lazio"
# il disegno deve usare le linee: confine spesso, province sottili
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
pc.disegna_confini(ax)
spessori = sorted({round(l.get_linewidth(), 1) for l in ax.lines})
assert spessori == [0.7, 1.0, 2.6], spessori
print("confini ok:", len(d["regione"]), "anelli del Lazio,", len(d["province"]), "province, linee", spessori)
EOF

passo "file met_em fatti come quelli di metgrid 4.7 (livelli letti dalla dimensione e dall'attributo)"
python3 - "$T" <<'EOF'
import subprocess, sys
from netCDF4 import Dataset
t = sys.argv[1]
def crea(nome, nlev=34, nsoil=4):
    with Dataset(f"{t}/{nome}", "w") as ds:
        ds.createDimension("Time", None)
        ds.createDimension("num_metgrid_levels", nlev)
        ds.createDimension("west_east", 3)
        ds.setncattr("TITLE", "OUTPUT FROM METGRID V4.7.0")
        if nsoil is not None:
            ds.setncattr("NUM_METGRID_SOIL_LEVELS", nsoil)
def info(nome):
    return subprocess.run(["python3", "wrf/config.py", "metgrid-info", f"{t}/{nome}"], capture_output=True, text=True)
crea("met_ok.nc")
r = info("met_ok.nc")
assert r.stdout.split() == ["34", "4"], (r.stdout, r.stderr)
crea("met_zero.nc", nsoil=0)
r = info("met_zero.nc")
assert r.returncode != 0 and "livelli di suolo" in r.stderr, r
crea("met_senza.nc", nsoil=None)
r = info("met_senza.nc")
assert r.returncode != 0 and "NUM_METGRID_SOIL_LEVELS" in r.stderr, r
print("met_em ok")
EOF

passo "file WRF e geo_em inventati"
python3 wrf/prova_sintetica.py --out "$T/sint" --geo "$T/geo"

passo "tutte le stazioni: ricerca a riquadri senza perdite, controllo di qualità con guasti inventati, rilettura con i formati di WRF"
python3 wrf/stazioni_wrf.py --prova --ciclo 2026101600 --geo "$T/geo" --out "$T/obs"
gfortran wrf/leggi_obs.f90 -o "$T/leggi_obs"
for f in "$T"/obs/OBS_DOMAIN101 "$T"/obs/OBS_DOMAIN201 "$T"/obs/OBS_DOMAIN301; do "$T/leggi_obs" "$f"; done

passo "ricerca e lettura delle stazioni usate dalle mappe (API inventata, tutte le stazioni, in parallelo)"
python3 - "$T" <<'EOF'
import sys
from datetime import datetime, timezone
sys.path.insert(0, "wrf"); sys.path.insert(0, ".")
import previsioni_lazio as pc
import stazioni_wrf as sw
dom = sw.carica_domini(sys.argv[1] + "/geo")
api = sw.ApiFinta(dom, datetime.now(timezone.utc))
sw.wu_get = api
trovate = pc.cerca_stazioni("finta")
dentro = sum(1 for la, lo in api.pos if pc.LAT_MIN <= la <= pc.LAT_MAX and pc.LON_MIN <= lo <= pc.LON_MAX)
assert dentro > 500 and len(trovate) >= 0.995 * dentro, (dentro, len(trovate))
def finto(url, params, validita):
    if params["stationId"].endswith("7"):
        raise KeyError("niente")
    return {"observations": [{"lat": 41.7, "lon": 12.7, "obsTimeLocal": "2026-10-16 12:00:00", "metric": {"elev": 100, "temp": 18.2, "dewpt": 9.0}}]}
pc._get_json = finto
ids = [f"IF{i:05d}" for i in range(200)]
oss = pc.leggi_stazioni("finta", ids)
assert len(oss) == sum(1 for i in ids if not i.endswith("7")), len(oss)
print(f"mappe: {len(trovate)} stazioni trovate su {dentro} nel riquadro, {len(oss)} lette su {len(ids)}")
EOF

passo "temperatura del mare: formato intermedio di WPS riletto"
python3 - "$T" <<'EOF'
import struct, sys
from pathlib import Path
import numpy as np
sys.path.insert(0, "wrf")
import scarica_sst as s
lat, lon = np.linspace(39, 44.5, 23), np.linspace(9, 16.5, 31)
k = np.where(np.random.default_rng(0).random((23, 31)) > 0.3, 290.0, -1.0e30)
p = Path(sys.argv[1]) / "SST:2026-10-16_00"
s.scrivi_intermedio(p, "2026-10-16_00:00:00", lat, lon, k)
b = p.read_bytes(); pos = 0
def rec():
    global pos
    n = struct.unpack(">i", b[pos:pos + 4])[0]; r = b[pos + 4:pos + 4 + n]
    assert struct.unpack(">i", b[pos + 4 + n:pos + 8 + n])[0] == n; pos += n + 8; return r
assert struct.unpack(">i", rec())[0] == 5
h = rec(); assert h[:19] == b"2026-10-16_00:00:00" and h[60:69].strip() == b"SST"
nx, ny, iproj = struct.unpack(">iii", h[-12:]); assert (nx, ny, iproj) == (31, 23, 0)
rec(); rec()
z = np.frombuffer(rec(), ">f4").reshape(ny, nx); assert np.allclose(z, k) and pos == len(b)
print("SST ok")
EOF

passo "mappe da wrfout inventati"
python3 wrf/postprocess.py --uscite "$T/sint" --out "$T/mappe" --ciclo 2026101600 --senza-stazioni --da-ora 2026-10-16T08:00
[ "$(find "$T/mappe" -maxdepth 1 -name '*.png' | wc -l)" -ge 9 ] || { echo "mancano mappe"; exit 1; }

passo "mappe con dati inventati (previsioni_lazio.py --simula, senza rete)"
python3 previsioni_lazio.py --simula --inizio 2026-10-16T08:00 --out "$T/simula" --senza-stazioni
python3 previsioni_lazio.py --simula --inizio 2026-10-16T08:00 --ora 30 --out "$T/simula" --senza-stazioni
[ "$(find "$T/simula" -maxdepth 1 -name '*.png' | wc -l)" -ge 11 ] || { echo "mancano mappe nella simulazione"; exit 1; }

passo "immagini orarie: una per ora e variabile, con indice"
python3 - "$T/mappe/orarie" <<'EOF2'
import json, sys
from pathlib import Path
d = Path(sys.argv[1]); idx = json.loads((d / "indice.json").read_text())
assert idx["ciclo"] == "2026101600" and idx["run"] == "2026-10-16T00:00:00Z", idx
assert len(idx["variabili"]) >= 9 and len(idx["ore"]) >= 24, (len(idx["variabili"]), len(idx["ore"]))
for v in idx["variabili"]:
    for t in idx["ore"]:
        f = d / idx["ciclo"] / v["id"] / (t[:13].replace("-", "").replace("T", "") + ".png")
        assert f.stat().st_size > 5000, f
print("orarie ok:", len(idx["variabili"]), "variabili x", len(idx["ore"]), "ore")
EOF2

passo "pubblicazione nel ramo risultati (su un repository finto): un solo commit, due cicli di immagini orarie"
R="$T/pubblica"; rm -rf "$R"; mkdir -p "$R"; git init -q --bare "$R/remoto.git"
for c in 2026101600 2026101612 2026101700; do
  rm -rf "$R/img"; mkdir -p "$R/img/orarie/$c/temperatura_2m"; echo x > "$R/img/01_t.png"
  echo x > "$R/img/orarie/$c/temperatura_2m/a.png"; echo "{\"ciclo\": \"$c\"}" > "$R/img/orarie/indice.json"
  REPO_URL="$R/remoto.git" GITHUB_REPOSITORY=u/r bash wrf/pubblica.sh "$R/img" "$c" 2>/dev/null
done
git clone -q -b risultati "$R/remoto.git" "$R/vedi"
[ "$(git -C "$R/vedi" rev-list --count HEAD)" = 1 ] || { echo "la storia si accumula"; exit 1; }
[ "$(ls "$R/vedi/orarie" | tr '\n' ' ')" = "2026101612 2026101700 indice.json " ] || { echo "cicli orari sbagliati"; exit 1; }

passo "pagina del sito: sintassi del JavaScript"
python3 - "$T/pagina.js" <<'EOF3'
import re, sys
html = open("sito/previsioni-wrf-lazio.html", encoding="utf-8").read()
open(sys.argv[1], "w", encoding="utf-8").write(re.search(r"<script>(.*?)</script>", html, re.S).group(1))
EOF3
if command -v node >/dev/null; then node --check "$T/pagina.js" && echo "pagina ok"; else echo "node non c'e': salto"; fi

passo "movimento della pioggia su un caso inventato"
python3 - <<'EOF'
import sys
sys.path.insert(0, "wrf")
import numpy as np
from scipy.ndimage import gaussian_filter, shift
import radar
rng = np.random.default_rng(0)
a = np.zeros((500, 500), "float32")
for _ in range(40):
    y, x = rng.integers(100, 400, 2)
    a[y - 6:y + 6, x - 8:x + 8] = rng.uniform(1, 20)
a = gaussian_filter(a, 3) * 3
v, _ = radar.movimento(a, shift(a, (6, 18), order=1), 6)
assert np.allclose(v, (3, 1), atol=0.2), v
v, _ = radar.movimento(a, shift(a, (1, 2), order=1), 6)
assert not v.any(), v
r = radar.estrapola(a, np.broadcast_to(np.float32([3, 1]), a.shape + (2,)).copy(), 6)
assert np.abs(r[150:350, 150:350] - shift(a, (6, 18), order=1)[150:350, 150:350]).max() < 0.5
print("movimento ok")
EOF

if [ "${PROVA_RADAR:-0}" = 1 ]; then
  passo "radar vero (Radar-DPC) con WRF inventato"
  python3 wrf/pioggia_radar.py --uscite "$T/sint" --out "$T/mappe" --ciclo 2026101600
fi

echo; echo "TUTTO OK  (file in $T)"
