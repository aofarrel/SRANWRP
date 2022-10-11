version 1.0

# prefetch is not always required, but is good practice
task pull_from_SRA_directly {
	input {
		String sra_accession

		Int? disk_size = 50
		Int? preempt = 1
	}

	command {
		ls
		prefetch ~{sra_accession}
		fasterq-dump ~{sra_accession}
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker: "ashedpotatoes/sranwrp:1.0.1"
		memory: 8
		preemptible: preempt
	}

	output {
		Array[File] fastqs = glob("*.fastq")
	}
}

# NOTE: This hasn't been throughly tested. It is based on this gist:
# https://gist.github.com/dianalow/5223b77c05b9780c30c633cb255e9fb2
task pull_from_SRA_by_bioproject {
	input {
		String bioproject_accession

		Int? disk_size = 50
		Int? preempt = 1
	}

	command {
		esearch -db sra -query ~{bioproject_accession} | \
			efetch -format runinfo | \
			cut -d ',' -f 1 | \
			grep SRR | \
			xargs fastq-dump -X 10 --split-files
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker: "ashedpotatoes/sranwrp:1.0.1"
		memory: 8
		preemptible: preempt
	}

	output {
		Array[File] fastqs = glob("*.fastq")
	}
}