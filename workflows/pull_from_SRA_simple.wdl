version 1.0

import "../tasks/pull_from_SRA.wdl" as sratasks

workflow SRA_YOINK {
	input {
		Array[String] sra_accessions

		# per iteration
		Int? disk_size = 50
		Int? preempt = 1
	}

	scatter(sra_accession in sra_accessions) {
		call sratasks.pull_from_SRA_directly {
			input:
				sra_accession = sra_accession,
				disk_size = disk_size,
				preempt = preempt
		}
	}

}