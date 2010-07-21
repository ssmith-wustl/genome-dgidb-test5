#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::DeNovoAssembly::Test;
use Test::More;

use_ok('Genome::Model::Build::DeNovoAssembly::Velvet');

my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'velvet',
);
ok($model, 'Got mock de novo assembly model') or die;
my $build = Genome::Model::Build::DeNovoAssembly->create(
    model_id => $model->id,
    data_directory => Genome::Model::DeNovoAssembly::Test->example_directory_for_model($model),
);
ok($build, 'Created de novo assembly build') or die;
isa_ok($build, 'Genome::Model::Build::DeNovoAssembly::Velvet');

# file in main dir
_test_files_and_values(
    $build->data_directory,
    collated_fastq_file => 'collated.fastq',
    assembly_afg_file => 'velvet_asm.afg',
    contigs_fasta_file => 'contigs.fa',
    sequences_file => 'Sequences',
);

# files in edit dir
my $edit_dir = $build->edit_dir;
is($edit_dir, $build->data_directory.'/edit_dir', 'edit_dir');
_test_files_and_values(
    $edit_dir,
    ace_file => 'velvet_asm.ace',
    gap_file => 'gap.txt',
    contigs_bases_file => 'contigs.bases',
    contigs_quals_file => 'contigs.quals',
    read_info_file => 'readinfo.txt',
    reads_placed_file => 'reads.placed',
    assembly_fasta_file => 'contigs.bases',
    supercontigs_agp_file => 'supercontigs.agp',
    supercontigs_fasta_file => 'supercontigs.fasta',
    stats_file => 'stats.txt',
);

# metrics
my %metrics = $build->set_metrics;
ok(%metrics, 'Set metrics');

done_testing();
exit;

sub _test_files_and_values {
    my ($dir, %files_and_values) = @_;

    for my $file ( keys %files_and_values ) {
        my $value = $build->$file or die;
        is($value, $dir.'/'.$files_and_values{$file}, $file);
        ok(-e $value, "$file exists");
    }

    return 1;
}

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
