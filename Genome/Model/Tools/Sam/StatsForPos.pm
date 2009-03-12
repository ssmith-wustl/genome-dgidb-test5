package Genome::Model::Tools::Sam::StatsForPos;

use strict;
use warnings;

use Genome;
use Command;

class Genome::Model::Tools::Sam::StatsForPos {
    is => 'Genome::Model::Tools::Sam',
    has => [
    bam_file => {
        doc => 'The input bam file WHICH MUST BE INDEXED',
        is => 'String',
    },
    position1 => {
        doc => 'The position of interest',
        is => 'String',
    },
    position2 => {
        doc => 'The position of interest',
        is => 'String',
        is_optional=>1,
    },

    chromosome => {
        doc => 'The position of interest',
        is => 'String',
    },
    ],
};

sub help_brief {
    'fill this out later';
}

sub help_detail {
    return "fill this out later";
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);



    return $self;
}

sub execute {
    my $self = shift;
    unless (-s $self->bam_file && -s $self->bam_file . ".bai") {
        $self->error_message('Map file '. $self->map_file .' not found or has zero size.');
        return;
    }
    unless ($self->position1) {
        $self->error_message('SUPPLY A POSITION!');
        return;
    }
    unless ($self->chromosome) {
        $self->error_message('SUPPLY A CHROMOSOME!');
        return;
    }
    unless($self->position2) {
        $self->position2($self->position1);
    }
    my $cmd = "samtools view " . $self->bam_file . " " . $self->chromosome . ":" . $self->position1 . "-" . $self->position2;
    print $cmd;
    return 1;
}
1;
