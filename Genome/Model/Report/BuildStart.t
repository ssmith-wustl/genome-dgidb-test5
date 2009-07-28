#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

#############################################################

package Genome::Model::Report::BuildStartTest;

use strict;
use warnings;

use base 'Test::Class';
#use base 'Genome::Utility::TestBase';

use Genome::Model::AmpliconAssembly::Test;
use Test::More;

sub test_01_generate : Tests() {
    my $self = shift;

    # Since this module doesn't really have any code, so just a use will do
    use_ok('Genome::Model::Report::BuildStart');
    
    if ( 0 ) { # if ya wanna save/see the report
        my $model = Genome::Model::AmpliconAssembly::Test->create_mock_model;
        my $generator = Genome::Model::Report::BuildStart->create(
            build_id => $_[0]->mock_model->latest_complete_build->id,
        );
        my $report = $self->{_object}->generate_report;
        #$report->save('/gsc/var/cache/testsuite/data/Genome-Report-Email', 1);
        my $xslt = Genome::Report::XSLT->create(
            report => $report,
            xslt_file => '/gscuser/ebelter/dev/to_deploy/Genome/Model/Report/BuildStart.email.xsl',
        );
        my $f = '/gscuser/ebelter/Desktop/t.html';
        unlink $f if -e $f;
        use IO::File;
        my $fh = IO::File->new($f, 'w');
        my $content = $xslt->transform_report;
        $fh->print( $content,"\n" );
        $fh->close;
    }

    return 1;
}

#############################################################

package main;

use strict;
use warnings;

Genome::Model::Report::BuildStartTest->runtests;

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

