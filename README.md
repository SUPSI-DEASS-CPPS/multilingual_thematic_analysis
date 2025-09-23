# Multilingual Thematic Analysis in R

A modular R pipeline for translating, cleaning, and clustering multilingual survey comments.

Built for multilingual surveys, this pipeline combines cloud-powered translation, contextual embeddings, unsupervised clustering, and rich visualizations to uncover thematic insights across languages — all with reproducibility, modularity, and privacy at its core.

---

## 🛡️ Badges

![R version](https://img.shields.io/badge/R-≥4.1-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-green)
![renv](https://img.shields.io/badge/Reproducible%20Environment-renv-yellow)
![Last Updated](https://img.shields.io/badge/Last%20Updated-September%202025-orange)

---

## ⚡ Quickstart Summary

For impatient users, here’s how to get started in 5 steps:

1. **Clone the repo**
   ```bash
   git clone https://github.com/SUPSI-DEASS-CPPS/multilingual_thematic_analysis.git
   cd multilingual_thematic_analysis
   ```
2. **Set up your .Renviron**
   ```bash
   cp .Renviron.example .Renviron
   ```
   Edit it with your Google Cloud credentials and restart R.
   
3. **Place your survey file** 
   Save your UTF-8 `.tsv` file as `data/comments.tsv`

4. **Restore the environment**
   ```r
   install.packages("renv")
   renv::restore()
   ```
5. **Run the pipeline**
   ```r
   source("scripts/00_validate_responses.R")
   source("scripts/01_load_translate.R")
   source("scripts/02_contextual_embeddings.R")
   source("scripts/03_clustering.R")
   source("scripts/04_visualization.R")
   ```

---

## 📑 Table of Contents
- [Quickstart Summary](#-quickstart-summary)
- [Overview](#-overview)
- [Research Context](#-research-context)
- [Features](#-features)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Input Format Specification](#-input-format-specification)
- [Configuration Guide](#-configuration-guide)
- [Script Dependencies](#-script-dependencies)
- [Installation](#-installation)
- [Usage](#-usage)
- [Example Output](#-example-output)
- [How It Works](#-how-it-works)
- [Troubleshooting](#-troubleshooting)
- [Data Privacy Note](#-data-privacy-note)
- [Limitations](#-limitations)
- [For Developers](#-for-developers)
- [License](#-license)

---

## 📚 Overview

This project provides a workflow for thematic analysis of multilingual text data. It includes:

- Validation of raw input  
- Translation using the polyglotr package or Google Cloud Translation API  
- Text preprocessing  
- Clustering with PCA and k-means  
- Visualization of thematic patterns

## 🧠 Research Context

Open-ended survey responses offer rich qualitative insights, but analyzing them at scale — especially across multiple languages — is notoriously difficult. Manual coding is time-consuming, inconsistent, and often biased by language fluency.

This pipeline addresses that challenge by combining:
- **Automated translation** to unify multilingual feedback
- **Contextual embeddings** to capture semantic nuance
- **Unsupervised clustering** to reveal emergent themes
- **Visualizations** to communicate findings clearly

It’s designed for researchers, analysts, and institutions who need to process large volumes of multilingual text data — whether for service evaluations, policy feedback, or global user studies — with reproducibility, transparency, and privacy in mind.

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
├── R/ 
│   └── utils.R 
├── config/ 
│   └── config.yml
├── data/ 
│   └── raw_survey_data_placeholder
├── output/
│   ├── csv/
│   │   ├── 00_flagged_responses.csv
│   │   ├── 00_clean_comments.csv
│   │   ├── 01_translated_comments.csv
│   │   ├── 02_embedding_summary.csv
│   │   └── cluster/
│   │       └── 03_clusters_summary.csv
│   ├── rds/
│   │   └── embeddings/
│   │       └── all_embeddings.rds
│   ├── png/
│   │   └── cluster/
│   └── html/
│       └── wordclouds/
├── cache/
├── scripts/
│   ├── 00_validate_responses.R
│   ├── 01_load_translate.R
│   ├── 02_contextual_embeddings.R
│   ├── 03_clustering.R
│   └── 04_visualization.R
├── renv/
│   └── (local renv infrastructure, ignored by git)
├── renv.lock
├── .Renviron.example
├── .gitignore
└── multilingual_analysis.Rproj
```

---

## 🧰 Prerequisites

Before running the pipeline, ensure you have the following:

- **R ≥ 4.1** installed on your system  
- **RStudio** (recommended for easier script execution and environment management)  
- **Google Cloud account** with access to:
  - Cloud Translation API
  - Vertex AI (for embeddings)
- **Service account keys** for both APIs saved as `.json` files  
- **Internet access** to connect to Google Cloud services  
- **UTF-8 encoded survey file** named `comments.tsv` placed in the `data/` folder  
- **Environment variables** configured in `.Renviron` (see `.Renviron.example`)  
- **renv** package installed to restore the project environment:
  ```r
  install.packages("renv")
  renv::restore()
  ```

These prerequisites ensure reproducibility, secure API access, and compatibility with the pipeline’s modular structure.

---

## 📄 Input Format Specification

The pipeline expects a UTF-8 encoded tab-separated file named `comments.tsv` placed in the `data/` folder.

### Required structure:

- File format: `.tsv` (tab-separated values)  
- Encoding: UTF-8  
- Columns:
  - `ResponseId`: Unique identifier for each survey response  
  - `UserLanguage`: Language code or label (e.g., `en`, `fr`, `de`)  
  - `Q4.2` to `Q4.10`: Open-ended comment fields (can vary depending on your survey)

### Example layout:

| ResponseId | UserLanguage | Q4.2                   | Q4.3         | Q4.4                     | ... | Q4.10       |
|------------|--------------|------------------------|--------------|--------------------------|-----|-------------|
| R_001      | en           | I loved the service.   | Very clean.  | Staff was friendly.      | ... | Will return!|
| R_002      | it           | Il servizio era ottimo.| Molto pulito.| Il personale era gentile.| ... | Tornerò!    |


⚠️ The pipeline assumes that the open-ended questions are labeled as `Q4.2` to `Q4.10`.  
If your survey uses different column names, you’ll need to adjust the `comment_cols` variable in the scripts or update the configuration file accordingly.

---

## ⚙️ Configuration Guide

The pipeline uses a centralized configuration file located at:

```
config/config.yml
```

This file controls all major parameters across the scripts, making the pipeline easy to customize without editing code.

### Key sections:

- `paths`: Input/output directories for data, results, and cache  
- `translation`: Minimum comment length, max allowed issues, and environment variable for API key  
- `embeddings`: Model ID, batch size, timeout, and environment variables for Vertex AI  
- `clustering`: UMAP dimensions, minimum documents, clustering method settings, and plot toggle  
- `visualization`: Wordcloud settings including max words, stopwords, colors, and export formats

### Example snippet:

```yaml
translation:
  min_comment_length: 10
  max_allowed_issues: 2
  google_key_env: "GOOGLE_TRANSLATE_KEY"

clustering:
  min_docs: 5
  min_pts: 5
  umap_dims: 50
  max_kmeans_k: 10
  make_plots: true
```

Customization tips:
- To change the number of clusters, adjust `max_kmeans_k`
- To skip wordcloud generation, set `make_plots: false`
- To use a different embedding model, update `model_id` under `embeddings`
- To add more stopwords, edit `custom_stopwords` and `regex_stopwords` under `visualization`
⚠️ After modifying `config.yml`, re-run the affected scripts to apply changes.

---

## 🔗 Script Dependencies

The pipeline is modular but sequential — each script depends on the outputs of the previous one.

### Execution flow:
```
00_validate_responses.R
↓ 01_load_translate.R
↓ 02_contextual_embeddings.R
↓ 03_clustering.R
↓ 04_visualization.R
```

### Dependency map:

- `00_validate_responses.R`  
  → Reads `data/comments.tsv`  
  → Outputs `00_clean_comments.csv` and `00_flagged_responses.csv`

- `01_load_translate.R`  
  → Reads `00_clean_comments.csv`  
  → Outputs `01_translated_comments.csv`

- `02_contextual_embeddings.R`  
  → Reads `01_translated_comments.csv`  
  → Outputs `all_embeddings.rds`, `all_embeddings.csv`, and `02_embedding_summary.csv`

- `03_clustering.R`  
  → Reads `all_embeddings.rds` and `01_translated_comments.csv`  
  → Outputs cluster CSVs, UMAP plots, and `03_clusters_summary.csv`

- `04_visualization.R`  
  → Reads cluster CSVs  
  → Outputs wordclouds in PNG and HTML formats

⚠️ If you modify any intermediate output (e.g., translated comments), re-run the downstream scripts to reflect those changes.

---

## 🚀 Installation

1. **Clone the repository**
	```bash
	git clone https://github.com/SUPSI-DEASS-CPPS/multilingual_thematic_analysis.git
	cd multilingual_thematic_analysis
	```

2. **Set up environment variables**
   - Copy `.Renviron.example` to `.Renviron`:
     ```bash
     cp .Renviron.example .Renviron
     ```
   - Edit `.Renviron` and add your Google Cloud credentials:
     ```bash
     GOOGLE_TRANSLATE_KEY=/path/to/google-translate-key.json
     GOOGLE_VERTEX_KEY=/path/to/google-vertex-key.json
     GCP_PROJECT=your-gcp-project-id
     ```
   - Restart R or RStudio to apply changes.

3. **Restore the R environment**
   - This project uses [renv](https://rstudio.github.io/renv/) for reproducible package management.
   - In R, run:
     ```r
     install.packages("renv")  # if not already installed
     renv::restore()
     ```
   - This installs the exact package versions listed in `renv.lock`.

4. **Open the project**
   - Use R or RStudio in the cloned project directory.

---

## 🛠 Usage

### Step 1: Prepare your data

Export your survey as a UTF-8 encoded `.tsv` file with line breaks preserved and choice text.

Save it as:

```bash
data/comments.tsv
```

⚠️ The data/ folder is ignored by Git to protect sensitive data. A placeholder file (raw_survey_data_placeholder) is included so the folder exists in the repo. Replace it with your actual survey file named comments.tsv

### Step 2: Set up Google Cloud Translation API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)  
2. Create a new project (e.g., `MyProject`)  
3. Enable the **Cloud Translation API** under APIs & Services > Library  
4. Go to **APIs & Services > Credentials**  
5. Click **Create Credentials > Service Account**  
6. Name it (e.g., `translation-service`) and click **Done**  
7. In the Service Account list, click your new account  
8. Go to the **Keys** tab  
9. Click **Add Key > Create new key**, choose **JSON**, and download the file  
10. Move the file to a secure location, e.g.: `~/.gcloud/translation-key.json`

### Step 3: Configure environment variables

Use the `.Renviron` file to store your keys and project ID.
Copy `.Renviron.example` to `.Renviron` and edit it with your values:

```bash
GOOGLE_TRANSLATE_KEY=/path/to/google-translate-key.json
GOOGLE_VERTEX_KEY=/path/to/google-vertex-key.json
GCP_PROJECT=your-gcp-project-id
```

Restart R or RStudio after editing `.Renviron`.

### Step 4: Install dependencies with renv

This project uses [renv] (https://rstudio.github.io/renv/) for reproducible environments.

1. Install renv if not already installed:

```r
install.packages("renv")
```

2. Initialize or restore the environment:

```r
renv::restore()
```

3. This installs the exact package versions listed in `renv.lock`.

### Step 5: Run the pipeline

```r
source("scripts/00_validate_responses.R")
source("scripts/01_load_translate.R")
source("scripts/02_contextual_embeddings.R")
source("scripts/03_clustering.R")
source("scripts/04_visualization.R")
```

The translation script will:
- Detect the actual language of each comment;
- Retry failed translations up to 3 times;
- Skip short or non-linguistic entries;
- Translate using the correct source language;
- Cache translations to avoid redundant API calls;
- Display a progress bar with estimated time remaining;

---

## 📂 Example Output

After running the full pipeline, you’ll find the following outputs:

- `output/csv/00_flagged_responses.csv`  
  → Responses flagged for being missing, too short, or corrupted

- `output/csv/00_clean_comments.csv`  
  → Validated and cleaned comments ready for translation

- `output/csv/01_translated_comments.csv`  
  → Comments translated to English using Google Cloud Translation API

- `output/rds/embeddings/all_embeddings.rds`  
  → Combined contextual embeddings for all questions

- `output/csv/embeddings/all_embeddings.csv`  
  → Embeddings in CSV format for inspection or reuse

- `output/csv/02_embedding_summary.csv`  
  → Summary of embedding dimensions and valid rows per question

- `output/csv/cluster/03_clusters_summary.csv`  
  → Cluster labels, methods used, and silhouette scores

- `output/csv/cluster/clusters_Q4.X_translated.csv`  
  → Cluster assignments and labels for each question (X = 2 to 10)

- `output/png/cluster/clusters_Q4.X_translated_hdbscan_umap.png`  
  → UMAP plots of clustered embeddings

- `output/png/wordclouds/04_wordclouds_Q4.X_translated_combined.png`  
  → Wordclouds summarizing cluster themes

- `output/html/wordclouds/04_wordclouds_Q4.X_translated_combined.html`  
  → Interactive HTML wordclouds for exploration
  
---

## 🔍 How It Works

The pipeline consists of five modular R scripts, each performing a distinct stage of multilingual thematic analysis:

1. **Validation** (`00_validate_responses.R`)  
   - Loads raw survey data from `data/comments.tsv`  
   - Flags missing, short, or corrupted responses  
   - Filters out low-quality entries  
   - Outputs `00_clean_comments.csv` and `00_flagged_responses.csv`

2. **Translation** (`01_load_translate.R`)  
   - Detects the actual language of each comment  
   - Translates comments to English using the Google Cloud Translation API  
   - Caches results to avoid redundant API calls  
   - Outputs `01_translated_comments.csv`

3. **Embedding** (`02_contextual_embeddings.R`)  
   - Generates contextual embeddings using Google Vertex AI  
   - Saves per-question and combined embeddings in `.rds` and `.csv` formats  
   - Outputs `02_embedding_summary.csv` and `all_embeddings.rds`

4. **Clustering** (`03_clustering.R`)  
   - Reduces embedding dimensions with PCA and UMAP  
   - Applies HDBSCAN clustering (with KMeans fallback)  
   - Labels clusters using TF-IDF keywords  
   - Outputs cluster assignments and visual plots  
   - Saves `03_clusters_summary.csv` and per-question cluster files

5. **Visualization** (`04_visualization.R`)  
   - Generates wordclouds for each cluster  
   - Exports both PNG and HTML versions  
   - Saves outputs in `output/png/wordclouds/` and `output/html/wordclouds/`

Each script is standalone and can be run independently, but they are designed to work sequentially for full pipeline execution.

---

## 🧯 Troubleshooting

Here are common issues you might encounter when running the pipeline, along with suggested fixes:

### 🔑 Missing API key or environment variable
**Error:** `Error: GOOGLE_TRANSLATE_KEY not found`  
**Fix:**  
- Ensure `.Renviron` exists in your project root  
- Add the correct path to your translation key:
  ```bash
  GOOGLE_TRANSLATE_KEY=/path/to/google-translate-key.json
  ```
- Restart R or RStudio to reload environment variables

### 📦 renv restore fails or hangs
**Error:** Packages not installing, or `renv::restore()` fails
**Fix:**
- Ensure you have internet access
- Run `install.packages("renv")` before restoring
- Try `renv::diagnostics()` for detailed troubleshooting
- If needed, delete `renv/` and re-run `renv::init()` followed by `renv::restore()`

### 🌐 Translation API quota exceeded
**Error:** `403: Quota exceeded` or `API key invalid`
**Fix:**
- Check your Google Cloud billing and quota settings
- Ensure the Translation API is enabled for your project
- Verify that your service account has the correct permissions

### 🧠 Vertex AI embedding timeout
**Error:** `Request timed out` or `Embedding failed`
**Fix:**
- Increase `timeout_seconds` in `config.yml` under `embeddings`
- Reduce `batch_size` to avoid overloading the API
- Ensure your Vertex AI key and project ID are correctly set in `.Renviron`

### 📁 File not found
**Error:** `Error in read_csv: file does not exist`
**Fix:**
- Ensure the expected input file (`comments.tsv`) is placed in the `data/` folder
- Check that filenames match exactly (case-sensitive)
- Re-run the previous script to regenerate missing outputs

### 📊 Empty or invalid output
**Error:** Wordclouds or plots are blank
**Fix:**
- Check that your input data contains enough valid comments
- Adjust `min_comment_length`, `min_docs`, or `min_freq` in `config.yml`
- Review logs printed by each script for warnings or skipped entries
If you encounter other issues, try running each script individually and inspecting intermediate outputs in the `output/` folder.

---

## 🔒 Data Privacy Note

This pipeline is designed to respect the privacy of survey respondents and prevent accidental exposure of sensitive data.

### Key safeguards:

- The `data/` folder is excluded from version control via `.gitignore`  
- A placeholder file (`raw_survey_data_placeholder`) is included to preserve folder structure  
- Raw survey files (e.g., `comments.tsv`) should be stored locally and never committed to GitHub  
- Translated and cleaned outputs are stored in `output/`, which is also ignored by default  
- API keys and credentials are stored in `.Renviron`, which is excluded from GitHub  
- A `.Renviron.example` file is provided to guide collaborators without exposing secrets

⚠️ Always review your data before sharing outputs or publishing results.  
If working with personally identifiable information (PII), consider additional anonymization steps before analysis.

---

## ⚠️ Limitations

- Requires internet access for API queries to Google Cloud Translation and Vertex AI  
- Google Cloud Translation API may require billing setup for high-volume usage  
- Embedding generation via Vertex AI may incur costs depending on your quota and usage  
- Language detection may be less accurate for short, ambiguous, or mixed-language comments  
- Clustering performance depends on the quality and diversity of responses  
- Wordclouds may overrepresent common filler terms if stopwords are not fully filtered  
- Scripts assume a consistent survey structure (e.g., Q4.2 to Q4.10); customization may be needed for other formats

---

## 🧑‍💻 For Developers

This pipeline is modular by design and easy to extend. Here are a few ways developers can build on it:

### 🔄 Swap out embedding models
- Replace Vertex AI with Hugging Face models (e.g., `sentence-transformers`)  
- Adjust `02_contextual_embeddings.R` to use local or open-source alternatives

### 💬 Add sentiment analysis
- Integrate sentiment scoring after translation  
- Use packages like `textdata`, `syuzhet`, or `sentimentr`  
- Visualize sentiment trends alongside thematic clusters

### 🧪 Customize clustering
- Try alternative methods like DBSCAN, hierarchical clustering, or topic modeling (LDA)  
- Tune `min_pts`, `umap_dims`, or `max_kmeans_k` in `config.yml`

### 🌍 Support other survey formats
- Modify `comment_cols` to match different question labels  
- Add logic to handle matrix-style or nested responses

### 📦 Package the pipeline
- Convert scripts into an R package with exported functions  
- Add unit tests and vignettes for reproducibility

If you build on this pipeline, feel free to fork the repo or open a discussion to share your improvements.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).

**Acknowledgment:**  
Documentation and refactoring support were assisted by Microsoft Copilot, an AI companion that helped streamline the pipeline and improve reproducibility.