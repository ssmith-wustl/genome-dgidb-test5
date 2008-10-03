#!/gsc/bin/sh

penalty=4;
for g in `awk '{print $1;}' Gene_SNPfrequency.list`; do
    for sample in tumor normal; do
	bsub -oo gene_dir/$g/reads-$sample.$g.crossmatch.kchen.p$penalty.screen.log -J cmp4 "cross_match.test gene_dir/$g/reads-$sample.fasta.screen ~/454-TSP-Test/Analysis/Ken/data/ref_seqsByGene/$g.fasta -minmatch 12 -minscore 25 -penalty -$penalty -discrep_lists -tags -gap_init -3 -gap_ext -1 > gene_dir/$g/reads-$sample.$g.crossmatch.kchen.p$penalty.screen.out";
    done
done
