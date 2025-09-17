# Multilingual Thematic Analysis in R

This project translates multilingual comments, validates input, preprocesses text, and applies clustering to uncover themes.

## Workflow
1. `00_validate_responses.R` – Flags and removes problematic rows
2. `01_load_translate.R` – Translates clean comments to English
3. `02_preprocess_nlp.R` – Cleans and tokenizes text
4. `03_clustering.R` – Applies k-means clustering
5. `04_visualization.R` – Visualizes clusters

## Notes
- Translation uses free MyMemory API via polyglotr
- Input must be UTF-8 encoded TSV from Qualtrics