# other

TB accessions from special places.

* auspice_unique: TB accessions which are available on Nextstrain, but are not in tb_a3 nor the known lineage dataset. SAMEA3721543 gets dropped for only having one fastq, and SAMEA3491431 times out during decontamination at default settings. SAMEA1707222 goes through fastq-TBprofiler as La3 and Sensitive, while SAMEA806953 returns no lineage and HR-TB.
* CRyPTIC_reuse_table_20231208: Column 42 of the CSV of the same name located on [this FTP site](http://ftp.ebi.ac.uk/pub/databases/cryptic/release_june2022/). This is good for testing ERS-->SAME capability.
* L7_auspice: Nextstrain's lone L7.
* L7_PMC5320646: Set of L7 accessions from [Nebenzahl-Guimaraes et al.](https://pubmed.ncbi.nlm.nih.gov/28348856/)
    * SAMEA3246143: In rand03456, correctly ID'd as L7 
    * SAMEA3250478: In rand04321, correctly ID'd as L7
    * todo: check the others
* ref_set: TB accessions from [Borrell et al.](doi.org/10.1371/journal.pone.0214088) Some of these are already present in other datasets.
his