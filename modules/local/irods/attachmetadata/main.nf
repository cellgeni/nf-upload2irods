def metaToTsv(meta) {
    def tsv_string = meta
                     .findAll { key, value -> key != 'id' } //drop 'id' and 'path' key
                     .collectMany { key, value ->
                         value.toString()
                              .split(/\s*,\s*/) // split by comma
                              .collect { it.trim() } // trim whitespace
                              .findAll { it } // filter out empty strings
                              .collect { v -> "${key}\t${v}" } // create key-value pairs
                    }
                    .join('\n')
                    .stripIndent() // remove leading whitespace
    return tsv_string
}

process IRODS_ATTACHMETADATA {
    tag "Attaching metadata for $prefix"

    input:
    tuple val(meta), val(irodspath)

    output:
    path "versions.yml"           , emit: versions

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    irodspath = irodspath.replaceFirst('/$', '') // ensure no trailing slash
    meta_tsv = metaToTsv(meta)
    """
    # Create tsv file with metadata
    echo -e "$meta_tsv" > metadata.tsv

    # Check if irodspath exists
    name=\$(basename "$irodspath")
    coll=\$(dirname "$irodspath")
    if iquest --no-page "SELECT COLL_ID WHERE COLL_NAME = '$irodspath'" | grep -q 'COLL_ID'; then
        resource="-C"
    elif iquest --no-page "SELECT DATA_ID WHERE COLL_NAME = '\$coll' AND DATA_NAME = '\$name'" | grep -q 'DATA_ID'; then
        resource="-d"
    else
        echo "Error: iRODS path $irodspath does not exist."
        exit 1
    fi

    # Get existing metadata from iRODS
    get_metadata.sh \$resource "$irodspath" > existing_metadata.csv

    echo "Existing metadata for $irodspath:"
    cat existing_metadata.csv

    # Remove existing metadata if specified
    if [ "${task.ext.remove_existing_metadata}" == "true" ]; then
        echo "Removing existing metadata for $irodspath"
        while IFS=, read -r key value units; do
            if [[ -n "\$key" && -n "\$value" ]]; then
                echo "Removing key=\${key}, value=\${value}, units=\${units} from $irodspath metadata"
                imeta rm \$resource "$irodspath" "\$key" "\$value" "\$units"
            fi
        done < existing_metadata.csv
        :> existing_metadata.csv # clear file
    fi

    # Load metadata to iRODS
    echo "Current metadata for $irodspath:"
    get_metadata.sh \$resource "$irodspath"
    while IFS=\$'\\t' read -r key value; do
        [[ -z "\$key" || -z "\$value" ]] && continue  # skip empty lines

        # Check if the key value pair already exists in iRODS metadata
        if grep -qzP "\${key},\${value}" existing_metadata.csv; then
            echo "[SKIP] \$key=\$value already present"
        else
            echo "Adding \$key=\$value to iRODS metadata"
            imeta add \$resource "$irodspath" "\$key" "\$value"
        fi
    done < metadata.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        irods: \$(ienv | grep version | awk '{ print \$3 }')
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args
    
    touch ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        irods: \$(ienv | grep version | awk '{ print \$3 }')
    END_VERSIONS
    """
}
