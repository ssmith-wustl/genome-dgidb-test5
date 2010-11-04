package Genome::Model::Tools::Xhong::SomaticCnvPng;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::Model::Tools::Xhong::SomaticCnvPng {
	is => 'Command',
	has => [
    	model_group => { type => 'String', is_optional => 0, doc => "name of the model group to process", },
        analysis_dir => { type => 'String', is_optional => 0, doc => "Directory where the CNV and CNV_PNG will be", },
        somatic_cnv_file_list  => { type => 'String', is_optional => 0, doc => "List of somatic CNV files",},
        somatic_cnv_png_file_list  => { type => 'String', is_optional => 0, doc => "list of somatic CNV PNG files",},
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
    	
    	my $analysis_dir=$self->analysis_dir;
    	my $somatic_cnv_file_list=$self->somatic_cnv_file_list;
    	my $somatic_cnv_png_file_list=$self->somatic_cnv_png_file_list;
#    	my $bamfile_list=$self->bamfile_list;
    	
	my %somatic_cnv={};
	my %somatic_cnv_png={};
	my $somatic_cnv_csv;
        my $somatic_cnv_png_csv;
       	my $common_name;
       	my @samples;
       	
       	my @models;
    	my $group = Genome::ModelGroup->get(name => $self->model_group);
    	unless($group) {
    	    $self->error_message("Unable to find a model group named " . $self->model_group);
    	    return;
    	}
    	push @models, $group->models;
#	my %tumor_bam;
#	my %normal_bam;
        	
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
        		next; #next;
        	}
#        	my $model_id = $build->model_id;
        	my $build_id = $build->build_id;
        #	push @id, $build_id;
        #	print "$build_id\t";
        # find bam files of somatic build and its common name & cancer type	
#        	my $tumor_wgs_bam = $build->tumor_build->whole_rmdup_bam_file;
#                my $normal_wgs_bam = $build->normal_build->whole_rmdup_bam_file;
#	        my $tumor_common_name = $build->tumor_build->model->subject->source_common_name;
#        	my $tumor_type = $build->tumor_build->model->subject->common_name;
#        	my $normal_common_name = $build->normal_build->model->subject->source_common_name;
#        	my $normal_type = $build->normal_build->model->subject->common_name;
#		push @name, $tumor_common_name;
#		$tumor_bam{$tumor_common_name}=$tumor_wgs_bam;
#		$normal_bam{$normal_common_name}=$normal_wgs_bam;
	
	#next unless($tumor_build->model->subject->sub_type !~ /M[13]/);

        #	printf "%s %s: %s\n%s %s: %s\n",$tumor_common_name, $tumor_type, $tumor_wgs_bam, $normal_common_name, $normal_type, $normal_wgs_bam;

        #satisfied we should start doing stuff here
	        my $data_directory = $build->data_directory . "/";

        	unless(-d $data_directory) {
        		$self->error_message("$data_directory is not a directory");
        		return;
        	}

 	        $somatic_cnv_csv = "$data_directory/cno_copy_number.csv";
 	        unless (-e $somatic_cnv_csv){
 	        	$somatic_cnv_csv = "$data_directory/copy_number_output.out";
 	        }
 	        
	        $somatic_cnv_png_csv = "$data_directory/cno_copy_number.csv.png";
	        unless (-e $somatic_cnv_png_csv){
 	        	$somatic_cnv_csv = "$data_directory/copy_number_output.out.png";
 	        }
 	        
        	$common_name = $build->tumor_build->model->subject->source_common_name;
        print "$common_name\n";
		push @samples, $common_name;
        	$somatic_cnv{$common_name}= $somatic_cnv_csv;
        	$somatic_cnv_png{$common_name}= $somatic_cnv_png_csv;

        	
    	} # finish of all models

    	#write out the lines
    	
    	open(CNV, ">$analysis_dir/$somatic_cnv_file_list") or die "cannot creat such a $analysis_dir/$somatic_cnv_file_list file";
    	open(CNVPNG, ">$analysis_dir/$somatic_cnv_png_file_list") or die "cannot creat such a $analysis_dir/$somatic_cnv_png_file_list file";
    	for my $sample (@samples) {
    		my $cnv =$somatic_cnv{$sample};
    		my $cnv_png =$somatic_cnv_png{$sample};
		print CNV "$sample\t$cnv\n";
		print CNVPNG "$sample\t$cnv_png\n";
	}		
    	close CNV;
    	close CNVPNG;
	return 1;
}


1;


