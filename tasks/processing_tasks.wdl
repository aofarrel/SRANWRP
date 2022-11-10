version 1.0

# These are tasks that synergize with the other tasks in this repo, but do not
# query SRA (or any other NCBI platform) directly.

task extract_accessions_from_file {
	# Convert txt file of a list of bioproject accessions, one accession
	# per newline (except for some blank lines), into an Array[String].
	# This allows us to work with NCBI web search's "send to file" output
	# more easily with WDLs. We can't just use WDL's built in "read_lines"
	# as the blank lines NCBI throws in would cause issues.

	input {
		# It doesn't matter if the input file is sorted by organism or 
		# uses NCBI's "default order." Either works.
		File bioprojects_file
		Int? preempt = 1
	}
	Int disk_size = ceil(size(bioprojects_file, "GB")) * 2

	command <<<
	python3.10 << CODE
	import os
	f = open("~{bioprojects_file}", "r")
	valid = []
	for line in (f.readlines()):
		if line == "":
			pass
		else:
			valid.append(line)
	f.close()
	os.system("touch valid.txt")
	g = open("valid.txt", "a")
	g.writelines(valid)
	g.close
	CODE
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.0.7"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		Array[String] bioproject_accessions = read_lines("valid.txt")
	}
}

task cat_files {
	# Concatenate Array[File] into a single File.

	input {
		Array[File] files
		String? out_filename = "all.txt"
		Int? preempt = 1
	}
	Int disk_size = ceil(size(files, "GB")) * 2

	command <<<

	touch ~{out_filename}
	cat ~{sep=" " files} >> ~{out_filename}

	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.0.7"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		File outfile = "~{out_filename}"
	}
}


