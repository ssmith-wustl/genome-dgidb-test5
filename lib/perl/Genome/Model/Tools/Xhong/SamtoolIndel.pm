package Genome::Model::Tools::Xhong::SamtoolIndel;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::Model::Tools::Xhong::SamtoolIndel {
	is => 'Command',
	has => [
    	model_group => { type => 'String', is_optional => 0, doc => "name of the model group to process", },
        analysis_dir => { type => 'String', is_optional => 0, doc => "Directory where the recurrent gene output will be", },
        ]
};

sub help_brief {
    	"Generates tier1 hc SNV table for model-groups, and found recurrent events"
}

sub help_detail {
    	<<'HELP';
Hopefully this script will run the ucsc annotator on indels and then tier them for an already completed somatic model. Since this is done in the data directory, the model is then reallocated.
HELP
}

sub execute {
	my $self=shift;
    	$DB::single = 1;
    	
    	my $analysis_dir=$self->analysis_dir;
    	my @models;
    	my $group = Genome::ModelGroup->get(name => $self->model_group);
    	unless($group) {
    	    $self->error_message("Unable to find a model group named " . $self->model_group);
    	    return;
    	}
    	push @models, $group->models;
    	my %indel_tiers;
    	my %lines;
	my %tumor_bam;
	my %normal_bam;

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
	        # find bam files of somatic build and its common name & cancer type	
        	my $tumor_wgs_bam = $build->tumor_build->whole_rmdup_bam_file;
                my $normal_wgs_bam = $build->normal_build->whole_rmdup_bam_file;
		#next unless($tumor_build->model->subject->sub_type !~ /M[13]/);

        #satisfied we should start doing stuff here
	        my $data_directory = $build->data_directory . "/";

        	unless(-d $data_directory) {
        		$self->error_message("$data_directory is not a directory");
        		return;
        	}

 #       my $indel_transcript_annotation = "$data_directory/annotate_output_indel.out";

		%indel_tiers=(
			"Tier1" => "$data_directory/t1i_tier1_indel.csv",
			"Tier2" => "$data_directory/t2i_tier2_indel.csv",
			"Tier3" => "$data_directory/t3i_tier3_indel.csv",
#			"Tier4" => "$data_directory/t4i_tier4_indel.csv",		
		);
		
        	my $common_name = $build->tumor_build->model->subject->source_common_name;
		print "$common_name\n";
		my $user = getlogin || getpwuid($<); #get current user name
        	# submit samtool assembly for each tier of indels for a sample
        	foreach my $tier (keys %indel_tiers) {
            		my $indel_file = $indel_tiers{$tier};
            		my $normal_dir=$analysis_dir."/".$common_name."/samtools/normal";
            		my $tumor_dir=$analysis_dir."/".$common_name."/samtools/tumor";
            		`mkdir -p $normal_dir`;
            		`mkdir -p $tumor_dir`; 
            		my $cmd ="bsub -N -u $user\@genome.wustl.edu -J $common_name.$tier.T -R \'select\[type==LINUX64\]\' \'gmt somatic assemble-indel --assembly-indel-list=$analysis_dir\/$common_name\/samtools\/$tier.tumor --bam-file=$tumor_wgs_bam --data-directory=$analysis_dir\/$common_name\/samtools\/tumor --indel-file=$indel_file\'";
            		print "$cmd\n";
            		system($cmd);
            		$cmd="bsub -N -u $user\@genome.wustl.edu -J $common_name.$tier.N -R \'select\[type==LINUX64\]\' \'gmt somatic assemble-indel --assembly-indel-list=$analysis_dir\/$common_name\/samtools\/$tier.normal --bam-file=$normal_wgs_bam --data-directory=$analysis_dir\/$common_name\/samtools\/normal --indel-file=$indel_file\'";
            		print "$cmd\n";
            		system($cmd);
            		print "\n";
        	}
    	} # finish of all sample (somatic models)

        return 1;
}


1;


