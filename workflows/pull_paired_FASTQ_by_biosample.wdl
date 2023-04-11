version 1.0

import "../tasks/pull_fastqs.wdl" as pulltasks
import "../tasks/get_metadata.wdl" as metatasks
import "../tasks/processing_tasks.wdl" as processingtasks

workflow BIOSAMP_YOINK {
	input {
		File biosample_accessions

		# per iteration
		Int? disk_size = 100 #GB
		Int? preempt = 1
	}

	call processingtasks.extract_accessions_from_file as get_sample_IDs {
		input:
			accessions_file = biosample_accessions
	}

	scatter(biosample_accession in get_sample_IDs.accessions) {
		call pulltasks.pull_fq_from_biosample as pull {
			input:
				biosample_accession = biosample_accession,
				disk_size = disk_size,
				preempt = preempt
		}
		if(length(pull.fastqs)>1) {
    		Array[File] paired_fastqs=select_all(pull.fastqs)
  		}
	}

	call sranwrp_processing.cat_strings as cat_reports {
		input:
			strings = pull.results
	}

	output {
		Array[Array[File]] all_fastqs = select_all(paired_fastqs)
		File pull_report = cat_reports.outfile
	}
}