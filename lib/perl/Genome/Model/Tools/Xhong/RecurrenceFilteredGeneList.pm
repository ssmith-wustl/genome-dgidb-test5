package Genome::Model::Tools::Xhong::RecurrenceFilteredGeneList;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::Model::Tools::Xhong::RecurrenceFilteredGeneList {
	is => 'Command',
	has => [
    	sample_name => { type => 'String', is_optional => 1, doc => "the common name of the sample to process", },
        analysis_dir => { type => 'String', is_optional => 0, doc => "Directory where the recurrent gene output will be", },
        ks_filtered_file_list => {type => 'String', is_optional => 0, doc => "filtered SNVs file list,"},
        all_sample_hf1_list  => { type => 'String', is_optional => 0, doc => "The name of the file that contains all tiers high confidence filterd (hf) predictions, analysis_dir will be added",},
        nonsilent_recurrent_gene  => { type => 'String', is_optional => 0, doc => "The name of the file that contains all nonsilent recurrent tier1 hf predictions,analysis_dir will be added ",},
        recurrent_list  => { type => 'String', is_optional => 0, doc => "The name of the file that contains all nonsilent recurrent tier1 hf predictions are in this file, sorted by gene, freq, sample. analysis_dir will be added",},
        ]
};

sub help_brief {
    	"Generates ks filtered tier1 SNV table and found nonsilent recurrent genes. Run example: gmt xhong recurrence-filtered-gene-list --analysis-dir /gscmnt/sata197/info/medseq/PCGP_Analysis/SNVs/hf_table/ --ks-filtered-file /gscmnt/sata197/info/medseq/PCGP_Analysis/SNVs/hf1_list.txt --nonsilent-recurrent-gene SJRHB_nonsilent_recurrent_gene.txt --recurrent-list SJRHB_recurrent_list.txt --all-sample-hf1-list SJRHB_hf1_list.txt --sample-name SJRHB"
}

sub help_detail {
    	<<'HELP';
This script is to find the recurrent ks-filtered SNVs.
HELP
}

sub execute {
	my $self=shift;
    	$DB::single = 1;
    	
    	my $dir=$self->analysis_dir;
    	my $ks_filtered_file = $self->ks_filtered_file_list;
    	my $all_sample_hf1_list=$self->all_sample_hf1_list;
    	my $nonsilent_recurrent_gene=$self->nonsilent_recurrent_gene;
    	my $recurrent_list=$self->recurrent_list;
    	my $sample_name="PCGP";
    	$sample_name=$self->sample_name;
	my $analysis_dir=$self->analysis_dir;
#    	my @samples=split/\,/, $sample_name;
	my %hc1;
	my %gene;
	my %recurrent_gene;
	my %recurrent_sample;
	my %nonsilent;
	my %sample;
	my %lines;
	my ($line,$sample, $chr, $pos, $gene, $change, $key)=("","","","","","","");
	my @column; my @lines; my @name;
 	
 	my $tier="Tier1";
 	open(I, "<$ks_filtered_file") or die "cannot open $ks_filtered_file";
 	my @ks_file=<I>;
 	close I;
 	for my $snv_file(@ks_file){
# 		print $snv_file;
 		$snv_file=~s/\s+$//;
 		my $snp_transcript_annotation = $snv_file.".anno";
		unless (-e $snp_transcript_annotation) {
       			$self->error_message("cannot find $snp_transcript_annotation file");
       			return;
       		}
		my ($t1, $t2,$t3, $t4,$t5,$t6,$t7,$common_name)=split/\//, $snp_transcript_annotation;
		$common_name=~s/\_ksfiltered//;
		print "$sample_name\n";
		if ($sample_name eq "PCGP"){
			@lines = `/gscuser/dlarson/bin/perl-grep-f -f $snv_file $snp_transcript_annotation`;
        		map { $_ = "$common_name\t".$_;} @lines; 
       			push @{$lines{$tier}}, @lines;
		}else{
			if ($common_name =~ $sample_name){
				print "$common_name\n";
				@lines = `/gscuser/dlarson/bin/perl-grep-f -f $snv_file $snp_transcript_annotation`;
				print "@lines\n";
	        		map { $_ = "$common_name\t".$_;} @lines; 
	       			push @{$lines{$tier}}, @lines;
			}
		}	
	}	
    	#write out the lines
    	print "$dir/$all_sample_hf1_list\n";
    	open(FH, ">$dir/$all_sample_hf1_list") or die "cannot create such a $dir/$all_sample_hf1_list file";
    	foreach my $tier (qw{ Tier1 }) {
    		@lines = @{$lines{$tier}};
    		foreach $line (@lines){ 
			print FH $line;
			my @column=split/\t/, $line;
			$sample=$column[0];
			$chr=$column[1];
			$pos=$column[2];
			$gene=$column[7];
			$change=$column[14];
			$key="$chr\t$pos";
			$hc1{$gene}{$sample}{$chr}{$pos}{$change}=$line;
			if ($change ne "silent"){
				$nonsilent{$gene}{$sample}{$chr}{$pos}=$line;
				if (!exists $sample{$sample}){
					$sample{$sample}=1;
				}
#			push @keys, $key;
				if (!exists $gene{$gene}){
					$gene{$gene}=1;
				}else{
					$gene{$gene}=$gene{$gene}+1;
				}
			}
		}
	}		
    	close FH;
    	    	
	my @samples =keys %sample;		
	my @genes= keys %gene;
	my $number_recurrent_gene=0;
	for my $GENE (@genes){
	if ($gene{$GENE} >1){
		for my $SAMPLE (@samples){
			for my $CHR (sort { $a<=>$b } keys %{$nonsilent{$GENE}{$SAMPLE}}){
				for my $POS (sort{ $a <=>$b} keys %{$nonsilent{$GENE}{$SAMPLE}{$CHR}}){
					if (!exists $recurrent_gene{$GENE}) {
						$recurrent_gene{$GENE}	= $nonsilent{$GENE}{$SAMPLE}{$CHR}{$POS};
					}else{
						$recurrent_gene{$GENE}=$recurrent_gene{$GENE}.$nonsilent{$GENE}{$SAMPLE}{$CHR}{$POS};
						}
						if (!exists $recurrent_sample{$GENE}{$SAMPLE}) {
							$recurrent_sample{$GENE}{$SAMPLE}=1;
						}else{
							$recurrent_sample{$GENE}{$SAMPLE}=$recurrent_sample{$GENE}{$SAMPLE}+1;
						}
					}
				}
			}
			$number_recurrent_gene++;
		}
	}
	
	@genes= keys %recurrent_gene;
	open(O, ">$dir/$nonsilent_recurrent_gene") or die "cannot creat such a $dir/$nonsilent_recurrent_gene file";
	open(L, ">$dir/$recurrent_list") or die "cannot creat such a $dir/$recurrent_list file";
	print L "Gene\tAppear_times\tNumber_sample\n";
	for my $GENE (@genes){
		my $recurrent_sample= keys %{$recurrent_sample{$GENE}};
		if ($recurrent_sample > 1){
			print O $recurrent_gene{$GENE};
			my @e =split/\n/, $recurrent_gene{$GENE};
			my $e=$#e +1;
			print L "$GENE\t$e\t$recurrent_sample\n";
		}
	}
	close O;
	print L "Total_number_of_recurrent_gene\t$number_recurrent_gene\n";
	close L;
    	
	return 1;

}

1;


