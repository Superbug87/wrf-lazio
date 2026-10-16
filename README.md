# WRF sul Lazio

Previsione a 48 ore con **WRF** (modello fisico vero) su tre domini annidati centrati sul Lazio
(41,82 N, 12,72 E): **27 km → 9 km → 3 km**. Il dominio a 3 km (306 km di lato) copre tutta la regione. Parte dai dati aperti di **ECMWF**
(IFS 0,25°; GFS è l'alternativa) e gira ogni giorno sui server gratuiti di GitHub. Alla fine disegna le mappe
(temperatura a 2 m e 850 hPa, vento medio, raffiche, pioggia 1/3/6 h, pressione, umidità, CAPE),
una ogni 6 ore, più una immagine per ogni ora e variabile, e le pubblica nel ramo `risultati`.

Nasce dal progetto gemello **wrf-castelli** (stessa catena, tre domini a 9 → 3 → 1 km sui Castelli Romani): qui cambiano la
geometria dei domini, il passo di calcolo, le stazioni, il mare, le mappe e il radar; compilazione, scarico dei dati, ungrib,
metgrid, real, segmenti e pubblicazione sono gli stessi. Questo repository è **ancora tutto da provare su GitHub**: vedi
«Stato del collaudo».

## Avvertenze
- **Progetto personale e sperimentale, non un servizio ufficiale.** Le previsioni sono prodotte in automatico da un modello
  numerico, senza il controllo di un meteorologo, e possono essere sbagliate, anche di molto. Per pioggia e temporali
  posizione e orario possono sbagliare di chilometri e di ore.
- **Non sostituiscono i bollettini e le allerte ufficiali** (Protezione Civile, Aeronautica Militare, centri funzionali
  regionali). Non usarle per decisioni che riguardano la sicurezza di persone o cose: protezione civile, volo,
  navigazione, lavori o eventi a rischio.
- **Nessuna garanzia.** Sono fornite «così come sono», senza garanzie di esattezza, continuità o disponibilità: il servizio
  può ritardare, fermarsi o dare errori. L'autore non risponde di danni derivanti dall'uso.
- **Nessun legame con i fornitori dei dati.** Il progetto non è collegato a ECMWF, NOAA, NCAR/UCAR, Weather Underground né
  agli altri fornitori elencati sotto e non è da loro approvato o rivisto.

## Che cosa cambia rispetto ai Castelli Romani
| | Castelli Romani | Lazio |
|---|---|---|
| domini | 9 → 3 → 1 km (450, 162, 60 km di lato) | 27 → 9 → 3 km (1296, 540, 306 km di lato) |
| passo di calcolo | 45 s (nidi: 15 s e 5 s) | 144 s (nidi: 48 s e 16 s) |
| convezione | esplicita da 3 km in giù | Kain-Fritsch a 27 e 9 km, esplicita a 3 km |
| mappe | 40 x 40 km, passo ~1 km | 256 x 256 km (40,67-42,97 N, 11,18-14,26 E), passo ~3 km |
| stazioni nel nudging | fino a 40 / 30 / 20 | fino a 50 / 20 / 10 (la chiave Wunderground è la stessa e ha un limite giornaliero) |
| raggio del nudging | 100 / 50 / 25 km | 200 / 100 / 50 km |
| temperatura del mare (MUR) | 1 km, 39-44,5 N 9-16,5 E | un punto ogni 2 km, 35,5-48 N 4-21,5 E |
| radar | un pixel ogni punto della mappa | media dei pixel da 1 km attorno a ogni punto da 3 km |

**Perché 3 km e non 1 km su tutta la regione.** Il Lazio è circa 230 x 210 km: un dominio a 1 km che lo coprisse con i margini (circa 300 x 300 km)
avrebbe circa 90 000 colonne, 25 volte quelle del dominio a 1 km dei Castelli, e il calcolo non starebbe nei tempi gratuiti di GitHub. A 3 km il costo (celle x passi) è
circa tre quarti di quello dei Castelli. Contro: il rilievo è levigato (l'Appennino a 3 km perde le valli strette) e i
temporali sono meno nitidi. Per il dettaglio sui Castelli resta il progetto gemello.

## Prima di cominciare
- Il repository deve essere **pubblico**: i server sono da 4 processori e i minuti sono illimitati.
  In un repository privato i server hanno 2 processori e 2000 minuti al mese: non bastano.
- Facoltativo ma consigliato: la chiave Wunderground, per far entrare le stazioni dentro WRF (vedi sotto).
  Su GitHub: *Settings → Secrets and variables → Actions → New repository secret*, nome `WU_API_KEY`.
- **La prima volta tutto parte da zero**: le cache di GitHub non si condividono tra repository, quindi WRF e WPS vanno
  ricompilati e i dati geografici rifatti anche qui.

## Come si avvia (anche da telefono)
1. App GitHub (o sito) → il repository → **Actions** → **Previsione WRF Lazio** → **Run workflow**.
2. Campi: `pilota` (`ecmwf` di default, oppure `gfs`), `ciclo` (vuoto = l'ultimo completo; per ECMWF solo le 00 e le 12 UTC),
   `ore` (default 48), `ore_segmento` (default 16), `stazioni` (nudging, sì di default), `mare` (temperatura del mare
   MUR, sì di default), `radar` (confronto con il radar e pioggia delle prossime 3 ore, sì di default).
3. **L'avvio automatico è spento** (righe `schedule` commentate in `.github/workflows/wrf.yml`) finché non c'è una prima
   esecuzione completa riuscita. Poi si tolgono i `#`: 09:10 UTC (ciclo ECMWF delle 00 UTC, pubblicato verso le 07:35) e
   20:20 UTC (ciclo delle 12 UTC, verso le 19:35). Gli orari sono sfalsati di mezz'ora rispetto ai Castelli perché le due
   catene usano la stessa chiave Wunderground (30 chiamate al minuto).

Tempi **stimati** (non ancora misurati qui; la compilazione e i dati statici sono quelli dei Castelli, il calcolo no):

| fase | quando | durata |
|---|---|---|
| compilazione di WRF e WPS | solo la prima volta | 40-90 min |
| dati statici (terreno, uso del suolo) | solo la prima volta | 30-60 min (il dominio esterno è 8 volte più esteso: forse di più) |
| scarico ECMWF, ungrib, metgrid, real | ogni giorno | 10-20 min |
| stazioni Wunderground (ricerca e lettura) | ogni giorno | 10-15 min |
| WRF, 3 segmenti da 16 h in fila | ogni giorno | 1-2 h ciascuno |
| mappe e pubblicazione | ogni giorno | 5-10 min |

GitHub ferma ogni job dopo 6 ore, per questo la previsione è divisa in segmenti che ripartono dal *restart*
del precedente. Se i segmenti vanno stretti, abbassa `ore_segmento` (massimo 4 segmenti) o `ore`.
Le uscite del dominio a 3 km pesano circa tre volte quelle dei Castelli (stima: circa 1,5 GB per segmento prima della compressione).

**La compilazione è a tappe** (`wrf/costruisci.sh prepara|wrf|wps|installa`, quattro passi del job `costruzione`):
- mentre WRF compila, il log scrive ogni 5 minuti a che punto è (oggetti compilati, ultimo file, carico, memoria);
- se in 30 minuti non cambia nulla (né file compilati né righe di log) un guardiano stampa quali processi sono rimasti
  appesi, salva la diagnosi (`diagnosi.txt`, tra gli allegati `log-compilazione`) e ferma il job invece di lasciarlo girare
  fino al limite;
- c'è un tempo massimo di 290 minuti per WRF: se scade, il sorgente parziale (con gli oggetti già compilati) va in cache
  e **rilanciando il flusso la compilazione riprende da lì**, senza ricominciare;
- la cache finale (`wrf-install`) si salva solo se tutte e quattro le tappe finiscono; quella parziale (`wrf-src`) si salva
  anche se si interrompe.

## Dove trovo i risultati
- Ramo **`risultati`** del repository: la cartella `ultimo/` e il suo `README.md` con tutte le immagini
  (si legge bene dall'app GitHub). In `archivio/` ci sono gli ultimi 28 cicli (14 giorni).
- Stesso ramo, cartella **`orarie/`**: una immagine per ogni ora e per ogni tipo di mappa (solo tipo, ora del run e ora
  della mappa, senza descrizioni), degli ultimi 2 cicli; `orarie/indice.json` elenca variabili e ore. Il ramo viene
  riscritto con un solo commit a ogni pubblicazione, così la storia non cresce.
- **Sul sito**: la pagina `sito/previsioni-wrf-lazio.html` (un solo file, senza dipendenze) sfoglia le immagini
  orarie: scelta del tipo di mappa, cursore delle ore, tasto play, frecce, scorrimento col dito, salto al giorno.
  Va caricata sul sito (FTP) e legge le immagini direttamente da GitHub (`raw.githubusercontent.com`), che le tiene in
  cache circa 5 minuti: si aggiorna da sola quando esce un nuovo ciclo. Si può anche incorporare con un `<iframe>`.
  **Caricamento automatico (FTP)**: `.github/workflows/sito.yml` + `wrf/carica_sito.sh` caricano la pagina a ogni
  sua modifica. Servono quattro segreti del repository (Settings → Secrets and variables → Actions): `FTP_HOST`,
  `FTP_USER`, `FTP_PASSWORD`, `FTP_CARTELLA` (es. `5archi`). Senza segreti il flusso non fa nulla.
- In *Actions → l'esecuzione → Artifacts*: `mappe` (le immagini) e, se qualcosa va storto, i log.

## Cosa fa e cosa non fa
- WRF è alimentato da un solo modello globale per volta (ECMWF o GFS).
- **Stazioni Wunderground dentro WRF (nudging).** Con la chiave `WU_API_KEY`, prima del calcolo si cercano le
  stazioni nei tre domini (su una griglia di punti: ogni 0,35° nel dominio a 3 km, 0,8° in quello a 9 km, 2° in quello a 27 km),
  se ne scelgono fino a 50 nel dominio a 3 km, 20 in quello a 9 km e 10 in quello a 27 km (le più distanziate tra loro),
  se ne scarica lo storico delle ultime 24 ore, si controllano (valori plausibili, quota dichiarata coerente con il
  terreno del modello entro 400/600/800 m nei tre domini, scarto dalle stazioni vicine riportate alla stessa quota) e si mediano ogni 15 minuti.
  WRF, dall'inizio del ciclo fino all'ultima osservazione, spinge temperatura e umidità verso quei valori
  (raggio di influenza 200/100/50 km nei tre domini, tempo di rilassamento circa mezz'ora); poi prosegue libero
  dallo stato raggiunto. Il **vento delle stazioni non viene usato**: gli anemometri amatoriali sono quasi sempre
  riparati. Senza chiave o senza dati utili WRF gira senza nudging. In questo caso le mappe applicano come prima
  la correzione dopo il calcolo (scala 5 km, 8 x 8 punti di ricerca); con il nudging non si corregge una seconda volta.
  Limiti: i sensori amatoriali sono di qualità diversa (quelli al sole di giorno scaldano) e l'effetto sulle ore
  lontane dall'ultima osservazione è piccolo: il nudging migliora lo stato di partenza, non cancella gli errori del
  modello globale. Assimilare le stazioni con un'analisi vera (WRFDA) sarebbe un lavoro a parte.
  **Limite della chiave**: Wunderground concede circa 1500 chiamate al giorno e 30 al minuto per chiave. Ogni ciclo ne usa
  circa 300, due cicli al giorno circa 600; il progetto dei Castelli usa la stessa chiave. Non lanciare molte
  esecuzioni a mano nello stesso giorno.
- **Temperatura del mare.** ECMWF dà la temperatura del mare a 25 km. Per il mare si scarica l'analisi MUR SST di NASA JPL
  (0,01°, circa 1 km, qui diradata a un punto ogni 0,02°, con 1-2 giorni di ritardo, tenuta costante per le 48 ore) e WRF la usa sui punti d'acqua
  al posto di quella del modello globale. Il riquadro scaricato copre tutto il dominio a 27 km.
  Se il servizio non risponde, WRF gira lo stesso con la temperatura del mare del modello globale.
- **Radar (Protezione Civile).** Due immagini in più, `radar_1_verifica` e `radar_2_prossime_3_ore`, e un CSV nell'archivio.
  *Verifica*: per le ultime ore (fino a 6) la pioggia oraria misurata dal radar nazionale (prodotto SRI, mosaico a 1 km
  ogni 5 minuti, mediata sui 3 km di WRF) accanto a quella di WRF, con la media sull'area delle mappe (256 x 256 km), la quota di area bagnata
  e un indice di accordo di posizione (FSS, soglia 0,5 mm in un'ora, controllato su circa 10 km). *Prossime 3 ore*: il radar spostato lungo il movimento che
  ha adesso, WRF per le stesse ore, e un mix dei due in cui il peso del radar scende da 83% (prima ora) a 17% (terza).
  I pesi sono una scelta di buon senso, **non tarati**. Se il radar non risponde lo script esce e le mappe di WRF non cambiano.
  Cosa dicono i collaudi fatti nel progetto dei Castelli (radar vero, ultimi 4 giorni, 76 casi su riquadri di 300 km in tutta
  Italia, confronto con «la pioggia resta dov'è»): spostare la pioggia **non migliora in media** l'accordo di posizione
  (differenza tra −0,02 e +0,02, indistinguibile da zero). Se però il movimento stimato è rapido (oltre circa 24 km/h) si guadagna
  poco (circa +0,04 su una base di circa 0,25), mentre con movimenti lenti spostare peggiora (circa −0,03). Per questo sotto quella
  velocità la pioggia è lasciata ferma. Un singolo episodio di pioggia organizzata (12 ottobre sul Lazio) andava molto
  meglio (accordo a un'ora 0,68 contro 0,43), ma è un caso favorevole, non la regola. Il radar non prevede la nascita dei
  temporali: dopo 1-2 ore conta soprattutto WRF. Il radar stesso può sbagliare (echi dei monti, schermature, calibrazione).
  Il confronto con WRF vero non è stato ancora visto. Il CSV (`archivio/<ciclo>/radar_verifica.csv`) serve a vedere nel tempo
  se WRF migliora e a tarare i pesi.
- **Raffiche = stima**: massimo orario del vento a 10 m (diagnostica di WRF) × 1,4.
- **CAPE = stima** da parcella di superficie. Controllata contro MetPy su 5 profili: scarti sotto l'1%.
- ECMWF (come GFS) ha punti ogni 25 km: i 3 km vengono da WRF e dall'orografia, non dal dato di partenza.
- I dati ECMWF sono quelli *open data* (licenza CC-BY 4.0): per ogni ora si scaricano solo i campi che servono
  (circa 40 MB invece di 140), si ritagliano su Mediterraneo e Europa (30-54 N, 0-32 E, più del dominio a 27 km, che va da 35,7 a 47,7 N
  e da 4,1 a 21,3 E) e si riscrivono con compressione semplice perché
  `ungrib` non legge la compressione CCSDS di ECMWF. Gli strati di suolo, numerati da 1 a 4, diventano
  profondità in cm (0-7, 7-28, 28-100, 100-289) e l'orografia dell'ora 0 è copiata in tutte le ore.
- Le mappe mostrano una stella per Velletri (il valore scritto in basso a destra di ogni riquadro) e le città principali.
- Il bordo del dominio a 3 km è a 25 km o più dalle mappe, ma le celle vicino al bordo del nido sono comunque influenzate
  dal dominio a 9 km: non fidarsi troppo dei dettagli ai margini della mappa.
- Non sostituisce le previsioni ufficiali.

## Fonti dei dati e licenze
| cosa | fonte | condizioni |
|---|---|---|
| Dati di partenza e al contorno (default) | [ECMWF IFS open data](https://www.ecmwf.int/en/forecasts/datasets/open-data), 0,25°, [doi:10.21957/open-data](https://doi.org/10.21957/open-data) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) e condizioni d'uso ECMWF. **Dati modificati**: ritagliati, ricodificati e usati come condizioni iniziali e al contorno di WRF. ECMWF non garantisce i dati e non risponde di errori o omissioni |
| Dati di partenza alternativi | [GFS di NOAA/NCEP](https://www.nco.ncep.noaa.gov/pmb/products/gfs/) | dati pubblici del governo statunitense; NOAA non approva questo lavoro |
| Temperatura del mare (facoltativa) | [MUR SST](https://podaac.jpl.nasa.gov/dataset/MUR-JPL-L4-GLOB-v4.1) di NASA JPL (0,01°, circa 1 km, diradata a 0,02°), via [NOAA CoastWatch ERDDAP](https://coastwatch.pfeg.noaa.gov/erddap/), citazione: JPL MUR MEaSUREs Project, 2015, [doi:10.5067/GHGMR-4FJ04](https://doi.org/10.5067/GHGMR-4FJ04) | dati NASA ad accesso libero, si chiede di citare la fonte |
| Radar (facoltativo) | [Radar-DPC](https://radar.protezionecivile.it), Dipartimento della Protezione Civile, mosaico nazionale SRI (intensità di pioggia) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/): va citata la fonte e le immagini ricavate (`radar_*`) hanno la stessa licenza. Dati usati solo per le due immagini radar, non ripubblicati in forma grezza; il CSV contiene solo medie sull'area |
| Modello | [WRF e WPS](https://www2.mmm.ucar.edu/wrf/users/public.html) di NCAR/UCAR | software pubblico, non incluso qui: lo compila il flusso di lavoro dai sorgenti ufficiali |
| Terreno e uso del suolo | dati geografici [WPS_GEOG](https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html) di NCAR/UCAR (tra cui GMTED2010 di USGS/NGA e MODIS) | scaricati durante il calcolo, non inclusi qui; vale la licenza di ciascun dato |
| Stazioni meteo | rete di stazioni amatoriali di [Weather Underground](https://www.wunderground.com/) (The Weather Company), tramite la chiave personale del proprietario | restano soggette ai termini d'uso di Weather Underground, da rispettare (la chiave è personale). I dati **non vengono ripubblicati**: si scaricano durante il calcolo, entrano in WRF e non finiscono nei risultati; i file temporanei che passano da un segmento all'altro sono cifrati; i log non riportano codici o posizioni delle stazioni; le mappe mostrano solo l'uscita del modello |
| Solo per `previsioni_lazio.py` usato da solo | [Open-Meteo](https://open-meteo.com/) ([CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); l'API gratuita è per uso non commerciale) e quote dal modello digitale del terreno Copernicus DEM («contiene dati Copernicus modificati») | non usati dalla catena WRF |

Librerie principali: ecCodes (Apache 2.0), JasPer, NumPy, SciPy, Matplotlib, netCDF4, requests, pyproj, OpenCV, tifffile: ciascuna con la sua licenza.
I nomi delle città e le posizioni sulle mappe sono scritti a mano nello script, non vengono da OpenStreetMap o altri archivi.
Le condizioni dei fornitori possono cambiare: prima di usare il progetto in modo diverso da quello personale
(per esempio per un servizio pubblico o commerciale) vanno ricontrollate.

## Stato del collaudo
**Nessuna esecuzione di WRF su GitHub è ancora stata fatta in questo repository.** Il codice è quello del progetto dei Castelli Romani
(dove compilazione, geogrid, segmenti e pubblicazione sono stati provati il 16 ottobre 2026, con le correzioni già incluse qui)
adattato al Lazio.

Provato qui (in un ambiente senza compilatore Fortran): geometria dei tre domini (annidamento centrato, margini, mappe e
tutta la regione dentro il dominio a 3 km), namelist (letti da f90nml: passo di 144 s che divide segmenti, bordi e uscite
orarie), file delle stazioni (inventate) riletti con le istruzioni di lettura di WRF, file `SST` riletto con `rd_intermediate` di WPS,
mappe e immagini orarie a partire da file `wrfout` inventati con la struttura di WRF (griglia 103 x 103 a 3 km),
mappe con dati inventati di `previsioni_lazio.py`, radar vero (scarico, media sui 3 km e le due immagini; il confronto con una pioggia vera
non è stato visto), pubblicazione nel ramo `risultati` su un repository finto, sintassi del flusso (actionlint in CI), degli script (shellcheck) e della pagina del sito.
Queste prove girano da sole a ogni modifica del codice: `wrf/prove.sh`, lanciato dal flusso **Prova automatica**
(`.github/workflows/prova.yml`, pochi minuti, non tocca le cache di WRF). Si può lanciare anche a mano: `bash wrf/prove.sh`
(con `PROVA_RADAR=1` prova anche il radar vero).

**Non provato in questo repository:** compilazione di WRF e WPS, download dei dati geografici NCAR, geogrid sul nuovo dominio
(1296 km a 27 km: più grande di quello dei Castelli), metgrid con il riquadro MUR esteso, real.exe e wrf.exe a 144 s
(stabilità numerica e tempi di calcolo da misurare), nudging con 80 stazioni e raggi 200/100/50 km, uscite da circa 1,5 GB
per segmento, pagina del sito con dati veri. Le scelte fisiche (Kain-Fritsch a 9 km, radiazione ogni 30/10/5 minuti, nessun
`slope_rad`) sono ragionevoli ma non tarate. Il primo avvio potrebbe richiedere qualche correzione: i log escono come artifact.

## File
- `.github/workflows/wrf.yml` — il flusso (a mano finché non si attiva l'avvio automatico)
- `wrf/dominio.py` — geometria dei tre domini · `wrf/config.py` — namelist di WPS e WRF
- `wrf/dipendenze.sh`, `costruisci.sh` (a tappe, con avanzamento e guardiano), `statico.sh`, `esegui.sh`, `pubblica.sh`
- `wrf/scarica_ecmwf.py` + `wrf/Vtable.ECMWF_OD` — dati ECMWF · `wrf/scarica_gfs.py` — alternativa GFS
- `wrf/postprocess.py` — da `wrfout` alle mappe · `wrf/orarie.py` — una immagine per ora e variabile + `indice.json`
- `sito/previsioni-wrf-lazio.html` — pagina per sfogliare le immagini orarie (da caricare sul sito)
- `wrf/stazioni_wrf.py` — stazioni Wunderground nel formato di WRF per il nudging
- `wrf/scarica_sst.py` — temperatura del mare MUR nel formato intermedio di WPS (campo `SST`)
- `wrf/radar.py` — scarico del radar Radar-DPC, posizione sulla mappa, movimento · `wrf/pioggia_radar.py` — verifica e
  pioggia delle prossime 3 ore
- `wrf/prova_sintetica.py` — file `wrfout` (e `geo_em`) inventati per collaudare senza WRF · `wrf/prove.sh` — tutte le prove
  · `wrf/leggi_obs.f90` — rilegge i file delle stazioni con i formati di WRF · `wrf/prova_costruzione.sh` — prova
  avanzamento, tempo massimo e guardiano della compilazione con comandi inventati
- `.github/workflows/prova.yml` — prova automatica a ogni modifica · `.github/workflows/sito.yml` — carica la pagina sul sito
- `previsioni_lazio.py` — mappe e correzione con le stazioni (usato da `postprocess.py`)
