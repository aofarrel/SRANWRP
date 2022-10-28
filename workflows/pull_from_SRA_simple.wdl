version 1.0

import "../tasks/pull_from_SRA.wdl" as sratasks
#import "https://raw.githubusercontent.com/aofarrel/SRANWRP/handle-odd-numbers/tasks/pull_from_SRA.wdl" as sratasks

workflow SRA_YOINK {
	input {
		Array[String] sra_accessions

		# per iteration
		Int? disk_size = 100
		Int? preempt = 1
	}

	scatter(sra_accession in sra_accessions) {
		call sratasks.pull_from_SRA_directly as pull {
			input:
				sra_accession = sra_accession,
				disk_size = disk_size,
				preempt = preempt
		}
		if(defined(pull.fastqs)) {
    		Array[File] paired_fastqs=select_all(pull.fastqs)
  		}
	}

	#call sratasks.take_names {
	#	input:
	#		all_fastqs = pull.fastqs,
	#		sra_accessions = pull.sra_accession_out
	#}

	output {
		Array[Array[File]?] all_fastqs = select_all(paired_fastqs)
		Array[Int] number_of_fastqs_per_accession = pull.num_fastqs
	}

}