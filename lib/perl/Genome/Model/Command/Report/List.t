#! /gsc/bin/perl

use strict;
use warnings;

####################

package Genome::Model::Command::Report::List::Test;

use base 'Genome::Utility::TestCommandBase';

use Test::More;

sub test_class {
    return 'Genome::Model::Command::Report::List';
}

sub valid_param_sets {
    return (
        {# defaults to all - tests generic and all type names
        },
        {# all type names
            type_names => 1,
        },
        {# aa reports
            type_name => 'amplicon assembly',
        },
        {# generic reports
            generic => 1,
        },
    );
}

sub invalid_param_sets {
    return (
        {# invalid type name
            type_name => 'no way this is a model',
        },
        {# more than one list method
            all => 1,
            type_name => 'amplicon assembly',
        },
    );
}

####################

package main;

use above 'Genome';

Genome::Model::Command::Report::List::Test->runtests;

exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

