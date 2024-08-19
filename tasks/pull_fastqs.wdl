version 1.0

task pull_fq_from_SRA_accession {
	input {
		String sra_accession

		Boolean crash_if_bad_output = false
		Int     disk_size_GB = 100
		Int     preempt = 1	
		Boolean prefetch = true
		Int     prefetch_max_size_KB = 20000000  # default for prefetch is 20 GB
		Int     subsample_cutoff_MB = -1
		Int     subsample_seed = 1965
		Int     timeout_minutes = 120
	}

	parameter_meta {
    	sra_accession:        "SRA run accession (not BioSample) to pull fastqs from - can be SRR, ERR, etc"
    	crash_if_bad_output:  "Error (instead of exit 0 with null output) if output invalid"
    	disk_size_GB:         "Size, in GB, of disk - acts as a hard limit on GCP backends including Terra"
    	preempt:              "Number of times to attempt task on a preemptible VM; ignored if not on a GCP backend"
    	prefetch:             "Should we use prefetch? (recommended)"
    	prefetch_max_size_KB: "prefetch --max_size. Note that this is in KB to align with how prefetch works."
    	subsample_cutoff_MB:  "If a fastq > this value in MB, the fastq will be subsampled (set to -1 to disable)"
    	subsample_seed:       "Seed to use when subsampling large fastqs"
		timeout_minutes:      "Time out and give no output if prefetch or the pull itself takes longer than n minutes"
	}

	command <<<
		start_time=$(date +%s)

		if [[ "~{prefetch}" == "true" ]]
		then
			timeout -v ~{timeout_minutes}m prefetch --max-size ~{prefetch_max_size_KB} "~{sra_accession}"
			rc_prefetch=$? 
			if [[ ! $rc_prefetch = 0 ]]
			then
				echo "ERROR -- prefetch returned $rc_fasterqdump -- check ~{prefetch_max_size_KB} KB is big enough for your file"
				end_time=$(date +%s)
				elapsed_time=$(( end_time - start_time ))
				elapsed_minutes=$(( elapsed_time / 60 ))
				echo "~{sra_accession}: FAIL (prefetch error $rc_fasterqdump) @ ${elapsed_minutes} minutes" >> "~{sra_accession}"_pull_results.txt
				#shellcheck disable=SC2086
				exit $rc_fasterqdump
			else
				timeout -v ~{timeout_minutes}m fasterq-dump -vvv -x ./"~{sra_accession}"
			fi
		else
			timeout -v ~{timeout_minutes}m fasterq-dump -vvv -x "~{sra_accession}"
		fi
		
		rc_fasterqdump=$?
		if [[ ! $rc_fasterqdump = 0 ]]
		then
			echo "ERROR -- prefetch succeeded, but fasterq-dump returned $rc_fasterqdump"
			echo "~{sra_accession}: FAIL (fasterq-dump error $rc_fasterqdump) @ ${elapsed_minutes} minutes" >> "~{sra_accession}"_pull_results.txt
			exit $rc_fasterqdump
		fi
		
		# check the number of fastq files we ended up with
		NUMBER_OF_FQ=$(fdfind "~{sra_accession}" | wc -l)
		echo "$NUMBER_OF_FQ" > number_of_reads.txt
		IS_ODD=$(echo "$NUMBER_OF_FQ % 2" | bc)
		if [[ $IS_ODD == 0 ]]
		then
			echo "Even number of fastqs"
			end_time=$(date +%s)
			elapsed_time=$(( end_time - start_time ))
			elapsed_minutes=$(( elapsed_time / 60 ))
			echo "~{sra_accession}: PASS @ ${elapsed_minutes} minutes" >> "~{sra_accession}"_pull_results.txt
			# don't exit yet!
		else
			echo "Odd number of fastqs; checking if we can still use them..."
			if [[ $NUMBER_OF_FQ == 1 ]]
			then
				echo "Only one fastq found"
				if [ "~{crash_if_bad_output}" == "true" ]
				then
					exit 1
				else  # don't fail, but don't output any fastqs
					end_time=$(date +%s)
					elapsed_time=$(( end_time - start_time ))
					elapsed_minutes=$(( elapsed_time / 60 ))
					echo "~{sra_accession}: FAIL (one fastq) @ ${elapsed_minutes} minutes" >> "~{sra_accession}"_pull_results.txt
					rm ./*.fastq
					exit 0
				fi
			else
				if [[ $NUMBER_OF_FQ != 3 ]]
				then
					# somehow we got 5, 7, 9, etc reads
					# this should probably never happen
					echo "Odd number > 3 files found"
					if [ "~{crash_if_bad_output}" == "true" ]
					then
						exit 1
					else  # TODO: could probably adapt the 3-case?
						end_time=$(date +%s)
						elapsed_time=$(( end_time - start_time ))
						elapsed_minutes=$(( elapsed_time / 60 ))
						echo "~{sra_accession}: FAIL (weird number of fastqs) @ ${elapsed_minutes} minutes" >> "~{sra_accession}"_pull_results.txt
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
				end_time=$(date +%s)
				elapsed_time=$(( end_time - start_time ))
				elapsed_minutes=$(( elapsed_time / 60 ))
				echo "~{sra_accession}: PASS (three fastqs, deleted the odd one out) @ ${elapsed_minutes} minutes" >> "~{sra_accession}"_pull_results.txt
			fi
		fi

		# hacky method for minimum number of reads, as fqtools refuses to compile for me
		#shellcheck disable=SC2086
		number_of_reads=$(awk '{s++} END {print s/4}' $READ1)
		if [ "$number_of_reads" -lt 20000 ]
		then
			echo "~{sra_accession}: FAIL (only $number_of_reads reads)"
			if [ "~{crash_if_bad_output}" == "true" ]
			then
				exit 1
			else  # don't crash, but don't output any fastqs
				end_time=$(date +%s)
				elapsed_time=$(( end_time - start_time ))
				elapsed_minutes=$(( elapsed_time / 60 ))
				echo "~{sra_accession}: FAIL (only $number_of_reads reads) @ ${elapsed_minutes} minutes" >> "~{sra_accession}"_pull_results.txt
				rm ./*.fastq
				exit 0
			fi
		fi
		
		# check file size, unless cutoff is -1 (eg, maximum number of reads... kind of)
		if [[ ! "~{subsample_cutoff_MB}" = "-1" ]]
		then
			READ1=$(fdfind _1)
			READ2=$(fdfind _2)
			fq1megabytes=$(du -m "$READ1" | cut -f1)
			if [[ fq1megabytes -gt ~{subsample_cutoff_MB} ]]
			then
				seqtk sample -s~{subsample_seed} "$READ1" 1000000 > temp1.fq
				seqtk sample -s~{subsample_seed} "$READ2" 1000000 > temp2.fq
				rm "$READ1"
				rm "$READ2"
				mv temp1.fq "$READ1"
				mv temp2.fq "$READ2"
				end_time=$(date +%s)
				elapsed_time=$(( end_time - start_time ))
				elapsed_minutes=$(( elapsed_time / 60 ))
				echo "~{sra_accession}: PASS (downsampled from $fq1megabytes MB) @ ${elapsed_minutes} minutes" >> "~{sra_accession}"_pull_results.txt
			else
				end_time=$(date +%s)
				elapsed_time=$(( end_time - start_time ))
				elapsed_minutes=$(( elapsed_time / 60 ))
				echo "~{sra_accession}: PASS @ ${elapsed_minutes} minutes" >> "~{sra_accession}"_pull_results.txt
			fi
		fi

		ls -lha
		
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size_GB + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.6"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		Array[File?] fastqs = glob("*.fastq")
		String status = read_string(sra_accession+"_pull_results.txt")
		#Int num_fastqs = read_int("number_of_reads.txt")
	}
}

task pull_fq_from_biosample {
	input {
		String biosample_accession

		Boolean fail_on_invalid = false
		Int minimum_reads = 20000
		Int subsample_cutoff = 450
		Int subsample_seed = 1965
		Boolean tar_outputs = false
		Int timeout_minutes = 120

		Int disk_size = 100
		Int preempt = 1
	}

	parameter_meta {
    	biosample_accession: "BioSample accession to pull fastqs from"
    	disk_size:           "Size, in GB, of disk (acts as a limit on GCP)"
    	fail_on_invalid:     "Error (instead of exit 0 with null output) if output invalid"
		minimum_reads:       "Minimum number of reads a FQ file needs in order for that FQ to pass"
    	preempt:             "Number of times to attempt task on a preemptible VM (GCP only)"
    	subsample_cutoff:    "If a fastq > this value in MB, the fastq will be subsampled (set to -1 to disable)"
    	subsample_seed:      "Seed to use when subsampling large fastqs"
    	tar_outputs:         "Tarball all fastqs into one output file"
		timeout_minutes:      "Time out and give no output if prefetch or the pull itself takes longer than n minutes"
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

		fx_calculate_elapsed_minutes() {
			local end_time
			end_time=$(date +%s)
			local elapsed_time=$(( end_time - start_time ))
			echo $(( elapsed_time / 60 ))
		}

		start_time=$(date +%s)
		
		# get run accessions from biosample
		SRRS_STR=$(timeout -v ~{timeout_minutes}m esearch -db sra -query ~{biosample_accession} | \
			esummary | xtract -pattern DocumentSummary -element Run@acc)
		read -ra SRRS_ARRAY -d ' ' <<<"$SRRS_STR"

		echo "$(fx_calculate_elapsed_minutes) minutes to esearch"
		
		if [[ "$SRRS_STR" = "" ]]
		then
			echo "edirect returned no run accessions, trying another method after a brief pause..."
			sleep 5
			SRRS_STR=$(timeout -v ~{timeout_minutes}m esearch -db biosample -query ~{biosample_accession} | \
				elink -target sra | efetch -format docsum | \
				xtract -pattern DocumentSummary -element Run@acc)
			IFS=" " read -r -a SRRS_ARRAY <<< "$SRRS_STR"
			if [[ "$SRRS_STR" = "" ]]
			then
				uh_oh="~{biosample_accession}: HUH @ $(fx_calculate_elapsed_minutes) minutes"
				sed -i "1s/.*/$uh_oh/" ~{biosample_accession}_pull_results.txt
				if [[ "~{fail_on_invalid}" = true ]]
				then
					set -eux -o pipefail
					exit 1
				else
					exit 0
				fi
			fi
			# script will continue in the else case
		fi

		# loop through every SRA accession and pull the fastqs
		for SRR in "${SRRS_ARRAY[@]}"
		do
			echo "searching $SRR"

			timeout -v ~{timeout_minutes}m prefetch "$SRR"
			rc_prefetch=$?
			if [[ ! $rc_prefetch = 0 ]]
			then
				echo "$SRR: ERROR -- prefetch returned $rc_prefetch @ $(fx_calculate_elapsed_minutes) minutes"
				if [[ "~{fail_on_invalid}" = "true" ]]
				then
					set -eux -o pipefail
					exit 1
				else
					# not necessarily a fatal error so continue
					rm ./"$SRR"*.fastq
				fi
			fi

			timeout -v ~{timeout_minutes}m fasterq-dump "$SRR"
			rc_fasterqdump=$?
			if [[ ! $rc_fasterqdump = 0 ]]
			then
				echo "ERROR -- fasterq-dump returned $rc_fasterqdump @ $(fx_calculate_elapsed_minutes) minutes"
				if [[ "$rc_prefetch" = "0" ]]
				then
					echo "        $SRR: ERROR -- prefetch succeeded but fasterqdump returned $rc_fasterqdump @ $(fx_calculate_elapsed_minutes) minutes" >> ~{biosample_accession}_pull_results.txt
				else
					echo "        $SRR: ERROR -- prefetch returned $rc_prefetch, fasterqdump returned $rc_fasterqdump @ $(fx_calculate_elapsed_minutes) minutes" >> ~{biosample_accession}_pull_results.txt
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
					
					# check if too small or too large
					READ1=$(fdfind "$SRR"_1.fastq -d 1)
					READ2=$(fdfind "$SRR"_2.fastq -d 1)
					echo "Checking size of $READ1..."
					fq1megabytes=$(du -m "$READ1" | cut -f1)
					#shellcheck disable=SC2086
					number_of_reads=$(awk '{s++} END {print s/4}' $READ1)  # this is hacky but good enough since fqtools refuses to compile
					if [[ fq1megabytes -gt ~{subsample_cutoff} ]]
					then
						seqtk sample -s~{subsample_seed} "$READ1" 1000000 > temp1.fq
						seqtk sample -s~{subsample_seed} "$READ2" 1000000 > temp2.fq
						rm "$READ1"
						rm "$READ2"
						mv temp1.fq "$READ1"
						mv temp2.fq "$READ2"
						echo "        $SRR: PASS - downsampled from $fq1megabytes MB @ $(fx_calculate_elapsed_minutes) minutes" >> "~{biosample_accession}"_pull_results.txt
					elif [ "$number_of_reads" -lt ~{minimum_reads} ]
					then
						echo "        $SRR: FAIL - only $number_of_reads reads @ $(fx_calculate_elapsed_minutes) minutes"
						if [ "~{fail_on_invalid}" == "true" ]
						then
							exit 1
						else  # don't crash, but don't output any fastqs
							echo "        $SRR: FAIL - only $number_of_reads reads @ ${elapsed_minutes} minutes" >> "~{biosample_accession}"_pull_results.txt
							rm ./*.fastq
							exit 0
						fi
					else
						echo "        $SRR: PASS @ $(fx_calculate_elapsed_minutes) minutes" >> "~{biosample_accession}"_pull_results.txt
					fi

				else
					echo "Odd number of fastqs; checking if we can still use them..."
					if [[ $NUMBER_OF_FQ == 1 ]]
					then
						echo "Only one fastq found"
						end_time=$(date +%s)
						elapsed_time=$(( end_time - start_time ))
						elapsed_minutes=$(( elapsed_time / 60 ))
						echo "        $SRR: FAIL - one fastq @ $(fx_calculate_elapsed_minutes) minutes" >> "~{biosample_accession}"_pull_results.txt
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
							echo "        $SRR: FAIL - odd number > 3 fastqs @ $(fx_calculate_elapsed_minutes) minutes" >> "~{biosample_accession}"_pull_results.txt
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
						echo "$BARCODE has been deleted, $READ1 and $READ2 remain @ $(fx_calculate_elapsed_minutes) minutes."

						# check if too small or too large
						READ1=$(fdfind "$SRR"_1.fastq -d 1)
						READ2=$(fdfind "$SRR"_2.fastq -d 1)
						echo "Checking size of $READ1..."
						fq1megabytes=$(du -m "$READ1" | cut -f1)
						#shellcheck disable=SC2086
						number_of_reads=$(awk '{s++} END {print s/4}' $READ1)  # this is hacky but good enough since fqtools refuses to compile
						if [[ fq1megabytes -gt ~{subsample_cutoff} ]]
						then
							seqtk sample -s~{subsample_seed} "$READ1" 1000000 > temp1.fq
							seqtk sample -s~{subsample_seed} "$READ2" 1000000 > temp2.fq
							rm "$READ1"
							rm "$READ2"
							mv temp1.fq "$READ1"
							mv temp2.fq "$READ2"
							echo "        $SRR: PASS - three fastqs and downsampled from $fq1megabytes MB @ $(fx_calculate_elapsed_minutes) minutes" >> "~{biosample_accession}"_pull_results.txt
						elif [ "$number_of_reads" -lt ~{minimum_reads} ]
						then
							echo "        $SRR: FAIL - only $number_of_reads reads @ $(fx_calculate_elapsed_minutes) minutes"
							if [ "~{fail_on_invalid}" == "true" ]
							then
								exit 1
							else  # don't crash, but don't output any fastqs
								echo "        $SRR: FAIL - only $number_of_reads reads @ $(fx_calculate_elapsed_minutes) minutes" >> "~{biosample_accession}"_pull_results.txt
								rm ./*.fastq
								exit 0
							fi
						else
							echo "        $SRR: PASS - three fastqs @ $(fx_calculate_elapsed_minutes) minutes" >> "~{biosample_accession}"_pull_results.txt
						fi
					fi
				fi
			fi
		done

		# double check that there actually are fastqs
		NUMBER_OF_FQ=$(fdfind ".fastq" | wc -l)
		if [[ ! $NUMBER_OF_FQ == 0 ]]
		then
			this_sample="~{biosample_accession}: YAY"
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
			this_sample="~{biosample_accession}: NAY"
			sed -i "1s/.*/$this_sample/" ~{biosample_accession}_pull_results.txt
		fi

		echo "Finished pulling @ $(fx_calculate_elapsed_minutes) minutes."
		
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
