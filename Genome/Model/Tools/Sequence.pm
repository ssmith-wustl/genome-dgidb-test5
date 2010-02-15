package Genome::Model::Tools::Sequence;

use strict;
use warnings;
use Genome;

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
        $build = Genome::Model::Build->get(93636924); #HB36 default option
        unless ($build){
            $self->error_message("couldn't grab default build HB36");
            die;
        }
    }

    my $seq_file = $build->get_bases_file($self->chromosome);
    unless (defined $seq_file){
        $self->error_message("seq file undefined for chromosome ".$self->chromosome);
        die;
    }
    unless (-e $seq_file){
        $self->error_message("seq_file $seq_file does not exist!");
    }
    my $seq = $build->sequence($seq_file, $self->start, $self->stop);
    print $seq;
    return 1;
}

1;

