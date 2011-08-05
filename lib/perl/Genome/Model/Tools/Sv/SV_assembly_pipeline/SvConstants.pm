package SvConstants;

use Carp;

#
# Directory paths, parameters, etc.
#
# For each sample make a directory with format:
#     "$PathToOutput/chr$chr/$sample"."_".$chr."_".$start."_".$stop;
# This is done in 'getReads.pl'
#

# This is where reads are dumped and all output files are written (different subdirectory for each chromosome)
#$PathToOutput = "/gscmnt/sata194/info/sralign/jwallis/structuralVariationExamples/ceuTril";
#$PathToOutput = "/gscmnt/sata194/info/sralign/jwallis/structuralVariationExamples/GBM/H_GP-0124t_090410";
#$PathToOutput = "/gscmnt/sata831/info/medseq/jwallis/OV1/090510/translocation";   # translocations
#$PathToOutput = "/gscmnt/sata831/info/medseq/jwallis/OV1/090510";
#$PathToOutput = "/gscmnt/sata831/info/medseq/jwallis/BreastCancer/090603/DeletionEndpoints";
#$PathToOutput = "/gscmnt/sata831/info/medseq/jwallis/OV2";
#$PathToOutput = "/gscmnt/sata831/info/medseq/jwallis/AML_translocations/AML12";
#$PathToOutput = "/gscmnt/sata831/info/medseq/jwallis/AML11_fragmentReads";
#$PathToOutput = "/gscmnt/sata831/info/medseq/jwallis/BreastCancer/091007";
$PathToOutput = "/gscmnt/sata831/info/medseq/jwallis/BreastCancer/091103";

                
# File with regions defined by Ken as potential variants.
#$SvFile = "$PathToOutput/tumor.4sd.normal.3sd.germline_somatic_del_inv.sv.Germline";
#$SvFile = "$PathToOutput/tumor.4sd.normal.3sd.germline_somatic_del_inv.sv.Somatic";
#$SvFile = "$PathToOutput/allInvIrx2009Jan12.noSatellite_090210";
#$SvFile = "$PathToOutput/confirmedInversions_090309.txt.noSat";
#$SvFile = "$PathToOutput/HuRef.homozygous_indels.inversion.chr17.gff.20bp+.log.noSatellite_090115";
#$SvFile = "$PathToOutput/allDelIns090202.txt.noSatellite_090210";
#$SvFile = "$PathToOutput/annotatedRegionList_090406.txt";
#$SvFile = "$PathToOutput/potentialTumorSVs_090417.txt";
#$SvFile = "$PathToOutput/translocationFile.txt";  # translocations
#$SvFile = "$PathToOutput/090510_allSomaticSv.noSatelliteNoTranslocationWithGenes";
#$SvFile = "$PathToOutput/allSVs_090603.noSatellite.noCTX.WithGenes";
#$SvFile = "$PathToOutput/GBM1.allchr.3sd.q40.del.q60.z100.ins.q60.z100.inv.2lib.round3.sv.noSat.withGenes_ver2";
#$SvFile = "$PathToOutput/deletions_090603.noSatellite.WithGenes";
#$SvFile = "$PathToOutput/allBreastCancerSVs_090708.noRepeatsWithGenes";
#$SvFile = "$PathToOutput/finalFifteenTranslocations091007.csv"; 
#$SvFile = "$PathToOutput/chr1_6Translocation.csv"; 
#$SvFile = "$PathToOutput/BC1SvForValidation_090825.csv"; 
#$SvFile = "$PathToOutput/combinedFileAllEvents.csv"; 
$SvFile = "$PathToOutput/combinedFileAllEvents_091103.csv";


$SampleToReadFile{"tumor"} = "/gscmnt/sata840/info/model_data/2785627887/build97629901/alignments/H_GQ-6888-D59687_merged_rmdup.bam";
$SampleToReadFile{"normal"} = "/gscmnt/sata840/info/model_data/2785622871/build97629549/alignments/H_GQ-206-0900339_merged_rmdup.bam";
$SampleToReadFile{"brainMets"} = "/gscmnt/sata903/info/model_data/2785622638/build97754333/alignments/H_GQ-206-D100109_merged_rmdup.bam";
$SampleToReadFile{"xenograft"} = "/gscmnt/sata835/info/medseq/model_data/2821006913/build98941414/alignments/H_KU-6888-D_MA_59689_merged_rmdup.bam";
@SampleNames = keys %SampleToReadFile;  # so other scripts will work



# Names of each member of the group
#@SampleNames = qw( NA19238 NA19239 NA19240);
#@SampleNames = qw(tumor normal); 
#@SampleNames = qw(jcv ref); 
#@SampleNames = qw(tumor skin);    
#@SampleNames = qw(combined NA12892 NA12891 NA12878);  # Mother NA12892, Father NA12891, Child NA12878
#@SampleNames = qw(tumor brainMets xenograft normal);
#@SampleNames = qw(tumor brainMets  normal);


# This is where the reads are kept. This is needed for David's program
#$PathToMapFiles = "/gscmnt/sata180/info/medseq/dlarson/YRI_Analysis";
#$PathToMapFiles = "/gscmnt/sata146/info/medseq/dlarson/GBM";
#$PathToMapFiles = "/gscmnt/sata194/info/sralign/xxx/1000genomes/simulation/proj/Venter_chr17/experiments";
#$PathToMapFiles = "/gscmnt/sata135/info/medseq/dlarson/AML2";
#$PathToMapFiles = "/gscmnt/sata194/info/sralign/1000genomes/data/ftp.1000genomes.ebi.ac.uk/analysis";
#$PathToMapFiles = "/gscmnt/sata821/info/model_data";
#$PathToMapFiles = "/gscmnt/sata831/info/medseq/jwallis/OV1/mapFiles";
#$PathToMapFiles = "/gscmnt/sata831/info/medseq/jwallis/OV2/mapFiles";
#$PathToMapFiles = "/gscmnt/sata831/info/medseq/jwallis/BreastCancer/mapFiles";


# David's program for dumping reads (090216: they are now in the bin)
$MapDumpShort = "map_dump";
$MapDumpLong = "map_dump.long";

# Maximum size of region before it is broken up into separate breakpoints
# (no longer used)
$MaxRegionSize = 200000;

# Buffer around breakpoint.  This should be at least as large as the library insert size
$BreakpointBuffer = 500; #  changed from 500 to 1000 on 090825; changed back to 500 on 091102

# Name of region used to parse cross_match alignments
# This assumes the region is downloaded using Ensembl $SliceAdaptor->fetch_by_region()
# The name given has 'chromosome:NCBI36'
$RegionName = "chromosome:NCBI3";

# File names for paired reads, unpaired reads and reads used by phrap
$PairedFileName = "reads.paired.fasta";
$UnpairedFileName = "reads.unPaired.fasta";
$PhrapReadFileName = "phrapReads.fasta";

# File names for contigs made
$PairedVelvetContig = "contigsPaired.fa";
$UnpairedVelvetContig = "contigsUnpaired.fa";
$PhrapContig = "$PhrapReadFileName.contigs";

#################
# File names for cross_match comparison results
#################
$ReadsToRegion = "readsToRegion.crossmatch";
# Contigs to region
$PhrapContigsToRegion = "phrapContigsToRegion.crossmatch";
$PairedVelvetContigsToRegion = "velvetPairedContigsToRegion.crossmatch";
$UnpairedVelvetContigsToRegion = "velvetUnpairedContigsToRegion.crossmatch";
# Reads to assembly contigs
$ReadsToPhrapContigs = "readsToPhrapContigs.crossmatch";
$ReadsToPairedVelvetContigs = "readsToVelvetPaired.crossmatch";
$ReadsToUnpairedVelvetContigs = "readsToVelvetUnpaired.crossmatch";
# For tumor/normal samples
$NormalReadsToVelvetPairedTumor = "normalReadsToVelvetPairedTumor.crossmatch";
$NormalReadsToVelvetUnpairedTumor = "normalReadsToVelvetUnpairedTumor.crossmatch";
$NormalReadsToPhrapTumor = "normalReadsToPhrapTumor.crossmatch";


# Velvet parameters
$K = 19;
$MinContigLength = 50;
$Coverage = 20;
$ReadLength = 36;
$InsertLength = 260;

# phrap parameters
$Phrap = "/gsc/pkg/bio/phrap/test/phrap";
$PhrapParameters = " -minscore 20 -vector_bound 0 -bandwidth 2 -max_group_size 0 -view -revise_greedy";

# cross_match parameters
$CrossMatch = "/gsc/pkg/bio/phrap/test/cross_match";
$CrossMatchParameters = "-discrep_lists -alignments  -minmatch 10 -maxmatch 10 -minscore 15";

# Alignment parameters
# Max number of bases at end of read that are not part of the alignment
# If set to 0, there has to be an end-to-end alignment.  This is for alignment of reads only
$MaxEndBases = 2;
$MaxMismatch = 6.7;   # 2/30 = 6.67
$MaxInDel = 6.7;  # Max % insertion or deletion

# Minimum number of reads covering a breakpoint to consider it 'covered'
$MinSupportingReads = 2;

# This is used to parse the cross_match hits
my $number = "\\d+\\.?\\d*";
my $deleted = "\\(\\s*\\d+\\s*\\)";
$AlignmentLine = "($number)\\s+($number)\\s+($number)\\s+($number)\\s+(\\S+)\\s+(\\d+)\\s+(\\d+)\\s+($deleted)\\s+(C\\s+)?(\\S+)\\s+($deleted)?\\s*(\\d+)\\s+(\\d+)\\s*($deleted)?";

# Example cross_match output line:
# 440  2.38 1.39 0.79  hh44a1.s1       33   536 (    0)  C 00311     ( 3084)  8277   7771  *

# 440 = smith-waterman score of the match (complexity-adjusted, by default).
# 2.38 = %substitutions in matching region
# 1.39 = %deletions (in 1st seq rel to 2d) in matching region
# 0.79 = %insertions (in 1st seq rel to 2d) in matching region
# hh44a1.s1 = id of 1st sequence
# 33 = starting position of match in 1st sequence
# 536 = ending position of match in 1st sequence
# (0) = no. of bases in 1st sequence past the ending position of match
#          (so 0 means that the match extended all the way to the end of
#           the 1st sequence)
# C : match is with the Complement of sequence name '00311'
# 00311: subject name
# ( 3084) <optional> : there are 3084 bases in (complement of) 2d sequence prior to
#         beginning of the match
# 8277 = starting position of match in 2d sequence (using top-strand
#          numbering)
# 7771 =  ending position of match in 2d sequence
# ( $num) <optional> : there are $num bases of 2nd sequence after end of match
# * indicates that there is a higher-scoring match whose domain partly
# includes the domain of this match.



return 1;
