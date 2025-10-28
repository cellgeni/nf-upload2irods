# nf-upload2irods

## Overview

This Nextflow pipeline uploads files and directories to iRODS storage with comprehensive metadata management. The pipeline supports three main operations: file upload with automatic checksum verification, metadata attachment to existing iRODS collections, and metadata retrieval from iRODS collections.

## Contents of Repo:
* `main.nf` — the main Nextflow pipeline that orchestrates file uploads and metadata management with iRODS
* `nextflow.config` — configuration script for IBM LSF submission on Sanger's HPC with Singularity containers and global parameters
* `configs/` — configuration files for individual pipeline modules
* `modules/local/irods/storefile/` — module for uploading files to iRODS with checksum verification
* `modules/local/irods/attachmetadata/` — module for attaching metadata to iRODS collections
* `modules/local/irods/getmetadata/` — module for retrieving metadata from iRODS collections
* `modules/local/irods/aggregatemetadata/` — module for aggregating retrieved metadata
* `modules/local/csv/concat/` — module for concatenating CSV files
* `examples/` — example input files for different pipeline operations
* `tests/` — test data and configurations for pipeline validation

## Pipeline Workflow

1. **File Discovery**: Reads file/directory information from CSV input file
2. **Path Classification**: Distinguishes between individual files and directories for processing
3. **File Collection**: For directories, recursively gathers all files within the directory structure
4. **File Filtering**: Applies ignore patterns to exclude specified file types from upload
5. **iRODS Upload**: Transfers files to iRODS with MD5 checksum verification
6. **Metadata Attachment**: Attaches custom metadata to iRODS collections (separate operation)
7. **Metadata Retrieval**: Retrieves metadata from existing iRODS collections (separate operation)

## Pipeline Parameters

### Required Parameters (choose one):
* `--upload` — Path to a CSV file containing upload information with columns: `path` (local filesystem path) and `irodspath` (target iRODS path)
  **OR**
* `--attach_metadata` — Path to a CSV or JSON file containing metadata information with columns: `irodspath` (target iRODS path) and additional metadata key-value pairs
  **OR**
* `--get_metadata` — Path to a CSV file containing iRODS paths with column: `irodspath` (iRODS path to retrieve metadata from)

### Optional Parameters:
* `--output_dir` — Output directory for pipeline results (`default: "results"`)
* `--publish_mode` — File publishing mode (`default: "copy"`)
* `--ignore_ext` — Comma-separated list of file extensions to ignore during upload (`default: null`)
* `--remove_existing_metadata` — Remove existing metadata before adding new metadata (`default: false`)
* `--dup_meta_separator` — Separator for splitting multiple values in metadata fields (`default: ";"`)
* `--metadata_index_name` — Column name for iRODS path in metadata files (`default: "irodspath"`)
* `--join` — Join method for metadata operations (`default: "outer"`)
* `--verbose` — Enable verbose output for detailed logging (`default: false`)

## Input File Formats

The pipeline supports three distinct operation modes:

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

### Option 2: Metadata Attachment (`--attach_metadata`)
CSV file with the following structure:

```csv
irodspath,meta1,meta2,meta3
/archive/cellgeni/target/collection1,value1,value2,value3
/archive/cellgeni/target/collection2,value4,value5,value6
/archive/cellgeni/target/collection3,value7,value8,value9
```

JSON file with the following structure:

```json
[
  {
    "irodspath": "/archive/cellgeni/target/collection1",
    "meta1": "value1",
    "meta2": "value2",
    "meta3": "value3"
  },
  {
    "irodspath": "/archive/cellgeni/target/collection2",
    "meta1": "value4",
    "meta2": "value5",
    "meta3": "value6"
  }
]
```

Where:
- `irodspath`: Target iRODS collection path for metadata attachment
- Additional fields: Custom metadata key-value pairs to attach to the collection
- Values can contain multiple entries separated by the `--dup_meta_separator` (default: ";") which will create separate metadata entries for each value

### Option 3: Metadata Retrieval (`--get_metadata`)
CSV file with the following structure:

```csv
irodspath
/archive/cellgeni/collection1
/archive/cellgeni/collection2
/archive/cellgeni/collection3
```

Where:
- `irodspath`: iRODS collection path to retrieve metadata from

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

### Metadata Value Splitting
When attaching metadata, values can contain multiple entries separated by a delimiter (default: ";"). Each entry will create a separate metadata attribute with the same key:

**Input CSV:**
```csv
irodspath,authors,keywords
/archive/collection1,"John Doe;Jane Smith","genomics;analysis"
```

**Result:** Creates four separate metadata entries:
- `authors = John Doe`
- `authors = Jane Smith` 
- `keywords = genomics`
- `keywords = analysis`

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
nextflow run main.nf --attach_metadata metadata.csv
```

### Metadata Attachment with JSON
Attach metadata using JSON format:
```bash
nextflow run main.nf --attach_metadata metadata.json
```

### Remove Existing Metadata
Remove existing metadata before adding new metadata:
```bash
nextflow run main.nf \
    --attach_metadata metadata.csv \
    --remove_existing_metadata
```

### Metadata Retrieval
Retrieve metadata from existing iRODS collections:
```bash
nextflow run main.nf --get_metadata get_metadata.csv
```

### Enable Verbose Output
Get detailed logging information during upload:
```bash
nextflow run main.nf \
    --upload upload.csv \
    --verbose
```

### Custom Output Directory
Specify a different output directory for results:
```bash
nextflow run main.nf \
    --upload upload.csv \
    --output_dir "my_results"
```

### Custom Metadata Separator
Use semicolons to split multiple values in metadata fields:
```bash
nextflow run main.nf \
    --attach_metadata metadata.csv \
    --dup_meta_separator ";"
```

### Custom Metadata Index Column
Use a different column name for iRODS paths:
```bash
nextflow run main.nf \
    --attach_metadata metadata.csv \
    --metadata_index_name "irods_collection_path"
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

### For Metadata Retrieval
Metadata is retrieved from existing iRODS collections. The collections should already exist in iRODS before running the metadata retrieval operation.

## Output Files

### Upload Operation
- **MD5 checksums file**: `{output_dir}/md5sums.csv`
  - Contains MD5 checksums for all uploaded files
  - Includes both local and iRODS checksums for verification
  - Format: `collection_id,filepath,irodspath,md5,irodsmd5`

### Metadata Attachment Operation
- Metadata is directly attached to iRODS collections
- No local output files are generated

### Metadata Retrieval Operation
- **Metadata file**: `{output_dir}/metadata.csv`
  - Contains retrieved metadata from specified iRODS collections
  - Aggregated metadata from all queried collections

## iRODS Integration

### Upload Process
1. Files are transferred to iRODS using the `iput` command
2. MD5 checksums are calculated for both local and iRODS copies
3. Checksums are compared to ensure data integrity
4. Upload results are logged and saved to CSV format

### Metadata Attachment Process
1. Metadata key-value pairs are extracted from the input CSV or JSON file
2. If `--remove_existing_metadata` is enabled, existing metadata is removed first
3. Each metadata attribute is attached to the specified iRODS collection
4. Existing metadata can be updated or new metadata can be added

### Metadata Retrieval Process
1. iRODS collection paths are read from the input CSV file
2. Metadata is retrieved from each specified iRODS collection using `imeta` commands
3. Retrieved metadata is aggregated and formatted into a consolidated CSV file
4. The final metadata file is saved to the output directory

## System Requirements

- **Nextflow**: Version 25.04.4 or higher
- **Singularity**: For containerized execution
- **iRODS client**: Access to iRODS commands (`iput`, `imeta`, etc.)
- **LSF**: For job submission on HPC clusters (configured for Sanger's environment)
- **Python**: Python 3.x with pandas for metadata aggregation operations

## Testing

The pipeline includes comprehensive testing infrastructure:
- **nf-test**: Testing framework for Nextflow modules and workflows
- **Test data**: Example files located in `tests/` directory
- **Module tests**: Individual module testing in `modules/*/tests/` directories
- **Example files**: Sample input files in `examples/` directory for each operation mode

To run tests:
```bash
nf-test test
```

## Error Handling

- **File not found**: Pipeline will fail if specified local files/directories don't exist
- **iRODS connection**: Pipeline will retry failed iRODS operations up to 5 times, then ignore on final failure
- **Checksum mismatch**: Upload failures are reported in the output logs
- **Invalid CSV format**: Pipeline validates CSV headers and structure
- **Empty metadata**: Modules handle empty metadata gracefully with appropriate warnings
- **Path resolution**: Automatic detection of iRODS collections vs data objects, including symbolic links

## Monitoring and Logging

The pipeline generates comprehensive reports in the `reports/` directory:
- **Timeline report**: Visual timeline of task execution
- **Execution report**: Detailed resource usage and performance metrics  
- **Trace file**: Complete execution trace for debugging

All temporary work files are stored in `nf-work/` directory and can be cleaned up after successful execution.

## Usage Notes

- Only one operation mode can be used per pipeline run (`--upload` OR `--attach_metadata` OR `--get_metadata`)
- File paths must be absolute paths to avoid ambiguity
- iRODS collections for metadata attachment and retrieval must exist before running the pipeline
- Metadata files can be in either CSV or JSON format
- When using `--remove_existing_metadata`, all existing metadata will be removed before adding new metadata
- Large file uploads may take considerable time depending on network bandwidth
- The pipeline is optimized for batch operations rather than single file transfers
- Configuration files in `configs/` directory allow fine-tuning of individual modules
- The pipeline uses Singularity containers with specific images for Python-based operations
- All modules include comprehensive metadata documentation in `meta.yml` files
