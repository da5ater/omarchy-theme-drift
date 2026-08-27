# Theme Drift

Theme Drift is a native Omarchy Shell plugin for people who want their desktop to feel fresh without losing control.

## Install

```bash
omarchy plugin add https://github.com/da5ater/omarchy-theme-drift.git --enable
```

## Requirements and behavior

- Omarchy Quattro and its standard `omarchy`, `jq`, `curl`, `perl`, `git`, and `flock` commands.
- Network access when refreshing the community catalog or installing a catalog-only theme.
- Theme Drift reads the curated catalog from `https://omarchy.org/themes/` and caches its metadata for six hours.
- Community theme repositories are third-party code and assets. Theme Drift delegates installation and activation to Omarchy's supported `omarchy theme install` and `omarchy theme set` commands.
- Theme Drift writes only its own state under `~/.local/state/theme-drift/`. It does not overwrite Omarchy or Hyprland configuration files.
- State is kept in a verified private directory. Configuration updates use secure same-directory temporary files and atomic replacement; process serialization uses a directory-descriptor lock in a verified private runtime directory.

## What it does

- Selects one different installed, eligible theme per machine boot.
- Uses an exhaustive shuffled cycle: every installed, eligible theme appears once before any theme repeats.
- Merges built-in, installed community, and catalog-only themes in a wallpaper-led gallery.
- Offers one catalog-only theme in a **TRY NEW ONE ✨** confirmation popup after boot, including a large wallpaper preview and the exact repository source.
- Installs catalog-only themes only after an explicit **Yes** in that popup or an explicit Apply/Permanent action in the gallery.
- Keeps a dedicated Favorites collection.
- Hides disliked themes from future rotation.
- Lets you apply any theme immediately or keep one permanently.
- Preserves favorites and hidden themes when rotation is paused.

The official catalog is refreshed every six hours. New catalog entries appear in Discover automatically, and themes installed by any tool join the unfinished rotation cycle automatically. Catalog-only themes use remote previews but are never installed unattended. The confirmation UI shows the exact GitHub repository and passes that approved URL directly to Omarchy's installer; automatic boot rotation never consumes repository URLs from the mutable catalog.

The first installation records the current boot without changing the active theme. Automatic rotation begins on the next boot.

## Keyboard

| Key | Action |
| --- | --- |
| `Left` / `Right` | Browse themes |
| `Enter` | Apply selected theme |
| `F` | Favorite or unfavorite |
| `H` | Hide or restore |
| `P` | Make selected theme permanent |
| `R` | Resume once-per-boot rotation |
| `1`, `2`, `3` | Discover, Favorites, Hidden |
| `Esc` | Close |

State is stored in `~/.local/state/theme-drift/config.json`. The plugin only calls Omarchy's public `omarchy theme` commands and never edits stock Omarchy files.

Approved catalog-only selections clone their displayed public GitHub repository into `~/.config/omarchy/themes/` through `omarchy theme install`. Installed themes remain available after removing Theme Drift.

## Remove

```bash
omarchy plugin remove io.github.da5ater.theme-drift --yes
```

The removal command deletes the plugin but leaves its small preference file and any themes Omarchy installed. To remove Theme Drift's preferences as well:

```bash
rm ~/.local/state/theme-drift/config.json ~/.local/state/theme-drift/catalog.tsv
```
