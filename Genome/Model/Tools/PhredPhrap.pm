package Genome::Model::Tools::PhredPhrap;

use strict;
use warnings;

use above 'Genome';

class Genome::Model::Tools::PhredPhrap {
    is => 'Command',
    is_abstract => 1,
    has => [
    version  => {
        type => 'String',
        is_optional => 1,
        default => __PACKAGE__->default_version,#=> $versions[0],
        doc => "Version to use: " . join(', ', __PACKAGE__->versions)
    },
    forcelevel  => {
        type => 'int non_neg',
        is_optional => 1,
        default => 1,
        doc => 'Relaxes stringency to varying degree during final contig merge pass.  Allowed values are integers from 0 (most stringent, to 10 (least stringent)',
    },
    minmatch  => {
        type => 'int non_neg',
        is_optional => 1,
        default => 17,
        doc => 'Minimum length of matching word to nucleate SWAT comparison. if minmatch = 0, a full (non-banded, comparison is done [N.B. NOT PERMITTED IN CURRENT VERSION]. Increasing -minmatch can dramatically decrease the time required for the pairwise sequence comparisons; in phrap, it also tends to have the effect of increasing assembly stringency. However it may cause some significant matches to be missed, and it may increase the risk of incorrect joins in phrap in certain situations (by causing implied overlaps between reads with high-quality discrepancies to be missed).',
    },
    minscore  => {
        type => 'int non_neg',
        is_optional => 1,
        default => 30,
        doc => 'Minimum alignment score.',
    },
    revise_greedy  => {
        type => 'Boolean',
        is_optional => 1,
        default => 0,
        doc => 'Splits initial greedy assembly into pieces at "weak joins", and then tries to reattach them to give higher overall score.  Use of this option should correct some types of missassembly.',
    },
    shatter_greedy  => {
        type => 'Boolean',
        is_optional => 1,
        default => 0,
        doc => 'Breaks assembly at weak joins (as with revise-greedy, but does not try to reattach pieces.',
    },
    view  => {
        type => 'Boolean',
        is_optional => 1,
        default => 1,
        doc => 'Create ".view" file suitable for input to phrapview.',
    },
    new_ace  => {
       type => 'Boolean',
       is_optional => 1,
       default => 1,
       doc => 'Create ".ace" file for viewing in consed. Default is to create an acefile.',
    },
    ],
};

#- COMMAND -#
sub phrap_command_name {
    my $self = shift;

    # TODO get full path of phrap executable?
    return sprintf('phrap%s', (( $self->version ) ? ('.' . $self->version) : ''));
}

#- VERSIONS -#
my @versions = (qw/ phrap manyreads longreads /);
sub versions {
    return @versions;
}

sub default_version {
    return $versions[0];
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
