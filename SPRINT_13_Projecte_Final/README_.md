# 🚲 Bicing Barcelona — Anàlisi de disponibilitat, patrons d'ús i predicció de l'estat de les estacions

**Projecte final · Sprint 13 · Itinerari d'Anàlisi de Dades**  
Cibernàrium / Barcelona Activa · 2026

---

## 📌 Descripció

Anàlisi del servei de bicicletes compartides Bicing de Barcelona a partir de **291 milions de mesuraments** recollits entre gener de 2020 i setembre de 2025 en 548 estacions de la xarxa (Open Data Barcelona).

El projecte respon tres preguntes clau:

1. **Com de greu és el problema de disponibilitat?** — Quantificar el percentatge de temps que les estacions estan buides (sense bicicletes) o plenes (sense ancoratges lliures).
2. **Quan i on passa?** — Identificar patrons temporals (hora, dia, mes) i geogràfics (districte, tipologia d'estació).
3. **Es pot predir?** — Avaluar models de machine learning per anticipar l'estat de les estacions amb 30 minuts d'antelació.

---

## 📊 Resultats principals

| Mètrica | Valor |
|---|---|
| Franges de 30 min amb estació buida o plena | **15–25%** |
| Pic d'estacions buides (hora) | **8–10h i 17–19h** |
| Districte més problemàtic | **Sarrià-Sant Gervasi (>30% del temps buides)** |
| Clústers d'estacions identificats | **5 perfils (sobre 517 estacions)** |
| Balanced Accuracy Random Forest | **83,2%** |

---

## 🗂️ Estructura del repositori

```
SPRINT_13_Projecte_Final/
├── 0.Dades_Analisi/
    │
    ├── 0_0_dades_bicing_opendata.ipynb      # Descàrrega i exploració inicial d'Open Data BCN
    ├── 0_1_dades_headers.py                 # Anàlisi de capçaleres dels CSVs descarregats
    ├── 0_2_dades_headers_concat.py          # Concatenació de CSVs per tipus de capçalera
    │
    ├── bicicletes_bicing.txt                # Instruccions per crear la base de dades DuckDB
    │                                        # des de zero (comandes CMD pas a pas)
    ├── bicicletes_creacio_1.sql             # SQL DuckDB: pipeline de dades (taules origen,
    │                                        # neteja, enriquiment, agregacions,
    │                                        # indicadors de clustering i baselines)
    │
    ├── 1_exploratori.ipynb                  # Anàlisi exploratòria: mapa d'estacions,
    │                                        # evolució de viatges, patrons hora/dia/mes,
    │                                        # distribució del problema de disponibilitat
    │
    ├── 2_clustering.ipynb                   # Clustering K-Means (k=5): preparació de
    │                                        # features, normalització, selecció de k,
    │                                        # interpretació i mapa de clústers
    │
    ├── bicicletes_creacio_2_rf.sql          # SQL DuckDB: taules de features per a Random
    │                                        # Forest amb arquitectura LAG(2) anti-leakage
    │                                        # (rf_nab_perfil, rf_features_train, rf_features_test)
    │
    ├── 3_prediccions.ipynb                  # Predicció de l'estat de les estacions:
    │                                        # Random Forest vs. baselines (HA i SN7),
    │                                        # mètriques per classe, importància de variables
    │
├── bicing.pdf                           # Informe escrit del projecte
├── Proyecto_bicing.pptx                 # Presentació per a l'exposició
└── README.md                            # Aquest fitxer
```

---

## 🔬 Metodologia

### Dades
- **Font:** [Open Data Barcelona — Servei Bicing](https://opendata-ajuntament.barcelona.cat/data/ca/dataset)
- **Període:** Gener 2020 – Setembre 2025
- **Volum:** 291 milions de mesuraments (~5 minuts de freqüència)
- **Variables:** bicicletes disponibles, ancoratges lliures, capacitat, timestamp, estat operatiu
- **Enriquiment:** coordenades, districte, hora local (Europe/Madrid), dia de la setmana, estació de l'any

### Pipeline de dades (DuckDB)

Les dades es processen en sis capes:

| Capa | Descripció |
|---|---|
| **Origen** | CSVs descarregats d'Open Data BCN, agrupats per tipus de capçalera |
| **Neteja** | Eliminació de duplicats, conversió de tipus, filtratge d'estacions no operatives |
| **Enriquiment** | Afegeix hora local, districte, dia de la setmana, estació de l'any |
| **Agregacions** | Estimació de viatges (caigudes en `num_bikes_available`), franges de 30 min |
| **Clustering** | 28 variables operatives per estació (NAB, variabilitat, capacitat, ràtios) |
| **Predicció** | Features amb LAG(2) per a Random Forest sense data leakage |

> Els viatges s'estimen a partir de les caigudes en el nombre de bicicletes disponibles (`delta_bicis < 0`).  
> El període 2020–2021 s'exclou de les anàlisis per les distorsions de la pandèmia.

### Eines

| Eina | Ús |
|---|---|
| **DuckDB** | Emmagatzematge i processament dels 291M de registres |
| **Python / Pandas** | Anàlisi i transformació de dades |
| **Scikit-learn** | Clustering K-Means i Random Forest |
| **Folium** | Mapes interactius d'estacions i clústers |
| **Matplotlib / Seaborn** | Visualitzacions estàtiques |

---

## 📈 Anàlisis realitzades

### 1. Anàlisi exploratòria (`1_exploratori.ipynb`)
- Mapa interactiu de les 548 estacions amb volum de viatges
- Evolució mensual de viatges 2020–2025 amb anotació de l'impacte COVID
- Mapa de calor hora × dia de la setmana
- Estacionalitat mensual per any
- Distribució del problema (buides/plenes) per hora, dia, districte i estació

### 2. Clustering K-Means (`2_clustering.ipynb`)

28 variables derivades per estació: perfil NAB horari (laborables i festius), capacitat mitjana, variabilitat del NAB, ràtios de saturació. Normalització amb StandardScaler. Selecció de k=5 amb mètode del colze + coeficient de Silhouette (k avaluat de 2 a 12).

| Clúster | Nom | N | % Buida | % Plena | NAB global |
|---|---|---|---|---|---|
| C0 | Perifèric Baix Ús | 132 | 20,6% | 0,4% | 0,22 |
| C1 | Central Alta Ocupació | 42 | 3,9% | 13,7% | 0,59 |
| C2 | Origen Commuter Matí | 162 | 12,3% | 2,4% | 0,37 |
| C3 | Ús Mixt Equilibrat | 122 | 2,3% | 3,7% | 0,49 |
| C4 | Residencial Entrada Tarda | 59 | 15,6% | 5,4% | 0,36 |

*31 estacions excloses per dades insuficients (>50% de franges sense mesuraments vàlids). Total analitzat: 517 estacions.*

### 3. Predicció de l'estat de les estacions (`3_prediccions.ipynb`)

Arquitectura **LAG(2)**: només s'utilitzen variables disponibles almenys 60 minuts abans de la predicció, eliminant el data leakage. Entrenament: 2022–2024. Test: gener–setembre 2025.

| Model | Balanced Accuracy | Macro F1 |
|---|---|---|
| Historical Average | 45,4% | 47,5% |
| Seasonal Naive 7d | 52,5% | 52,8% |
| **Random Forest** | **83,2%** | **64,6%** |

**Mètriques detallades del Random Forest:**

| Classe | Precision | Recall | F1 |
|---|---|---|---|
| Buida | 53,1% | 87,8% | 66,2% |
| Normal | 96,1% | 74,9% | 84,2% |
| Plena | 29,1% | 86,9% | 43,6% |

---

## ⚙️ Com reproduir el projecte

### Requisits
- Python 3.10+
- DuckDB v1.5.0
- Paquets: `pandas`, `scikit-learn`, `folium`, `matplotlib`, `seaborn`, `jupyter`

### Passos

**1. Descarregar les dades**  
Executar `0_0_dades_bicing_opendata.ipynb` o descarregar manualment des d'[Open Data BCN - estat estacions](https://opendata-ajuntament.barcelona.cat/data/ca/dataset/estat-estacions-bicing). Els fitxers `.7z` mensuals van a la carpeta `data_raw/`. Descarregar també des d'[Open Data BCN - informació estacions](https://opendata-ajuntament.barcelona.cat/data/ca/dataset/informacio-estacions-bicing) i [Open Data BCN - geolocalització](https://opendata-ajuntament.barcelona.cat/data/ca/dataset/20170706-districtes-barris/resource/cd800462-f326-429f-a67a-c69b7fc4c50a)

**2. Preprocessar els CSVs**
```bash
python 0_1_dades_headers.py
python 0_2_dades_headers_concat.py
```

**3. Crear la base de dades DuckDB**  
Seguir les instruccions de `bicicletes_bicing.txt`:
```bash
duckdb bicicletes.duckdb
.read bicicletes_creacio_1.sql
.read bicicletes_creacio_2_rf.sql
```

**4. Executar els notebooks en ordre**
```
1_exploratori.ipynb → 2_clustering.ipynb → 3_prediccions.ipynb
```

> **Nota:** Les dades en brut i la base de dades DuckDB no són en aquest repositori pel seu volum (>6 GB). Els fitxers exportats de l'anàlisi (CSV amb mètriques i clústers) sí que estan disponibles a la carpeta `csv/`.

---

## 📚 Referències

- Ajuntament de Barcelona. (2025). *Bicing: Dades obertes de disponibilitat d'estacions.* Open Data BCN. https://opendata-ajuntament.barcelona.cat/ (revisat al febrer de 2026)
- Froehlich, J., Neumann, J., & Oliver, N. (2009). Sensing and predicting the pulse of the city through shared bicycling. *IJCAI 2009*, 1420–1426. [PDF lliure](https://www.ijcai.org/Proceedings/09/Papers/238.pdf) (revisat al març de 2026)
- O'Brien, O., Cheshire, J., & Batty, M. (2014). Mining bicycle sharing data for generating insights into sustainable transport systems. *Journal of Transport Geography*, 34, 262–273. https://doi.org/10.1016/j.jtrangeo.2013.06.007 — [PDF lliure](http://www.complexcity.info/files/2014/03/BATTY-JTG-2014.pdf) (revisat al març de 2026)
- Pedregosa, F., et al. (2011). Scikit-learn: Machine learning in Python. *JMLR*, 12, 2825–2830. [PDF lliure](https://jmlr.org/papers/volume12/pedregosa11a/pedregosa11a.pdf) (revisat al març de 2026)
- Raasveldt, M., & Mühleisen, H. (2019). DuckDB: An embeddable analytical database. *SIGMOD 2019*, 1981–1984. https://doi.org/10.1145/3299869.3320212 (revisat al març de 2026)
- Fishman, E., Washington, S., & Haworth, N. (2013). Bike share: A synthesis of the literature. *Transport Reviews*, 33(2), 148–165. https://doi.org/10.1080/01441647.2013.775612 (revisat al març de 2026)

---

## ✍️ Autora

**Vanessa Plaza**  
Itinerari d'Anàlisi de Dades · Cibernàrium / Barcelona Activa · 2026
