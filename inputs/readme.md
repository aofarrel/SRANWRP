# debug
Not all accessions work on all versions of fasterq-dump. Here's some examples.

## 2.10/3.0
All test data is tuberculosis data for the time being.
* full: List of 156 SRA accessions; superset of fail + pass_DL
* fail_DL: List of SRA accessions which fail fasterq-dump
* pass_DL: List of SRA accessions which pass fasterq-dump
* pass_map_reads: List of SRA accessions which pass DL + myco map_reads step
* pass_var_call: List of SRA accessions which pass DL + myco map_reads step + myco var_call step

### 2.10
Out of 156 tested, 120 accessions pass fasterq-dump, and 36 accessions fail fasterq-dump. See 2.10/readme.md for more info.

### 3.0
Out of 156 tested, all except two fail fasterq-dump. The two that fail are both from the same mouse, so I'm going to blame the mouse.

## denylists
Lists of accessions that should not be used in production pipelines.

## tb_accessions
Lists of various tuberculosis accessions. See [./tb_accessions/readme.md]()for more information.