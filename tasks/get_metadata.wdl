version 1.0

task get_biosample_accession_ID_from_SRA {
	# Given an SRA accession, get its BioSample accession
	input {
		String sra_accession
		Int? preempt = 1
		Int? disk_size = 50
	}

	command {
		esearch -db sra -query ~{sra_accession} | \
			elink -target biosample | esummary | \
			xtract -pattern DocumentSummary -element Accession >> biosample.txt
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.0.7"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		File accession_as_file = "biosample.txt"
		String accession = read_string("biosample.txt")
	}
}

task get_SRA_accession_IDs_by_biosample {
	# Given a BioSample accession, get its SRA accession(s) -- but don't pull any fqs.
	input {
		String biosample_accession
		Int? preempt = 1
		Int? disk_size = 50
	}

	command {
		esearch -db biosample -query ~{biosample_accession} | \
			elink -target sra | \
			efetch -format docsum | \
			xtract -pattern DocumentSummary -ACC @acc -block DocumentSummary -element "&ACC" >> ~{biosample_accession}.txt
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.0.7"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		File accessions_as_file = "~{biosample_accession}.txt"
		# We cannot use WDL built-in read_lines() to get an Array[File] here,
		# because there tends to be blank lines in the output.
		# Use extract_accessions_from_file from processing_tasks.wdl instead!
	}
}

task get_SRA_accession_IDs_by_bioproject {
	# Given a BioProject accession, get its SRA accession(s) -- but don't pull any fqs
	input {
		String bioproject_accession
		Int? preempt = 1
		Int? disk_size = 50
	}

	command {
		esearch -db bioproject -query ~{bioproject_accession} | \
			elink -target sra | \
			efetch -format docsum | \
			xtract -pattern DocumentSummary -element Run@acc >> ~{bioproject_accession}.txt
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.0.7"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		File accessions_as_file = "~{bioproject_accession}.txt"
		# We cannot use WDL built-in read_lines() to get an Array[File] here,
		# because there tends to be blank lines in the output.
		# Use extract_accessions_from_file from processing_tasks.wdl instead!
	}
}


task get_all_accession_IDs_by_bioproject {
	# Given a BioProject accession, get ALL of its accessions 
	# eg: SRS000422 (which has three SRAs attached to it) returns the following:
	# SRA001011	SRX000306	SRP000179	SRS000422	SRR001703	SRR001704	SRR001705
	# Based on https://github.com/NCBI-Hackathons/EDirectCookbook/issues/9
	input {
		String bioproject_accession
		Int? preempt = 1
		Int? disk_size = 50
	}

	command {
		esearch -db bioproject -query ~{bioproject_accession} | \
			elink -target sra | \
			efetch -format docsum | \
			xtract -pattern DocumentSummary -ACC @acc -block DocumentSummary -element "&ACC" >> ~{bioproject_accession}.txt
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.0.7"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		File accessions_as_file = "~{bioproject_accession}.txt"
		# We cannot use WDL built-in read_lines() to get an Array[File] here,
		# because there tends to be blank lines in the output.
		# Use extract_accessions_from_file from processing_tasks.wdl instead!
	}
}

task get_organism_per_SRA_accession_from_bioproject {
	# Based on https://www.biostars.org/p/411975/#412033
	# Example: Input "PRJNA46769" --> one line file:
	# SRR039106	748227	Mycobacterium tuberculosis 210_8C6
	#
	# Note that some projects such as "PRJEB21680" would
	# instead result in a file with about 12,000 lines, since
	# it links to about 12,000 SRA accessions of many
	# different species (even though most are S. pneumoniae)
	input {
		String bioproject_accession
		Int? preempt = 1
		Int? disk_size = 50
	}

	command {
		esearch -db sra -query ~{bioproject_accession} | \
			esummary | \
			xtract -pattern DocumentSummary -element Run@acc,Organism@taxid,Organism@ScientificName >> ~{bioproject_accession}_organisms.txt 
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.0.7"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		File organisms_and_SRA_accessions = "~{bioproject_accession}_organisms.txt"
	}
}