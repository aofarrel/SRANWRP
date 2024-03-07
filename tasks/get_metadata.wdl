version 1.0

task get_biosample_accession_ID_from_SRA {
	# Given an SRA accession, get its BioSample accession
	input {
		String sra_accession
		Int preempt = 1
		Int disk_size = 50
		Boolean fail_if_sample_groups = true
	}

	command {
		esearch -db sra -query ~{sra_accession} | \
			elink -target biosample | esummary | \
			xtract -pattern DocumentSummary -element Accession >> biosample.txt

		if [[ "~{fail_if_sample_groups}" == "true" ]]
		then
			words=$(wc -l "biosample.txt")
			if [[ ! "$words" == "1 biosample.txt" ]]
			then
				echo "More than one biosample associated with ~{sra_accession}."
				exit 1
			fi
		fi
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker: "ashedpotatoes/sranwrp:1.0.8"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		File accession_as_file = "biosample.txt"
		String accession = read_string("biosample.txt")
	}
}

task get_biosample_accession_IDs_from_SRA {
	# Given multiple SRA accessions, get a bunch of BioSample accessions
	# It is more resource-efficient to run this instead of the above task
	# in a scatter, but this task might obscure which accessions come from
	# which sample due to deleting duplicate samples.
	# Note that this does not check if multiple samples return for a given run!
	input {
		Array[String] sra_accessions
		Int preempt = 1
		Int disk_size = 50
	}

	command <<<
		touch biosamples.txt
		for SRR in ~{sep=' ' sra_accessions}
		do
			esearch -db sra -query "$SRR" | \
			elink -target biosample | esummary | \
			xtract -pattern DocumentSummary -element Accession >> biosamples.txt
		done
		sort biosamples.txt | uniq -u >> biosamples_unique.txt
		
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker: "ashedpotatoes/sranwrp:1.1.0"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		File accessions_as_file = "biosamples_unique.txt"
	}
}

task get_SRA_accession_IDs_by_biosample_classic {
	# Given a BioSample accession, get its SRA accession(s) -- but don't pull any fqs.
	# BEWARE: elink is unreliable these days
	input {
		String biosample_accession
		Int preempt = 1
		Int disk_size = 10
	}

	command {
		esearch -db biosample -query ~{biosample_accession} | \
			elink -target sra | \
			efetch -format docsum | \
			xtract -pattern DocumentSummary -ACC @acc -block DocumentSummary -element "&ACC" >> ~{biosample_accession}.txt
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker: "ashedpotatoes/sranwrp:1.0.8"
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

task get_SRA_accession_IDs_by_biosample_new {
	# Given a BioSample accession, get its SRA accession(s) -- but don't pull any fqs.
	# This avoid using elink and should be more reliable
	input {
		String biosample_accession
		Int disk_size = 10
		Int preempt = 2
	}

	parameter_meta {
    	biosample_accession: "BioSample accession to query run accesions for"
    	disk_size:           "Size, in GB, of disk (acts as a limit on GCP)"
    	preempt:             "Number of times to attempt task on a preemptible VM (GCP only)"
	}

	command <<<
		echo "~{biosample_accession}" >> ~{biosample_accession}_accessions.txt
		SRRS_STR=$(esearch -db sra -query ~{biosample_accession} | \
			esummary | xtract -pattern DocumentSummary -element Run@acc)
		read -ra SRRS_ARRAY -d ' ' <<<"$SRRS_STR"
		for SRR in "${SRRS_ARRAY[@]}"
		do
			echo "        $SRR" >> "~{biosample_accession}"_accessions.txt
		done
		>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker: "ashedpotatoes/sranwrp:1.1.6"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		# This output takes a similar format to the string output of pull_fastqs.wdl's DL task
		String results = read_string("~{biosample_accession}_accessions.txt")
	}
}

task get_SRA_accession_IDs_by_bioproject {
	# Given a BioProject accession, get its SRA accession(s) -- but don't pull any fqs
	input {
		String bioproject_accession
		Int preempt = 1
		Int disk_size = 50
	}

	command {
		esearch -db bioproject -query ~{bioproject_accession} | \
			elink -target sra | \
			efetch -format docsum | \
			xtract -pattern DocumentSummary -element Run@acc >> ~{bioproject_accession}.txt
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker: "ashedpotatoes/sranwrp:1.0.8"
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

task get_BioSample_accession_IDs_by_bioproject {
	# Given a BioProject accession, get its BioSample accession(s) -- but don't pull any fqs
	input {
		String bioproject_accession
		Int preempt = 1
		Int disk_size = 50
	}

	command {
		esearch -db bioproject -query ~{bioproject_accession} | \
			elink -target sra | \
			efetch -format docsum | \
			xtract -pattern DocumentSummary -element Sample@acc >> ~{bioproject_accession}.txt
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker: "ashedpotatoes/sranwrp:1.0.8"
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
		Int preempt = 1
		Int disk_size = 50
	}

	command {
		esearch -db bioproject -query ~{bioproject_accession} | \
			elink -target sra | \
			efetch -format docsum | \
			xtract -pattern DocumentSummary -ACC @acc -block DocumentSummary -element "&ACC" >> ~{bioproject_accession}.txt
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker: "ashedpotatoes/sranwrp:1.0.8"
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
		Int preempt = 1
		Int disk_size = 10
	}

	command {
		esearch -db sra -query ~{bioproject_accession} | \
			esummary | \
			xtract -pattern DocumentSummary -element Biosample,Run@acc,Organism@taxid,Organism@ScientificName >> ~{bioproject_accession}_organisms.txt 
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker: "ashedpotatoes/sranwrp:1.0.8"
		memory: "4 GB"
		preemptible: preempt
	}

	output {
		File organisms_and_SRA_accessions = "~{bioproject_accession}_organisms.txt"
	}
}

task get_organism_per_biosample_single {
	input {
		String biosample_accession
		Int preempt = 1
		Int disk_size = 10
	}

	command {
		esearch -db sra -query ~{biosample_accession} | \
			esummary | \
			xtract -pattern DocumentSummary -element Biosample,Run@acc,Organism@taxid,Organism@ScientificName >> ~{biosample_accession}_organisms.txt 
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker: "ashedpotatoes/sranwrp:1.0.8"
		memory: "4 GB"
		preemptible: preempt
	}

	output {
		File organisms_and_SRA_accessions = "~{biosample_accession}_organisms.txt"
	}
}

task get_organism_per_biosample_multiple {
	input {
		Array[String] biosample_accessions
		Int preempt = 1
		Int disk_size = 10
	}

	command <<<
		python3.10 << CODE
		import subprocess
		accessions = ['~{sep="','" biosample_accessions}']
		outs = []
		subprocess.check_output(["touch organisms.txt"], shell=True)
		for accession in accessions:
			esearch = subprocess.Popen(["esearch", "-db", "sra", "-query", f"{accession}"], stdout=subprocess.PIPE)
			esummary = subprocess.Popen("esummary", stdin=esearch.stdout, stdout=subprocess.PIPE)
			xtract = subprocess.check_output(["xtract", "-pattern", "DocumentSummary", "-element", "Biosample,Run@acc,Organism@taxid,Organism@ScientificName"], stdin=esummary.stdout, text=True)
			outs.append(xtract)
		with open('organisms.txt', 'w') as f:
			for out in outs:
				f.write("%s" % out)
		CODE
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " HDD"
		docker: "ashedpotatoes/sranwrp:1.0.8"
		memory: "4 GB"
		preemptible: preempt
	}

	output {
		File organisms_and_SRA_accessions = "organisms.txt"
	}
}