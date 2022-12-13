# tb_accessions
* five_per_sublineage: Contains, in this order:
 * 5 L1.1.1.1
 * 5 L1.1.1
 * 5 L1.1.2
 * 5 L1.1.3
 * 5 L1.1
 * 5 L1.2.1
 * 5 L1.2.2
 * 5 L3.1.1
 * 5 L3.1.2.1
 * 5 L3.1.2.2
 * 5 L3.1.2
 * 5 L3
* L*: various lineages -- pulled by hand, so there's a chance a few are off
* TB_a3: list of "every" MTBC accession on SRA


## tb_a3 process
On SRA's website, the following search was performed.

```
txid77643[Organism:exp] AND "library layout paired"[Properties] AND "filetype fastq"[Properties] AND "biomol dna"[Properties] AND ("strategy wga"[Filter] OR "strategy wgs"[Filter]) AND "filetype fastq"[Properties] NOT "filetype bam"[Properties] AND "platform illumina"[Properties] AND "cloud gs"[Properties] 
```

Excludes:
* anything not in gs://
* anything that's not wga/wgs (this means wcs is excluded)
* anything that's not a paired-end FASTQ from an Illumina machine
* [that one bam file from a boar in the French countryside](https://www.ncbi.nlm.nih.gov/sra/ERX1041379[accn])

Note that `txid77643[Organism:exp]` matches everything "downstream" of txid77643. So, for example, _Mycobacterium canettii_ would be included because that is a subset of txid77643.

This search resulted in 96341 accessions. The resulting file from SRA's website was then loaded into big query.

```
bq load tb_foobar.tb_a3_strict tb_a3_strict.txt run_id:string

bq --format=json query --nouse_legacy_sql --max_rows=200000 \
    'select acc, assay_type, center_name, consent, experiment, sample_name, instrument,
            librarylayout, libraryselection, librarysource, sample_acc, biosample, organism,
            sra_study, bioproject, insertsize, library_name, collection_date_sam, loaddate,
            geo_loc_name_country_calc, geo_loc_name_country_continent_calc, geo_loc_name_sam,
            sample_name_sam, datastore_filetype, datastore_region, jattr
     from `nih-sra-datastore.sra.metadata` as m,
          `tb_foobar.tb_a3_strict` as l
     where m.acc = l.run_id;' \
     > tb_a3_strict_metadata.json

jq -c -r '.[] | [.acc, .assay_type, .bioproject, .biosample, .center_name, .collection_date_sam, .consent, .experiment, .library_name, .librarylayout, .libraryselection, .librarysource, .organism, (.sample_name_sam | join(",")), .sra_study ] | join("\t")' \
    tb_metadata.json \
| sort \
    > tb_a3_strict_metadata_simple.tsv

cut -f 4 tb_a3_strict_metadata_simple.tsv | sort | uniq > tb_a3_strict_biosample.txt
```