package Genome::Model::Build::DeNovoAssembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::DeNovoAssembly {
    is => 'Genome::Model::Build',
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->model->type_name eq 'de novo assembly' ) {
        $self->error_message( 
            sprintf(
                'Incompatible model type (%s) to build as an de novo assembly',
                $self->model->type_name,
            )
        );
        $self->delete;
        return;
    }

    mkdir $self->data_directory unless -d $self->data_directory;
    
    return $self;
}
    
sub velvet_fastq_file {
    return $_[0]->data_directory.'/velvet.fastq';
}


1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Build/DeNovoAssembly.pm $
#$Id: DeNovoAssembly.pm 47126 2009-05-21 21:59:11Z ebelter $
