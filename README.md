# Multilingual Thematic Analysis in R

A modular R pipeline for translating, cleaning, and clustering multilingual survey comments.

---

## Overview

This project provides a workflow for thematic analysis of multilingual text data. It includes:

- Validation of raw input  
- Translation using the polyglotr package  
- Text preprocessing  
- Clustering with PCA and k-means  
- Visualization of thematic patterns

---

## Features

- Filters missing, short, or corrupted responses  
- Translates comments to English via MyMemory API  
- Cleans and tokenizes text  
- Builds a document-term matrix (DTM)  
- Applies PCA and k-means clustering  
- Visualizes clusters with ggplot2

---

## Usage

### Step 1: Prepare your data

Export your survey as a UTF-8 encoded `.tsv` file with line breaks preserved and choice text.

Save it as:

```bash
data/comments.tsv
```

### Step 2: Run the pipeline

```r
source("scripts/00_validate_responses.R")
source("scripts/01_load_translate.R")
source("scripts/02_preprocess_nlp.R")
source("scripts/03_clustering.R")
source("scripts/04_visualization.R")
```

---

## Example Output

- `translated_comments.csv`: Translated comments  
- `clusters.csv`: Cluster labels  
- Cluster plot: Visual representation of themes

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/multilingual_analysis.git
```

### 2. Install required R packages

```r
install.packages(c(
  "tidyverse", "polyglotr", "text2vec", "tm",
  "cluster", "factoextra", "ggplot2"
))
```

### 3. Open the project

Open `multilingual_analysis.Rproj` in RStudio.

---

## Citation

If you use this project, please cite:

Salvatore. 2025. *Multilingual Thematic Analysis in R*. GitHub.  
https://github.com/yourusername/multilingual_analysis

```bibtex
@misc{salvatore2025multilingual,
  author       = {Salvatore},
  title        = {Multilingual Thematic Analysis in R},
  year         = {2025},
  howpublished = {https://github.com/yourusername/multilingual_analysis},
  note         = {Accessed: YYYY-MM-DD}
}
```

---

## License

MIT License. See `LICENSE` file for details.
