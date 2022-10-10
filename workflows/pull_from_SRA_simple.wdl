version 1.0

import "./pull_from_SRA.wdl" as sratasks

workflow SRA_YOINK {
	inputs {
		String sra_accession

		# per iteration
		Int? disk_size = 50
		Int? preempt = 1
	}

	call sratasks.pull_from_SRA_directly

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker: "ashedpotatoes/sranwrp:1.0.0"
		memory: 8
		preemptible: preempt
	}

	output {
		Array[File] fastqs = glob("*.fastq")
	}
}