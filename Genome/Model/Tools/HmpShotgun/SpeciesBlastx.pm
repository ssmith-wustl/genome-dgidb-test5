package Genome::Model::Tools::HmpShotgun::SpeciesBlastx;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::HmpShotgun::SpeciesBlastx {
    is  => ['Command'],
    has => [
        model_id => {
            is  => 'String',
            is_input => '1',
            doc => 'The model id to process.',
        },
        working_directory => {
            is => 'String',
            is_input => '1',
            doc => 'The working directory where results will be deposited.',
        },
         final_file => {
            is  => 'String',
            is_output => '1',
            is_optional => '1',
            doc => 'The model id to process.',
        },
        delete_intermediates => {
            is => 'Integer',
            is_input =>1,
            is_optional =>1,
            default=>0,
        },
    ],
};


sub help_brief {
    'Use Blastx to align against 800 proteomes';
}

sub help_detail {
    return <<EOS
    Use Blastx to align against 800 proteomes
EOS
}


sub execute {
    my $self = shift;
    $self->dump_status_messages(1);
    $self->dump_error_messages(1);
    $self->dump_warning_messages(1);

    my $now = UR::Time->now;
    $self->status_message(">>>Starting SpeciesBlastX execute() at $now"); 
    $self->final_file("species_blastx_final_file_path");
    $self->status_message("<<<Ending species_blastx execute() at ".UR::Time->now); 
    return 1;

}
1;