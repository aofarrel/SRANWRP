## 1/3/20/99/100
1/3/20/99/100 samples. The 1 sample case is a very simple sample.

## dupes_10/dupes_90_diverse
10 or 90 samples, some of which are duplicates. The "diverse" 90 are taken from all over the tb_a3 (or maybe tb_a2) list.

## fails_var_call
This sample failed in variant calling in older versions of the pipeline.

## huge_samples
Three Illumina samples with huge runs. For example, SAMEA10030200 has only one run, ERR7911443, but it's 5.9 gigabytes.

## L1_L3_sublineage
Contains, in this order:
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
 * 5 L2

## multirun_sample
2 multirun (ie multiple SRRs) samples.

## pacbio
1 PacBio sample -- expected to fail fasterq-dump

## PRJEB41201_and_PRJEB41205
100 samples from the BioProjects PRJEB41201 and PRJEB41205.

## slow_to_decontaminate
Three of these samples, even after being downsampled, go very slowly during clockwork-wdl's combined decontamination (single) step. They get stuck in minimap2 for hours. The first sample on the list (SAMN18648679) is a control that proceeds at a normal rate.

## sample_edge_cases
* SRS1528302: Single-run (SRR11947402) but returns one FASTQ file
* SRS3269160: Single-run (SRR7131136) but returns three FASTQ files
* SAMEA2534128: Two runs with different ERX accessions
* ERS457530: Same as SAMEA2534128, should have equivalent output
