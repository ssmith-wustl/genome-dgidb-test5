package Genome::Model::Event;

use strict;
use warnings;

use Genome;
UR::Object::Class->define(
    class_name => 'Genome::Model::Event',
    is => ['Command'],
    english_name => 'genome model event',
    table_name => 'GENOME_MODEL_EVENT',
    id_by => [
        id => { is => 'INT', len => 11 },
    ],
    has => [
        date_completed => { is => 'TIMESTAMP', len => 14 },
        date_scheduled => { is => 'TIMESTAMP', len => 14 },
        event_status   => { is => 'VARCHAR', len => 32 },
        event_type     => { is => 'VARCHAR', len => 255 },
        lsf_job_id     => { is => 'VARCHAR', len => 64, is_optional => 1 },
        model          => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'event_genome_model' },
        model_id       => { is => 'INT', len => 11, implied_by => 'model_id' },
        ref_seq_id     => { is => 'VARCHAR', len => 64, is_optional => 1 },
        run            => { is => 'Genome::RunChunk', id_by => 'run_id', constraint_name => 'event_run' },
        run_id         => { is => 'INT', len => 11, is_optional => 1, implied_by => 'run_id' },
        user_name      => { is => 'VARCHAR', len => 64 },
    ],
    unique_constraints => [
        { properties => [qw/id/], sql => 'PRIMARY' },
    ],
    schema_name => 'Main',
    data_source => 'Genome::DataSource::Main',
);


sub create {
    my $class = shift;

    if (exists $ENV{'LSB_JOBID'}) {
        push(@_, 'lsf_job_id', $ENV{'LSB_JOBID'});
    }
    $class->SUPER::create(@_);
}
    

sub _shell_args_property_meta {
    # exclude this class' commands from shell arguments
    return grep { 
            $_->class_name ne __PACKAGE__ 
            or
            ($_->via and $_->via eq 'run')
        } shift->SUPER::_shell_args_property_meta(@_);
}


sub resolve_run_directory {
    my $self = shift;

    $DB::single = 1;
    return sprintf('%s/runs/%s/%s', Genome::Model->get($self->model_id)->data_directory,
                                    $self->run->sequencing_platform,
                                    $self->run->name);
}


1;
