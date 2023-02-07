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
		Int preempt = 1
		Boolean filter_na = true
	}
	Int disk_size = ceil(size(accessions_file, "GB")) * 2

	command <<<
	sort "~{accessions_file}" | uniq -u > unique.txt
	python3 << CODE
	import os
	f = open("unique.txt", "r")
	valid = []
	for line in (f.readlines()):
		if line == "":
			pass
		elif line == "NA" and "~{filter_na}" == "true":
			print("WARNING -- NA found")
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
		docker: "ashedpotatoes/sranwrp:1.1.6"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		Array[String] accessions = read_lines("valid.txt")
	}
}

task cat_files {
	# Concatenate Array[File] into a single File.
	#
	# Files going into removal_candidates should be formatted as TSVs
	# where the first column is the filename and the second column is
	# a float value. (Other columns will be ignored.) These TSVs will
	# be cat to create a single big TSV. Then, any values above the
	# user-input float removal_threshold will have their associated
	# file removed, preventing it from being cat'd.
	#
	# For example:
	# files = [SAMEA10030079.diff, SAMEA7555065.diff]
	# removal_candidates = [SAMEA10030079.report, SAMEA7555065.report]
	# removal_threshold = 0.02
	#
	# Let's say SAMEA10030079.report looked like this:
	# SAMEA10030079.diff	0.02230766998856633
	#
	# And SAMEA7555065.report looked like this
	# SAMEA7555065.diff	0.019289670799169087
	#
	# First, the reports would get cat into this:
	# SAMEA10030079	0.02230766998856633
	# SAMEA7555065	0.019289670799169087
	#
	# Then, the script would notice that SAMEA10030079 has a value above
	# the removal_threshold of 0.02, so it deletes the SAMEA10030079.diff
	# input. As a result, the final cat file will only consist of
	# SAMEA7555065.diff.

	input {
		Array[File] files
		Array[File]? removal_candidates
		Float removal_threshold = 0.05
		String out_filename = "all.txt"
		Int preempt = 1
		Boolean keep_only_unique_lines = false
		Boolean output_first_lines = true
		Boolean strip_first_line_first_char = true
	}
	Int disk_size = ceil(size(files, "GB")) * 2

	command <<<

	if [[ ! "~{sep=' ' removal_candidates}" = "" ]]
	then
		echo "Checking which files ought to not be included..."
		cat ~{sep=" " removal_candidates} >> removal_guide.tsv
		FILES=(~{sep=" " files})
		for FILE in "${FILES[@]}"
		do
			# check if it's in the removal guide and below threshold
			basename_file=$(basename "$FILE")
			this_files_info=$(awk -v file_to_check="$basename_file" '$1 == file_to_check' removal_guide.tsv)
			echo "$this_files_info" > temp
			if [[ ! "$this_files_info" = "" ]]
			then
				# okay, we have information about this file. is it above the removal threshold?
				this_files_value=$(cut -f2 temp)
				is_bigger=$(echo "$this_files_value>~{removal_threshold}" | bc)
				if [[ $is_bigger == 0 ]]
				then
					cat "$FILE" >> "~{out_filename}"

					# now, check if we're grabbing first lines
					if [[ "~{output_first_lines}" = "true" ]]
					then
						touch firstlines.txt
						if [[ "~{strip_first_line_first_char}" = "true" ]]
						then
							firstline=$(head -1 "$FILE")
							echo "${firstline:1}" >> firstlines.txt
						else
							head -1 "$FILE" >> firstlines.txt
						fi
					fi
				
				else
					# this is below the theshold
					echo "$basename_file's value of $this_files_value is below threshold. It won't be included."
				fi
			else
				echo "WARNING: Removal guide exists but can't find $basename_file in it! Skipping..."
			fi
		done
	else
		# no removal guide
		echo "No removal guide found"
		cat ~{sep=" " files} >> "~{out_filename}"
	fi

	if [[ "~{keep_only_unique_lines}" = "true" ]]
	then
		touch temp
		sort "~{out_filename}" | uniq -u >> temp
		rm "~{out_filename}"
		mv temp "~{out_filename}"
	fi
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.6"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		File outfile = "~{out_filename}"
		File? first_lines = "firstlines.txt"
		File? removal_guide = "removal_guide.tsv"
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