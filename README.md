# FoodRecipe App (CookEasy)

Flutter app for browsing multi-cuisine recipes with EN/TH localization.
Includes category and country discovery, favorites, completed history, and
an in-recipe cooking timer with alerts.

## Features

- Home with hero search, random countries, categories, popular picks, favorites,
  and completed recipes.
- Country list (cuisines) and category list with localized labels.
- Recipe list with search, sorting, and tags for country + category.
- Recipe details with ingredient/step checklist, finish flow, and cooking timer.
- Favorites and completed history stored locally (SQLite).
- Local notifications, sound, and vibration on timer completion.

## Project Structure

- `lib/` app source (screens, services, models, theme, localization).
- `assets/` data, images, and translations.
- `assets/data/country/` per-cuisine recipe JSON files.
- `assets/data/cuisines.json` list of cuisines shown in UI.
- `assets/data/categories.json` category definitions (ids + translations).

## Data & Localization

- EN/TH strings: `assets/lang/en.json`, `assets/lang/th.json`.
- Category/cuisine names map to IDs for filtering and tags.
- Recipe categories should use category IDs from `assets/data/categories.json`.

## Running

```bash
flutter pub get
flutter run
```

## Notes

- Images for cuisines should live in `assets/images/cuisines/{id}/`.
- If adding a new cuisine, add its entry in `assets/data/cuisines.json` and
  a corresponding recipe file in `assets/data/country/`.
