#!/gsc/bin/sh

Pvalue=$1;
rt=$2;
rn=$3;
DIR=$4;
job=j$5;
echo $DIR;
mkdir $DIR;
for g in `awk '{print $1};' data/Gene_SNPfrequency.list`; do 
#for g in `awk '{print $1};' data/Selected_Genes.lst`; do 
    bsub -q aml -oo $DIR/$g.log -J $job "scripts/PyroScan.pl -g $g -ref data/ref_seqsByGene/$g.fasta -qt data/gene_dir/$g/reads-tumor.fasta.qual -cmt data/gene_dir/$g/reads-tumor.$g.crossmatch.kchen.p4.screen.out -qn data/gene_dir/$g/reads-normal.fasta.qual -cmn data/gene_dir/$g/reads-normal.$g.crossmatch.kchen.p4.screen.out -p $Pvalue -rt $rt -rn $rn 1>$DIR/$g.stat";
done
