# Multilingual Thematic Analysis in R

A modular R pipeline for translating, cleaning, and clustering multilingual survey comments.

---

## 📑 Table of Contents
- [Overview](#-overview)
- [Features](#-features)
- [Project Structure](#-project-structure)
- [Usage](#-usage)
- [Example Session](#-example-session)
- [Installation](#-installation)
- [How It Works](#-how-it-works)
- [Limitations](#-limitations)
- [License](#-license)

---

## 📚 Overview

This project provides a workflow for thematic analysis of multilingual text data. It includes:

- Validation of raw input  
- Translation using the polyglotr package  
- Text preprocessing  
- Clustering with PCA and k-means  
- Visualization of thematic patterns

---

## ✨ Features

- Filters missing, short, or corrupted responses  
- Translates comments to English via MyMemory API  
- Cleans and tokenizes text  
- Builds a document-term matrix (DTM)  
- Applies PCA and k-means clustering  
- Visualizes clusters with ggplot2

---

## 📂 Project Structure

```
├── data/
│   └── comments.csv
├── output/
│   ├── clean_comments.csv
│   ├── clusters.csv
│   ├── dtm.rds
│   ├── flagged_responses.csv
│   └── translated_comments.csv
├── scripts/
│   ├── 00_validate_responses.R
│   ├── 01_load_translate.R
│   ├── 02_preprocess_nlp.R
│   ├── 03_clustering.R
│   └── 04_visualization.R
└── multilingual_analysis.Rproj
```

---

## 🛠 Usage

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

## 📂 Example Output

- `translated_comments.csv`: Translated comments  
- `clusters.csv`: Cluster labels  
- Cluster plot: Visual representation of themes

---

## 🚀 Installation

1. **Clone the repository**
	```bash
	git clone https://github.com/SUPSI-DEASS-CPPS/multilingual_thematic_analysis.git
	cd multilingual_thematic_analysis
	```

2. **Install required R packages**
	```r
	install.packages(c(
	  "tidyverse", "polyglotr", "text2vec", "tm",
	  "cluster", "factoextra", "ggplot2"
	))
	```

3. **Open the project**  
   Use R or RStudio in the cloned project directory.

---

## ⚠️ Limitations

- Requires internet access for API queries

---

## 📜 License

MIT License — see [LICENSE](LICENSE) for details.
