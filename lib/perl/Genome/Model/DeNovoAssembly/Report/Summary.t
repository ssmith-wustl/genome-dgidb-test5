#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::DeNovoAssembly::Test;
use Test::More;

use_ok('Genome::Model::DeNovoAssembly::Report::Summary') or die;

my $model = Genome::Model::DeNovoAssembly::Test->model_for_velvet;
ok($model, 'Got mock model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->example_build_for_model($model);
ok($build, 'Got mock build') or die;

my $generator = Genome::Model::DeNovoAssembly::Report::Summary->create(
    build_id => $build->id,
);
ok($generator, 'Created generator');
my $report = $generator->generate_report;
ok($report, 'Generated report');


=pod Save report, html
die;
$report->save($build->reports_directory, 1);
my $xslt = Genome::Report::XSLT->transform_report(
    report => $report,
    xslt_file => $generator->get_xsl_file_for_html,
);
my $html_file = $report->directory.'/report.html';
unlink $html_file;
my $fh = Genome::Sys->open_file_for_writing($html_file);
unless ( $fh ) {
    die "can't open $html_file";
}
$fh->print( $xslt->{content} );
$fh->close;
=cut

done_testing();
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
