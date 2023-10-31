version 1.0

# Pull FASTQs from a list of SRA Run accessions (SRR/ERR/DRR).
# Will only return paired FASTQs. Accessions that give only
# one FASTQ will be ignored, and accessions that give two paired
# reads + one additional FASTQ will only return the paired FASTQs.

import "../tasks/pull_fastqs.wdl" as pulltasks
#import "https://raw.githubusercontent.com/aofarrel/SRANWRP/main/tasks/pull_fastqs.wdl" as pulltasks

workflow SRA_YOINK {
	input {
		Array[String] sra_accessions

		# per iteration
		Int disk_size_GB = 100
		Int preempt = 1
	}

	scatter(sra_accession in sra_accessions) {
		call pulltasks.pull_fq_from_SRA_accession as pull {
			input:
				sra_accession = sra_accession,
				disk_size_GB = disk_size_GB,
				preempt = preempt
		}
		if(length(pull.fastqs)>1) {
    		Array[File] paired_fastqs=select_all(pull.fastqs)
  		}
	}

	output {
		Array[Array[File]] all_fastqs = select_all(paired_fastqs)
		Array[Int] number_of_fastqs_per_accession = pull.num_fastqs
	}

}