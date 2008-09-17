package Genome::Model::Tools::PhredPhrap::Fasta;

use strict;
use warnings;

use above 'Genome';

class Genome::Model::Tools::PhredPhrap::Fasta {
    is => 'Genome::Model::Tools::PhredPhrap',
    has => [
    fasta_file => {
        is => 'String', #file_r
        doc => "Fasta file.  If desired, have a quality file named '<FASTA>.qual'",
    },
    ],
};

require Cwd;
use Data::Dumper;
require File::Copy;

sub help_brief {
    return 'Creates an assembly by running phrap on a FASTA (and Qual - <FASTA_FILE>.qual) file.';
}

sub help_detail {
    return '';
}

sub _command_name {
    my $self = shift;

    my $version = $self->version;

    return 'phrap' if $version eq $self->default_version;

    return 'phrap.' . $version;
}

sub _memlog {
    my $self = shift;

    return sprintf('%s.memlog', $self->fasta_file);
}

sub _out {
    my $self = shift;

    return sprintf('%s.phrap.out', $self->fasta_file);
}

sub execute {
    my $self = shift;

    for my $file (qw/ memlog out /) {
        unlink $self->$file if -e $self->$file;
    }

    my $cmd = sprintf('%s %s', $self->_command_name, $self->fasta_file);
    # FIXME
    my @attributes = grep { $_ ne 'fasta_file' } $self->attributes;
    @attributes = grep { $_ ne 'version' } @attributes;
    for my $attr ( @attributes ) {
        my $value = $self->$attr;
        next unless defined $value;
        if ( $self->attributes_attribute($attr, 'isa') eq 'boolean' ) {
            next unless $value;
            $value = '';
        }
        $cmd .= sprintf(
            ' -%s %s', 
            $attr, 
            $value,
        );
    }

    $cmd .= sprintf(' > %s 2> %s ', $self->_out, $self->_memlog);

    $self->fatal_msg("Error running phrap:\n$cmd") if system $cmd;

    return 1;
}

1;

=pod

=head1 Name

=head1 Synopsis

=head1 Methods

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This module is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
