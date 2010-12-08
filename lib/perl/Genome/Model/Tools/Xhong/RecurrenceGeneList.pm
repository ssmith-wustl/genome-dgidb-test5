package Genome::Model::Tools::Xhong::RecurrenceGeneList;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::Model::Tools::Xhong::RecurrenceGeneList {
	is => 'Command',
	has => [
    	model_group => { type => 'String', is_optional => 0, doc => "name of the model group to process", },
        analysis_dir => { type => 'String', is_optional => 0, doc => "Directory where the recurrent gene output will be", },
        all_tier1  => { type => 'String', is_optional => 0, doc => "The name of the file that contains all tier1 hc predictions, analysis_dir will be added",},
        nonsilent_recurrent_gene  => { type => 'String', is_optional => 0, doc => "The name of the file that contains all nonsilent recurrent tier1 hc predictions,analysis_dir will be added ",},
        recurrent_list  => { type => 'String', is_optional => 0, doc => "The name of the file that contains all nonsilent recurrent tier1 hc predictions are in this file, sorted by gene, freq, sample. analysis_dir will be added",},
        bamfile_list => { type => 'String', is_optional => 0, doc => "The file name that contains all wgs bam files. analysis_dir will be added"},
    	]
};

sub help_brief {
    	"Generates tier1 hc SNV table for model-groups, and found nonsilent recurrent genes. "
}

sub help_detail {
    	<<'HELP';
Hopefully this script will run the ucsc annotator on indels and then tier them for an already completed somatic model. Since this is done in the data directory, the model is then reallocated.
HELP
}

sub execute {
	my $self=shift;
    	$DB::single = 1;
    	
    	my $dir=$self->analysis_dir;
    	my $all_tier1=$self->all_tier1;
    	my $nonsilent_recurrent_gene=$self->nonsilent_recurrent_gene;
    	my $recurrent_list=$self->recurrent_list;
    	my $bamfile_list=$self->bamfile_list;
    	my @models;
    	my $group = Genome::ModelGroup->get(name => $self->model_group);
    	unless($group) {
    	    $self->error_message("Unable to find a model group named " . $self->model_group);
    	    return;
    	}
    	push @models, $group->models;
    	my %snv_tiers;
    	my %lines;
	my %tumor_bam;
	my %normal_bam;
	my %hc1;
	my %gene;
	my %recurrent_gene;
	my %recurrent_sample;
	my %nonsilent;
	my %sample;
	my ($line,$sample, $chr, $pos, $gene, $change, $key)=("","","","","","","");
	my @column; my @lines; my @name;
 	
    	foreach my $model (@models) {
    		my $subject_name = $model->subject_name;
 #   print "$subject_name\t";
        	unless($model->type_name eq 'somatic') {
            		$self->error_message("This build must be a somatic pipeline build");
            		return;
        	}

	        my $build = $model->last_succeeded_build;
	        unless (defined($build)) {
        		$self->error_message("Unable to find succeeded build for model ".$model->id);
        		return; #next;
        	}
#        	my $model_id = $build->model_id;
        	my $build_id = $build->build_id;
        #	push @id, $build_id;
        #	print "$build_id\t";
        # find bam files of somatic build and its common name & cancer type	
        	my $tumor_wgs_bam = $build->tumor_build->whole_rmdup_bam_file;
                my $normal_wgs_bam = $build->normal_build->whole_rmdup_bam_file;
	        my $tumor_common_name = $build->tumor_build->model->subject->source_common_name;
        	my $tumor_type = $build->tumor_build->model->subject->common_name;
        	my $normal_common_name = $build->normal_build->model->subject->source_common_name;
        	my $normal_type = $build->normal_build->model->subject->common_name;
	#	print "$tumor_common_name\t$normal_common_name\t$normal_type\n";
		push @name, $tumor_common_name;
		$tumor_bam{$tumor_common_name}=$tumor_wgs_bam;
		$normal_bam{$normal_common_name}=$normal_wgs_bam;
	
	#next unless($tumor_build->model->subject->sub_type !~ /M[13]/);

        #	printf "%s %s: %s\n%s %s: %s\n",$tumor_common_name, $tumor_type, $tumor_wgs_bam, $normal_common_name, $normal_type, $normal_wgs_bam;

        #satisfied we should start doing stuff here
	        my $data_directory = $build->data_directory . "/";

        	unless(-d $data_directory) {
        		$self->error_message("$data_directory is not a directory");
        		return;
        	}

 #       my $indel_transcript_annotation = "$data_directory/annotate_output_indel.out";
	        my $snp_transcript_annotation = "$data_directory/upload_variants_snp_1_output.out";
        	 %snv_tiers = (
        		"Tier1" => "$data_directory/tier_1_snp_high_confidence_file.out",
        	);

	        # if not exist, check if using new files
	        unless(-e $snp_transcript_annotation) {
        		$snp_transcript_annotation = "$data_directory/uv1_uploaded_tier1_snp.csv";
	        	%snv_tiers = (
	                	"Tier1" => "$data_directory/hc1_tier1_snp_high_confidence.csv",
        		);

	        }


        	my $common_name = $build->tumor_build->model->subject->source_common_name;
#        print "$common_name\n";

        	foreach my $tier (qw{ Tier1 }) {

            		my $snv_file = $snv_tiers{$tier};
            		@lines = `/gscuser/dlarson/bin/perl-grep-f -f $snv_file $snp_transcript_annotation`;
#            		print `wc -l $snv_file $snp_transcript_annotation`;
	                map { $_ = "$common_name\t".$_;} @lines; 
	            	push @{$lines{$tier}}, @lines;
        	}
#       	print "\n"; 
    	} # finish of all models

    	#write out the lines
    	
    	open(FH, ">$dir/$all_tier1") or die "cannot creat such a $dir/$all_tier1 file";
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
#				push @keys, $key;
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
    	
    	open(B, ">$dir/$bamfile_list") or die "cannot creat such a $dir/$bamfile_list file";
#    	my @id= keys %tumor_bam;
    	foreach my $name (@name){
    		print B "$name\n";
    		print B "tumor\t$tumor_bam{$name}\n";
		print B "normal\t$normal_bam{$name}\n";
    	}
    	close B;
    return 1;
}


1;


