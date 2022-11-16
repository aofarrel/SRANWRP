version 1.0

import "../tasks/processing_tasks.wdl" as processingtasks
import "../tasks/get_metadata.wdl" as metatasks

workflow SRA_TO_BIOSAMP {
	input {
		File sra_accessions
	}

	call processingtasks.extract_accessions_from_file as get_run_IDs {
		input:
			accessions_file = sra_accessions
	}


	scatter(sra_accession in get_run_IDs.accessions) {
		call metatasks.get_biosample_accession_ID_from_SRA as get_samples {
			input:
				sra_accession = sra_accession
		}
	}

	call processingtasks.cat_files as cat {
		input:
			files = get_samples.accession_as_file,
			keep_only_unique_lines = true
	}

	output {
		File unique_biosample_accessions = cat.outfile
	}

}