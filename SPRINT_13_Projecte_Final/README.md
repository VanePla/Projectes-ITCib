# 🚲 Bicing Barcelona — Análisis de disponibilidad, patrones de uso y predicción del estado de las estaciones

**Proyecto final · Sprint 13 · Itinerario de Análisis de Datos**  
Cibernàrium / Barcelona Activa · 2026

---

## 📌 Descripción

Análisis del servicio de bicicletas compartidas Bicing de Barcelona a partir de **291 millones de mediciones** recogidas entre enero de 2020 y septiembre de 2025 en las 548 estaciones de la red (Open Data Barcelona).

El proyecto responde tres preguntas clave:

1. **¿Qué tan grave es el problema de disponibilidad?** — Cuantificar el porcentaje de tiempo que las estaciones están vacías (sin bicicletas) o llenas (sin anclajes libres).
2. **¿Cuándo y dónde ocurre?** — Identificar patrones temporales (hora, día, mes) y geográficos (distrito, tipología de estación).
3. **¿Se puede predecir?** — Evaluar modelos de machine learning para anticipar el estado de las estaciones con 30 minutos de antelación.

---

## 📊 Resultados principales

| Métrica | Valor |
|---|---|
| Franjas de 30 min con estación vacía o llena | **15–25%** |
| Pico de estaciones vacías (hora) | **8–10h y 17–19h** |
| Distrito más problemático | **Sarrià-Sant Gervasi (>30% del tiempo vacías)** |
| Clústeres de estaciones identificados | **5 perfiles (sobre 517 estaciones)** |
| Balanced Accuracy Random Forest | **83,2%** |

---

## 🗂️ Estructura del repositorio

```
SPRINT_13_Projecte_Final/
│
├── 0_0_dades_bicing_opendata.ipynb      # Descarga y exploración inicial de Open Data BCN
├── 0_1_dades_headers.py                 # Análisis de encabezados de los CSVs descargados
├── 0_2_dades_headers_concat.py          # Concatenación de CSVs por tipo de encabezado
│
├── bicicletes_bicing.txt                # Instrucciones para crear la base de datos DuckDB
│                                        # desde cero (comandos CMD paso a paso)
├── bicicletes_creacio_1.sql             # SQL DuckDB: pipeline de datos (tablas origen,
│                                        # limpieza, enriquecimiento, agregaciones,
│                                        # indicadores de clustering y baselines)
│
├── 1_exploratori.ipynb                  # Análisis exploratorio: mapa de estaciones,
│                                        # evolución de viajes, patrones hora/día/mes,
│                                        # distribución del problema de disponibilidad
├── 1_exploratorio_es.ipynb              # notebook en castellano
│
├── 2_clustering.ipynb                   # Clustering K-Means (k=5): preparación de
│                                        # features, normalización, selección de k,
│                                        # interpretación y mapa de clústeres
├── 2_clustering_es.ipynb                # notebook en castellano
│
├── bicicletes_creacio_2_rf.sql          # SQL DuckDB: tablas de features para Random
│                                        # Forest con arquitectura LAG(2) anti-leakage
│                                        # (rf_nab_perfil, rf_features_train, rf_features_test)
│
├── 3_prediccions.ipynb                  # Predicción del estado de las estaciones:
│                                        # Random Forest vs. baselines (HA y SN7),
│                                        # métricas por clase, importancia de variables
├── 3_predicciones_es.ipynb              # notebook en castellano
│
├── bicing.pdf                           # Informe escrito del proyecto (catalan)
├── bicing_es.pdf                        # Informe escrito del proyecto (castellano)
├── Proyecto_bicing.pptx                 # Presentación para la exposición (catalan)
├── Proyecto_bicing_esp.pptx             # Presentación para la exposición (castellano)
└── README.md                            # Este archivo
```

---

## 🔬 Metodología

### Datos
- **Fuente:** [Open Data Barcelona — Servicio Bicing](https://opendata-ajuntament.barcelona.cat/data/ca/dataset)
- **Período:** Enero 2020 – Septiembre 2025
- **Volumen:** 291 millones de mediciones (~5 minutos de frecuencia)
- **Variables:** bicicletas disponibles, anclajes libres, capacidad, timestamp, estado operativo
- **Enriquecimiento:** coordenadas, distrito, hora local (Europe/Madrid), día de la semana, estación del año

### Pipeline de datos (DuckDB)

Los datos se procesan en seis capas:

| Capa | Descripción |
|---|---|
| **Origen** | CSVs descargados de Open Data BCN, agrupados por tipo de encabezado |
| **Limpieza** | Eliminación de duplicados, conversión de tipos, filtrado de estaciones no operativas |
| **Enriquecimiento** | Añade hora local, distrito, día de semana, estación del año |
| **Agregaciones** | Estimación de viajes (caídas en `num_bikes_available`), franjas de 30 min |
| **Clustering** | 28 variables operativas por estación (NAB, variabilidad, capacidad, ratios) |
| **Predicción** | Features con LAG(2) para Random Forest sin data leakage |

> Los viajes se estiman a partir de las caídas en el número de bicicletas disponibles (`delta_bicis < 0`).  
> El período 2020–2021 se excluye de los análisis por las distorsiones de la pandemia.

### Herramientas

| Herramienta | Uso |
|---|---|
| **DuckDB** | Almacenamiento y procesamiento de los 291M de registros |
| **Python / Pandas** | Análisis y transformación de datos |
| **Scikit-learn** | Clustering K-Means y Random Forest |
| **Folium** | Mapas interactivos de estaciones y clústeres |
| **Matplotlib / Seaborn** | Visualizaciones estáticas |

---

## 📈 Análisis realizados

### 1. Análisis exploratorio (`1_exploratori.ipynb`)
- Mapa interactivo de las 548 estaciones con volumen de viajes
- Evolución mensual de viajes 2020–2025 con anotación del impacto COVID
- Mapa de calor hora × día de la semana
- Estacionalidad mensual por año
- Distribución del problema (vacías/llenas) por hora, día, distrito y estación

### 2. Clustering K-Means (`2_clustering.ipynb`)

28 variables derivadas por estación: perfil NAB horario (laborables y festivos), capacidad media, variabilidad del NAB, ratios de saturación. Normalización con StandardScaler. Selección de k=5 con método del codo + coeficiente de Silhouette (k evaluado de 2 a 12).

| Clúster | Nombre | N | % Vacía | % Llena | NAB global |
|---|---|---|---|---|---|
| C0 | Periférico Bajo Uso | 132 | 20,6% | 0,4% | 0,22 |
| C1 | Central Alta Ocupación | 42 | 3,9% | 13,7% | 0,59 |
| C2 | Origen Commuter Mañana | 162 | 12,3% | 2,4% | 0,37 |
| C3 | Uso Mixto Equilibrado | 122 | 2,3% | 3,7% | 0,49 |
| C4 | Residencial Entrada Tarde | 59 | 15,6% | 5,4% | 0,36 |

*31 estaciones excluidas por datos insuficientes (>50% de franjas sin mediciones válidas). Total analizado: 517 estaciones.*

### 3. Predicción del estado de las estaciones (`3_prediccions.ipynb`)

Arquitectura **LAG(2)**: solo se usan variables disponibles al menos 60 minutos antes de la predicción, eliminando el data leakage. Entrenamiento: 2022–2024. Test: enero–septiembre 2025.

| Modelo | Balanced Accuracy | Macro F1 |
|---|---|---|
| Historical Average | 45,4% | 47,5% |
| Seasonal Naive 7d | 52,5% | 52,8% |
| **Random Forest** | **83,2%** | **64,6%** |

**Métricas detalladas del Random Forest:**

| Clase | Precision | Recall | F1 |
|---|---|---|---|
| Vacía | 53,1% | 87,8% | 66,2% |
| Normal | 96,1% | 74,9% | 84,2% |
| Llena | 29,1% | 86,9% | 43,6% |

---

## ⚙️ Cómo reproducir el proyecto

### Requisitos
- Python 3.10+
- DuckDB v1.5.0
- Paquetes: `pandas`, `scikit-learn`, `folium`, `matplotlib`, `seaborn`, `jupyter`

### Pasos

**1. Descargar los datos**  
Ejecutar `0_0_dades_bicing_opendata.ipynb` o descargar manualmente desde [Open Data BCN - estado estaciones](https://opendata-ajuntament.barcelona.cat/data/ca/dataset/estat-estacions-bicing). Los archivos `.7z` mensuales van a la carpeta `data_raw/`. Descargar tambien desde [Open Data BCN - infromacion estaciones](https://opendata-ajuntament.barcelona.cat/data/ca/dataset/informacio-estacions-bicing) y [Open Data BCN - geolocalizacion](https://opendata-ajuntament.barcelona.cat/data/ca/dataset/20170706-districtes-barris/resource/cd800462-f326-429f-a67a-c69b7fc4c50a)

**2. Preprocesar los CSVs**
```bash
python 0_1_dades_headers.py
python 0_2_dades_headers_concat.py
```

**3. Crear la base de datos DuckDB**  
Seguir las instrucciones de `bicicletes_bicing.txt`:
```bash
duckdb bicicletes.duckdb
.read bicicletes_creacio_1.sql
.read bicicletes_creacio_2_rf.sql
```

**4. Ejecutar los notebooks en orden**
```
1_exploratori.ipynb → 2_clustering.ipynb → 3_prediccions.ipynb
```

> **Nota:** Los datos crudos y la base de datos DuckDB no están en este repositorio por su tamaño (>6 GB). Los archivos exportados del análisis (CSV con métricas y clústeres) sí están disponibles en la carpeta `csv/`.

---

## 📚 Referencias

- Ajuntament de Barcelona. (2025). *Bicing: Datos abiertos de disponibilidad de estaciones.* Open Data BCN. https://opendata-ajuntament.barcelona.cat/
- Froehlich, J., Neumann, J., & Oliver, N. (2009). Sensing and predicting the pulse of the city through shared bicycling. *IJCAI 2009*, 1420–1426. [PDF libre](https://www.ijcai.org/Proceedings/09/Papers/238.pdf)
- O'Brien, O., Cheshire, J., & Batty, M. (2014). Mining bicycle sharing data for generating insights into sustainable transport systems. *Journal of Transport Geography*, 34, 262–273. https://doi.org/10.1016/j.jtrangeo.2013.06.007 — [PDF libre](http://www.complexcity.info/files/2014/03/BATTY-JTG-2014.pdf)
- Pedregosa, F., et al. (2011). Scikit-learn: Machine learning in Python. *JMLR*, 12, 2825–2830. [PDF libre](https://jmlr.org/papers/volume12/pedregosa11a/pedregosa11a.pdf)
- Raasveldt, M., & Mühleisen, H. (2019). DuckDB: An embeddable analytical database. *SIGMOD 2019*, 1981–1984. https://doi.org/10.1145/3299869.3320212
- Fishman, E., Washington, S., & Haworth, N. (2013). Bike share: A synthesis of the literature. *Transport Reviews*, 33(2), 148–165. https://doi.org/10.1080/01441647.2013.775612

---

## ✍️ Autora

**Vanessa Plaza**  
Itinerario de Análisis de Datos · Cibernàrium / Barcelona Activa · 2026
