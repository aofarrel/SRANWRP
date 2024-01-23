version 1.0
import "../tasks/get_metadata.wdl" as metadata
import "../tasks/pull_fastqs.wdl" as pull
import "../tasks/processing_tasks.wdl" as processing

workflow Download_FQs_From_BioProject {
    input {
        String bioproject
        Boolean to_terra_data_table = true
    }
    
    call metadata.get_BioSample_accession_IDs_by_bioproject as get_biosamples {
        input:
            bioproject_accession = bioproject,
            disk_size = 5
    }
    
    call processing.extract_accessions_from_file as get_biosamples_array {
        input:
            accessions_file = get_biosamples.accessions_as_file
    }
    
    scatter(accessions in get_biosamples_array.accessions) {
        call pull.pull_fq_from_biosample as yoink {
            input:
                biosample_accession = accessions,
                subsample_cutoff = 1500,
                tar_outputs = true
        }
        
        if(length([yoink.tarball_fastqs]) != 0) {
            String valid_biosample = yoink.biosample
            String valid_fastqs = select_first([yoink.tarball_fastqs, bioproject])
            Array[String] biosample_and_fqs = [valid_biosample, valid_fastqs]
        }
    }
    
    if(to_terra_data_table) {
        call processing.write_csv as make_terra_data_table {
            input:
                headings = ["entity:sample_id", "fastqs"],
                stuff_to_write = select_all(biosample_and_fqs),
                outfile = bioproject + ".tsv",
                tsv = true
        }
    }
    
    output {
        Array[File?] fqs_per_biosample = yoink.tarball_fastqs
        File? terra_tsv = make_terra_data_table.finalOut
    }

}