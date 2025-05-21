version 1.0

# These are tasks that synergize with the other tasks in this repo, but do not
# query SRA (or any other NCBI platform) directly.

task gather_files {
	# A final task for workflows with a lot of outputs across a lot of tasks
	# Useful for forcing miniwdl to put your outputs in a single folder
	input {
		Array[File] some_files
	}
	command <<<
	FILES=( ~{sep=' ' some_files} )
	for FILE in "${FILES[@]}"
	do
		mv "$FILE" .
	done
	>>>
	output {
		Array[File] the_same_files = glob("*")
	}
}

task write_csv {
	input {
		Array[String] headings
		Array[Array[String]] stuff_to_write
		Int lines_of_data = length(stuff_to_write)
		String outfile = "reports.csv"
		Boolean tsv = false
	}

	command <<<
	set -eux -o pipefail
	python << CODE
	
	sep="\t" if "~{tsv}" == "true" else ","
	
	def write_array(array)
		with open("~{outfile}", "a") as f:
			f.write(thing+sep for thing in array)
	
	write_array(["~{sep='","' headings}"])
	if ~{lines_of_data} == 1:
		write_array(["~{sep='","' stuff_to_write}[0]"])
	else:
		pass

	CODE
	>>>

	output {
		File finalOut = outfile
	}

	runtime {
		disks: "local-disk 10 HDD"
		docker: "python:3.12-slim"
		preemptible: 2
		memory: "8 GB"
	}
}

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
		Boolean sort_and_uniq = true
	}
	Int disk_size = ceil(size(accessions_file, "GB")) * 2

	command <<<
	if [[ "~{sort_and_uniq}" = "true" ]]
	then
		sort "~{accessions_file}" | uniq -u > likely_valid.txt
	else
		cp "~{accessions_file}" ./likely_valid.txt
	fi
	python3 << CODE
	import os
	f = open("likely_valid.txt", "r")
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

task cat_strings {
	# Concatenate Array[String] into a single File.

	input {
		Array[String] strings
		String out = "pull_reports.txt"
		Int disk_size = 10
	}

	command <<<
		printf "~{sep='\n' strings}" > "~{out}"
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.6"
		memory: "8 GB"
		preemptible: 2
	}

	output {
		File outfile = out
	}
}

task cat_files {
	# Concatenate Array[File] into a single File.
	#
	# Files going into removal_candidates should be formatted as TSVs
	# where the first column is the filename and the second column is
	# a float value. (Other columns will be ignored.) These TSVs will
	# be cat to create a single big TSV. Then, any values ABOVE the
	# user-input float removal_threshold will have their associated
	# file removed, preventing it from being cat'd. In other words,
	# this is a lowpass filter.
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
		Array[String]? overwrite_first_lines
		File? king_file
		File? king_file_first_lines
		
		String  first_lines_out_filename = "firstlines.txt"
		Boolean keep_only_unique_files = false
		Boolean keep_only_unique_lines = false
		Int     preempt = 1
		String  out_filename = "all.txt"
		Float   removal_threshold = 0.05
		Boolean strip_first_line_first_char = true
		Boolean verbose = false
		Int?    disk_size_override
	}
	Int disk_size = select_first([disk_size_override, ceil(size(files, "GB")) * 2])
	Int number_of_files = length(files)
	Boolean overwrite = defined(overwrite_first_lines)

	command <<<
	
	# check for valid inputs
	FILES=(~{sep=" " files})
	REPORTS=(~{sep= " " removal_candidates})
	OVERWRITES=(~{sep= " " overwrite_first_lines})
	
	if (( ${#REPORTS[@]} != 0 )) && (( ${#REPORTS[@]} != ${#FILES[@]} )); then echo "WARNING: Number of removal guides (${#REPORTS[@]}) doesn't match number of inputs (${#FILES[@]})"; fi
	if (( ${#OVERWRITES[@]} != 0 )) && (( ${#OVERWRITES[@]} != ${#FILES[@]} )); then echo "ERROR: Rename array (${#OVERWRITES[@]}) doesn't match number of input files (${#FILES[@]})" && exit 1; fi

	if [[ "~{keep_only_unique_files}" = "true" ]]
	then
		mapfile -t FILES < <(printf "%s\n" "${FILES[@]}" | awk -F'/' '!seen[$NF]++')
	fi

	fx_cat_and_firstlines () {
		# $1 is iteration (index), $2 is file
		if [[ "~{overwrite}" = "true" ]]
		then
			ITER=$1
			echo "${OVERWRITES[$ITER]}" >> "~{first_lines_out_filename}"
			echo ">${OVERWRITES[$ITER]}" >> "~{out_filename}"
			tail -n +2 "$2" >> "~{out_filename}"
			echo iter is "$ITER" and overwrite is "${OVERWRITES[$ITER]}" at this index
		elif [[ "~{overwrite}" = "false" && "~{strip_first_line_first_char}" = "true" ]]
		then
			firstline=$(head -1 "$2")
			echo "${firstline:1}" >> "~{first_lines_out_filename}"
			cat "$2" >> "~{out_filename}"
		else
			head -1 "$2" >> "~{first_lines_out_filename}"
			cat "$2" >> "~{out_filename}"
		fi
	}
	
	if [[ ! "~{sep=' ' removal_candidates}" = "" ]]
	then
		echo "Checking which files ought to not be included..."
		cat ~{sep=" " removal_candidates} >> removal_guide.tsv
		ITER=0
		for FILE in "${FILES[@]}"
		do
			# check if it's in the removal guide and below threshold
			basename_file=$(basename "$FILE")
			this_files_info=$(awk -v file_to_check="$basename_file" '$1 == file_to_check' removal_guide.tsv)
			baseroot_file=$(basename -s ".diff" "$FILE")
			echo "$this_files_info" > temp
			if [[ ! "$this_files_info" = "" ]]
			then
				# okay, we have information about this file. is it above the removal threshold?
				# piping an inequality to `bc` will return 0 if false, 1 if true
				this_files_value=$(cut -f2 temp)
				is_bigger=$(echo "$this_files_value>~{removal_threshold}" | bc) 
				if [[ $is_bigger == 0 ]]
				then
					# this_files_value is below the removal threshold and passes
					fx_cat_and_firstlines $ITER "$FILE"
					if [[ "~{verbose}" = "true" ]]
					then
						echo "$FILE added."
					fi
				
				else
					# this_files_value is above the removal threshold and fails
					echo "$baseroot_file" >> removed.txt
					echo "$basename_file's value of $this_files_value is above threshold. It won't be included."
				fi
			else
				echo "$baseroot_file" >> removed.txt
				echo "WARNING: Removal guide exists but can't find $basename_file in it! Skipping..."
			fi
			(( ITER++ ))
		done
	else
		# no removal guide, so we keep things simple
		echo "No removal guide found, so we'll add all the files we have to the outfile..."

		# output first lines
		ITER=0
		for FILE in "${FILES[@]}"
		do
			fx_cat_and_firstlines $ITER "$FILE"
			(( ITER++ ))
		done
	fi

	if [[ "~{keep_only_unique_lines}" = "true" ]]
	then
		echo "Sorting and removing non-unique lines..."
		touch temp
		sort "~{out_filename}" | uniq -u >> temp
		rm "~{out_filename}"
		mv temp "~{out_filename}"
	fi

	if [[ ! -f "~{out_filename}" ]]
	then
		printf "\n\n\n ========================= "
		echo "ERROR: Could not locate cat'd file. This probably means either: "
		echo "a) nothing passed the removal threshold (remember, it's a lowpass, not a highpass)"
		echo "b) you didn't actually pass any files in, just an empty array"
		echo "It looks like you tried to merge ~{number_of_files} files."
		if [[ -f removed.txt ]]
		then
			echo "removal.txt doesn't seem to exist, so this looks like option B."
			echo "This task will now exit with an error."
			return 1
		else
			echo "$(number_of_removed_files) files were removed for being below the threshold, or not having removal candidate data."
			echo "The contents of removal.txt will be printed below and this task will then exit with an error."
			cat removed.txt
			return 1
		fi
	fi

	if [[ -f removed.txt ]]
	then
		# count how many samples were removed
		# wc acts differently on different OS, this is most portable way I've found
		number_of_removed_files="$(wc -l removed.txt | awk '{print $1}')"
		echo "$number_of_removed_files" >> number_of_removed_files.txt
	else
		# no samples were removed
		# make sure removed.txt and number_of_removed_files.txt exist so WDL doesn't crash
		touch removed.txt
		number_of_removed_files=0
		echo "$number_of_removed_files" >> number_of_removed_files.txt
	fi


	if [[ ! "~{king_file}" = "" ]]
	then
		cat "~{out_filename}" "~{king_file}" > temp
		rm "~{out_filename}"
		mv temp "~{out_filename}"
	fi

	if [[ ! "~{king_file_first_lines}" = "" ]]
	then
		cat "~{first_lines_out_filename}" "~{king_file_first_lines}" > temp
		rm "~{first_lines_out_filename}"
		mv temp "~{first_lines_out_filename}"
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
		Int files_removed = read_int("number_of_removed_files.txt")
		Int files_input = number_of_files
		Int files_passed = number_of_files - read_int("number_of_removed_files.txt")
		Array[String] removed_files = read_lines("removed.txt")
		File? first_lines = first_lines_out_filename
		File? removal_guide = "removal_guide.tsv"
	}
}

task compare_files {
	# NOTE: This modifies an input file
	input {
		File query_file
		File pull_report
	}

	command <<<
	python3 << CODE
	import re
	from difflib import Differ
	pull_sample_minues_status = []
	with open("~{pull_report}", "r") as pull_file_read:
		for line in pull_file_read.readlines():
			subbed=re.sub(": .*", "", line)
			print(f"changing {line} to {subbed}")
			pull_sample_minues_status.append(subbed)
	with open("~{pull_report}", "w") as pull_file_write:
		pull_file_write.writelines(pull_sample_minues_status)
	with open("~{query_file}", "r") as query_file, open("~{pull_report}", "r") as pull_file:
		differ = Differ()
		with open("difference.txt", "w") as difference:
			for line in differ.compare(query_file.readlines(), pull_file.readlines()):
				difference.write(line)
	CODE
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + 10 + " HDD"
		docker: "ashedpotatoes/sranwrp:1.1.8"
		memory: "8 GB"
		preemptible: 2
	}

	output {
		File difference = "difference.txt"
	}
}

task map_to_tsv_or_csv {
	input {
		Map[String, String] the_map
		String outfile = "something"
		Array[String] column_names = ["values"] # probably should only ever be one value
		Boolean csv = true
		Boolean ordered = true
		Boolean transpose = true
		Boolean round = true
	}
	
	# TODO: make the values column the name of the sample or something
	
	command <<<
	mv ~{write_map(the_map)} map.tsv
	cat map.tsv
	if [[ "~{ordered}" == "true" ]]
	then
		sort -o map.tsv map.tsv
	fi
	python3 << CODE
	import pandas
	raw = pandas.read_csv("map.tsv", sep='\t', index_col=0, names=["~{sep='' column_names}"])
	raw.fillna("N/A", inplace=True)  # necessary b/c Pandas thinks "NA" is NaN and then leaves a black space in CSV
	
	def round_values(x):
		# will be performed on every member of the "values" column iff round is true
		try:
			rounded = round(float(x), 2)
			if rounded.is_integer():
				return int(x)
			else:
				return rounded
		except ValueError:  # string
			return x
	
	if "~{round}" == "true":
		raw = raw.map(round_values)
	
	if "~{transpose}" == "true":
		transposed = raw.T
		print(transposed)
		if "~{csv}" == "true":
			transposed.to_csv("~{outfile}.csv")
		else:
			transposed.to_csv("~{outfile}.tsv", sep='\t')
	else:
		if "~{csv}" == "true":
			raw.to_csv("~{outfile}.csv")
		else:
			raw.to_csv("~{outfile}.tsv", sep='\t')
	CODE
	
	>>>
	
	runtime {
		cpu: 4
		disks: "local-disk " + 10 + " HDD"
		docker: "ashedpotatoes/sranwrp:1.1.15"
		memory: "8 GB"
		preemptible: 2
	}

	output {
		File tsv_or_csv = glob(outfile+"*")[0]
		File? debug_map = "map.tsv"
	}
}

task several_arrays_to_tsv {
	input {
		Array[String] row_keys
		Array[String] column_keys
		Array[Float] value1
		Array[Float] value2
		Array[Int] value3
		Array[Float] value4
		Array[Float] value5
		Array[Float] value6
		Array[Float] value7
		Array[Int] value8
		Array[Int] value9
		Array[Int] value10
		Array[Int] value11
		Array[String] value12
		Array[String] value13
		String output_filename = "qc_report.tsv"
	}

	command <<<
	VALUE12_WITH_SPACES="~{sep='~' value12}"  # yes, we are delimiting with a tilde
	VALUE13_WITH_SPACES="~{sep='~' value13}"

	# shellcheck disable=SC2001
	VALUE12_NO_WHITESPACE=$(echo "$VALUE12_WITH_SPACES" | sed 's/[[:space:]]/_/g')
	# shellcheck disable=SC2001
	VALUE12_NO_COMMAS_NOR_WHITESPACE=$(echo "$VALUE12_NO_WHITESPACE" | sed 's/,//g')
	IFS="~" read -r -a VALUE12_FIXED <<< "$VALUE12_NO_COMMAS_NOR_WHITESPACE"
	# shellcheck disable=SC2001
	VALUE13_NO_WHITESPACE=$(echo "$VALUE13_WITH_SPACES" | sed 's/[[:space:]]/_/g')
	# shellcheck disable=SC2001
	VALUE13_NO_COMMAS_NOR_WHITESPACE=$(echo "$VALUE13_NO_WHITESPACE" | sed 's/,//g')
	IFS="~" read -r -a VALUE13_FIXED <<< "$VALUE13_NO_COMMAS_NOR_WHITESPACE"

	# verbose debugging stuff
	echo "Converted ''$VALUE13_WITH_SPACES'' --> ''$VALUE13_NO_WHITESPACE'' --> ''$VALUE13_NO_COMMAS_NOR_WHITESPACE'' "
	declare -p VALUE12_FIXED
	declare -p VALUE13_FIXED

	ROWS=( ~{sep=' ' row_keys} )
	COLUMNS=( ~{sep=' ' column_keys} )
	VALUE1=( ~{sep=' ' value1} )
	VALUE2=( ~{sep=' ' value2} )
	VALUE3=( ~{sep=' ' value3} )
	VALUE4=( ~{sep=' ' value4} )
	VALUE5=( ~{sep=' ' value5} )
	VALUE6=( ~{sep=' ' value6} )
	VALUE7=( ~{sep=' ' value7} )
	VALUE8=( ~{sep=' ' value8} )
	VALUE9=( ~{sep=' ' value9} )
	VALUE10=( ~{sep=' ' value10} )
	VALUE11=( ~{sep=' ' value11} )

	TARGET_LENGTH=${#ROWS[@]}
	NUMBER_OF_COLUMN_HEADERS=${#COLUMNS[@]}
	EVERYTHING_ELSE=("ROWS" "VALUE1" "VALUE2" "VALUE3" "VALUE4" "VALUE5" "VALUE6" "VALUE7" "VALUE8" "VALUE9" "VALUE10" "VALUE11" "VALUE12_FIXED" "VALUE13_FIXED")

	# shellcheck disable=SC2086
	if [ ${#EVERYTHING_ELSE[@]} -ne $NUMBER_OF_COLUMN_HEADERS ]
	then
		echo "Number of columns (${#EVERYTHING_ELSE[@]}) doesn't match number of column headers ($NUMBER_OF_COLUMN_HEADERS)"
		exit 1
	fi

	for array_name in "${EVERYTHING_ELSE[@]}"
	do
		declare -n array="$array_name"  # nameref the actual array, requires bash > 4.3
		if [ ${#array[@]} -ne "$TARGET_LENGTH" ]
		then
			printf "%s" "ERROR: $array_name has length ${#array[@]} but our target length is $TARGET_LENGTH"
			exit 1
		fi
	done

	for ((i=0; i<NUMBER_OF_COLUMN_HEADERS; i++))
	do
		# this will leave a trailing tab but I think we can live with that
		echo -e -n "${COLUMNS[i]}\t" >> "~{output_filename}"
	done

	# psych! we can't live with a trailing tab! it bothers me too much!
	truncate -s-1 "~{output_filename}" && echo >> "~{output_filename}"

	for ((i=0; i<TARGET_LENGTH; i++))
	do
		echo -e "${ROWS[i]}\t${VALUE1[i]}\t${VALUE2[i]}\t${VALUE3[i]}\t${VALUE4[i]}\t${VALUE5[i]}\t${VALUE6[i]}\t${VALUE7[i]}\t${VALUE8[i]}\t${VALUE9[i]}\t${VALUE10[i]}\t${VALUE11[i]}\t${VALUE12_FIXED[i]}\t${VALUE13_FIXED[i]}" >> "~{output_filename}"
	done

	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + 10 + " HDD"
		docker: "ashedpotatoes/sranwrp:1.1.15"
		memory: "8 GB"
		preemptible: 2
	}

	output {
		File tsv = output_filename
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
