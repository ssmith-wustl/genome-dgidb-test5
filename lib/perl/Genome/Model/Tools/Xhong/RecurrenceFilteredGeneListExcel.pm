package Genome::Model::Tools::Xhong::RecurrenceFilteredGeneListExcel;

use strict;
use warnings;

use Genome;
use IO::File;
use Spreadsheet::WriteExcel;

class Genome::Model::Tools::Xhong::RecurrenceFilteredGeneListExcel {
	is => 'Command',
	has => [
    	sample_name => { type => 'String', is_optional => 1, doc => "the common name of the sample to process", },
        analysis_dir => { type => 'String', is_optional => 0, doc => "Directory where the recurrent gene output will be", },
        ks_filtered_file_list => {type => 'String', is_optional => 0, doc => "filtered SNVs file list,"},
#        all_sample_hf1_list  => { type => 'String', is_optional => 0, doc => "The name of the file that contains all tiers high confidence filterd (hf) predictions, analysis_dir will be added",},
#        nonsilent_recurrent_gene  => { type => 'String', is_optional => 0, doc => "The name of the file that contains all nonsilent recurrent tier1 hf predictions,analysis_dir will be added ",},
#        recurrent_list  => { type => 'String', is_optional => 0, doc => "The name of the file that contains all nonsilent recurrent tier1 hf predictions are in this file, sorted by gene, freq, sample. analysis_dir will be added",},
        ]
};

sub help_brief {
    	"Generates ks filtered tier1 SNV table and found nonsilent recurrent genes. Run example: gmt xhong recurrence-filtered-gene-list-excel --analysis-dir /gscmnt/sata166/info/medseq/SJCBF_Analysis/SNVs/hf_table/ --ks-filtered-file /gscmnt/sata166/info/medseq/SJCBF_Analysis/SNVs/hf_table/PCGP_hf1_file_list.txt --sample-name SJCBF,SJTALL,SJMB,SJRB,SJRHB,SJINF"
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
    	my $all_sample_hf1_list="hf1_list.csv";
    	my $nonsilent_recurrent_gene="nonsilent_recurrent_gene.csv";
    	my $recurrent_list="recurrent_list.csv";
    	my @sample_name=split/\,/,$self->sample_name;
	my $analysis_dir=$self->analysis_dir;
 	
 	my $tier="Tier1";
 	open(I, "<$ks_filtered_file") or die "cannot open $ks_filtered_file";
 	my @ks_file=<I>;
 	close I;
 	
 	my $name= "$dir/$all_sample_hf1_list.xls";
	my $allhf1book=Spreadsheet::WriteExcel->new($name);
	$name= "$dir/$recurrent_list.xls";
	my $recurrentbook=Spreadsheet::WriteExcel->new($name);
	
 	for my $sample_name(@sample_name){
 		my %hc1;
		my %gene;
		my %recurrent_gene;
		my %recurrent_sample;
		my %nonsilent;
		my %sample;
		my %lines;
		my ($line,$sample, $chr, $pos, $gene, $change, $key)=("","","","","","","");
		my @column; my @lines; my @name;
		for my $snv_file(@ks_file){
 			$snv_file=~s/\s+$//;
			my $snp_transcript_annotation = $snv_file.".anno";
			unless (-e $snp_transcript_annotation) {
       				$self->error_message("cannot find $snp_transcript_annotation file");
       				return;
       			}
			my ($t1, $t2,$t3, $t4,$t5,$t6,$t7,$common_name)=split/\//, $snp_transcript_annotation;
			$common_name=~s/\_ksfiltered//;
#			print "$sample_name\n";
			if ($sample_name eq "PCGP"){
				@lines = `/gscuser/dlarson/bin/perl-grep-f -f $snv_file $snp_transcript_annotation`;
        			map { $_ = "$common_name\t".$_;} @lines; 
       				push @{$lines{$tier}}, @lines;
			}else{
				if ($common_name =~ $sample_name){
#					print "$common_name\n";
					@lines = `/gscuser/dlarson/bin/perl-grep-f -f $snv_file $snp_transcript_annotation`;
	        			map { $_ = "$common_name\t".$_;} @lines; 
	       				push @{$lines{$tier}}, @lines;
				}
			}	
		}
		
    		#write out the lines
    		my $hf1sheet=$allhf1book->add_worksheet($sample_name);
    		my $n=0;
		my $row="A$n";
    		open(FH, ">$dir/$sample_name.$all_sample_hf1_list") or die "cannot create such a $dir/$all_sample_hf1_list file";
    		foreach my $tier (qw{ Tier1 }) {
    			@lines = @{$lines{$tier}};
    			foreach $line (@lines){ 
				print FH $line;
				@column=split/\t/, $line;
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
					if (!exists $gene{$gene}){
						$gene{$gene}=1;
					}else{
						$gene{$gene}=$gene{$gene}+1;
					}
				}
				$n++;
				$row="A$n";
				$hf1sheet->write($row,\@column);
				
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
		
		my $list_name=$sample_name.".list";
		my $recurrentgenesheet=$recurrentbook->add_worksheet($sample_name);
		my $recurrentlistsheet=$recurrentbook->add_worksheet($list_name);
		print "$list_name\n";
		open(O, ">$dir/$sample_name.nonsilent_recurrent_gene.csv") or die "cannot creat such a $dir/$sample_name.nonsilent_recurrent_gene file";
		open(L, ">$dir/$sample_name.recurrent_list.csv") or die "cannot creat such a $dir/$sample_name.recurrent_list.csv file";
		print L "Gene\tAppear_times\tNumber_sample\n";
		$n=1;my $m=1;
		my $row2="A$m";
		my $row="A$n";
		my @header=('Gene','Appear_times','Number_sample');
		$recurrentlistsheet->write($row,\@header);
	
		for my $GENE (@genes){
			my $recurrent_sample= keys %{$recurrent_sample{$GENE}};
			if ($recurrent_sample > 1){
				print O $recurrent_gene{$GENE};
				my @e =split/\n/, $recurrent_gene{$GENE};
				my $element=$#e +1;
				print L "$GENE\t$element\t$recurrent_sample\n";
				$n++; $row="A$n";
				my @list=($GENE,$element,$recurrent_sample);
				$recurrentlistsheet->write($row,\@list);
				for my $e (@e){
					my @list=split/\t/,$e;
					$m++; $row2="A$m";
					$recurrentgenesheet->write($row2,\@list);
				}
				
			}
		}
		close O;
		print L "Total_number_of_recurrent_gene\t$number_recurrent_gene\n";
		close L;
    	}
	return 1;
}

1;


