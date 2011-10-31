#ClinSeq Code paths
/gscmnt/sata206/techd/git/genome/lib/perl/Genome/Model/ClinSeq/original-scripts/
/gscmnt/sata206/techd/git/genome/lib/perl/Genome/ProcessingProfile/ClinSeq.pm
/gscmnt/sata206/techd/git/genome/lib/perl/Genome/ProcessingProfile/ClinSeq.t
/gscmnt/sata206/techd/git/genome/lib/perl/Genome/Model/ClinSeq.pm

#ClinSeq Data paths (data files used by the pipeline - not the input data, but annotation data, etc.)
/gscmnt/sata132/techd/mgriffit/reference_annotations/
/gscmnt/sata132/techd/mgriffit/reference_annotations/EnsemblGene/
/gscmnt/sata132/techd/mgriffit/reference_annotations/EntrezGene/
/gscmnt/sata132/techd/mgriffit/reference_annotations/GeneSymbolLists/
/gscmnt/sata132/techd/mgriffit/reference_annotations/hg18/
/gscmnt/sata132/techd/mgriffit/reference_annotations/hg18/ideogram/
/gscmnt/sata132/techd/mgriffit/reference_annotations/hg18/transcript_to_gene/
/gscmnt/sata132/techd/mgriffit/reference_annotations/hg19/
/gscmnt/sata132/techd/mgriffit/reference_annotations/hg19/ideogram/
/gscmnt/sata132/techd/mgriffit/reference_annotations/hg19/transcript_to_gene/
/gscmnt/sata132/techd/mgriffit/DruggableGenes/KnownDruggable/DrugBank/query_files/


#TODO / Feature wish list
#- Summary stats.tsv -> # SNVs, #tier 1,2,3, WGS. vs. Exome, etc.
#- CNV amplified / deleted + over-expressed / under-expressed
#- WGS vs. Exome Venn Diagrams : For SNVs & Indels
#- Mutated and expressed vs. not expressed summary
#- RNA-seq variant validation
#  - BAM read counts ... WGS, Exome, RNA
#  - Cufflinks expression.  FPKM + percentile
#- RNA-seq outlier analysis
#  - Differential / relative comparisons to other samples / tumors of the same type
#- SVs.  Annotation strategies, validation, filtering
#- RNA-seq gene fusions
#  - Tophat fusion, Chimera scan
#- Previously discovered variants
#- Germline variants
#- Find partial gene amplifications / deletions
#  - Use 'gmt copy-number cbs' and 'gmt copy-number cna-seg' to find segments that are copy-number amplified/deleted
#  - Find the genes that overlap these regions
#- Overlap of observed mutations with Cosmic / OMIM sites (use MUSIC?)
#- Overlap of observed mutations with TGI recurrent sites



