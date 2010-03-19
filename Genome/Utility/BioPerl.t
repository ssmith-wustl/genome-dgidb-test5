#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More 'no_plan';
require IO::File;
require File::Temp;

my $class = 'Genome::Utility::BioPerl';
use_ok($class) or die;

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
ok(-d $tmpdir, 'Created temp dir.');
my $fasta_file = $tmpdir.'/fasta';

ok(!$class->create_bioseq_writer(undef), 'can\'t create bioseq writer w/o file');
ok(!$class->create_bioseq_reader(undef), 'can\'t create bioseq reader w/o file');
ok(!$class->create_bioseq_reader($fasta_file), 'can\'t create bioseq reader w/o existing file');
ok($class->create_bioseq_writer($fasta_file), 'created bioseq writer');
ok($class->create_bioseq_reader($fasta_file), 'created bioseq reader');

exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2010 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$
