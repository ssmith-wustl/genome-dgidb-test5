package Genome::Model::Command::GenotypeMicroarray;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Command::GenotypeMicroarray {
    is => 'Genome::Model::Command',
    doc => "Command for tracking microarray genotyping data",
    has => [
        subject_name => {
            is => 'String',
            doc => 'Sample name(?)',
        },
        filename => {
            is => 'String',
            doc => "The path to the microarray file",
        },
        source => {
            is => 'String',
            doc => "source of the microarray file/format of microarray file",
        },
#        processing_profile_id => {
#            is => 'Number',
#            doc => "processing profile id",
#        },
    ],
};

sub help_detail
{
    my $self = shift;
    return  <<"EOS"
This is for defining a microarray model for tracking the genotyping microarray
data.

EOS

}

sub create
{
    my $class = shift;
    $DB::single = 1;
    my $self = $class->SUPER::create(@_);
    unless(defined($self))
    {
        $class->error_message("can't set up command class...". $class->error_message());
        return; 
    }
    return $self;
}

sub execute
{
    my $self = shift;
    # shave file name off of tip of $self->filename()
    my $basefilename = basename($self->filename()); # goes to name
    my $datadirectory = dirname($self->filename()); # ??? needed?
    my $model = Genome::Model->get($self->model_id);

    # pop off the build step automagically
    #Genome::Model::Build::GenotypeMicroarray::Start->execute(); #?
    my $build = Genome::Model::Command::Build::GenotypeMicroarray::Run->create(
        model => $self->id,
        filename => $self->filename,
        );
    $build->execute() ;
    return 1;
}



1;

# $Id$
