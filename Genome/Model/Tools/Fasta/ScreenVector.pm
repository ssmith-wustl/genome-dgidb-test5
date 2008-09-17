package Genome::Model::Tools::Fasta::ScreenVector;

use strict;
use warnings;

use above "Genome";
use Command;

require Cwd;
use Data::Dumper;
require File::Basename;
require File::Copy;
require File::Temp;
require XML::Simple;

class Genome::Model::Tools::Fasta::ScreenVector
{
    is => 'Genome::Model::Tools::Fasta',
    has => [
                project_name => {
                    is => 'String',
                    doc => 'Name of project',
                    default => 'none',
                },
            ],
};

sub help_brief {
    return '(Fnq = Fasta And Quality) screen for vector';
}

sub out_file_ext { return 'screen'; }

sub execute {
    my $self = shift;

    # Load conf
    my $xs = XML::Simple->new(
        rootname => 'configuration',
        KeyAttr => {
            defaults => 'name',
        },
        ForceArray => [qw/ screen defaults projects /],
        ContentKey => '-content',
        VarAttr => 'name',
    );

    my $conf = $xs->XMLin('screen_vector.conf.xml');

    # Back up FASTA
    my $fasta_bak = sprintf('%s.prescreen', $self->_fasta_base);
    File::Copy::copy($self->_fasta_base, $fasta_bak)
        or ($self->error_message( sprintf('Can\'t copy %s to %s: %s', $self->_fasta_base, $fasta_bak, $!) )
            and return);
    my $fasta_screen = sprintf('%s.screen', $self->_fasta_base);

    # Get project w/ screen params
    my $project;
    for my $project_to_check ( @{ $conf->{projects} } ) {
        my $pattern = $project_to_check->{pattern};
        #print "YES\n" if $self->project_name =~ /$pattern/;
        next unless $self->project_name =~ /$pattern/;
        $project = $project_to_check;
        last;
    }

    for my $screen ( @{ $project->{screen} } ) {
        my $subject_file = $project->{file};
        my $query_file = $self->_fasta_base;
        my $params = $screen->{params};

        my $cmd = sprintf(
            "cross_match %s %s %s -screen",
            $self->_fasta_base,
            $screen->{file},
            $screen->{params},
        );

        ($self->error_message("Error running cross_match:\n$cmd") and return) if system $cmd;

        # Copy the screen file bak to the fasta to be used as input.
        unlink $self->_fasta_base;
        File::Copy::copy($fasta_screen, $self->_fasta_base)
            or ($self->error_message( sprintf('Can\'t copy screen file (%s) to %s: %s', $fasta_screen, $self->_fasta_base, $!) )
                and return);
        unlink $fasta_screen;
    }

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
