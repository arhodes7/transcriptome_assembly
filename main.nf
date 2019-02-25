#!/usr/bin/env nextflow


/* 
 * Define the pipeline parameters
 *
 */

// Pipeline version
version = '0.1'

params.help            = false
params.resume          = false

log.info """

╔╗ ┬┌─┐┌─┐┌─┐┬─┐┌─┐╔═╗╦═╗╔═╗  ╔╦╗┬─┐┌─┐┌┐┌┌─┐┌─┐┬─┐┬┌─┐┌┬┐┌─┐┌┬┐┌─┐  ╔═╗┌─┐┌─┐┌─┐┌┬┐┌┐ ┬ ┬ ┬
╠╩╗││ ││  │ │├┬┘├┤ ║  ╠╦╝║ ╦   ║ ├┬┘├─┤│││└─┐│  ├┬┘│├─┘ │ │ ││││├┤   ╠═╣└─┐└─┐├┤ │││├┴┐│ └┬┘
╚═╝┴└─┘└─┘└─┘┴└─└─┘╚═╝╩╚═╚═╝   ╩ ┴└─┴ ┴┘└┘└─┘└─┘┴└─┴┴   ┴ └─┘┴ ┴└─┘  ╩ ╩└─┘└─┘└─┘┴ ┴└─┘┴─┘┴ 
                                                                                       
====================================================
BIOCORE@CRG Transcriptome Assembly - N F  ~  version ${version}
====================================================
pairs                               : ${params.pairs}
email                               : ${params.email}
minsize (after filtering)           : ${params.minsize}
orientation (RF or FR)              : ${params.orientation}
genetic code                        : ${params.geneticode}
output (output folder)              : ${params.output}
blastDB (uniprot or uniRef90)       : ${params.blastDB}
pfamDB (pfam database path)         : ${params.pfamDB}
minProtSize (minimum protein sized) : ${params.minProtSize}
batchseq                            : ${params.batchseq}
"""

if (params.help) exit 1
if (params.resume) exit 1, "Are you making the classical --resume typo? Be careful!!!! ;)"
if (params.orientation != "RF" && params.orientation != "FR")  exit 1, "Orientation not allowed. Only FR or RF" 

minContigSize   = (params.minProtSize*3)
outputfolder    = "${params.output}"
outputQC        = "${outputfolder}/QC"
outputTrimmed   = "${outputfolder}/trimmedReads"
outputMultiQC   = "${outputfolder}/multiQC"
outputMapping   = "${outputfolder}/Alignments"
outputAssembly  = "${outputfolder}/Assembly"
outputAnnotation= "${outputfolder}/Annotation"

util_scripts_image_path = "/usr/local/bin/trinityrnaseq/util/"
support_scripts_image_path = "${util_scripts_image_path}/support_scripts"


/*
 * Creates the `read_pairs` channel that emits for each read-pair a tuple containing
 * three elements: the pair ID, the first read-pair file and the second read-pair file
 */
Channel
    .fromFilePairs( params.pairs )                                             
    .ifEmpty { error "Cannot find any reads matching: ${params.pairs}" }  
    .into { read_pairs; raw_reads_for_trimming; raw_reads_for_assembly }

Channel
    .fromPath( params.pairs )
    .set{ reads_for_fastqc }                                           


/*
 * Run FastQC on raw data
*/
process QConRawReads {
    publishDir outputQC
    tag { read }

    input:
    file(read) from reads_for_fastqc

    output:
    file("*_fastqc.*") into raw_fastqc_files

    script:
    def qc = new QualityChecker(input:read, cpus:task.cpus)
    qc.fastqc()
}

 /*
 * Trim reads with skewer (optional). Make empty channels for multiQC
 */
process trimReads {
    publishDir outputTrimmed
    tag { pair_id }

    input:
    set pair_id, file(reads) from (raw_reads_for_trimming )

    output:
    set val("pair1"), file("*-trimmed-pair1.fastq.gz") into trimmed_pair1_for_assembly
    set val("pair2"), file("*-trimmed-pair2.fastq.gz") into trimmed_pair2_for_assembly
    file("*trimmed*.fastq.gz") into filtered_read_for_QC
    file("*trimmed.log") into logTrimming_for_QC
     
    script:
    def trimmer = new Trimmer(reads:reads, id:pair_id, min_read_size:params.minsize, cpus:task.cpus)
    trimmer.trimWithSkewer()
}

process fastqcTrim {
    tag { filtered_read }
    publishDir outputQC

 	afterScript 'mv *_fastqc.zip `basename *_fastqc.zip _fastqc.zip`_sel_fastqc.zip'

    input:
    file(filtered_read) from filtered_read_for_QC.flatten()

    output:
    file("*_sel_fastqc.zip") into trimmed_fastqc_files

    script:
    def qc = new QualityChecker(input:filtered_read, cpus:task.cpus)
    qc.fastqc()
}


process TrinityStep1 {
    label 'big_mem_cpus'
    
    input:
    set val(pair1), file(pair1) from trimmed_pair1_for_assembly.groupTuple()
    set val(pair2), file(pair2) from trimmed_pair2_for_assembly.groupTuple()

    output:
    file ("trinity_out_dir/read_partitions/*/*/*.trinity.reads.fa") into single_read_partitions
    
    script:
    def pair1_list = pair1.join(',')
    def pair2_list = pair2.join(',')
    """
    Trinity --min_contig_length ${minContigSize} --seqType fq --max_memory ${task.memory.giga}G --left ${pair1_list} --right ${pair2_list} --CPU ${task.cpus} --no_distributed_trinity_exec
    """
}


process TrinityStep2 {
    tag { partition_file }
    
    input:
    file(partition_file) from single_read_partitions.flatten()

    output:
    file ("${partition_file}.out.Trinity.fasta") optional true into components
    
    script:
    """
    Trinity --single ${partition_file} --output ${partition_file}.out --CPU 1 --max_memory ${task.memory.giga}G --run_as_paired --seqType fa --trinity_complete --full_cleanup --no_distributed_trinity_exec
    """
}

process collectTrinityRes {
    publishDir outputAssembly, mode: 'copy', pattern: "Trinity.fasta*"
    
    input:
    file("*") from components.collect()

    output:
    file ("Trinity.fasta") into (transcripts, transcripts_for_prediction)
    
    script:
    """
    cat *.fasta >> Trinity.fasta
    ${support_scripts_image_path}/get_Trinity_gene_to_trans_map.pl Trinity.fasta >  Trinity.fasta.gene_trans_map
    ${util_scripts_image_path}/TrinityStats.pl Trinity.fasta > Trinity.fasta.stat
    """
}

process TransDecoder {
    publishDir outputAssembly, mode: 'copy', pattern: "longest*"
    
    input:
    file(transcripts)

    output:
    file ("longest_orfs.pep") into (orfs_for_blastp, orfs_for_pfam)
    file ("${transcripts}.transdecoder_dir") into transdecoder_dir
    
    script:
    """
	TransDecoder.LongOrfs -m ${params.minProtSize} -t ${transcripts} -G ${params.geneticode} -S 
	cp ${transcripts}.transdecoder_dir/longest* .
    """
}

process blastP {  
    tag "$orf_batches"  
    input:
    file(orf_batches) from orfs_for_blastp.splitFasta( by: params.batchseq, file: true )

    output:
    file ("blastp.outfmt6") into blastout
    
    // fixing the --max_target_seqs problem
    script:
    """
    blastp -query ${orf_batches} -db ${params.blastDB} \
    -outfmt 6 -evalue 1e-5 -num_threads ${task.cpus} | awk 'BEGIN{print \$0;id=\$1}{if (id!=\$1){print \$0; id=\$1} }' > blastp.outfmt6
    """
}


process concatenateBlastRes {    
    publishDir outputAnnotation, mode: 'copy'
    input:
    file("blastres*") from blastout.collect()

    output:
    file ("blastp.all.results") into blastoutall

    script:
    """
    cat blastres* >> blastp.all.results
    """
}

process pfam_search {  
    tag "$orf_batches" 
     
    input:
    file(orf_batches) from orfs_for_pfam.splitFasta( by: params.batchseq, file: true )

    output:
    file ("pfam.domtblout") into pfamout
    
    script:
    """
    hmmscan --cpu ${task.cpus} --domtblout pfam.domtblout ${params.pfamDB} ${orf_batches}
    """
}

process concatenatePfamRes {    
    publishDir outputAnnotation, mode: 'copy'

    input:
    file("pfamout*") from pfamout.collect()

    output:
    file ("pfamout.all.results") into pfamoutall

    script:
    """
    cat pfamout* >> pfamout.all.results
    """
}

process transcoderPredict {    
    publishDir outputAnnotation, mode: 'copy'
    label 'temp'

    input:
    file(blastoutall)
    file(pfamoutall)
    file(transcripts_for_prediction)
    file(transdecoder_dir)

    output:
    set file("Trinity.fasta.transdecoder.bed"), file("Trinity.fasta.transdecoder.cds"), file("Trinity.fasta.transdecoder.gff3"), file("Trinity.fasta.transdecoder.pep") into finalRes

    script:
    """
    TransDecoder.Predict --no_refine_starts -G ${params.geneticode} -t ${transcripts_for_prediction} --retain_pfam_hits ${pfamoutall} --retain_blastp_hits ${blastoutall}
    """
}


/*
* send mail

workflow.onComplete {
    def subject = 'Transcriptome assembly execution'
    def recipient = "${params.email}"
    def attachment = "${outputMultiQC}/multiqc_report.html"

    ['mail', '-s', subject, '-a', attachment, recipient].execute() << """

    Pipeline execution summary
    ---------------------------
    Completed at: ${workflow.complete}
    Duration    : ${workflow.duration}
    Success     : ${workflow.success}
    workDir     : ${workflow.workDir}
    exit status : ${workflow.exitStatus}
    Error report: ${workflow.errorReport ?: '-'}
    """
}
*/



