
package Genome::Model::Alignment::Mock;
use base 'Genome::Model::Alignment';

use warnings;
use strict;

sub new{
    my ($pkg, %params) = @_;
    
    die "You must pass in a read_bases_probability_vectors and a mismatch_code or mismatch_string to use this Mock!"
        unless(
                    defined($params{read_bases_probability_vectors})
                    && (
                             defined($params{mismatch_code})
                          ||
                             defined($params{mismatch_string})
                         )
               );
    
    $pkg->SUPER::new(%params, reads_fh => '');
}

sub decode_match_string{
    return ('','');
}

sub get_current_mismatch_code{
    my $self = shift;
    return $self->{mismatch_code} if $self->{mismatch_code};
    
    return Genome::Model::Alignment::Mock->SUPER::get_current_mismatch_code();
}

1;