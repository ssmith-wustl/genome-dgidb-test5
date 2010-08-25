package Genome::Model::Tools::Sequence;

use strict;
use warnings;
use Genome;
use IO::File;

class Genome::Model::Tools::Sequence{
    is => 'Command',
    has =>[
        chromosome => {
            is => 'Text',
            doc => "chromosome for desired sequence",
        },
        start => {
            is => 'Number',
            doc => 'sequence start position',
        },
        stop => {
            is => 'Number',
            doc => 'sequence stop position',
        },
        build_id => {
            is => 'Number',
            is_optional => 1,
            doc => "build id to grab sequence from, defaults to hb36",
        },
        build => {
            is => 'Genome::Model::Build',
            id_by => 'build_id',
            is_optional => 1,
        },
        species => {
            is => 'Text',
            is_optional => 1,
            doc => 'use reference for this species',
            default => 'human',
            valid_values => ['human', 'mouse'],
        },
        version => {
            is => 'Text',
            is_optional => 1,
            doc => 'reference version to be used',
            default => '36',
        },
        output_file =>{
            is => 'Path',
            is_optional => 1,
            doc => "output will be sent to this filepath.  If unspecified, defaults to STDOUT",
        }
    ],
};

sub sub_command_sort_position { 15 }

sub help_brief {
    "get a seqeunce from an ImportedReferenceSequence model";
}

sub help_synopsis {
    return <<"EOS"
Given chromosome start and stop, returns a sequence from a ImportedReferenceSequence
EOS
}

sub help_detail {
    return <<"EOS"
Given chromosome start and stop, returns a sequence from a ImportedReferenceSequence
EOS
}

sub execute {
    my $self = shift;

    my $build = $self->build;
    unless ($build){
        my $model = Genome::Model->get(name => "NCBI-" . $self->species);
        unless ($model) {
            $self->error_message("Could not get imported reference model for " . $self->species);
            die;
        }

        $build = $model->build_by_version($self->version);
        unless ($build) {
            $self->error_message("Could not get imported reference version " . $self->version . " for " . $self->species);
            die;
        }
    }

    my $seq = $build->sequence($self->chromosome, $self->start, $self->stop);
    if (defined $self->output_file){
        my $fh = IO::File->new($self->output_file, "w");
        $fh or die "Could not open handle for output_file " . $self->output_file ." : $!";
        print $fh "$seq\n";
        $fh->close or die "Could not close output_file " . $self->output_file . " : $!";
    }else{
        print $seq . "\n";
    }
    return 1;
}

1;

