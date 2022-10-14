version 1.0

#import "../tasks/pull_from_SRA.wdl" as sratasks
import "https://raw.githubusercontent.com/aofarrel/SRANWRP/main/tasks/pull_from_SRA.wdl" as sratasks

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
	}

	output {
		Array[Array[File]] all_fastqs = pull.fastqs
	}

}