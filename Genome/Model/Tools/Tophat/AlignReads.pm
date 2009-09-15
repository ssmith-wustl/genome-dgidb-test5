package Genome::Model::Tools::Tophat::AlignReads;

use strict;
use warnings;

use Genome;
use Genome::Utility::FileSystem;

class Genome::Model::Tools::Tophat::AlignReads {
    is  => 'Genome::Model::Tools::Tophat',
    has => [
    ],
};

sub help_synopsis {
    return <<EOS
    A Tophat based utility for aligning reads.
EOS
}

sub help_brief {
    return <<EOS
    A Tophat based utility for aligning reads.
EOS
}

sub help_detail {
    return <<EOS
Provides an interface to the Tophat aligner.  Inputs are:

NOT IMPLEMENTED

EOS
}

sub create {
    my $class = shift;
    my $self  = $class->SUPER::create(@_);

    unless ($self) {
        return;
    }

    unless ( $self->use_version ) {
        my $msg = 'use_version is a required parameter to ' . $class;
        $self->delete;
        die($msg);
    }
    unless ( $self->tophat_path ) {
        my $msg =
            'No path found for bwa version '
          . $self->use_version
          . ".  Available versions are:\n";
        $msg .= join( "\n", $self->available_tophat_versions );
        $self->delete;
        die($msg);
    }

    return $self;
}


sub execute {
    my $self = shift;
    $self->error_message('No execute method implemeted in '. __PACKAGE__);
    return;
}

1;
