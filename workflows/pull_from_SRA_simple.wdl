version 1.0

import "../tasks/pull_fastqs.wdl" as pulltasks
#import "https://raw.githubusercontent.com/aofarrel/SRANWRP/main/tasks/pull_fastqs.wdl" as pulltasks

workflow SRA_YOINK {
	input {
		Array[String] sra_accessions

		# per iteration
		Int? disk_size = 100
		Int? preempt = 1
	}

	scatter(sra_accession in sra_accessions) {
		call pulltasks.pull_fq_from_SRA_accession as pull {
			input:
				sra_accession = sra_accession,
				disk_size = disk_size,
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