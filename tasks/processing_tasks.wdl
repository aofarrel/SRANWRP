version 1.0

# These are tasks that synergize with the other tasks in this repo, but do not
# query SRA (or any other NCBI platform) directly.

task extract_accessions_from_file {
	# Convert txt file of a list of bioproj/biosamp/run accessions, one accession
	# per newline (except for some blank lines), into an Array[String].
	# This allows us to work with NCBI web search's "send to file" output
	# more easily with WDLs. We can't just use WDL's built in "read_lines"
	# as the blank lines NCBI throws in would cause issues.
	#
	# This can also handle the situation where xtract gives us tab-seperated
	# accessions all on the same line.
	input {
		# It doesn't matter if the input file is sorted by organism or 
		# uses NCBI's "default order." Either works.
		File accessions_file
		Int? preempt = 1
	}
	Int disk_size = ceil(size(accessions_file, "GB")) * 2

	command <<<
	sort "~{accessions_file}" | uniq -u > unique.txt
	python3.10 << CODE
	import os
	f = open("unique.txt", "r")
	valid = []
	for line in (f.readlines()):
		if line == "":
			pass
		else:
			split = line.split("\t")
			for accession in split:
				valid.append(accession.strip("\n")+"\n")
	f.close()
	os.system("touch valid.txt")
	g = open("valid.txt", "a")
	g.writelines(valid)
	g.close()
	CODE
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.0"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		Array[String] accessions = read_lines("valid.txt")
	}
}

task cat_files {
	# Concatenate Array[File] into a single File.

	input {
		Array[File] files
		String? out_filename = "all.txt"
		Int? preempt = 1
		Boolean? keep_only_unique_lines = false
	}
	Int disk_size = ceil(size(files, "GB")) * 2

	command <<<

	touch ~{out_filename}
	cat ~{sep=" " files} >> ~{out_filename}

	if [[ "~{keep_only_unique_lines}" = "true" ]]
	then
		touch temp
		sort ~{out_filename} | uniq -u >> temp
		rm ~{out_filename}
		mv temp ~{out_filename}
	fi

	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.0.8"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		File outfile = "~{out_filename}"
	}
}


## This task removes invalid output from pull_from_SRA_accession.
## Array[Array[File]?] will return empty subarrays sometimes, such
## as with SRR11947402. We can handle that in later tasks, but why
## keep creating garbage instances of a scattered task when we can
## just call a single task to generate known output for us?
## Note: This relies on file-->string-->file coercion working...
#task take_names {
#	input {
#		Array[Array[File]] all_fastqs
#		Array[String] sra_accessions
#
#		Int disk_size = 50
#		Int preempt = 1
#	}
#
#	command <<<
#	python << CODE
#	print('~{sep="," sra_accessions}')
#	print('~{sep="," all_fastqs}')
#	CODE
#	>>>
#
#	runtime {
#		cpu: 4
#		disks: "local-disk " + disk_size + " SSD"
#		docker: "ashedpotatoes/sranwrp:1.0.8"
#		memory: "8 GB"
#		preemptible: preempt
#	}
#
#	#output {
#		#Array[Array[String]] good_fastqs
#		#Array[String] good_accessions
#	#}
#}