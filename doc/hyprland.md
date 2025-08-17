Ecco una spiegazione step-by-step di ogni categoria nella tua configurazione Hyprland:

## 📂 **IMPORT SUBMAP CONFIGURATION**
```bash
source = ~/.config/hypr/rule.conf
source = ~/.config/hypr/monitor.conf  
source = ~/.config/hypr/bind.conf
```
**Funzione:** Importa configurazioni esterne per mantenere il file principale pulito
- `rule.conf` - Regole per finestre specifiche (posizione, workspace, etc.)
- `monitor.conf` - Configurazione multi-monitor (risoluzione, posizione)
- `bind.conf` - Keybinding e shortcut

## 🌍 **ENV VARIABLES**
```bash
env = XCURSOR_SIZE,24
env = XCURSOR_THEME,Adwaita
```
**Funzione:** Variabili d'ambiente per compatibilità Wayland
- Dimensione e tema del cursore
- Garantisce rendering corretto delle applicazioni

## ⚙️ **GENERAL**
**Funzione:** Configurazioni base del window manager
- `resize_on_border` - Ridimensiona finestre trascinando i bordi
- `border_size` + colori - Aspetto e spessore bordi finestre
- `gaps_in/out` - Spazi tra finestre e bordi schermo
- `layout = dwindle` - Algoritmo di tiling (divisione automatica)
- `allow_tearing` - Per gaming (riduce input lag)

## ⌨️ **INPUT**
**Funzione:** Gestione keyboard, mouse e touchpad
- `kb_layout = us` - Layout tastiera
- `kb_options = caps:escape` - CapsLock diventa Escape
- `follow_mouse` - Focus segue il mouse
- `touchpad{}` - Configurazioni touchpad (scroll naturale, tap-to-click)
- `sensitivity` - Sensibilità mouse

## 👆 **GESTURES**
**Funzione:** Gesture touchpad per navigazione
- `workspace_swipe` - Swipe con 3 dita cambia workspace
- `workspace_swipe_distance` - Distanza necessaria per trigger
- `workspace_swipe_create_new` - Crea nuovo workspace se necessario

## 👥 **GROUP**
**Funzione:** Raggruppamento finestre in tab
- `col.border_*` - Colori bordi per gruppi attivi/inattivi/locked
- `groupbar{}` - Barra tab per navigare tra finestre raggruppate
- Permette di avere più finestre "stacked" in una posizione

## 🔲 **DWINDLE LAYOUT**
**Funzione:** Configurazione layout tiling principale
- `pseudotile` - Finestre floating mantengono aspect ratio
- `preserve_split` - Mantiene direzione split quando chiudi finestre
- `smart_resizing` - Ridimensionamento intelligente
- `special_scale_factor` - Scala per workspace speciali

## 👑 **MASTER LAYOUT**
**Funzione:** Layout alternativo master-stack
- `mfact = 0.55` - Finestra master occupa 55% dello spazio
- `new_on_top` - Nuove finestre vanno in cima allo stack
- `orientation` - Master a sinistra/destra/top

## 🔧 **MISC**
**Funzione:** Impostazioni avanzate e comportamenti
- `disable_hyprland_logo` - Rimuove logo all'avvio
- `enable_swallow` - Terminali "ingoiano" programmi GUI
- `swallow_regex` - Pattern per terminali che supportano swallowing
- `mouse_move_enables_dpms` - Movimento mouse riattiva schermo
- `background_color` - Colore sfondo quando nessuna finestra

## 🎨 **DECORATION**
**Funzione:** Aspetto visivo finestre
- `active/inactive_opacity` - Trasparenza finestre attive/inattive
- `rounding` - Angoli arrotondati
- `blur{}` - Effetto blur dietro finestre trasparenti
    - `size/passes` - Intensità blur
    - `noise/contrast/brightness` - Fine-tuning effetto
    - `popups/special` - Blur anche su popup e workspace speciali
- `dim_*` - Oscuramento finestre inattive

## 🎬 **ANIMATIONS**
**Funzione:** Transizioni e effetti movimento
- `bezier` - Curve di animazione personalizzate
- `animation = tipo, durata, curve, effetto`
    - `windowsIn/Out` - Apertura/chiusura finestre
    - `workspaces` - Cambio workspace
    - `fade` - Dissolvenze
    - `popin X%` - Zoom da/a X% dimensione
    - `slidefade` - Scorrimento + dissolvenza

## 🚀 **AUTOSTART**
**Funzione:** Programmi avviati automaticamente
- `waybar` - Barra di stato
- `hyprpaper` - Gestore wallpaper
- `polkit-gnome` - Autenticazione grafica
- `dbus-update` - Variabili ambiente
- `wl-paste + cliphist` - Clipboard manager

**In sintesi:** Ogni sezione controlla un aspetto specifico del window manager, dalla gestione finestre agli effetti visivi, permettendo un controllo granulare dell'esperienza desktop.