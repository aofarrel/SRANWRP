# Current TB Accessions

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

```
(#34) AND "Mycobacterium tuberculosis complex sp."[orgn] AND ("biomol dna"[Properties] AND "library layout paired"[Properties] AND "strategy wgs"[Properties] OR "strategy wga"[Properties] OR "strategy wcs"[Properties] OR "strategy clone"[Properties] OR "strategy finishing"[Properties] OR "strategy validation"[Properties] AND "filetype fastq"[Properties])
```