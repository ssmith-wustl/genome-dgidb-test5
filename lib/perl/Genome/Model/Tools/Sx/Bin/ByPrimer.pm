package Genome::Model::Tools::Sx::Bin::ByPrimer;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Tools::Sx::Bin::ByPrimer {
    is  => 'Genome::Model::Tools::Sx::Bin',
    has => [
        primers => {
            is  => 'Text',
            is_many => 1,
            doc => 'Names and primer sequences to bin sequences.',
        },
        remove => {
            is => 'Boolean',
            doc => 'If found, remove the primer from the sequence.',
        },
    ],
};

sub help_brief {
    return 'Bin sequences by primers';
}

sub help_synopsis {
    return <<HELP
HELP
}

sub help_detail {
    return <<HELP 
HELP
}

sub __errors__ {
    my $self = shift;

    my @errors = $self->SUPER::__errors__(@_);
    return @errors if @errors;

    my %primers;
    for my $primer ( $self->primers ) {
        my ($name, $sequence) = split('=', $primer);
        if ( not $name or $name eq '' ) {
            push @errors, UR::Object::Tag->create(
                type => 'invalid',
                properties => [qw/ primers /],
                desc => "Primer ($primer) does not have a name. Primers should have format of name=sequence",
            );
        }
        if ( not $sequence or $sequence eq '' ) {
            push @errors, UR::Object::Tag->create(
                type => 'invalid',
                properties => [qw/ primers /],
                desc => "Primer ($primer) does not have a sequence. Primers should have format of name=sequence",
            );
        }
        push @{$primers{$name}}, $sequence;
    }

    $self->{_primers} = \%primers;

    return @errors;
}

sub execute {
    my $self = shift;

    my $init = $self->_init;
    return if not $init;

    my $reader = $self->_reader;
    my $writer = $self->_writer;

    my $binner = ( $self->remove )
    ? $self->_create_bin_by_primer_and_remove
    : $self->_create_bin_by_primer;

    while ( my $seqs = $reader->read ) {
        for my $seq ( @$seqs ) {
            $binner->($seq);
        }
        $writer->write($seqs);
    }

    return 1;
}

sub _create_bin_by_primer {
    my $self = shift;

    my $primers = $self->{_primers};

    return sub{
        my $seq = shift;
        for my $name ( keys %$primers ) {
            for my $primer ( @{$primers->{$name}} ) {
                if ( $seq->{seq} =~ /^$primer/ ) {
                    $seq->{writer_name} = $name;
                    return 1;
                }
            }
        }
    };
}

sub _create_bin_by_primer_and_remove {
    my $self = shift;

    my $primers = $self->{_primers};

    return sub{
        my $seq = shift;
        for my $name ( keys %$primers ) {
            for my $primer ( @{$primers->{$name}} ) {
                if ( $seq->{seq} =~ s/^$primer// ) {
                    substr($seq->{qual}, 0, length($primer), '') if $seq->{qual}; # rm qual
                    $seq->{writer_name} = $name;
                    return 1;
                }
            }
        }
    };
}

1;

