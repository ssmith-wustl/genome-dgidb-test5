package Genome::Model::Command::Build::AmpliconAssembly;

use strict;
use warnings;

use Genome;

use Genome::Model::Command::Build::AmpliconAssembly::VerifyInstrumentData;
use Genome::Model::Command::Build::AmpliconAssembly::Assemble;
use Genome::Model::Command::Build::AmpliconAssembly::Collate;
use Genome::Model::Command::Build::AmpliconAssembly::Orient;
use Genome::Model::Command::Build::AmpliconAssembly::PostProcess;
use Genome::Model::Command::Build::AmpliconAssembly::PostProcess::Composition;
use Genome::Model::Command::Build::AmpliconAssembly::PostProcess::Reference;
use Genome::Model::Command::Build::AmpliconAssembly::CleanUp;
;
class Genome::Model::Command::Build::AmpliconAssembly {
    is => 'Genome::Model::Command::Build',
};

#< Subclassing...default is to not >#
sub _get_sub_command_class_name{
    return __PACKAGE__;
}

#< Helps >#
sub help_brief {
    return
}

sub help_synopsis {
    return;
}

sub help_detail {
    return;
}

#< Beef >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->_verify_model ) {
        $self->delete;
        return;
    }

    unless ( $self->model->type_name eq 'amplicon assembly' ) {
        $self->error_message( 
            sprintf(
                'Incompatible model type (%s) to build as an amplicon assembly',
                $self->model->type_name,
            )
        );
        $self->delete;
        return;
    }

    return $self;
}

#< Stages >#
sub stages {
    return (qw/
        assemble
        /);
}

#< Pre Assemble Process >#
sub assemble_job_classes {
    return (qw/
        Genome::Model::Command::Build::AmpliconAssembly::VerifyInstrumentData
        Genome::Model::Command::Build::AmpliconAssembly::Assemble
        Genome::Model::Command::Build::AmpliconAssembly::Collate
        Genome::Model::Command::Build::AmpliconAssembly::Orient
        Genome::Model::Command::Build::AmpliconAssembly::PostProcess
        Genome::Model::Command::Build::AmpliconAssembly::CleanUp
        /);
}

sub assemble_objects {
    return 1;
}

1;

#$HeadURL$
#$Id$
