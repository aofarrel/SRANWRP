version 1.0

# Get the organism (including taxID) from a bunch of BioProject accessions
# Author: Ash O'Farrell
# If you don't already have a file with bioprojects already, you can get one from an
# SRA query. Select "Send to" > "File" radio > "Accessions list" dropdown > "Create File"
# Have the resulting file be the input to this pipeline.

import "../tasks/get_metadata.wdl" as metatasks
import "../tasks/processing_tasks.wdl" as processingtasks
#import "https://raw.githubusercontent.com/aofarrel/SRANWRP/main/tasks/get_metadata.wdl" as metatasks
#import "https://raw.githubusercontent.com/aofarrel/SRANWRP/main/tasks/processing_tasks.wdl" as processingtasks

workflow IS_THIS_A_BUTTERFLY {
	input {
		File biosamples_file
		Boolean do_not_scatter = true
	}

	call processingtasks.extract_accessions_from_file as get_biosamp_IDs {
		input:
			accessions_file = biosamples_file
	}


	if (!do_not_scatter) {
		scatter(biosample_accession in get_biosamp_IDs.accessions) {
			call metatasks.get_organism_per_biosample_single as get_organism_names_scattered {
				input:
					biosample_accession = biosample_accession
			}
		}

		call processingtasks.cat_files as cat {
			input:
				files = get_organism_names_scattered.organisms_and_SRA_accessions
		}
	}

	if (do_not_scatter) {
		call metatasks.get_organism_per_biosample_multiple as get_organism_names_single {
			input:
				biosample_accessions = get_biosamp_IDs.accessions
		}
	}


	output {
		File? all_organisms_per_biosample = select_first([cat.outfile, get_organism_names_single.organisms_and_SRA_accessions])
	}

}