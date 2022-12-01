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
	}

	call processingtasks.extract_accessions_from_file as get_biosamp_IDs {
		input:
			accessions_file = biosamples_file
	}


	scatter(biosample_accession in get_biosamp_IDs.accessions) {
		call metatasks.get_organism_per_biosample as get_organism_names {
			input:
				biosample_accession = biosample_accession
		}
	}

	call processingtasks.cat_files as cat {
		input:
			files = get_organism_names.organisms_and_SRA_accessions
	}

	output {
		File all_organisms_per_biosample = cat.outfile
		#Array[File] all_organism_files = get_organism_names.organisms_and_SRA_accessions # useful if cat takes too long
	}

}