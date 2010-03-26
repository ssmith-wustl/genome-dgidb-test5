# FIXME ebelter
#  Long: remove this and all define modeuls to have just one that can handle model inputs
package Genome::Model::Command::Define::PooledAssemblyDecomposition;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::PooledAssemblyDecomposition {
    is => 'Genome::Model::Command::Define',
    has => [
#         pooled_assembly_links => { 
#            is => 'Genome::Model::Link', 
#            reverse_as => 'to_model', 
#            where => [ role => 'pooled_assembly'], 
#            is_many => 1,
#            doc => '' 
#        },
#        pooled_assembly => { 
#            is => 'Genome::Model', 
#            via => 'tumor_model_links', 
#            to => 'from_model', 
#            id_by => 'from_assembly',
#            doc => '' 
#        },
        pooled_assembly => { 
            is => 'Genome::Model', 
            id_by => 'from_assembly',
            doc => '' 
        },
        from_assembly => { 
            is => 'Text',
            doc => 'The input pooled assembly' 
        },
        ref_seq_file =>
        {
            type => 'String',
            is_optional => 0,
            doc => "location of the reference sequence"        
        },        
        subject_name => {
            is => 'Text',
            len => 255,
            doc => 'The name of the subject all the reads originate from',
        },
    ],
    has_optional => [
        model_name => {
            is => 'Text',
            len => 255,
            doc => 'User meaningful name for this model (default value: $SUBJECT_NAME.$PP_NAME)'
        },
        subject_type => {
            is => 'Text',
            len => 255,
            doc => 'The type of subject all the reads originate from, defaults to sample_name',
            default => 'sample_group',
        },
        data_directory => {
            is => 'Text',
            len => 255,
            doc => 'Optional parameter representing the data directory the model should use. Will use a default if none specified.'
        },
        processing_profile_name => {
            is => 'Text',
            doc => 'identifies the processing profile by name',
            default => 'default',
        },
        ace_file_name =>
        {
            type => 'String',
            is_optional => 1,
            doc => "name of ace file, if different than Pcap.454Contigs.ace.1"        
        },
        phd_ball_name =>
        {
            type => 'String',
            is_optional => 1,
            doc => "name of phdball if different than phd.ball.1"        
        }, 

   ],
};

sub help_synopsis {
    return <<"EOS"
genome model define pooled-assembly-decomposition
  --subject_name ovc2
  --from-assembly 54321
  --data-directory /gscmnt/somedisk/somedir/model_dir
EOS
}

sub help_detail {
    return <<"EOS"
This defines a new genome model representing pooled assemblies that have been separated
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    return $self;
}

sub execute {
    my $self = shift;

    $DB::single=1;

    unless(defined $self->pooled_assembly) {
        $self->error_message("Could not get a model for pooled assembly id: " . $self->from_assembly);
        return;
    }
    unless(defined $self->ref_seq_file && -e $self->ref_seq_file) {
        $self->error_message("Ref_seq_file does not exist");
        return;
    }
    
        # run Genome::Model::Command::Define execute
    my $super = $self->super_can('_execute_body');
    $super->($self,@_);
    

    my $model = Genome::Model->get($self->result_model_id);
    my $pooled_assembly = $self->pooled_assembly;
    my $pooled_assembly_build_directory = $pooled_assembly->last_complete_build_directory;
    unless ($pooled_assembly_build_directory && -e $pooled_assembly_build_directory) {
        $self->error_message("Failed to get last complete build directory for the input pooled assembly");
        return;
    }
    #exit;
    $model->add_input(name => 'pooled_assembly_dir', value_class_name => 'UR::Value', value_id => $pooled_assembly_build_directory);
    $model->add_input(name => 'ref_seq_file', value_class_name => 'UR::Value', value_id => $self->ref_seq_file);
    unless(!defined $self->ace_file_name) {
        $model->add_input(name => 'ace_file_name', value_class_name => 'UR::Value', value_id => $self->ace_file_name);
        return;
    }
    unless(!defined $self->phd_ball_name) {
        $model->add_input(name => 'phd_ball_name', value_class_name => 'UR::Value', value_id => $self->phd_ball_name);
        return;
    }
    $model->add_from_model(from_model => $self->pooled_assemblyl, role => 'pooled_assembly');

    return 1; # for now just execute body an return
    # get the model created by the super
    $model = Genome::Model->get($self->result_model_id);

    unless(defined $self->pooled_assembly) {
        $self->error_message("Could not get a model for pooled assembly id: " . $self->from_assembly);
        return;
    }
    
#ddd    Genome::Model::Input GENOME_MODEL_INPUT model_id, name, value_class


    $model->add_input(name => 'ref_seq_path', value_class_name => 'UR::Value', value_id => $self->ref_seq_path);
    #$model->add_input(name => 'ref_seq_path', value => $self->ref_seq_path);
    #$model->ref_seq_path($self->ref_seq_path);

    # Link to pooled assembly model
    #$model->add_from_model(from_model => $self->pooled_assemblyl, role => 'normal');#todo figure out what the correct parameter for role is

    return 1;
}

1;
