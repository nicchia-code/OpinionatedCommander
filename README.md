# OpinionatedCommander

> Sistema minimalista, prescrittivo e privo di intelligenza artificiale per la costruzione di mazzi Magic: The Gathering Commander solidi, basato sul framework di [BASE.md](BASE.md), sinergie EDHREC e compilazione WebAssembly per GitHub Pages.

---

## Filosofia & Regole di Costruzione (BASE.md)

1. **Base 36/10/10/8/3**: 36 Terre, 10 Ramp, 10 Card Advantage, 8 Spot Removal, 3 Board Wipe, 3 Protezioni, 3 Recursion, 2 Tutor, 4 Wincon, 20 Engine/Sinergia.
2. **Single Slot Rule**: Ogni carta occupa un solo slot funzionale primario (nessun doppio conteggio).
3. **Infrastruttura Prioritaria**: Le prime 75–80 carte garantiscono funzionamento e mana, le ultime 20–25 massimizzano il tema.
4. **Guardrail di Curva**: Mana Value medio non-terra $\le 3.5$ (casual) o $\le 3.0$ (optimized); massimo 8–10 carte con MV $\ge 5$.
5. **Rimozione Rapida & Definitiva**: Almeno 4 spot removal con MV $\le 2$, almeno 50% instant speed, e almeno 2 risposte definitive non-destroy (exilio/sacrificio/-X/-X).

---

## Funzionalità dell'App

- **Split-Screen Workspace**:
  - **Sinistra**: Board a 10 bucket con contatori rigidi, curva di mana e pips cromatici.
  - **Destra**: Explorer con sinergie e percentuali di inclusione da EDHREC (CORS nativo) e ricerca libera Scryfall.
- **Auto-Fill Terre Base**: Calcolo proporzionale dei pips colorati per bilanciare le terre mancanti con 1 click.
- **Real-Time Guardrail Auditor**: Checklist istantanea di conformità rispetto ai target dell'archetipo selezionato (*Midrange*, *Aggro*, *Control*, *Combo*, *Group Hug*, *Stax*).
- **Import/Export Formato MTG**: Compatibilità con Archidekt, Moxfield e clipboard testuale.
- **Zero AI & 100% Client-Side**: Euristiche deterministiche e database staple offline; nessun server backend necessario.

---

## Esecuzione e Sviluppo Locale

### Prerequisiti
- Flutter SDK 3.22+ (con supporto WebAssembly).
- Google Chrome o browser moderno compatibile con WASM GC.

### Avvio in sviluppo
```bash
flutter run -d chrome
```

### Compilazione WebAssembly (WASM)
```bash
flutter build web --wasm
```

Per testare localmente la build WASM:
```bash
python3 -m http.server 8088 --directory build/web
```
Quindi apri `http://localhost:8088/`.

---

## Deploy su GitHub Pages

Il repository include un workflow GitHub Actions in `.github/workflows/deploy.yml`:
1. Crea un repository su GitHub e collega il remote:
   ```bash
   git remote add origin https://github.com/<tuo-utente>/OpinionatedCommander.git
   git branch -M main
   git push -u origin main
   ```
2. Nelle impostazioni del repository su GitHub (**Settings** > **Pages**):
   - Seleziona **Source**: **GitHub Actions**.
3. Il workflow compilerà automaticamente in WASM e pubblicherà il sito su `https://<tuo-utente>.github.io/OpinionatedCommander/`.
