
#This script takes an input gene list and annotates it against various lists of gene setting values as 0/1
#e.g. I have a list of 1000 genes, and I want to know which is a kinase, transcription factor, etc.

#Input parameters / options
#Input file (containing gene names)
#Gene name column.  Column number containing gene symbols
#Symbol lists to annotate with (display a list of gene symbol lists to select from and the location being queried)
#Output file

#1.) Take an input file with gene names in it
#2.) Get the gene name column from input
#3.) 'fix' gene names to Entrez official gene symbols
#4.) Load the symbols lists (fixing gene names on each)
#5.) Intersect the gene names in the input list with each symbol list
#6.) Print output file with annotations and new column headers appended


