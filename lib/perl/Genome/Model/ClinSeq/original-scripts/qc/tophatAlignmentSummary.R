#!/usr/bin/env Rscript
#Written by Malachi Griffith
#Start with results from tophatAlignmentSummary.pl.  Summarize and visualize the outcome

args = (commandArgs(TRUE))
working_dir = args[1]; #Directory where output will be written
#working_dir="/Users/mgriffit/Dropbox/Documents/Analysis_development/tophat/"

if (length(args) < 1){
  message_text1 = "Required arguments missing for tophatAlignmentSummary.R"
  stop(message_text1)
}

#Load libraries
library(ggplot2)

#Set working directory and load all neccessary input files
setwd(working_dir)

alignment_stats = read.table("alignment_stats.txt", header=TRUE, as.is=1, sep="\t", comment.char="#")
all_junction_ss = read.table("ALL.junctions.splicesites.junc", header=TRUE, as.is=c(1,4), sep="\t")
ensg_junction_ss = read.table("Ensembl.junctions.splicesites.junc", header=TRUE, as.is=c(1,4), sep="\t")
obs_junction_anno_all = read.table("observed.junctions.anno.ALL.tsv", header=TRUE, as.is=c(1,4,5,9), sep="\t", na.strings=c("na","NA","n/a","N/A"))
obs_junction_anno_ensg = read.table("observed.junctions.anno.Ensembl.tsv", header=TRUE, as.is=c(1,4,5,9), sep="\t", na.strings=c("na","NA","n/a","N/A"))
gene_expression = read.table("Ensembl.Junction.GeneExpression.tsv", header=TRUE, as.is=c(1,2,3,4), sep="\t", na.strings=c("na","NA","n/a","N/A"))
transcript_expression = read.table("Ensembl.Junction.TranscriptExpression.tsv", header=TRUE, as.is=c(1,2,3,4), sep="\t", na.strings=c("na","NA","n/a","N/A"))

#Create an output directory and set that to the working directory
results_dir=paste(working_dir, "summary_stats/", sep="")
dir.create(results_dir, showWarnings = FALSE)
setwd(results_dir)

#Initialize a stats data.frame
stats = data.frame(NA,NA,NA,NA,NA,NA)
names(stats) = c("Question", "Answer", "Data_Type", "Analysis_Type", "Statistic_Type", "Extra description")

#- Summarize the alignment stats file
#- Total and percent of total for the following: reads, total reads mapped, unmapped reads, multiple hit reads



#- Further summarize the alignment stats file (treat MT alignments separately)
mt_chrs = which(alignment_stats[,"chr"]=="MT")
nonmt_chrs = which(!alignment_stats[,"chr"]=="MT")
sum_top_alignments = sum(alignment_stats[,"top"])
sum_top_alignments_mt = sum(alignment_stats[mt_chrs,"top"])
sum_top_alignments_mt_p = (sum_top_alignments_mt/sum_top_alignments)*100
sum_top_alignments_nonmt = sum(alignment_stats[nonmt_chrs,"top"])
sum_top_alignments_nonmt_p = (sum_top_alignments_nonmt/sum_top_alignments)*100
sum_top_spliced_alignments_nonmt = sum(alignment_stats[nonmt_chrs,"top.spliced"])
sum_top_spliced_alignments_nonmt_p = (sum_top_spliced_alignments_nonmt/sum_top_alignments_nonmt)*100
sum_multi_reads_nonmt = sum(alignment_stats[nonmt_chrs,"multi_reads"])
sum_multi_reads_nonmt_p = (sum_multi_reads_nonmt/(sum_top_alignments_nonmt+sum_multi_reads_nonmt))*100


#Store these stats in the stats object for printing later
stats[dim(stats)[1],] = c("TopHat 'top' alignments", sum_top_alignments, "RNA-seq", "Alignments", "Count", "Number of 'top' read alignments found by TopHat")
stats[dim(stats)[1]+1,] = c("TopHat 'top' alignments - Mt only", sum_top_alignments_mt, "RNA-seq", "Alignments", "Count", "Number of 'top' read alignments found by TopHat for Mt chromosome only")
stats[dim(stats)[1]+1,] = c("TopHat 'top' alignments - Mt only", sum_top_alignments_mt_p, "RNA-seq", "Alignments", "Percent", "Percent of 'top' read alignments found by TopHat that hit the Mt chromosome")
stats[dim(stats)[1]+1,] = c("TopHat 'top' alignments - Non-Mt", sum_top_alignments_nonmt, "RNA-seq", "Alignments", "Count", "Number of 'top' read alignments found by TopHat for all Non-Mt chromosomes")
stats[dim(stats)[1]+1,] = c("TopHat 'top' alignments - Non-Mt", sum_top_alignments_nonmt_p, "RNA-seq", "Alignments", "Percent", "Percent of 'top' read alignments found by TopHat that hit any chromosome but Mt")
stats[dim(stats)[1]+1,] = c("TopHat 'top spliced' alignments - Non-Mt", sum_top_spliced_alignments_nonmt, "RNA-seq", "Alignments", "Count", "Number of 'top spliced' read alignments found by TopHat that hit any chromosome but Mt")
stats[dim(stats)[1]+1,] = c("TopHat 'top spliced' alignments - Non-Mt", sum_top_spliced_alignments_nonmt_p, "RNA-seq", "Alignments", "Percent", "Percent of read alignments found by TopHat that are 'top spliced' and hit any chromosome but Mt")
stats[dim(stats)[1]+1,] = c("TopHat 'multi map' alignments - Non-Mt", sum_multi_reads_nonmt, "RNA-seq", "Alignments", "Count", "Number of reads that are multi-mapped by TopHat and hit any chromosome but Mt")
stats[dim(stats)[1]+1,] = c("TopHat 'multi map' alignments - Non-Mt", sum_multi_reads_nonmt_p, "RNA-seq", "Alignments", "Percent", "Percent of reads that are multi-mapped by TopHat and hit any chromosome but Mt")


#- Basic junction stats: 
#  - Total junctions observed
#  - Total known junctions observed
#  - Proportion of all junctions observed that are known (based on ALL annotations and Ensembl only)
#  - ALL
total_junctions_observed = dim(obs_junction_anno_all)[1]
stats[dim(stats)[1]+1,] = c("Total distinct junctions observed", total_junctions_observed, "RNA-seq", "Alignments", "Count", "Number of distinct exon-exon junctions observed by 1 or more reads")

total_known_junctions_observed_all = length(which(obs_junction_anno_all[,"Anchored"] == "DA"))
stats[dim(stats)[1]+1,] = c("Total distinct known junctions observed (ALL annotations)", total_known_junctions_observed_all, "RNA-seq", "Alignments", "Count", "Number of distinct *known* exon-exon junctions observed by 1 or more reads (ALL annotations)")

total_known_junctions_observed_all_p = (total_known_junctions_observed_all/total_junctions_observed)*100
stats[dim(stats)[1]+1,] = c("Percent observed junctions that are known (ALL annotations)", total_known_junctions_observed_all_p, "RNA-seq", "Alignments", "Percent", "Percent of observed exon-exon junctions that correspond to a known transcript (ALL annotations)")

# - Ensembl
total_known_junctions_observed_ensg = length(which(obs_junction_anno_ensg[,"Anchored"] == "DA"))
stats[dim(stats)[1]+1,] = c("Total distinct known junctions observed (Ensembl annotations)", total_known_junctions_observed_ensg, "RNA-seq", "Alignments", "Count", "Number of distinct *known* exon-exon junctions observed by 1 or more reads (Ensembl annotations)")

total_known_junctions_observed_ensg_p = (total_known_junctions_observed_ensg/total_junctions_observed)*100
stats[dim(stats)[1]+1,] = c("Percent observed junctions that are known (Ensembl annotations)", total_known_junctions_observed_ensg_p, "RNA-seq", "Alignments", "Percent", "Percent of observed exon-exon junctions that correspond to a known transcript (Ensembl annotations)")

#  - Proportion of all known junctions that were observed (based on ALL annotations and Ensembl only)
total_known_junctions_all = dim(all_junction_ss)[1]
stats[dim(stats)[1]+1,] = c("Total known junctions possible (ALL annotations)", total_known_junctions_all, "RNA-seq", "Alignments", "Count", "Number of known exon-exon junctions in the annotation source (ALL annotations)")
total_known_junctions_all_p = (total_known_junctions_observed_all/total_known_junctions_all)*100
stats[dim(stats)[1]+1,] = c("Percent known junctions actually observed (ALL annotations)", total_known_junctions_all_p, "RNA-seq", "Alignments", "Count", "Percent of known exon-exon junctions in the annotation source that were actually observed in the data (ALL annotations)")

total_known_junctions_ensg = dim(ensg_junction_ss)[1]
stats[dim(stats)[1]+1,] = c("Total known junctions possible (Ensembl annotations)", total_known_junctions_ensg, "RNA-seq", "Alignments", "Count", "Number of known exon-exon junctions in the annotation source (Ensembl annotations)")
total_known_junctions_ensg_p = (total_known_junctions_observed_ensg/total_known_junctions_ensg)*100
stats[dim(stats)[1]+1,] = c("Percent known junctions actually observed (Ensembl annotations)", total_known_junctions_ensg_p, "RNA-seq", "Alignments", "Count", "Percent of known exon-exon junctions in the annotation source that were actually observed in the data (Ensembl annotations)")


#  - Total exon skipping junctions observed (and proportion of the library)
exon_skipping_junctions_observed_ensg = length(which(obs_junction_anno_ensg[,"Exons_Skipped"] > 0))
exon_skipping_junctions_observed_ensg_p = (exon_skipping_junctions_observed_ensg/total_junctions_observed)*100
stats[dim(stats)[1]+1,] = c("Total exon skipping junctions observed", exon_skipping_junctions_observed_ensg, "RNA-seq", "Alignments", "Count", "Number of exon skipping junctions observed")
stats[dim(stats)[1]+1,] = c("Percent of junctions observed that are exon skipping", exon_skipping_junctions_observed_ensg_p, "RNA-seq", "Alignments", "Percent", "Percent of junctions observed that are exon skipping")

#  - Total novel exon skipping junctions observed (and proportion of the library)
novel_exon_skipping_junctions_observed_ensg = length(which(obs_junction_anno_ensg[,"Exons_Skipped"] > 0 & obs_junction_anno_ensg[,"Anchored"] == "NDA"))
novel_exon_skipping_junctions_observed_ensg_p = (novel_exon_skipping_junctions_observed_ensg/total_junctions_observed)*100
stats[dim(stats)[1]+1,] = c("Total *novel* exon skipping junctions observed", novel_exon_skipping_junctions_observed_ensg, "RNA-seq", "Alignments", "Count", "Number of novel exon skipping junctions observed")
stats[dim(stats)[1]+1,] = c("Percent of junctions observed that are novel exon skipping", novel_exon_skipping_junctions_observed_ensg_p, "RNA-seq", "Alignments", "Percent", "Percent of junctions observed that are novel exon skipping")

#- Pie chart of splice sites observed (GC-AG, GT-AC, etc.) - compare to a pie chart of all known splice sites ...
observed_ss_counts = table(obs_junction_anno_ensg[,"Splice_Site"])
zz=as.data.frame(observed_ss_counts)
names(zz) = c("SpliceSite", "Count")
pdf("ObservedJunctions_SpliceSiteUsage_Pie.pdf")
print({
	pp <- ggplot(zz, aes(x='', y=Count, fill=SpliceSite)) + geom_bar(width=1) + coord_polar("y") + xlab("") + 	ylab("") + opts(title="Splice site usages in observed exon-exon junctions")
})
dev.off()

ensg_ss_counts = table(ensg_junction_ss[,"splice_site"])
zz=as.data.frame(ensg_ss_counts)
names(zz) = c("SpliceSite", "Count")
pdf("KnownEnsemblJunctions_SpliceSiteUsage_Pie.pdf")
print({
	pp <- ggplot(zz, aes(x='', y=Count, fill=SpliceSite)) + geom_bar(width=1) + coord_polar("y") + xlab("") + 	ylab("") + opts(title="Splice site usages in known Ensembl exon-exon junctions")
})
dev.off()

#Store the observed splice site usage numbers/percentages 
atac_p = (observed_ss_counts["AT-AC"] / total_junctions_observed)*100
gcag_p = (observed_ss_counts["GC-AG"] / total_junctions_observed)*100
gtag_p = (observed_ss_counts["GT-AG"] / total_junctions_observed)*100

stats[dim(stats)[1]+1,] = c("Percent of AT-AC junctions observed", atac_p, "RNA-seq", "Alignments", "Percent", "Percent of junctions observed that use an AT-AC splice site")
stats[dim(stats)[1]+1,] = c("Percent of GC-AG junctions observed", gcag_p, "RNA-seq", "Alignments", "Percent", "Percent of junctions observed that use an GC-AG splice site")
stats[dim(stats)[1]+1,] = c("Percent of GT-AG junctions observed", gtag_p, "RNA-seq", "Alignments", "Percent", "Percent of junctions observed that use an GT-AG splice site")

#- Pie chart of anchor types (DA, NDA, D, A, N) - Number and Percentage of reads corresponding to each type
anchor_counts = table(obs_junction_anno_ensg[,"Anchored"])
zz=as.data.frame(anchor_counts)
names(zz) = c("AnchorType", "Count")
pdf("ObservedJunctions_SpliceSiteAnchorTypes_Pie.pdf")
print({
	pp <- ggplot(zz, aes(x='', y=Count, fill=AnchorType)) + geom_bar(width=1) + coord_polar("y") + xlab("A = acceptor, D = donor, NDA = Novel donor/acceptor, N = not anchored") + 	ylab("") + opts(title="Splice site anchor types in observed exon-exon junctions")
})
dev.off()

#- Distribution of exon-exon junction read counts
obs_junction_anno_ensg[,"Read_Count_Log2"] = log2(obs_junction_anno_ensg[,"Read_Count"])
pdf("ObservedJunctions_ReadCounts_Log2_Hist.pdf")
print({
	m <- ggplot(obs_junction_anno_ensg, aes(x=Read_Count_Log2)); m + geom_histogram(aes(y = ..density.., fill= ..count..)) + geom_density() + opts(title="Distribution of exon junction read counts") + xlab("Junction Read Count (log2)") + ylab("Frequency")
})
dev.off()

#- Display junction read count distribution at both the gene and transcript level
i=which(gene_expression[,"read_count"] > 0)
nonzero_count = length(i)
data = gene_expression[i,c("fid","read_count")]
data[,"read_count_log2"] = log2(data[,"read_count"]+1)
pdf("GeneJunctionReadCounts_Log2_Hist.pdf")
print({
	ylabel = paste("Frequency (n = ", nonzero_count, " detected genes)", sep="")
	m <- ggplot(data, aes(x=read_count_log2)); m + geom_histogram(aes(y = ..density.., fill= ..count..)) + geom_density() + opts(title="Distribution of exon junction read counts - Gene level") + xlab("Gene Junction Read Count (log2)") + ylab(ylabel)
})
dev.off()

i=which(transcript_expression[,"read_count"] > 0)
nonzero_count = length(i)
data = transcript_expression[i,c("fid","read_count")]
data[,"read_count_log2"] = log2(data[,"read_count"]+1)
pdf("TranscriptJunctionReadCounts_Log2_Hist.pdf")
print({
	ylabel = paste("Frequency (n = ", nonzero_count, " detected transcripts)", sep="")
	m <- ggplot(data, aes(x=read_count_log2)); m + geom_histogram(aes(y = ..density.., fill= ..count..)) + geom_density() + opts(title="Distribution of exon junction read counts - Transcript level") + xlab("Gene Junction Read Count (log2)") + ylab(ylabel)
})
dev.off()

#How many junctions, known junctions, transcripts, genes are detected by: >1, >10, >30, >100 reads
junctions_rc_1x = length(which(obs_junction_anno_ensg[,"Read_Count"] >= 1))
junctions_rc_10x = length(which(obs_junction_anno_ensg[,"Read_Count"] >= 10))
junctions_rc_30x = length(which(obs_junction_anno_ensg[,"Read_Count"] >= 30))
junctions_rc_100x = length(which(obs_junction_anno_ensg[,"Read_Count"] >= 100))
known_junctions_rc_1x = length(which(obs_junction_anno_ensg[,"Read_Count"] >= 1 & obs_junction_anno_ensg[,"Anchored"] == "DA"))
known_junctions_rc_10x = length(which(obs_junction_anno_ensg[,"Read_Count"] >= 10 & obs_junction_anno_ensg[,"Anchored"] == "DA"))
known_junctions_rc_30x = length(which(obs_junction_anno_ensg[,"Read_Count"] >= 30 & obs_junction_anno_ensg[,"Anchored"] == "DA"))
known_junctions_rc_100x = length(which(obs_junction_anno_ensg[,"Read_Count"] >= 100 & obs_junction_anno_ensg[,"Anchored"] == "DA"))
transcripts_rc_1x = length(which(transcript_expression[,"read_count"] >= 1))
transcripts_rc_10x = length(which(transcript_expression[,"read_count"] >=10))
transcripts_rc_30x = length(which(transcript_expression[,"read_count"] >= 30))
transcripts_rc_100x = length(which(transcript_expression[,"read_count"] >= 100))
genes_rc_1x = length(which(gene_expression[,"read_count"] >= 1))
genes_rc_10x = length(which(gene_expression[,"read_count"] >= 10))
genes_rc_30x = length(which(gene_expression[,"read_count"] >= 30))
genes_rc_100x = length(which(gene_expression[,"read_count"] >= 100))
stats[dim(stats)[1]+1,] = c("Junctions observed at >= 1X", junctions_rc_1x, "RNA-seq", "Alignments", "Count", "Number of junctions observed by >= 1 reads")
stats[dim(stats)[1]+1,] = c("Junctions observed at >= 10X", junctions_rc_10x, "RNA-seq", "Alignments", "Count", "Number of junctions observed by >= 10 reads")
stats[dim(stats)[1]+1,] = c("Junctions observed at >= 30X", junctions_rc_30x, "RNA-seq", "Alignments", "Count", "Number of junctions observed by >= 30 reads")
stats[dim(stats)[1]+1,] = c("Junctions observed at >= 100X", junctions_rc_100x, "RNA-seq", "Alignments", "Count", "Number of junctions observed by >= 100 reads")
stats[dim(stats)[1]+1,] = c("Known junctions observed at >= 1X", known_junctions_rc_1x, "RNA-seq", "Alignments", "Count", "Number of known junctions observed by >= 1 reads")
stats[dim(stats)[1]+1,] = c("Known junctions observed at >= 10X", known_junctions_rc_10x, "RNA-seq", "Alignments", "Count", "Number of known junctions observed by >= 10 reads")
stats[dim(stats)[1]+1,] = c("Known junctions observed at >= 30X", known_junctions_rc_30x, "RNA-seq", "Alignments", "Count", "Number of known junctions observed by >= 30 reads")
stats[dim(stats)[1]+1,] = c("Known junctions observed at >= 100X", known_junctions_rc_100x, "RNA-seq", "Alignments", "Count", "Number of known junctions observed by >= 100 reads")
stats[dim(stats)[1]+1,] = c("Transcripts observed at >= 1X", transcripts_rc_1x, "RNA-seq", "Alignments", "Count", "Number of transcripts (measured by their junctions) observed by >= 1 reads")
stats[dim(stats)[1]+1,] = c("Transcripts observed at >= 10X", transcripts_rc_10x, "RNA-seq", "Alignments", "Count", "Number of transcripts (measured by their junctions) observed by >= 10 reads")
stats[dim(stats)[1]+1,] = c("Transcripts observed at >= 30X", transcripts_rc_30x, "RNA-seq", "Alignments", "Count", "Number of transcripts (measured by their junctions) observed by >= 30 reads")
stats[dim(stats)[1]+1,] = c("Transcripts observed at >= 100X", transcripts_rc_100x, "RNA-seq", "Alignments", "Count", "Number of transcripts (measured by their junctions) observed by >= 100 reads")
stats[dim(stats)[1]+1,] = c("Genes observed at >= 1X", genes_rc_1x, "RNA-seq", "Alignments", "Count", "Number of genes (measured by their junctions) observed by >= 1 reads")
stats[dim(stats)[1]+1,] = c("Genes observed at >= 10X", genes_rc_10x, "RNA-seq", "Alignments", "Count", "Number of genes (measured by their junctions) observed by >= 10 reads")
stats[dim(stats)[1]+1,] = c("Genes observed at >= 30X", genes_rc_30x, "RNA-seq", "Alignments", "Count", "Number of genes (measured by their junctions) observed by >= 30 reads")
stats[dim(stats)[1]+1,] = c("Genes observed at >= 100X", genes_rc_100x, "RNA-seq", "Alignments", "Count", "Number of genes (measured by their junctions) observed by >= 100 reads")

#- Expression distribution bias.  Percentage of all reads consumed by top N .. M % of detected genes
detected_genes = length(which(gene_expression[,"read_count"] >= 1))
read_counts = gene_expression[which(gene_expression[,"read_count"] >= 1), "read_count"]
read_counts_o = read_counts[order(read_counts, decreasing=TRUE)]
grand_read_count = sum(read_counts_o)
genes_001p = floor(detected_genes * (0.01/100))
genes_01p = floor(detected_genes * (0.1/100))
genes_1p = floor(detected_genes * (1/100))
genes_2p = floor(detected_genes * (2/100))
genes_5p = floor(detected_genes * (5/100))
genes_10p = floor(detected_genes * (10/100))
genes_20p = floor(detected_genes * (20/100))
genes_30p = floor(detected_genes * (30/100))
genes_40p = floor(detected_genes * (40/100))
genes_50p = floor(detected_genes * (50/100))
reads_consumed_001p = (sum(read_counts_o[1:genes_001p])/grand_read_count)*100
reads_consumed_01p = (sum(read_counts_o[1:genes_01p])/grand_read_count)*100
reads_consumed_1p = (sum(read_counts_o[1:genes_1p])/grand_read_count)*100
reads_consumed_2p = (sum(read_counts_o[1:genes_2p])/grand_read_count)*100
reads_consumed_5p = (sum(read_counts_o[1:genes_5p])/grand_read_count)*100
reads_consumed_10p = (sum(read_counts_o[1:genes_10p])/grand_read_count)*100
reads_consumed_20p = (sum(read_counts_o[1:genes_20p])/grand_read_count)*100
reads_consumed_30p = (sum(read_counts_o[1:genes_30p])/grand_read_count)*100
reads_consumed_40p = (sum(read_counts_o[1:genes_40p])/grand_read_count)*100
reads_consumed_50p = (sum(read_counts_o[1:genes_50p])/grand_read_count)*100
stats[dim(stats)[1]+1,] = c("Percent of junctions reads consumed by top 0.01% of detected genes", reads_consumed_001p, "RNA-seq", "Alignments", "Percent", "Percent of junctions reads consumed by top 0.01% of detected genes (>=1 junction read for the gene)")
stats[dim(stats)[1]+1,] = c("Percent of junctions reads consumed by top 0.1% of detected genes", reads_consumed_01p, "RNA-seq", "Alignments", "Percent", "Percent of junctions reads consumed by top 0.1% of detected genes (>=1 junction read for the gene)")
stats[dim(stats)[1]+1,] = c("Percent of junctions reads consumed by top 1% of detected genes", reads_consumed_1p, "RNA-seq", "Alignments", "Percent", "Percent of junctions reads consumed by top 1% of detected genes (>=1 junction read for the gene)")
stats[dim(stats)[1]+1,] = c("Percent of junctions reads consumed by top 2% of detected genes", reads_consumed_2p, "RNA-seq", "Alignments", "Percent", "Percent of junctions reads consumed by top 2% of detected genes (>=1 junction read for the gene)")
stats[dim(stats)[1]+1,] = c("Percent of junctions reads consumed by top 5% of detected genes", reads_consumed_5p, "RNA-seq", "Alignments", "Percent", "Percent of junctions reads consumed by top 5% of detected genes (>=1 junction read for the gene)")
stats[dim(stats)[1]+1,] = c("Percent of junctions reads consumed by top 10% of detected genes", reads_consumed_10p, "RNA-seq", "Alignments", "Percent", "Percent of junctions reads consumed by top 10% of detected genes (>=1 junction read for the gene)")
stats[dim(stats)[1]+1,] = c("Percent of junctions reads consumed by top 20% of detected genes", reads_consumed_20p, "RNA-seq", "Alignments", "Percent", "Percent of junctions reads consumed by top 20% of detected genes (>=1 junction read for the gene)")
stats[dim(stats)[1]+1,] = c("Percent of junctions reads consumed by top 30% of detected genes", reads_consumed_30p, "RNA-seq", "Alignments", "Percent", "Percent of junctions reads consumed by top 30% of detected genes (>=1 junction read for the gene)")
stats[dim(stats)[1]+1,] = c("Percent of junctions reads consumed by top 40% of detected genes", reads_consumed_40p, "RNA-seq", "Alignments", "Percent", "Percent of junctions reads consumed by top 40% of detected genes (>=1 junction read for the gene)")
stats[dim(stats)[1]+1,] = c("Percent of junctions reads consumed by top 50% of detected genes", reads_consumed_50p, "RNA-seq", "Alignments", "Percent", "Percent of junctions reads consumed by top 50% of detected genes (>=1 junction read for the gene)")

#- Distribution of known junction counts for each gene and transcript 
gene_expression[,"known_junction_count_log2"] = log2(gene_expression[,"known_junction_count"]+1)
pdf("KnownJunctionCounts_Genes_Log2_Hist.pdf")
print({
	m <- ggplot(gene_expression, aes(x=known_junction_count_log2)); m + geom_histogram(aes(y = ..density.., fill= ..count..)) + geom_density() + opts(title="Distribution of known junction counts - Gene level") + xlab("Gene Known Junction Read Count (log2)") + ylab("Frequency")
})
dev.off()

transcript_expression[,"known_junction_count_log2"] = log2(transcript_expression[,"known_junction_count"]+1)
pdf("KnownJunctionCounts_Transcripts_Log2_Hist.pdf")
print({
	m <- ggplot(transcript_expression, aes(x=known_junction_count_log2)); m + geom_histogram(aes(y = ..density.., fill= ..count..)) + geom_density() + opts(title="Distribution of known junction counts - Transcript level") + xlab("Transcript Known Junction Read Count (log2)") + ylab("Frequency")
})
dev.off()

#- Distribution of JPJM values for genes and transcripts


#- How many genes/transcripts exceed a minimum JPJM cutoff value (e.g. >= 1)?


#- For exon-skipping events, display the proportion that are 1S, 2S, 3S, etc. - Show for all known, known observed, novel observed


#- How many genes are covered over the majority of their junctions (25%, 50%, 75%, 90%, 95%, 100%) at different minimum coverage values?
#  - Boxplots of these values?
#  - Report medians


#- Produce ranked gene expression lists based on exon-junction values


#- What is the distribution of observed intron sizes versus known intron sizes


#- Produce a Top N% expressed file


#Write out the stats table
write.table(stats, file="Stats.tsv", quote=FALSE, sep="\t", row.names=FALSE)




