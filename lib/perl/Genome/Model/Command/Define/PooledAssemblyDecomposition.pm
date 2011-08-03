package Genome::Model::Command::Define::PooledAssemblyDecomposition;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::PooledAssemblyDecomposition {
    is => 'Genome::Model::Command::Define::Helper',
    has => [
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
    ],
    has_optional => [
        subject_name =>
        {
            type => 'String',
            is_optional => 1,
            doc => "this parameter is for internal use, any value specified will be over-ridden"
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
    my $pooled_assembly = $self->pooled_assembly;
    $self->subject_name($pooled_assembly->subject_name);
    $self->subject_type($pooled_assembly->subject_type);
     
     # run Genome::Model::Command::Define execute
    my $super = $self->super_can('_execute_body');
    $super->($self,@_);    

    my $model = Genome::Model->get($self->result_model_id);    

    $model->add_from_model(from_model => $self->pooled_assembly, role => 'pooled_assembly');

    $model->add_input(name => 'ref_seq_file', value_class_name => 'UR::Value', value_id => $self->ref_seq_file);
    
    if (defined $self->ace_file_name) {
        $model->add_input(name => 'ace_file_name', value_class_name => 'UR::Value', value_id => $self->ace_file_name);
    }
    
    if (defined $self->phd_ball_name) {
        $model->add_input(name => 'phd_ball_name', value_class_name => 'UR::Value', value_id => $self->phd_ball_name);
    }
    
    return 1; 
}

1;
