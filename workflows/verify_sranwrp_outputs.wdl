version 1.0

# This workflow verifies that older verisons SRANWRP's pull task gave the correct number of run accessions
# by querying how many run accessions biosamples should have compared to what showed up in the pull report.

workflow verify_old_downloads {
    input {
        File pull_report
        File biosample_file
    }

    call query_fq_from_biosample
}