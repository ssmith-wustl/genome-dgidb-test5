package Genome::Model::Tools::FastQual::Trimmer::BwaStyle;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Tools::FastQual::Trimmer::BwaStyle {
    is  => 'Genome::Model::Tools::FastQual::Trimmer',
    has_input => [
        trim_qual_level => {
            is  => 'Integer',
            is_optional => 1,
            default => 10,
            doc => 'Trim quality level.',
        },
    ],
    has => [
        _trimmer => {
            is => 'Genome::Model::Tools::Fastq::TrimBwaStyle',
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

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;
    
    my $trim_qual_level = $self->trim_qual_level;
    unless ( $trim_qual_level =~ /^$RE{num}{int}$/ and $trim_qual_level > 0 ) {
        $self->error_message("Trim qual level ($trim_qual_level) must be an integer.");
        $self->delete;
        return;
    }
    my $trimmer = Genome::Model::Tools::Fastq::TrimBwaStyle->create(
        trim_qual_level => $self->trim_qual_level,
        qual_type => $self->type,
    );
    unless ( $trimmer ) {
        $self->error_message("Can't create BWA trimmer.");
        $self->delete;
        return;
    }
    $self->_trimmer($trimmer);

    return $self;
}

sub _trim {
    return $_[0]->_trimmer->trim($_[1]);
}

1;

#$HeadURL$
#$Id$
