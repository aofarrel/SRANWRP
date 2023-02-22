# tb_accessions
There's two types of files here: tb_a3 files and lineage files.

The lineage files are derivied from a bunch of TSVs floating around with sample accessions for known TB lineages. Those TSVs are not rehosted here.

tb_a3 files are derivied from a search of SRA circa November 2022. It represents "every" MTBC accession on the site at that time.

## lineage 
* lineage/all_lineages -- all samples for which we have lineage information + their lineage
* lineage/all_not_in_tb_a3 -- samples in all_lineage but not tb_a3
* lineage/all_samples_only -- all_sorted, but without lineage information (can be put into a workflow directly)
* lineage/all_sorted -- all_lineages but sorted alphabetically
* lineage/cat.py and filter.sh -- small scripts for putting some files together
* lineage/L*: various lineages -- pulled by hand, so there's a chance a few are off

### caveat
When we say something "has no lineage information," what we actually mean is that it isn't on any of the TSVs from which lineage/L*.txt are derived and by extension are not in any lineage/L*.txt file. There's bound to be samples on SRA that do have lineage information that weren't on those TSVs -- in fact we already found some lineage 3 lurking around. Right now, we're deciding not to retroactively update the L*.txt files when additional samples with lineage information are found. By extension, tb_a3_no_lineage.txt and its derivatives may have some samples that actually do have lineage information (but not lineage information we were aware of when making the lineage/L*.txt files).

## tb_a3
* tb_a3 -- list of "every" MTBC accession on SRA circa November 2022
    * see lineage/all_not_in_tb_a3.txt for some exceptions
* tb_a3_no_lineage -- all tb_a3 samples not also in all_lineages

### exclusive_subsets folder
This has randomized subsets of tb_a3. All of them are derivied from tb_a3_pool, which acts as the "pool" of valid tb_a3 samples from which more samples can be taken. Everything in the pool has no lineage information (see caveats) and also isn't already in any other tb_a3_rand* file.

tb_a3_rand00100.txt was the first of our tests and wasn't from the pool file, but just happened to have no samples with lineage information. Everything else has been derived from the pool file, and upon creation, modifies the pool file accordingly.

Some files have less the number of samples than you may expect from the file name. This is because they've been filtered via the denylists -- for example, SAMN18648259 was discovered to be an issue when running an older version of tb_a3_rand00500.txt, so it's not in that file anymore.

### tb_a3 creation process
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