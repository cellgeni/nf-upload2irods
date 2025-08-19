# nf-upload2irods

## Overview

This Nextflow pipeline uploads files and directories to iRODS storage with comprehensive metadata management. The pipeline supports two main operations: file upload with automatic checksum verification and metadata attachment to existing iRODS collections.

## Contents of Repo:
* `main.nf` — the main Nextflow pipeline that orchestrates file uploads and metadata attachment to iRODS
* `nextflow.config` — configuration script for IBM LSF submission on Sanger's HPC with Singularity containers and global parameters
* `modules/local/irods/storefile/` — module for uploading files to iRODS with checksum verification
* `modules/local/irods/attachmetadata/` — module for attaching metadata to iRODS collections

## Pipeline Workflow

1. **File Discovery**: Reads file/directory information from CSV input file
2. **Path Classification**: Distinguishes between individual files and directories for processing
3. **File Collection**: For directories, recursively gathers all files within the directory structure
4. **File Filtering**: Applies ignore patterns to exclude specified file types from upload
5. **iRODS Upload**: Transfers files to iRODS with MD5 checksum verification
6. **Metadata Attachment**: Attaches custom metadata to iRODS collections (separate operation)

## Pipeline Parameters

### Required Parameters:
* `--upload` — Path to a CSV file containing upload information with columns: `path` (local filesystem path) and `irodspath` (target iRODS path)
  **OR**
* `--metadata` — Path to a CSV file containing metadata information with columns: `irodspath` (target iRODS path) and additional metadata key-value pairs

### Optional Parameters:
* `--output_dir` — Output directory for pipeline results (`default: "results"`)
* `--publish_mode` — File publishing mode (`default: "copy"`)
* `--ignore_ext` — Comma-separated list of file extensions to ignore during upload (`default: null`)
* `--verbose` — Enable verbose output for detailed logging (`default: false`)

## Input File Formats

The pipeline supports two distinct operation modes:

### Option 1: File Upload (`--upload`)
CSV file with the following structure:

```csv
path,irodspath
/path/to/local/file.txt,/archive/cellgeni/target/file.txt
/path/to/local/directory,/archive/cellgeni/target/directory
/path/to/another/file.csv,/archive/cellgeni/target/data.csv
```

Where:
- `path`: Absolute path to the local file or directory to upload
- `irodspath`: Target path in iRODS where the file/directory should be stored

### Option 2: Metadata Attachment (`--metadata`)
CSV file with the following structure:

```csv
irodspath,meta1,meta2,meta3
/archive/cellgeni/target/collection1,value1,value2,value3
/archive/cellgeni/target/collection2,value4,value5,value6
/archive/cellgeni/target/collection3,value7,value8,value9
```

Where:
- `irodspath`: Target iRODS collection path for metadata attachment
- Additional columns: Custom metadata key-value pairs to attach to the collection

## Upload Behavior

### For Individual Files
Files are uploaded directly to the specified iRODS path:
- Local: `/path/to/file.txt`
- iRODS: `/archive/cellgeni/target/file.txt`

### For Directories
All files within the directory are uploaded while preserving the directory structure:
- Local: `/path/to/directory/subdir/file.txt`
- iRODS: `/archive/cellgeni/target/directory/subdir/file.txt`

### File Filtering
When `--ignore_ext` is specified, files containing the specified extensions are excluded from upload:
```bash
--ignore_ext ".bam,.fastq.gz,.tmp"
```

## Examples

### Basic File Upload
Upload files and directories to iRODS:
```bash
nextflow run main.nf --upload upload.csv
```

### File Upload with Filtering
Upload files while excluding specific file types:
```bash
nextflow run main.nf \
    --upload upload.csv \
    --ignore_ext ".bam,.fastq.gz,.tmp"
```

### Metadata Attachment
Attach metadata to existing iRODS collections:
```bash
nextflow run main.nf --metadata metadata.csv
```

### Enable Verbose Output
Get detailed logging information during upload:
```bash
nextflow run main.nf \
    --upload upload.csv \
    --verbose true
```

### Custom Output Directory
Specify a different output directory for results:
```bash
nextflow run main.nf \
    --upload upload.csv \
    --output_dir "my_results"
```

## Expected Data Structure

### For File Upload
The pipeline accepts any file or directory structure. Common use cases include:

**Individual files:**
```
/path/to/data.csv
/path/to/analysis.txt
/path/to/results.json
```

**Directory structures:**
```
/path/to/experiment/
├── sample1/
│   ├── data.txt
│   ├── results.csv
│   └── analysis/
│       └── output.json
├── sample2/
│   └── data.txt
└── metadata.tsv
```

### For Metadata Attachment
Metadata is attached to existing iRODS collections. The collections should already exist in iRODS before running the metadata attachment operation.

## Output Files

### Upload Operation
- **MD5 checksums file**: `{output_dir}/md5sums.csv`
  - Contains MD5 checksums for all uploaded files
  - Includes both local and iRODS checksums for verification
  - Format: `collection_id,filepath,irodspath,md5,irodsmd5`

### Metadata Operation
- Metadata is directly attached to iRODS collections
- No local output files are generated

## iRODS Integration

### Upload Process
1. Files are transferred to iRODS using the `iput` command
2. MD5 checksums are calculated for both local and iRODS copies
3. Checksums are compared to ensure data integrity
4. Upload results are logged and saved to CSV format

### Metadata Process
1. Metadata key-value pairs are extracted from the input CSV
2. Each metadata attribute is attached to the specified iRODS collection
3. Existing metadata can be updated or new metadata can be added

## System Requirements

- **Nextflow**: Version 25.04.4 or higher
- **Singularity**: For containerized execution
- **iRODS client**: Access to iRODS commands (`iput`, `imeta`, etc.)
- **LSF**: For job submission on HPC clusters (configured for Sanger's environment)

## Error Handling

- **File not found**: Pipeline will fail if specified local files/directories don't exist
- **iRODS connection**: Pipeline will retry failed iRODS operations up to 5 times
- **Checksum mismatch**: Upload failures are reported in the output logs
- **Invalid CSV format**: Pipeline validates CSV headers and structure

## Monitoring and Logging

The pipeline generates comprehensive reports in the `reports/` directory:
- **Timeline report**: Visual timeline of task execution
- **Execution report**: Detailed resource usage and performance metrics
- **Trace file**: Complete execution trace for debugging

## Usage Notes

- Only one operation mode can be used per pipeline run (`--upload` OR `--metadata`)
- File paths must be absolute paths to avoid ambiguity
- iRODS collections for metadata attachment must exist before running the pipeline
- Large file uploads may take considerable time depending on network bandwidth
- The pipeline is optimized for batch operations rather than single file transfers
