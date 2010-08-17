#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use IO::File;
use Test::More;

use_ok('Genome::Model::Tools::FastQual') or die;

class Genome::Model::Tools::FastQual::Tester {
    is => 'Genome::Model::Tools::FastQual',
};

# Create w/ in fastq file to PIPE
my $fastq_tester = Genome::Model::Tools::FastQual::Tester->create(
    input_files => [ 
        "/gsc/var/cache/testsuite/data/Genome-Model-Tools-FastQual/in.fastq" 
    ],
    output_files => [ 
        # ok, not actually gonna write to this file
        "/gsc/var/cache/testsuite/data/Genome-Model-Tools-FastQual/out.fastq" 
    ],
);
ok($fastq_tester, 'create w/ fastq files');
my $fastq_reader = $fastq_tester->_open_reader;
ok($fastq_reader, 'opened reader for fastq files') or die;
isa_ok($fastq_reader, 'Genome::Model::Tools::FastQual::FastqSetReader');
is($fastq_tester->type, 'sanger', 'type is sanger');
my $fastq_writer = $fastq_tester->_open_writer;
ok($fastq_writer, 'opened writer for fastq files') or die;
isa_ok($fastq_writer, 'Genome::Model::Tools::FastQual::FastqSetWriter');

# Test pipes
my $pipe_tester = Genome::Model::Tools::FastQual::Tester->create(
    input_files => [qw/ PIPE /],
    output_files => [qw/ PIPE /], 
);
ok($pipe_tester, 'create w/ pipes');
my $pipe_writer = $pipe_tester->_open_writer;
ok($pipe_writer, 'opened writer for pipes') or die;
isa_ok($pipe_writer, 'Genome::Utility::IO::StdoutRefWriter');
my $pipe_reader;
eval{
    $pipe_reader = $pipe_tester->_open_reader;
};
diag("\n".$@);
ok((!$pipe_reader && $@ =~ /No pipe meta info/), 'failed to open reader b/c no meta info');

done_testing();
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

 Eddie Belter <ebelter@watson.wustl.edu>

=cut
