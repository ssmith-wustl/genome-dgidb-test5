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
        sequence =>{
            is => 'SCALAR',
            is_output => 1,
            doc => "This is populated with the sequence returned from running this command",
            is_optional => 1,
        },
        suppress_output => {
            is => 'Boolean',
            is_input => 1,
            is_optional => 1,
            default => 0,
            doc => 'Setting this option suppresses printing the sequence.  Useful for calling this inside another program',
        },
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
    print($seq . "\n") unless $self->suppress_output;
    $self->sequence($seq);
    return 1;
}

1;
