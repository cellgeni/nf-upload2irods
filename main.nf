include { IRODS_ATTACHMETADATA } from './modules/local/irods/attachmetadata'
include { IRODS_STOREFILE } from './modules/local/irods/storefile'

def helpMessage() {
    log.info(
      """
      ===================
      nf-upload2irods pipeline
      ===================
      This Nextflow pipeline uploads files and directories to iRODS storage with comprehensive metadata management. 
      The pipeline supports two main operations: file upload with automatic checksum verification and metadata attachment to existing iRODS collections.

      Usage: nextflow run main.nf [parameters]

      Required parameters:
        --upload <string>         Path to a CSV file containing upload information with columns: 'path' (local filesystem path) and 'irodspath' (target iRODS path)
        OR
        --metadata <string>       Path to a CSV or JSON file containing metadata information with columns: 'irodspath' (target iRODS path) and additional metadata key-value pairs

      Optional parameters:
        --help                      Display this help message
        --output_dir                Output directory for pipeline results (default: "results")
        --publish_mode              File publishing mode (default: "copy")
        --ignore_ext                Comma-separated list of file extensions to ignore during upload (default: null)
        --remove_existing_metadata  Remove existing metadata before adding new metadata (default: false)
        --verbose                   Enable verbose output for detailed logging (default: false)

      Input file formats:
        
        For --upload parameter (CSV file):
        path,irodspath
        /path/to/local/file.txt,/archive/cellgeni/target/file.txt
        /path/to/local/directory,/archive/cellgeni/target/directory
        /path/to/another/file.csv,/archive/cellgeni/target/data.csv
        
        For --metadata parameter (CSV file):
        irodspath,meta1,meta2,meta3
        /archive/cellgeni/target/collection1,value1,value2,value3
        /archive/cellgeni/target/collection2,value4,value5,value6
        /archive/cellgeni/target/collection3,value7,value8,value9
        
        For --metadata parameter (JSON file):
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

      Upload behavior:
        - Individual files: Uploaded directly to the specified iRODS path
        - Directories: All files within the directory are uploaded while preserving structure
        - File filtering: Files containing specified extensions in --ignore_ext are excluded

      Pipeline workflow:
        1. File Discovery - Reads file/directory information from CSV input file
        2. Path Classification - Distinguishes between individual files and directories
        3. File Collection - For directories, recursively gathers all files within the structure
        4. File Filtering - Applies ignore patterns to exclude specified file types
        5. iRODS Upload - Transfers files to iRODS with MD5 checksum verification
        6. Metadata Attachment - Attaches custom metadata to iRODS collections (separate operation)

      Examples:
        # Basic file upload - Upload files and directories to iRODS
        nextflow run main.nf --upload upload.csv
        
        # File upload with filtering - Exclude specific file types
        nextflow run main.nf --upload upload.csv --ignore_ext ".bam,.fastq.gz,.tmp"
        
        # Metadata attachment - Attach metadata to existing iRODS collections
        nextflow run main.nf --metadata metadata.csv
        
        # Metadata attachment with JSON format
        nextflow run main.nf --metadata metadata.json
        
        # Remove existing metadata before adding new metadata
        nextflow run main.nf --metadata metadata.csv --remove_existing_metadata true
        
        # Enable verbose output - Get detailed logging information
        nextflow run main.nf --upload upload.csv --verbose true
        
        # Custom output directory - Specify different output location
        nextflow run main.nf --upload upload.csv --output_dir "my_results"

      Output files:
        - MD5 checksums file: {output_dir}/md5sums.csv (for upload operations)
          Contains MD5 checksums for all uploaded files with verification data
          Format: collection_id,filepath,irodspath,md5,irodsmd5

      Expected data structure:
        The pipeline accepts any file or directory structure for upload.
        For metadata operations, iRODS collections must already exist.

      System requirements:
        - Nextflow: Version 25.04.4 or higher
        - Singularity: For containerized execution
        - iRODS client: Access to iRODS commands (iput, imeta, etc.)
        - LSF: For job submission on HPC clusters

      For more details, see the README.md file in this repository.
      """.stripIndent()
    )
}

def missingParametersError() {
    log.error("Missing input parameters")
    helpMessage()
    error("Please provide all required parameters: --upload OR --metadata. See --help for more information.")
}

workflow {
    if (params.help) {
    helpMessage()
    } else if (!((params.upload && !params.metadata) || (!params.upload && params.metadata))) {
        missingParametersError()
    }

    if (params.upload) {
        // Read upload list to channel
        upload = channel.fromPath(params.upload, checkIfExists: true)
            .splitCsv(header: true, sep: ',')
            // Branch directories and files
            .branch { contents ->
                def path = file(contents.path)
                def meta = [id: path.name, path: contents.path]
                isFile: path.isFile()
                    return tuple(meta, path, contents.irodspath)
                isDir: path.isDirectory()
                    return tuple(meta, files(path.toString().replaceFirst('/$', '') + '/**', type: 'file'), path, contents.irodspath)
                other: true
            }
        
        // Collect all files together
        files = upload.isDir
            // flatten file lists [meta, [file1, file2, ...], dirpath, irodsdirpath] -> [meta, file1, dirpath, irodsdirpath], [meta, file2, dirpath, irodsdirpath], ...
            .transpose()
            // Construct irodspath for each file
            .map { meta, filepath, dirpath, irodscollection -> 
                def relativepath = filepath.toString().replaceFirst(dirpath.toString(), '').replaceFirst('/', '')
                def irodspath = irodscollection.replaceFirst('/$', '') + "/${relativepath}"
                def file_meta = [id: filepath.name, collection_path: dirpath, path: filepath]
                tuple(file_meta, filepath, irodspath)
            }
            // Filter files if ignore_pattern is provided
            .filter { meta, path, irodspath ->
                def ignore_ext = params.ignore_ext ? params.ignore_ext.split(',').collect { it.trim() } : []
                return !ignore_ext.any { ext -> path.name.contains(ext) }
            }
            // Attach files from upload file
            .mix(upload.isFile)
          
        // Log file counts if verbose is enabled
        if (params.verbose) {
          // Count files
            files.map { meta, path, irodspath ->
                def new_id = meta.collection_path ? meta.collection_path : "file"
                tuple(new_id, path)
            }
            .groupTuple()
            .subscribe { id, filelist ->
                def directory_string = id == "file" ? "Standalone:" : "Directory ${id}:"
                log.info("${directory_string} ${filelist.size()} files")
            }
        }

        // Upload files to iRODS
        IRODS_STOREFILE(files)

        // Collect versions of the tools used
        IRODS_STOREFILE.out.md5
            .collectFile(name: 'md5sums.csv', newLine: false, storeDir: params.output_dir, sort: true, keepHeader: true, skip: 1) { meta, irodspath, md5, md5irods -> 
                def collection_id = meta.collection_id ?: "file"
                def header = "collection_id,filepath,irodspath,md5,irodsmd5"
                def line = "${collection_id},${meta.path},${irodspath},${md5},${md5irods}"
                "${header}\n${line}\n"
            }
            .subscribe { __ -> 
                log.info("MD5 checksums saved to ${params.output_dir}/md5sums.csv")
            }
    }

    if (params.metadata) {
        // Read metadata file to channel
        metadata = channel.fromPath(params.metadata, checkIfExists: true)

        // Split metadata based on file format
        if (params.metadata.endsWith('.json')) {
            metadata = metadata.splitJson()
        } else if (params.metadata.endsWith('.csv')) {
            metadata = metadata.splitCsv(header: true, sep: ',')
        } else {
            log.error("Unsupported metadata file format. Please provide a CSV or JSON file.")
            error("Unsupported metadata file format. Please provide a CSV or JSON file.")
        }

        // remove irodspath from contents dict
        metadata = metadata
            .map { contents -> 
              def new_meta = [id: contents.irodspath] + contents.findAll { key, value -> key != 'irodspath' }
              tuple(new_meta, contents.irodspath)
            }
        
        // Attach metadata to iRODS path
        IRODS_ATTACHMETADATA(metadata)
    }
}   