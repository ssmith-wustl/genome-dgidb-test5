package Genome::Model::Command::Build::GenotypeMicroarray::Run;

use strict;
use warnings;

use Genome;
use IPC::Run;
use File::Basename;

class Genome::Model::Command::Build::GenotypeMicroarray::Run {
    is => 'Genome::Model::Event',
    has => [
        filename => {
            is  => 'String',
            doc => 'Source filename',
        },
    ],
};

sub help_brief {
    return '';
}

sub help_detail {
    return <<"EOS"
EOS
}

sub execute
{
    my $self = shift;

    my $source_file = basename($self->filename); # uh...
    my $destination = $self->build->data_directory;
    my $procprof = $self->model->processing_profile;

    my @params = $procprof->params;
    my ($input_format,$instrument_type) = (undef,undef);
    foreach my $param (@params)
    {
        if($param->name eq 'input_format')
        {
            $input_format = $param->value;
        }
        elsif($param->name eq 'instrument_type')
        {
            $instrument_type = $param->value;
        }
    }
    #check input format
    unless ($input_format eq 'wugc')
    {
        die "unsupported format \"$input_format\", only wugc supported right now.";
    }
    # check instrument type
    unless ( ($instrument_type eq 'illumina') or
             ($instrument_type eq 'affymetrix') )
    {
        die "unknown/unsupported instrument type \"$instrument_type\"";
    }

    my $destination_file = $destination ."/". $source_file ;
    my $gtfile = Genome::MiscAttribute->create(
                           entity_id         => $self->model->id,
                           entity_class_name => 'Genome::Model',
                           property_name     => 'genotype_file',
                           value             => $destination_file,
                          );


    # copy file to build directory
    my @cp = ('cp',$self->filename,$destination_file);
    my ($stdout, $stderr);
    IPC::Run::run(\@cp,
                  '>',
                  \$stdout,
                  '2>',
                  \$stderr,) or die "can't copy:\n$stderr";

    return 1;
}

1;

# $Id$
