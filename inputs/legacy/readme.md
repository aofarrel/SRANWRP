# legacy

## 2.10/3.0
Not all accessions work on all versions of fasterq-dump. Here's some examples. All test data is tuberculosis data for the time being.
* full: List of 156 SRA accessions; superset of fail + pass_DL
* fail_DL: List of SRA accessions which fail fasterq-dump
* pass_DL: List of SRA accessions which pass fasterq-dump
* pass_map_reads: List of SRA accessions which pass DL + myco map_reads step
* pass_var_call: List of SRA accessions which pass DL + myco map_reads step + myco var_call step

### 2.10
Out of 156 tested, 120 accessions pass fasterq-dump, and 36 accessions fail fasterq-dump. See 2.10/readme.md for more info.

### 3.0
Out of 156 tested, all except two fail fasterq-dump. The two that fail are both from the same mouse, so I'm going to blame the mouse.

## tb_accessions
* TB_a: a's first attempt at a list of all TB accessions
* TB_a2: a's second attempt at a list of all TB accessions
* TB_a3: a's third attempt **(this is the one you probably care about)**
* TB_l: l's list
* TB_z: z's list

### tb_a process
1. Go to https://www.ncbi.nlm.nih.gov/bioproject
2. `(("bioproject sra"[Filter]) AND ("mycobacterium tuberculosis"[Organism] OR "mycobacterium tuberculosis complex"[Organism])) NOT avium NOT gordonae NOT kansasii NOT nonchromogenicum NOT simiae NOT abscessus NOT ulcerans NOT leprae NOT lepromatosis NOT marinum NOT chelonae NOT fortuitum NOT smegmatis`
3. On `Data types` (right hand column) click `Genome sequencing` and `Other`
4. On `Find related data` (right hand column) choose `SRA` from dropdown, then click "Find items" button (if button doesn't appear, choose something else in the column, then select SRA again)
5. On `Source` (left hand column) click `DNA`
6. On `File type` (left hand column, scroll down a bit) click `fastq`
7. On `library layout` (left hand column) click `paired`
8. On `strategy` (left hand column) click `Genome`
9. On `Results by taxa` (left hand column) click `Mycobacterium tuberculosis` and save to file
10. Hit back button, select TB complex, save to file.

### tb_a2 process
Was likely this:

```
(#34) AND "Mycobacterium tuberculosis complex sp."[orgn] AND ("biomol dna"[Properties] AND "library layout paired"[Properties] AND "strategy wgs"[Properties] OR "strategy wga"[Properties] OR "strategy wcs"[Properties] OR "strategy clone"[Properties] OR "strategy finishing"[Properties] OR "strategy validation"[Properties] AND "filetype fastq"[Properties])
```

but the subquery of 34 has been lost. These seem to be roughly equivalent:

```
txid77643[Organism:exp] AND "Mycobacterium tuberculosis complex sp."[orgn] AND ("biomol dna"[Properties] AND "library layout paired"[Properties] AND "strategy wgs"[Properties] OR "strategy wga"[Properties] OR "strategy wcs"[Properties] OR "strategy clone"[Properties] OR "strategy finishing"[Properties] OR "strategy validation"[Properties] AND "filetype fastq"[Properties])
```

```
txid77643[Organism:exp] AND ("biomol dna"[Properties] AND "library layout paired"[Properties] AND "strategy wgs"[Properties] OR "strategy wga"[Properties] OR "strategy wcs"[Properties] OR "strategy clone"[Properties] OR "strategy finishing"[Properties] OR "strategy validation"[Properties] AND "filetype fastq"[Properties]) AND ("biomol dna"[Properties] AND "library layout paired"[Properties] AND "strategy wgs"[Properties] OR "strategy wga"[Properties] OR "strategy wcs"[Properties] OR "strategy clone"[Properties] OR "strategy finishing"[Properties] OR "strategy validation"[Properties] AND "filetype fastq"[Properties])
```
### tb_a3 process

#### strict

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

#### loose
This process could be repeated by allowing WCS and the mysterious "other" category, but wasn't.