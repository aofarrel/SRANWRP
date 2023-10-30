version 1.0

# Pull FASTQs from a list of SRA Run accessions (SRR/ERR/DRR).
# Will only return paired FASTQs. Accessions that give only
# one FASTQ will be ignored, and accessions that give two paired
# reads + one additional FASTQ will only return the paired FASTQs.

#import "../tasks/pull_fastqs.wdl" as pulltasks
#import "https://raw.githubusercontent.com/aofarrel/SRANWRP/main/tasks/pull_fastqs.wdl" as pulltasks


# temporarily moving task here to avoid cache issues on Terra
task pull_fq_from_SRA_accession {
	input {
		String sra_accession

		Int prefetch_max_size = 20  # default for prefetch is 20 GB
		Boolean fail_on_invalid = false
		Int subsample_cutoff = -1
		Int subsample_seed = 1965

		Int disk_size = 100
		Int preempt = 1	
	}

	parameter_meta {
    	sra_accession:     "SRA run accession (not BioSample) to pull fastqs from - can be SRR, ERR, etc"
    	disk_size:         "Size, in GB, of disk - acts as a hard limit on GCP backends including Terra"
    	fail_on_invalid:   "Error (instead of exit 0 with null output) if output invalid"
    	preempt:           "Number of times to attempt task on a preemptible VM; ignored if not on a GCP backend"
    	prefetch_max_size: "prefetch --max_size"
    	subsample_cutoff:  "If a fastq > this value in MB, the fastq will be subsampled (set to -1 to disable)"
    	subsample_seed:    "Seed to use when subsampling large fastqs"
	}

	command <<<
		set -eux pipefail
		prefetch -vvv --max-size ~{prefetch_max_size} "~{sra_accession}"  # prefetch is not always required, but is good practice
		fasterq-dump -vvv -x "~{sra_accession}"
		NUMBER_OF_FQ=$(fdfind "~{sra_accession}" | wc -l)
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
				echo "    ~{sra_accession}: PASS - downsampled from $fastq1size MB" >> "~{sra_accession}"_pull_results.txt
			else
				echo "    ~{sra_accession}: PASS" >> "~{sra_accession}"_pull_results.txt
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

workflow SRA_YOINK {
	input {
		Array[String] sra_accessions

		# per iteration
		Int disk_size = 100
		Int preempt = 1
	}

	scatter(sra_accession in sra_accessions) {
		call pull_fq_from_SRA_accession as pull {
			input:
				sra_accession = sra_accession,
				disk_size = disk_size,
				preempt = preempt
		}
		if(length(pull.fastqs)>1) {
    		Array[File] paired_fastqs=select_all(pull.fastqs)
  		}
	}

	output {
		Array[Array[File]] all_fastqs = select_all(paired_fastqs)
		Array[Int] number_of_fastqs_per_accession = pull.num_fastqs
	}

}