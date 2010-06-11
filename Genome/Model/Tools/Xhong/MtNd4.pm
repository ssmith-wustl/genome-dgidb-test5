package Genome::Model::Tools::Xhong::MtNd4;

use strict;
use warnings;

use Genome;
use Command;

my @exciting_recurrencies = Genome::Model::Variant->get(gene_name=>"MT-ND4");

for my $variant (@exciting_recurrencies) {
	my @builds_variant_was_found_in = Genome::Model::Build::Variant->get(variant_id=>$variant->id);
	for my $build (@builds_variant_was_found_in){
		my $tumor_model = $build->tumor_model;
		my $normal_model = $build->normal_model;
		my $normal_bam = $normal_model->last_succeeded_build->whoel_rmdup_bam_file;
		my $tumor_bam = $normal_model->last_succeeded_build->whole_rmdup_bam_file;
		my $somatic_model_name_to_name_the_output_files_with = $build->model->name; 
		system("samtools view -b -o /tmp/normal.MT.bam $normal_bam MT:1");
		system("samtools view -b -o /tmp/tumor.MT.bam $tumor_bam MT:1");

		system("gmt varscan somatic --normal-bam /tmp/normal.MT.bam --tumor-bam /tmp/tumor.MT.bam --output /tmp/MT-ND4.varScan.output");
	}
}	