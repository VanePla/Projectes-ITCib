#!/usr/bin/env python3
"""
Generador del timelapse Bicing Barcelona — Setmana 8-14 abril 2024
═════════════════════════════════════════════════════════════════════════

Genera un fitxer HTML autocontingut amb un mapa Leaflet animat que mostra
l'estat de les 548 estacions Bicing al llarg de la setmana del 8 al 14
d'abril de 2024 (dilluns a diumenge, 48 franges de 30 min per dia = 336
fotogrames).

Per a cada franja, el color de cada estació reflecteix l'estat real
registrat: buida (vermell), plena (blau), mixt (groc) o normal (gris fosc).

Execució:
    cd <directori on es troba bicicletes.duckdb>
    python3 generar_timelapse.py

Genera: timelapse_bicing.html (~2-3 MB)
        Obrir directament al navegador — no cal servidor.

Requisits: duckdb, pandas  (pip install duckdb pandas)
"""

import duckdb
import json
import os
import sys

# ═══════════════════════════════════════════════════════════════════════════
# Configuració
# ═══════════════════════════════════════════════════════════════════════════
DB_PATH      = 'bicicletes.duckdb'
OUTPUT       = 'timelapse_bicing.html'
SPRING_START = '2024-04-08'
SPRING_END   = '2024-04-15'

DIES_CA = ['Dilluns', 'Dimarts', 'Dimecres', 'Dijous',
           'Divendres', 'Dissabte', 'Diumenge']

# ═══════════════════════════════════════════════════════════════════════════
# 1. Connexió i consultes SQL
# ═══════════════════════════════════════════════════════════════════════════
if not os.path.exists(DB_PATH):
    print(f"ERROR: No es troba '{DB_PATH}' al directori actual.")
    print(f"       Executa l'script des del directori on es troba la base de dades.")
    sys.exit(1)

print(f'Connectant a {DB_PATH}...')
con = duckdb.connect(DB_PATH, read_only=True)

# ── Coordenades de les 548 estacions ─────────────────────────────────────
print('Llegint coordenades de les estacions...')
df_est = con.execute("""
    SELECT id_estacio,
           CAST(lat AS DOUBLE) AS lat,
           CAST(lon AS DOUBLE) AS lon,
           nom_districte
    FROM estacions
    ORDER BY id_estacio
""").df()

station_ids = df_est['id_estacio'].tolist()
n_stations  = len(station_ids)
print(f'  {n_stations} estacions carregades')

# ── Dades reals setmana 8-14 abril 2024 per estació × franja ──────────
print(f'Llegint dades reals de la setmana {SPRING_START} → {SPRING_END}...')

SQL_SETMANA = f"""
    SELECT
        id_estacio,
        ISODOW(data)                    AS dia_setmana,
        CAST(hora_dia AS INTEGER)       AS hora_dia,
        mitja_hora,
        estat
    FROM totes_mitja_hores
    WHERE data >= '{SPRING_START}' AND data < '{SPRING_END}'
    ORDER BY dia_setmana, hora_dia, mitja_hora, id_estacio
"""

df = con.execute(SQL_SETMANA).df()
con.close()
print(f'  {len(df)} files de dades agregades')

# ═══════════════════════════════════════════════════════════════════════════
# 2. Funció de color (estat directe)
# ═══════════════════════════════════════════════════════════════════════════
STATE_COLORS = {
    'buida':         '#dc2626',   # vermell
    'plena':         '#2563eb',   # blau
    'extremes':      '#eab308',   # groc (mixt)
    'normal':        '#333333',   # gris fosc
    'sense_mesures': '#333333',   # gris fosc (sense dades)
}

DEFAULT_COLOR = '#333333'


# ═══════════════════════════════════════════════════════════════════════════
# 3. Construir fotogrames (336 = 7 dies × 48 franges)
# ═══════════════════════════════════════════════════════════════════════════
print('Construint 336 fotogrames...')

# Lookup ràpid: (dia, hora, mh, id_estacio) → estat
lookup = {}
for _, row in df.iterrows():
    key = (int(row['dia_setmana']), int(row['hora_dia']),
           int(row['mitja_hora']),  int(row['id_estacio']))
    lookup[key] = row['estat']

frames_colors = []      # llista de llistes de colors hex
frames_labels = []      # "Dilluns 08:00"
frames_stats  = []      # [n_buida, n_plena] per fotograma

for dia in range(1, 8):             # 1=Dl … 7=Dg
    for slot in range(48):          # 0-47  (slot 0 = 00:00, slot 1 = 00:30 …)
        hora = slot // 2
        mh   = slot % 2

        label = f"{DIES_CA[dia-1]} {hora:02d}:{mh*30:02d}"
        colors  = []
        n_buida = 0
        n_plena = 0

        for sid in station_ids:
            key = (dia, hora, mh, sid)
            estat = lookup.get(key, 'normal')
            c = STATE_COLORS.get(estat, DEFAULT_COLOR)

            if estat == 'buida':
                n_buida += 1
            elif estat == 'plena':
                n_plena += 1

            colors.append(c)

        frames_colors.append(colors)
        frames_labels.append(label)
        frames_stats.append([n_buida, n_plena])

print(f'  {len(frames_colors)} fotogrames × {n_stations} estacions = '
      f'{len(frames_colors) * n_stations:,} entrades de color')

# ═══════════════════════════════════════════════════════════════════════════
# 4. Generar HTML autocontingut
# ═══════════════════════════════════════════════════════════════════════════
print(f'Generant {OUTPUT}...')

stations_json = json.dumps([
    {'lat': float(r['lat']), 'lon': float(r['lon']),
     'id': int(r['id_estacio']), 'dist': r['nom_districte']}
    for _, r in df_est.iterrows()
], separators=(',', ':'))

frames_json = json.dumps(frames_colors, separators=(',', ':'))
labels_json = json.dumps(frames_labels, separators=(',', ':'))
stats_json  = json.dumps(frames_stats,  separators=(',', ':'))

# ── Plantilla HTML ───────────────────────────────────────────────────────
HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="ca">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Bicing Barcelona — Timelapse setmanal · 8-14 abril 2024</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,500;0,9..40,700&family=JetBrains+Mono:wght@300;500&display=swap" rel="stylesheet">
<style>
  *, *::before, *::after { margin:0; padding:0; box-sizing:border-box; }
  body { font-family:'DM Sans',system-ui,sans-serif; background:#07080c; overflow:hidden; }

  #map {
    position:absolute; top:0; left:0; right:0; bottom:88px; z-index:1;
  }

  /* ─── Top bar ─── */
  .top-bar {
    position:absolute; top:0; left:0; right:0; z-index:1000;
    display:flex; justify-content:space-between; align-items:flex-start;
    padding:14px 20px; pointer-events:none; gap:12px;
  }
  .title-box {
    background:rgba(255,255,255,0.93); backdrop-filter:blur(10px);
    padding:10px 18px; border-radius:10px;
    box-shadow:0 2px 16px rgba(0,0,0,0.12); pointer-events:auto;
  }
  .title-box h1 { font-size:14px; color:#0f172a; font-weight:700; }
  .title-box .sub { font-size:11px; color:#64748b; margin-top:1px; }

  .stats-box {
    background:rgba(255,255,255,0.93); backdrop-filter:blur(10px);
    padding:10px 16px; border-radius:10px;
    box-shadow:0 2px 16px rgba(0,0,0,0.12); pointer-events:auto;
    min-width:170px;
  }
  .stats-title {
    font-size:10px; text-transform:uppercase; letter-spacing:1.5px;
    color:#94a3b8; font-weight:700; margin-bottom:6px;
  }
  .stat-row { display:flex; align-items:center; gap:8px; margin:5px 0; font-size:13px; color:#334155; }
  .stat-dot { width:10px; height:10px; border-radius:50%; flex-shrink:0; }
  .stat-dot.buida { background:#dc2626; }
  .stat-dot.plena { background:#2563eb; }
  .stat-val {
    font-family:'JetBrains Mono',monospace; font-weight:500;
    min-width:32px; text-align:right; font-size:14px; color:#0f172a;
  }
  .stat-label { flex:1; }

  /* ─── Legend ─── */
  .legend {
    position:absolute; bottom:104px; left:20px; z-index:1000;
    background:rgba(255,255,255,0.93); backdrop-filter:blur(10px);
    padding:10px 14px; border-radius:10px;
    box-shadow:0 2px 12px rgba(0,0,0,0.12); font-size:12px;
  }
  .legend-title {
    font-size:10px; font-weight:700; text-transform:uppercase;
    letter-spacing:1.5px; color:#94a3b8; margin-bottom:6px;
  }
  .legend-item { display:flex; align-items:center; gap:7px; margin:4px 0; color:#475569; }
  .legend-swatch {
    width:12px; height:12px; border-radius:50%;
    border:1px solid rgba(0,0,0,0.08); flex-shrink:0;
  }

  /* ─── Bottom controls ─── */
  .controls {
    position:absolute; bottom:0; left:0; right:0; height:88px;
    background:linear-gradient(180deg, #0e1019 0%, #12141f 100%);
    border-top:1px solid rgba(255,255,255,0.06);
    z-index:1000; display:flex; flex-direction:column;
    justify-content:center; padding:6px 24px 10px;
  }

  .day-ticks {
    display:flex; padding:0 6px; margin-bottom:2px;
  }
  .day-ticks span {
    flex:1; text-align:center; font-size:10px; font-weight:500;
    color:rgba(255,255,255,0.3); letter-spacing:1px;
    border-left:1px solid rgba(255,255,255,0.07);
    padding-bottom:2px;
  }
  .day-ticks span:first-child { border-left:none; }

  .slider-wrap { padding:0 4px; margin-bottom:6px; }
  .slider-wrap input[type=range] {
    width:100%; height:5px; -webkit-appearance:none; appearance:none;
    background:#1e2030; border-radius:3px; outline:none; cursor:pointer;
  }
  .slider-wrap input[type=range]::-webkit-slider-thumb {
    -webkit-appearance:none; width:14px; height:14px;
    background:#e2e8f0; border-radius:50%; cursor:pointer;
    box-shadow:0 0 8px rgba(226,232,240,0.25);
    transition:transform 0.1s;
  }
  .slider-wrap input[type=range]::-webkit-slider-thumb:hover {
    transform:scale(1.3);
  }

  .btn-row {
    display:flex; align-items:center; justify-content:center; gap:5px;
  }
  /* ─── Floating draggable clock ─── */
  .time-float {
    position:absolute; z-index:1001;
    bottom:240px; left:24px;
    background:rgba(8,10,22,0.88); backdrop-filter:blur(12px);
    padding:10px 24px; border-radius:12px;
    box-shadow:0 4px 24px rgba(0,0,0,0.4);
    cursor:grab; user-select:none;
    display:flex; align-items:baseline; gap:12px;
    transition:box-shadow 0.15s;
  }
  .time-float:active { cursor:grabbing; box-shadow:0 8px 32px rgba(0,0,0,0.55); }
  .time-float .t-day {
    font-size:13px; color:rgba(255,255,255,0.45);
    letter-spacing:2.5px; text-transform:uppercase; font-weight:500;
  }
  .time-float .t-hour {
    font-family:'JetBrains Mono',monospace; font-size:38px; font-weight:300;
    color:#e2e8f0; letter-spacing:5px; line-height:1;
  }
  .btn {
    background:rgba(255,255,255,0.06); border:1px solid rgba(255,255,255,0.1);
    color:#94a3b8; padding:3px 12px; border-radius:6px; cursor:pointer;
    font-size:13px; font-family:'DM Sans',sans-serif; font-weight:500;
    transition:all 0.15s; user-select:none;
  }
  .btn:hover { background:rgba(255,255,255,0.12); color:#e2e8f0; }
  .btn.play-btn { padding:3px 18px; }
  .btn.active { background:rgba(96,165,250,0.15); border-color:rgba(96,165,250,0.3); color:#93c5fd; }
  .sep { width:1px; height:18px; background:rgba(255,255,255,0.08); margin:0 6px; }
  .speed-group { display:flex; align-items:center; gap:4px; margin-left:auto; }
  .speed-lbl { color:rgba(255,255,255,0.35); font-size:11px; }
  .speed-val {
    font-family:'JetBrains Mono',monospace; font-size:12px;
    font-weight:500; color:rgba(255,255,255,0.6);
    min-width:44px; text-align:center;
  }

  /* ─── Responsive ─── */
  @media (max-width:700px) {
    .top-bar { flex-wrap:wrap; gap:8px; padding:8px 10px; }
    .title-box, .stats-box { font-size:12px; }
    .controls { height:80px; padding:4px 12px 8px; }
    .time-float .t-hour { font-size:28px; }
    .time-float .t-day { font-size:11px; }
  }
</style>
</head>
<body>

<div id="map"></div>

<div class="top-bar">
  <div class="title-box">
    <h1>Bicing Barcelona — Timelapse setmanal</h1>
    <div class="sub">Setmana del 8 al 14 d'abril de 2024 · 548 estacions</div>
  </div>
  <div class="stats-box">
    <div class="stats-title">Estacions afectades</div>
    <div class="stat-row">
      <span class="stat-dot buida"></span>
      <span class="stat-label">Buides</span>
      <span class="stat-val" id="nBuida">0</span>
    </div>
    <div class="stat-row">
      <span class="stat-dot plena"></span>
      <span class="stat-label">Plenes</span>
      <span class="stat-val" id="nPlena">0</span>
    </div>
  </div>
</div>

<div class="legend">
  <div class="legend-title">Problema dominant</div>
  <div class="legend-item"><span class="legend-swatch" style="background:#dc2626"></span> Buida — sense bicis</div>
  <div class="legend-item"><span class="legend-swatch" style="background:#2563eb"></span> Plena — sense anclatges</div>
  <div class="legend-item"><span class="legend-swatch" style="background:#eab308"></span> Mixt — ambdós</div>
  <div class="legend-item"><span class="legend-swatch" style="background:#333"></span> Normal</div>
</div>

<!-- Floating draggable clock -->
<div class="time-float" id="timeFloat">
  <span class="t-day" id="tDay">Dilluns</span>
  <span class="t-hour" id="tHour">00:00</span>
</div>

<div class="controls">
  <div class="day-ticks">
    <span>Dl</span><span>Dt</span><span>Dc</span><span>Dj</span><span>Dv</span><span>Ds</span><span>Dg</span>
  </div>
  <div class="slider-wrap">
    <input type="range" id="slider" min="0" max="335" value="0" step="1">
  </div>
  <div class="btn-row">
    <button class="btn" id="bPrevDay" title="Dia anterior (PageUp)">⏮ Dia</button>
    <button class="btn" id="bPrev" title="Retrocedir (←)">◀</button>
    <button class="btn play-btn active" id="bPlay" title="Play / Pausa (Espai)">▶ Play</button>
    <button class="btn" id="bNext" title="Avançar (→)">▶</button>
    <button class="btn" id="bNextDay" title="Dia següent (PageDown)">Dia ⏭</button>
    <div class="speed-group">
      <span class="speed-lbl">Velocitat</span>
      <button class="btn" id="bSlower" title="Més lent">−</button>
      <span class="speed-val" id="spdVal">4 fps</span>
      <button class="btn" id="bFaster" title="Més ràpid">+</button>
    </div>
  </div>
</div>

<script>
// ═══════════════════════════════════════════════════════════════
// Data (injectat pel script Python)
// ═══════════════════════════════════════════════════════════════
var S  = __STATIONS__;
var FR = __FRAMES__;
var LB = __LABELS__;
var ST = __STATS__;

// ═══════════════════════════════════════════════════════════════
// Map
// ═══════════════════════════════════════════════════════════════
var map = L.map('map', {
  center: [41.3925, 2.1654],
  zoom: 13,
  zoomControl: false
});
L.control.zoom({ position: 'bottomright' }).addTo(map);
L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png', {
  attribution: '&copy; OpenStreetMap &copy; CartoDB',
  maxZoom: 18
}).addTo(map);

// Create all markers once
var markers = new Array(S.length);
for (var i = 0; i < S.length; i++) {
  markers[i] = L.circleMarker([S[i].lat, S[i].lon], {
    radius: 4.5,
    weight: 0.4,
    color: '#333',
    fillColor: '#333',
    fillOpacity: 0.85
  }).addTo(map);
  markers[i].bindTooltip(
    '<b>Est. ' + S[i].id + '</b><br>' + S[i].dist,
    { direction: 'top', offset: [0, -5] }
  );
}

// ═══════════════════════════════════════════════════════════════
// Animation engine
// ═══════════════════════════════════════════════════════════════
var frame   = 0;
var playing = false;
var fps     = 4;
var timer   = null;
var TOTAL   = FR.length;  // 336

var $sl   = document.getElementById('slider');
var $tDay = document.getElementById('tDay');
var $tHr  = document.getElementById('tHour');
var $nB   = document.getElementById('nBuida');
var $nP   = document.getElementById('nPlena');
var $play = document.getElementById('bPlay');
var $spd  = document.getElementById('spdVal');

function render(f) {
  frame = ((f % TOTAL) + TOTAL) % TOTAL;
  var c = FR[frame];
  for (var i = 0; i < markers.length; i++) {
    markers[i].setStyle({ fillColor: c[i], color: c[i] });
  }
  var lb = LB[frame];
  var sp = lb.indexOf(' ');
  $tDay.textContent = lb.substring(0, sp);
  $tHr.textContent  = lb.substring(sp + 1);
  $sl.value = frame;
  $nB.textContent = ST[frame][0];
  $nP.textContent = ST[frame][1];
}

function play() {
  if (timer) clearInterval(timer);
  playing = true;
  $play.textContent = '⏸ Pausa';
  $play.classList.add('active');
  timer = setInterval(function() { render(frame + 1); }, 1000 / fps);
}

function pause() {
  if (timer) clearInterval(timer);
  timer = null;
  playing = false;
  $play.textContent = '▶ Play';
  $play.classList.remove('active');
}

// Controls
$play.onclick = function() { playing ? pause() : play(); };
document.getElementById('bNext').onclick     = function() { pause(); render(frame + 1); };
document.getElementById('bPrev').onclick     = function() { pause(); render(frame - 1); };
document.getElementById('bNextDay').onclick  = function() { pause(); render(Math.min(frame + 48, TOTAL - 1)); };
document.getElementById('bPrevDay').onclick  = function() { pause(); render(Math.max(frame - 48, 0)); };

$sl.addEventListener('input', function() {
  pause();
  render(parseInt(this.value));
});

document.getElementById('bFaster').onclick = function() {
  fps = Math.min(fps + 2, 30);
  $spd.textContent = fps + ' fps';
  if (playing) play();
};
document.getElementById('bSlower').onclick = function() {
  fps = Math.max(fps - 2, 1);
  $spd.textContent = fps + ' fps';
  if (playing) play();
};

// Keyboard
document.addEventListener('keydown', function(e) {
  switch(e.code) {
    case 'Space':     e.preventDefault(); playing ? pause() : play(); break;
    case 'ArrowRight': render(frame + 1); break;
    case 'ArrowLeft':  render(frame - 1); break;
    case 'PageDown':   e.preventDefault(); render(Math.min(frame + 48, TOTAL - 1)); break;
    case 'PageUp':     e.preventDefault(); render(Math.max(frame - 48, 0)); break;
  }
});

// ═══════════════════════════════════════════════════════════════
// Draggable clock
// ═══════════════════════════════════════════════════════════════
(function() {
  var el = document.getElementById('timeFloat');
  var dragging = false, ox = 0, oy = 0;

  function onDown(e) {
    e.preventDefault();
    dragging = true;
    var pt = e.touches ? e.touches[0] : e;
    var r = el.getBoundingClientRect();
    ox = pt.clientX - r.left;
    oy = pt.clientY - r.top;
    // Switch from bottom/left positioning to top/left for free dragging
    el.style.top  = r.top + 'px';
    el.style.left = r.left + 'px';
    el.style.bottom = 'auto';
    el.style.right  = 'auto';
  }

  function onMove(e) {
    if (!dragging) return;
    e.preventDefault();
    var pt = e.touches ? e.touches[0] : e;
    var nx = pt.clientX - ox;
    var ny = pt.clientY - oy;
    // Clamp within viewport
    nx = Math.max(0, Math.min(nx, window.innerWidth  - el.offsetWidth));
    ny = Math.max(0, Math.min(ny, window.innerHeight - el.offsetHeight));
    el.style.left = nx + 'px';
    el.style.top  = ny + 'px';
  }

  function onUp() { dragging = false; }

  el.addEventListener('mousedown',  onDown);
  document.addEventListener('mousemove', onMove);
  document.addEventListener('mouseup',   onUp);
  el.addEventListener('touchstart', onDown, { passive: false });
  document.addEventListener('touchmove', onMove, { passive: false });
  document.addEventListener('touchend',  onUp);
})();

// Initial
render(0);
</script>
</body>
</html>"""

# ── Injectar dades a la plantilla ────────────────────────────────────────
html = HTML_TEMPLATE
html = html.replace('__STATIONS__', stations_json)
html = html.replace('__FRAMES__',   frames_json)
html = html.replace('__LABELS__',   labels_json)
html = html.replace('__STATS__',    stats_json)

with open(OUTPUT, 'w', encoding='utf-8') as f:
    f.write(html)

size_mb = os.path.getsize(OUTPUT) / (1024 * 1024)
print(f'\n✓ Generat: {OUTPUT}  ({size_mb:.1f} MB)')
print(f'  Obre el fitxer al navegador per veure el timelapse.')
print(f'  Controls: Espai=play/pausa, ←→=avançar/retrocedir, PgUp/PgDn=dia')
