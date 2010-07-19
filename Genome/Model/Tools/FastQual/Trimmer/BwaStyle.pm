package Genome::Model::Tools::FastQual::Trimmer::BwaStyle;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::Trimmer::BwaStyle {
    is  => 'Genome::Model::Tools::FastQual::Trimmer',
    has_input => [
        trim_qual_level => {
            is  => 'Integer',
            is_optional => 1,
            default => 10,
            doc => 'trim quality level',
        },
    ],
};

sub help_synopsis {
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS 
EOS
}

sub execute {
    my $self = shift;
        
    my $trimmer = Genome::Model::Tools::Fastq::TrimBwaStyle->create(
        trim_qual_level => $self->trim_qual_level,
        qual_type => $self->type,
    ) or return;

    my $reader = $self->_open_reader
        or return;
    my $writer = $self->_open_writer
        or return;

    while ( my $seqs = $reader->next ) {
        $trimmer->trim($seqs);
        $writer->write($seqs);
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
