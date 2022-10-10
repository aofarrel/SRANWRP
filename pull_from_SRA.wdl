version 1.0

task pull_from_SRA {
	inputs {
		String accession

		Int? disk_size = 50
		Int? preempt = 1
	}

	task {
		fasterq-dump ~{accession}
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker:
		memory: 8
		preemptible: preempt
	}

	output {
		Array[File] fastqs = glob("*.fastq")
	}
}