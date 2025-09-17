# Multilingual Thematic Analysis in R

A modular R pipeline for translating, cleaning, and clustering multilingual survey comments. Designed for researchers and analysts working with open-ended responses across languages.

## Overview

This project provides a complete workflow for thematic analysis of multilingual text data. It includes validation of raw input, free translation using the polyglotr package, natural language preprocessing, unsupervised clustering, and visualization of thematic patterns.

## Features

- Validates and excludes problematic responses (missing, short, or corrupted)
- Translates multilingual comments to English using the free MyMemory API
- Cleans and tokenizes text for NLP analysis
- Builds a document-term matrix (DTM)
- Applies PCA and k-means clustering
- Visualizes thematic clusters

## Project Structure

multilingual_thematic_analysis/
├── data/
│   └── comments.tsv
├── scripts/
│   ├── 00_validate_responses.R
│   ├── 01_load_translate.R
│   ├── 02_preprocess_nlp.R
│   ├── 03_clustering.R
│   └── 04_visualization.R
├── output/
│   ├── flagged_responses.csv
│   ├── clean_comments.csv
│   ├── translated_comments.csv
│   ├── dtm.rds
│   └── clusters.csv
├── multilingual_analysis.Rproj
└── README.md

## Installation

1. Clone the repository

   git clone https://github.com/yourusername/multilingual_analysis.git

2. Install required R packages

   install.packages(c(
     "tidyverse", "polyglotr", "text2vec", "tm",
     "cluster", "factoextra", "ggplot2"
   ))

3. Open the project in RStudio

   Open multilingual_analysis.Rproj

## Usage

Step 1: Prepare your TSV file

Export your Qualtrics survey as a TSV file with:
- UTF-8 encoding
- Line breaks preserved
- Choice text (not recoded values)

Save it as data/comments.tsv

Step 2: Run the pipeline

source("scripts/00_validate_responses.R")   # Cleans and filters raw input  
source("scripts/01_load_translate.R")       # Translates comments to English  
source("scripts/02_preprocess_nlp.R")       # Prepares text for clustering  
source("scripts/03_clustering.R")           # Applies k-means clustering  
source("scripts/04_visualization.R")        # Visualizes thematic clusters

## Output

- translated_comments.csv: Cleaned and translated comments
- clusters.csv: Final dataset with cluster labels
- Cluster plot: Visual representation of themes

## Citation

If you use this project in academic work, please cite it as:

Salvatore. 2025. Multilingual Thematic Analysis in R: A modular pipeline for translating, preprocessing, and clustering multilingual survey comments. GitHub. https://github.com/yourusername/multilingual_analysis

BibTeX:

@misc{salvatore2025multilingual,
  author       = {Salvatore},
  title        = {Multilingual Thematic Analysis in R: A modular pipeline for translating, preprocessing, and clustering multilingual survey comments},
  year         = {2025},
  howpublished = {https://github.com/yourusername/multilingual_analysis},
  note         = {Accessed: YYYY-MM-DD}
}

## License

This project is licensed under the MIT License.
