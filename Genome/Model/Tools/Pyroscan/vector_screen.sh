#!/gsc/bin/sh

penalty=4;
for g in `awk '{print $1;}' Gene_SNPfrequency.list`; do
    for sample in tumor normal; do
	bsub -oo gene_dir/$g/reads-$sample.$g.vector.screen.log -J cmvector "cd gene_dir/$g; cross_match.test reads-$sample.fasta ~/454-TSP-Test/Analysis/Ken/data/vector.fasta -minmatch 10 -minscore 15 -screen > reads-$sample.screen.out; ln -s reads-$sample.fasta.qual reads-$sample.fasta.screen.qual";
    done
done
