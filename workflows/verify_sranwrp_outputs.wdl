version 1.0

import "https://raw.githubusercontent.com/aofarrel/SRANWRP/bash-arrays-are-hard/tasks/get_metadata.wdl" as metatasks
import "https://raw.githubusercontent.com/aofarrel/SRANWRP/bash-arrays-are-hard/tasks/processing_tasks.wdl" as processingtasks

# This workflow verifies that older verisons SRANWRP's pull task gave the correct number of run accessions
# by querying how many run accessions biosamples should have compared to what showed up in the pull report.

workflow verify_old_downloads {
    input {
        File pull_report
        File biosample_file
    }

    call processingtasks.extract_accessions_from_file as get_sample_IDs {
		input:
			accessions_file = biosample_file
	}

	scatter(biosample_accession in get_sample_IDs.accessions) {
        call metatasks.get_SRA_accession_IDs_by_biosample_new as query { 
            input:
                biosample_accession = biosample_accession
        }
	}

	call processingtasks.cat_strings as cat_queries {
		input:
			strings = query.results,
            out = "run_accessions_by_biosample.txt"
	}

    call compare_files {
        input:
            query_file = cat_queries.outfile,
            pull_report = pull_report
    }

    output {
        File compare = compare_files.difference
    }
}

task compare_files {
    input {
        File query_file
        File pull_report
    }

    command <<<
    python3 << CODE
    from difflib import Differ
    with open("~{query_file}", "r") as query_file, open("~{pull_report}, "r") as pull_file:
        differ = Differ()
        with open("difference.txt", "w") as difference:
            for line in differ.compare(query_file.readlines(), pull_file.readlines()):
                difference.write(line)
    CODE
    >>>

    output {
        File difference = "difference.txt"
    }
}