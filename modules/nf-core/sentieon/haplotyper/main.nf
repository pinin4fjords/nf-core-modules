process SENTIEON_HAPLOTYPER {
    tag "$meta.id"
    label 'process_medium'
    label 'sentieon'

    secret 'SENTIEON_LICENSE_BASE64'

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        exit 1, "Sentieon modules does not support Conda. Please use Docker / Singularity / Podman instead."
    }

    container 'nf-core/sentieon:202112.06'

    input:
    tuple val(meta), path(input), path(input_index), path(intervals)
    path  fasta
    path  fai
    path  dbsnp
    path  dbsnp_tbi
    val(emit_vcf)
    val(emit_gvcf)

    output:
    tuple val(meta), path("*.unfiltered.vcf.gz")    , optional:true, emit: vcf   // added the substring ".unfiltered" in the filename of the vcf-files since without that the g.vcf.gz-files were ending up in the vcf-channel
    tuple val(meta), path("*.unfiltered.vcf.gz.tbi"), optional:true, emit: vcf_tbi
    tuple val(meta), path("*.g.vcf.gz")             , optional:true, emit: gvcf   // these output-files have to have the extension ".vcf.gz", otherwise the subsequent GATK-MergeVCFs will fail.
    tuple val(meta), path("*.g.vcf.gz.tbi")         , optional:true, emit: gvcf_tbi
    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''    // options for the driver
    def args2 = task.ext.args2 ?: ''  // options for the vcf generation
    def args3 = task.ext.args3 ?: ''  // options for the gvcf generation
    def prefix = task.ext.prefix ?: "${meta.id}"
    def dbsnp_command = dbsnp ? "-d $dbsnp " : ""
    def interval_command = intervals ? "--interval $intervals" : ""
    def sentieon_auth_mech_base64 = task.ext.sentieon_auth_mech_base64 ?: ''
    def sentieon_auth_data_base64 = task.ext.sentieon_auth_data_base64 ?: ''
    def vcf_cmd = ""
    def gvcf_cmd = ""
    def base_cmd = '--algo Haplotyper ' + dbsnp_command

    if (emit_vcf) {  // emit_vcf can be the empty string, 'variant', 'confident' or 'all' but NOT 'gvcf'
        vcf_cmd = base_cmd + args2 + ' --emit_mode ' + emit_vcf + ' ' + prefix + '.unfiltered.vcf.gz'
    }

    if (emit_gvcf) { // emit_gvcf can be either true or false
        gvcf_cmd = base_cmd + args3 + ' --emit_mode gvcf ' + prefix + '.g.vcf.gz'
    }

    """
    if [ "\${#SENTIEON_LICENSE_BASE64}" -lt "1500" ]; then  # If the string SENTIEON_LICENSE_BASE64 is short, then it is an encrypted url.
        export SENTIEON_LICENSE=\$(echo -e "\$SENTIEON_LICENSE_BASE64" | base64 -d)
    else  # Localhost license file
        # The license file is stored as a nextflow variable like, for instance, this:
        # nextflow secrets set SENTIEON_LICENSE_BASE64 \$(cat <sentieon_license_file.lic> | base64 -w 0)
        export SENTIEON_LICENSE=\$(mktemp)
        echo -e "\$SENTIEON_LICENSE_BASE64" | base64 -d > \$SENTIEON_LICENSE
    fi

    if  [ ${sentieon_auth_mech_base64} ] && [ ${sentieon_auth_data_base64} ]; then
        # If sentieon_auth_mech_base64 and sentieon_auth_data_base64 are non-empty strings, then Sentieon is mostly likely being run with some test-license.
        export SENTIEON_AUTH_MECH=\$(echo -n "${sentieon_auth_mech_base64}" | base64 -d)
        export SENTIEON_AUTH_DATA=\$(echo -n "${sentieon_auth_data_base64}" | base64 -d)
        echo "Decoded and exported Sentieon test-license system environment variables"
    fi

    sentieon driver $args -r $fasta -t $task.cpus -i $input $interval_command $vcf_cmd $gvcf_cmd

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sentieon: \$(echo \$(sentieon driver --version 2>&1) | sed -e "s/sentieon-genomics-//g")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.unfiltered.vcf.gz
    touch ${prefix}.unfiltered.vcf.gz.tbi
    touch ${prefix}.g.vcf.gz
    touch ${prefix}.g.vcf.gz.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sentieon: \$(echo \$(sentieon driver --version 2>&1) | sed -e "s/sentieon-genomics-//g")
    END_VERSIONS
    """
}
