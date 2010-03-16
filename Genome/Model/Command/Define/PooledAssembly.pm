# FIXME ebelter
#  Long: remove this and all define modeuls to have just one that can handle model inputs
package Genome::Model::Command::Define::PooledAssembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::PooledAssemblyDecomposition {
    is => 'Genome::Model::Command::Define',
    has => [
       # pooled_assembly => { 
#            is => 'Genome::Model',
#            id_by => 'from_assembly', 
#            doc => 'The input pooled assembly' 
#        },
#        ref_seq_file =>
#        {
#            type => 'String',
#            is_optional => 1,
#            doc => "location of the reference sequence"        
#        },

        data_directory => {
            is => 'Text',
            len => 255,
            doc => 'Optional parameter representing the data directory the model should use. Will use a default if none specified.'
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
        processing_profile_name => {
            is => 'Text',
            doc => 'identifies the processing profile by name',
            default => 'default',
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
    exit;
    

    # run Genome::Model::Command::Define execute
    my $super = $self->super_can('_execute_body');
    $super->($self,@_);
    return 1; # for now just execute body an return
    # get the model created by the super
    my $model = Genome::Model->get($self->result_model_id);

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
