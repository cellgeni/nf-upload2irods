process IRODS_GETMETADATA {
    tag "Getting metadata for ${irodspath}"

    input:
    tuple val(meta), val(irodspath)

    output:
    tuple val(meta), path("irods_metadata.csv"), emit: csv
    path "versions.yml", emit: versions

    script:
    """
    set -euo pipefail

    # Check if irodspath exists
    name=\$(basename "${irodspath}")
    coll=\$(dirname "${irodspath}")
    if iquest --no-page "SELECT COLL_ID WHERE COLL_NAME = '${irodspath}'" | grep -q 'COLL_ID'; then
        resource="-C"
    elif iquest --no-page "SELECT DATA_ID WHERE COLL_NAME = '\$coll' AND DATA_NAME = '\$name'" | grep -q 'DATA_ID'; then
        resource="-d"
    else
        echo "Error: iRODS path ${irodspath} does not exist."
        exit 1
    fi

    # Get metadata from iRODS
    imeta ls \$resource ${irodspath} \
        | grep -E 'attribute|value|units' \
        | sed -e 's/^attribute: //' -e 's/^value: //' -e 's/^units: //' \
        | awk 'NR%3!=0 {printf "\\\"%s\\\",", \$0} NR%3==0 {printf "\\\"%s\\\"\\n", \$0}' > irods_metadata.csv
    
    cat <<-END_VERSIONS > versions.yml
    "":
        irods: \$(ienv | grep version | awk '{ print \$3 }')
        awk: \$(awk --version | head -n1)
        sed: \$(sed --version | head -n1 | awk '{ print \$4 }')
    END_VERSIONS
    """

    stub:
    """
    touch irods_metadata.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        irods: \$(ienv | grep version | awk '{ print \$3 }')
        awk: \$(awk --version | head -n1)
        sed: \$(sed --version | head -n1 | awk '{ print \$4 }')
    END_VERSIONS
    """
}
