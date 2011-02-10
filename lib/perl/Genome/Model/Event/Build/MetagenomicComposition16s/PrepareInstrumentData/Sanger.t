#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::MetagenomicComposition16s::Test;
use Test::More;

use_ok('Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Sanger') or die;

my $model = Genome::Model::MetagenomicComposition16s::Test->model_for_sanger;
ok($model, 'got mc16s sanger model');
my $build = Genome::Model::Build->create(
    model => $model,
    data_directory => $model->data_directory,
);
ok($build, 'created build');

# run
my $pid = Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Sanger->create(build => $build);
ok($pid, 'create');
$pid->dump_status_messages(1);
ok($pid->execute, 'execute');

# verify
my @amplicon_sets = $build->amplicon_sets;
is(@amplicon_sets, 1, 'amplicon_sets');
for my $set ( @amplicon_sets ) {
    while ( my $amplicon = $set->next_amplicon ) {
        ok(-s $build->scfs_file_for_amplicon($amplicon), 'scfs file');
        ok(-s $build->phds_file_for_amplicon($amplicon), 'phds file');
        ok(-s $build->reads_fasta_file_for_amplicon($amplicon), 'fasta file');
        ok(-s $build->reads_qual_file_for_amplicon($amplicon), 'qual file');
    }
}
is($build->amplicons_attempted, 5, 'amplicons attempted is 5');
ok(-s $build->raw_reads_fasta_file, 'Created the raw reads fasta file');
ok(-s $build->raw_reads_qual_file, 'Created the raw reads qual file');

#print $build->data_directory."\n";<STDIN>;
done_testing();  
exit;

