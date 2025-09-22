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
- Translation using the polyglotr package or Google Cloud Translation API  
- Text preprocessing  
- Clustering with PCA and k-means  
- Visualization of thematic patterns

---

## ✨ Features

- Filters missing, short, or corrupted responses  
- Detects actual language of each comment  
- Translates comments to English via Google Cloud Translation API  
- Retries failed translations up to 3 times  
- Skips non-linguistic or too-short texts  
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

If your dataset contains only one column named `comment`, the pipeline will automatically detect and process it.

### Step 2: Set up Google Cloud Translation API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)  
2. Create a new project (e.g., `TranslationProject`)  
3. Enable the **Cloud Translation API** under APIs & Services > Library  
4. Go to **APIs & Services > Credentials**  
5. Click **Create Credentials > Service Account**  
6. Name it (e.g., `translation-service`) and click **Done**  
7. In the Service Account list, click your new account  
8. Go to the **Keys** tab  
9. Click **Add Key > Create new key**, choose **JSON**, and download the file  
10. Move the file to a secure location, e.g.: `~/.gcloud/translation-key.json`

### Step 3: Configure environment variable in RStudio

Use the `usethis` package to edit your `.Renviron` file:

```r
install.packages("usethis")
usethis::edit_r_environ()
```

Add this line: `GOOGLE_TRANSLATE_KEY=~/.gcloud/translation-key.json`

Save and restart RStudio.

### Step 4: Run the pipeline

```r
source("scripts/00_validate_responses.R")
source("scripts/01_load_translate.R")
source("scripts/02_preprocess_nlp.R")
source("scripts/03_clustering.R")
source("scripts/04_visualization.R")
```

The translation script will:
- Detect the actual language of each comment
- Retry failed translations up to 3 times
- Skip short or non-linguistic entries
- Translate using the correct source language
- Cache translations to avoid redundant API calls
- Display a progress bar with estimated time remaining

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
	  "tidyverse", "polyglotr", "text2vec", "tm", "furrr",
	  "cluster", "factoextra", "ggplot2", "cld3", "ISOcodes",
	  "progressr", "googleLanguageR"
	))
	```

3. **Open the project**  
   Use R or RStudio in the cloned project directory.

---

## ⚠️ Limitations

- Requires internet access for API queries
- Google Cloud Translation API may require billing setup for high-volume usage
- Language detection may be less accurate for short or mixed-language comments

---

## 📜 License

MIT License — see [LICENSE](LICENSE) for details.

**Acknowledgment:** The preparation of this documentation benefited from the use of Microsoft Copilot, an AI system that assisted in drafting and editing.
