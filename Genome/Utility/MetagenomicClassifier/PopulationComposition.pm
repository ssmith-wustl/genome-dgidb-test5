package Genome::Utility::MetagenomicClassifier::PopulationComposition;

use strict;
use warnings;

use Carp 'confess';
use Data::Dumper 'Dumper';
use Regexp::Common;

sub new {
    my ($class, %params) = @_;

    my $self = bless {}, $class;

    if ( my $threshold = delete $params{confidence_threshold} ) {
        $self->_fatal_message(
            "Invalid confidence_threshold ($threshold) sent to 'new'"
        ) unless $threshold =~ /^$RE{num}{real}$/;
        $self->{confidence_threshold} = $threshold;
    }
    else {
        $self->{confidence_threshold} = 0.8;
    }

    $self->_fatal_message(
        "Unknown params sent to 'new': ".join(',', map { $_.'=>'.$params{$_} } keys %params)
    ) if %params;
        
    return $self;
}

sub _fatal_message {
    my ($self, $msg) = @_;

    confess ref($self)." ERROR: $msg\n";
}
 
sub get_confidence_threshold {
    return $_[0]->{confidence_threshold};
}

sub add_classification {
    my ($self, $classification) = @_;

    my $classifications = ( ($classification->get_root_taxon->get_tag_values('confidence'))[0] >= $self->get_confidence_threshold ) 
    ? $self->get_confident_classifications
    : $self->get_unconfident_classifications;

    push @$classifications, $classification;

    return 1;
}

sub get_classifications {
    return $_[0]->{_classifications};
    #return @{$_[0]->{_classifications}};
}

sub get_confident_classifications {
    return $_[0]->{_classifications}->[1];
}

sub get_unconfident_classifications {
    return $_[0]->{_classifications}->[0];
}

sub get_genus_count_for_confident_bacteria_domain {
}

1;

=pod

=head1 Name

ModuleTemplate

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

