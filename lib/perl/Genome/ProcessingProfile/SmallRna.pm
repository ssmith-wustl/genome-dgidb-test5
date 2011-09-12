package Genome::ProcessingProfile::SmallRna;

use strict;
use warnings;
my $DEFAULT_CLUSTERS = '5000';
my $DEFAULT_CUTOFF = '2';
my $DEFAULT_ZENITH = '5';
use Workflow::Simple;
use Workflow;
use Genome;

class Genome::ProcessingProfile::SmallRna{
    is => 'Genome::ProcessingProfile',
    doc => "miRNA processing profile.",
    has_param => [

		annotation_files => {
			is => 'Text',
			doc =>'Comma separated list of input BED files',
		},
		
		annotation_name => {
            is => 'String',
            doc => 'Comma delimited list of the Annotation Tracks. Should be in the same order as the list of annotation bed files.',
        },
		
		minimum_zenith => {
            is => 'String',
            is_optional => 1,
            doc => 'Minimum zenith depth for generating clusters',
            default_value => $DEFAULT_ZENITH,
        },
        
		size_bins => {
			is => 'Text',
			doc =>'comma separated list of Min_max read length bins: eg 17_75,17_25',
		},
		
		subcluster_min_mapzero => {
			is        => 'Text',
			is_optional => 1,
			doc       =>'Minimum %MapZero Alignments to call subclusters',
			default_value => $DEFAULT_CUTOFF,

		},
		
		input_cluster_number => {
            is => 'Text',
            is_optional => 1,
            doc => 'Number of TOP Clusters to calculate statistcs',
            default_value => $DEFAULT_CLUSTERS,
	   },
	   
	   

	],
};

sub help_synopsis_for_create {
    my $self = shift;
    return <<"EOS"
TO DO
EOS
}

sub help_detail_for_create {
    return <<EOS
  TO DO
EOS
}

sub help_manual_for_create {
    return <<EOS
  
TO DO

EOS
}


sub _initialize_build {
    my($self,$build) = @_;
    $DB::single=1;
    return 1;
}

sub _resolve_workflow_for_build {
    my $self = shift;
    $DB::single = 1;
    my $build = shift;

    my $operation = Workflow::Operation->create_from_xml(__FILE__ . '.xml');
    
    my $log_directory = $build->log_directory;
    $operation->log_dir($log_directory);
    
    $operation->name($build->workflow_name);

    return $operation;
}

sub _map_workflow_inputs {
    my $self = shift;
    $DB::single = 1;
    my $build = shift;

    my @inputs = ();

    my $model = $build->model;
    
    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        die $self->error_message;
    }
 
    my $data_directory = $build->data_directory;
    unless ($data_directory) {
        $self->error_message("Failed to get a data_directory for this build!");
        die $self->error_message;
    }
	
	my $ref_model = $build->ref_model;
	my $ref_build = $ref_model->last_succeeded_build;
	
	my $bam_file = $ref_build->whole_rmdup_bam_file;
	
    unless (-e $bam_file) {
        $self->error_message("Bam file $bam_file does not exist!");
        die $self->error_message;
    }
     
    push @inputs, bam_file => $bam_file;
    push @inputs, output_base_dir => $data_directory;
	push @inputs,
        annotation_files => (defined $self->annotation_files ),
        annotation_name => (defined $self->annotation_name),
        minimum_zenith => (defined $self->minimum_zenith),
        size_bins => (defined $self->size_bins),
        subcluster_min_mapzero => (defined $self->subcluster_min_mapzero),
        input_cluster_number => (defined $self->input_cluster_number), 
        ;


    return @inputs;

    return @inputs;
}

1;
