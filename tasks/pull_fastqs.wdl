version 1.0

task pull_fq_from_SRA_accession {
	input {
		String sra_accession

		Boolean fail_on_invalid = false
		Int subsample_cutoff = 450
		Int subsample_seed = 1965

		Int disk_size = 100
		Int preempt = 1	
	}

	parameter_meta {
    	sra_accession:     "SRA run accession (NOT BioSample!) to pull fastqs from - can be SRR, ERR, etc"
    	disk_size:         "Size, in GB, of disk (acts as a limit on GCP)"
    	fail_on_invalid:   "Error (instead of exit 0 with null output) if output invalid"
    	preempt:           "Number of times to attempt task on a preemptible VM (GCP only)"
    	subsample_cutoff:  "If a fastq > this value in MB, the fastq will be subsampled (set to -1 to disable)"
    	subsample_seed:    "Seed to use when subsampling large fastqs"
	}

	command <<<
		set -eux pipefail
		prefetch "~{sra_accession}"  # prefetch is not always required, but is good practice
		fasterq-dump "~{sra_accession}"
		NUMBER_OF_FQ=$(fdfind "$SRR" | wc -l)
		echo "$NUMBER_OF_FQ" > number_of_reads.txt
		IS_ODD=$(echo "$NUMBER_OF_FQ % 2" | bc)
		if [[ $IS_ODD == 0 ]]
		then
			echo "Even number of fastqs"
			echo "~{sra_accession}" > accession.txt
		else
			echo "Odd number of fastqs; checking if we can still use them..."
			if [[ $NUMBER_OF_FQ == 1 ]]
			then
				echo "Only one fastq found"
				if [ "~{fail_on_invalid}" == "true" ]
				then
					exit 1
				else
					# don't fail, but give no output
					rm ./*.fastq
					exit 0
				fi
			else
				if [[ $NUMBER_OF_FQ != 3 ]]
				then
					# somehow we got 5, 7, 9, etc reads
					# this should probably never happen
					echo "Odd number > 3 files found"
					if [ "~{fail_on_invalid}" == "true" ]
					then
						exit 1
					else
						# could probably adapt the 3-case
						rm ./*.fastq
						exit 0
					fi

				fi

				# three files present
				READ1=$(fdfind _1)
				READ2=$(fdfind _2)
				mkdir temp
				mv "$READ1" "temp/$READ1"
				mv "$READ2" "temp/$READ2"
				BARCODE=$(fdfind ".fastq")
				rm "$BARCODE"
				mv "temp/$READ1" "./$READ1"
				mv "temp/$READ2" "./$READ2"
				echo "~{sra_accession}" > accession.txt
			fi
		fi
		# check size, unless cutoff is -1
		if [[ ! "~{subsample_cutoff}" = "-1" ]]
		then
			READ1=$(fdfind _1)
			READ2=$(fdfind _2)
			fastq1size=$(du -m "$READ1" | cut -f1)
			if [[ fastq1size -gt ~{subsample_cutoff} ]]
			then
				seqtk sample -s~{subsample_seed} "$READ1" 1000000 > temp1.fq
				seqtk sample -s~{subsample_seed} "$READ2" 1000000 > temp2.fq
				rm "$READ1"
				rm "$READ2"
				mv temp1.fq "$READ1"
				mv temp2.fq "$READ2"
				echo "    $SRR: PASS - downsampled from $fastq1size MB" >> "~{sra_accession}"_pull_results.txt
			else
				echo "    $SRR: PASS" >> "~{sra_accession}"_pull_results.txt
			fi
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
		Array[File?] fastqs = glob("*.fastq")
		Int num_fastqs = read_int("number_of_reads.txt")
	}
}

task pull_fq_from_biosample {
	input {
		String biosample_accession

		Boolean fail_on_invalid = false
		Boolean tar_outputs = false
		Int subsample_cutoff = 450
		Int subsample_seed = 1965

		Int disk_size = 100
		Int preempt = 1
	}

	parameter_meta {
    	biosample_accession: "BioSample accession to pull fastqs from"
    	disk_size:           "Size, in GB, of disk (acts as a limit on GCP)"
    	fail_on_invalid:     "Error (instead of exit 0 with null output) if output invalid"
    	preempt:             "Number of times to attempt task on a preemptible VM (GCP only)"
    	subsample_cutoff:    "If a fastq > this value in MB, the fastq will be subsampled (set to -1 to disable)"
    	subsample_seed:      "Seed to use when subsampling large fastqs"
    	tar_outputs:         "Tarball all fastqs into one output file"
	}
	
	# Statuses:
	# * ERROR: this run caused fasterq-dump or prefetch to throw an error
	# * PASS:  this run passed
	# * FAIL:  this run failed
	# * YAY:   this sample had at least one passing read
	# * NAY:   this sample does not have any passing reads
	# * HUH:   this sample did not return any run accessions (usually an issue with edirect)

	# an easy way to test the find commands:
	# touch ERR551697_1.fastq ERR551697_2.fastq ERR551697.fastq ERR551698_1.fastq ERR551698_2.fastq

	command <<<
		echo "~{biosample_accession}" >> ~{biosample_accession}_pull_results.txt
		
		# get SRA accessions from biosample
		SRRS_STR=$(esearch -db biosample -query ~{biosample_accession} | \
			elink -target sra | efetch -format docsum | \
			xtract -pattern DocumentSummary -element Run@acc)

		SRRS_ARRAY=($SRRS_STR)
		
		if [[ "$SRRS_STR" = "" ]]
		then
			uh_oh=$(echo "~{biosample_accession}: HUH -- edirect did not return any run accessions")
			sed -i "1s/.*/$uh_oh/" ~{biosample_accession}_pull_results.txt
			if [[ "~{fail_on_invalid}" = true ]]
			then
				set -eux -o pipefail
				exit 1
			else
				exit 0
			fi
		fi

		# loop through every SRA accession and pull the fastqs
		for SRR in "${SRRS_ARRAY[@]}"
		do
			echo "searching $SRR"

			prefetch "$SRR"
			rc_prefetch=$?
			if [[ ! $rc_prefetch = 0 ]]
			then
				echo "$SRR: ERROR -- prefetch returned $rc_prefetch"
				if [[ "~{fail_on_invalid}" = "true" ]]
				then
					set -eux -o pipefail
					exit 1
				else
					rm ./"$SRR"*.fastq
				fi
			fi

			fasterq-dump "$SRR"
			rc_fasterqdump=$?
			if [[ ! $rc_fasterqdump = 0 ]]
			then
				echo "ERROR -- fasterq-dump returned $rc_fasterqdump"
				if [[ "$rc_prefetch" = "0" ]]
				then
					echo "    $SRR: ERROR -- fasterqdump returned $rc_fasterqdump" >> ~{biosample_accession}_pull_results.txt
				else
					echo "    $SRR: ERROR -- prefetch returned rc_prefetch, fasterqdump returned $rc_fasterqdump" >> ~{biosample_accession}_pull_results.txt
				fi
				if [[ "~{fail_on_invalid}" = "true" ]]
				then
					set -eux -o pipefail
					exit 1
				else
					rm ./"$SRR"*.fastq
				fi
			else
				rm -rf "${SRR:?}/"
				NUMBER_OF_FQ=$(fdfind "$SRR" | wc -l)
				IS_ODD=$(echo "$NUMBER_OF_FQ % 2" | bc)
				if [[ $IS_ODD == 0 ]]
				then
					echo "Even number of fastqs"
					
					# check size, unless cutoff is -1
					if [[ ! "~{subsample_cutoff}" = "-1" ]]
					then
						READ1=$(fdfind "$SRR"_1.fastq -d 1)
						READ2=$(fdfind "$SRR"_2.fastq -d 1)
						echo "Checking size of $READ1..."
						fastq1size=$(du -m "$READ1" | cut -f1)
						if [[ fastq1size -gt ~{subsample_cutoff} ]]
						then
							seqtk sample -s~{subsample_seed} "$READ1" 1000000 > temp1.fq
							seqtk sample -s~{subsample_seed} "$READ2" 1000000 > temp2.fq
							rm "$READ1"
							rm "$READ2"
							mv temp1.fq "$READ1"
							mv temp2.fq "$READ2"
							echo "    $SRR: PASS - downsampled from $fastq1size MB" >> "~{biosample_accession}"_pull_results.txt
						else
							echo "    $SRR: PASS" >> "~{biosample_accession}"_pull_results.txt
						fi
					fi


				else
					echo "Odd number of fastqs; checking if we can still use them..."
					if [[ $NUMBER_OF_FQ == 1 ]]
					then
						echo "Only one fastq found"
						echo "    $SRR: FAIL - one fastq" >> "~{biosample_accession}"_pull_results.txt
						if [ "~{fail_on_invalid}" == "true" ]
						then
							set -eux pipefail
							exit 1
						else
							# don't fail, but give no output for this SRR
							remove=$(fdfind "$SRR" -d 1)
							rm "./$remove"
						fi
					else
						if [[ $NUMBER_OF_FQ != 3 ]]
						then
							# somehow we got 5, 7, 9, etc reads
							# this should probably never happen
							echo "Odd number > 3 files found"
							echo "    $SRR: FAIL - odd number > 3 fastqs" >> "~{biosample_accession}"_pull_results.txt
							if [ "~{fail_on_invalid}" == "true" ]
							then
								set -eux pipefail
								exit 1
							else
								# could probably adapt the 3-case
								rm ./"$SRR"*.fastq
							fi

						fi

						# three files present
						# do some folder stuff to avoid confusion with other accessions
						mkdir temp
						declare -a THIS_SRA_FQS_ARR
						readarray -t THIS_SRA_FQS_ARR < <(fdfind "$SRR")
						for THING in "${THIS_SRA_FQS_ARR[@]}"
						do
							mv "$THING" "temp/$THING"
						done
						cd temp
						READ1=$(fdfind _1.fastq -d 1)
						READ2=$(fdfind _2.fastq -d 1)
						mv "$READ1" "../$READ1"
						mv "$READ2" "../$READ2"
						BARCODE=$(fdfind ".fastq" -d 1)
						rm "$BARCODE"
						cd ..
						echo "$BARCODE has been deleted, $READ1 and $READ2 remain."

						# check size -- if very large, we should subsample
						if [[ ! "~{subsample_cutoff}" = "-1" ]]
						then
							echo "Checking size of $READ1..."
							fastq1size=$(du -m "$READ1" | cut -f1)
							if (( fastq1size > ~{subsample_cutoff} ))
							then
								seqtk sample -s~{subsample_seed} "$READ1" 1000000 > temp1.fq
								seqtk sample -s~{subsample_seed} "$READ2" 1000000 > temp2.fq
								rm "$READ1"
								rm "$READ2"
								mv temp1.fq "$READ1"
								mv temp2.fq "$READ2"
								echo "    $SRR: PASS - three fastqs and downsampled from $fastq1size MB" >> "~{biosample_accession}"_pull_results.txt
							else
								# not bigger than the cutoff, but still a triplet, so make note of that
								echo "    $SRR: PASS - three fastqs" >> "~{biosample_accession}"_pull_results.txt
							fi
						fi
					fi
				fi
			fi
		done

		# double check that there actually are fastqs
		NUMBER_OF_FQ=$(fdfind ".fastq" | wc -l)
		if [[ ! $NUMBER_OF_FQ == 0 ]]
		then
			this_sample=$(echo "~{biosample_accession}: YAY")
			sed -i "1s/.*/$this_sample/" ~{biosample_accession}_pull_results.txt

			# append biosample name to the fastq filenames
			for fq in *.fastq
				do
					mv -- "$fq" "~{biosample_accession}_${fq%.fastq}.fastq"
				done

			# tar the outputs, if that's what you want
			if [ ~{tar_outputs} == "true" ]
			then
				FQ=$(fdfind ".fastq")
				tar -rf "~{biosample_accession}.tar" "$FQ"
			fi
		else
			this_sample=$(echo "~{biosample_accession}: NAY")
			sed -i "1s/.*/$this_sample/" ~{biosample_accession}_pull_results.txt
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
		Array[File?] fastqs = glob("*.fastq")
		File? tarball_fastqs = "~{biosample_accession}.tar"
		String results = read_string("~{biosample_accession}_pull_results.txt")
	}
}

# NOTE: This hasn't been throughly tested. It is based on this gist:
# https://gist.github.com/dianalow/5223b77c05b9780c30c633cb255e9fb2
# It doesn't work on DRR or ERR accessions.
task pull_fq_from_bioproject {
	input {
		String bioproject_accession

		Int disk_size = 50
		Int preempt = 1
	}

	command {
		esearch -db sra -query "~{bioproject_accession}" | \
			efetch -format runinfo | \
			cut -d ',' -f 1 | \
			grep SRR | \
			xargs fastq-dump -X 10 --split-files
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.6"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		Array[File] fastqs = glob("*.fastq")
	}
}
