#!/gsc/bin/sh

Pvalue=$1;
ratio=$2;
DIR=$3;
echo $DIR;
mkdir $DIR;
for g in `awk '{print $1};' data/Gene_SNPfrequency.list`; do 
    bsub -q aml -oo $DIR/$g.log -J snpcall "scripts/SNPCall.pl -g $g -ref data/ref_seqsByGene/$g.fasta -qt data/gene_dir/$g/reads-tumor.fasta.qual -cmt data/gene_dir/$g/reads-tumor.$g.crossmatch.kchen.allgenes.out -p $Pvalue 1>$DIR/$g.stat";
done
