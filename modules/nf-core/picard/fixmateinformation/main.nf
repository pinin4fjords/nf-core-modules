process PICARD_FIXMATEINFORMATION {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::picard=3.0.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/picard:3.0.0--hdfd78af_1' :
        'biocontainers/picard:3.0.0--hdfd78af_1' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.bam"), emit: bam
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def STRINGENCY = task.ext.stringency ?: "STRICT"
    def avail_mem = 3072
    if (!task.memory) {
        log.info '[Picard FixMateInformation] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }
    """
    picard \\
        FixMateInformation \\
        -Xmx${avail_mem}M \\
        --INPUT ${bam} \\
        --OUTPUT ${prefix}.bam \\
        --VALIDATION_STRINGENCY ${STRINGENCY}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        picard: \$(picard FixMateInformation --version 2>&1 | grep -o 'Version:.*' | cut -f2- -d:)
    END_VERSIONS
    """
}
