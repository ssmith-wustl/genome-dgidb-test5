#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::MetagenomicComposition16s::Test;
use Test::More;

use_ok('Genome::Model::Event::Build::MetagenomicComposition16s::Assemble::PhredPhrap') or die;

my $model = Genome::Model::MetagenomicComposition16s::Test->model_for_sanger;
ok($model, 'got mc16s sanger model');
my $build = Genome::Model::Build->create(
    model => $model,
    data_directory => $model->data_directory,
);
ok($build, 'created build');
my $example_build = Genome::Model::MetagenomicComposition16s::Test->example_build_for_model($model);
ok($example_build, 'got example build');
ok(_link_example_data($build, $example_build), 'linked example data');

my ($amplicon_set) = $build->amplicon_sets;
ok($amplicon_set, 'amplicon set');

# rm files that will be created
while ( my $amplicon = $amplicon_set->next_amplicon ) {
    my $ace_file = $build->ace_file_for_amplicon($amplicon);
    unlink $ace_file;
    for my $ext (qw/ log memlog phrap.out problems problems.qual singlets contigs contigs.qual view /) {
        my $file = $build->edit_dir.'/'.$amplicon->{name}.'.fasta.'.$ext;
        unlink $file;
    }
}

# run
my $phred_phrap = Genome::Model::Event::Build::MetagenomicComposition16s::Assemble::PhredPhrap->create(build => $build);
ok($phred_phrap, 'created phred phrap');
$phred_phrap->dump_status_messages(1);
ok($phred_phrap->execute, 'execute');

# validate files 
ok(-s $amplicon_set->processed_fasta_file, 'Created the processed fasta file');
ok(-s $amplicon_set->processed_qual_file, 'Created the processed qual file');
while ( my $amplicon = $amplicon_set->next_amplicon ) {
    ok(-s $build->ace_file_for_amplicon($amplicon), 'ace file');
}

# metrics
is($build->reads_attempted, 30, 'reads attempted is 30');
is($build->reads_processed, 17, 'reads processed is 17');
is($build->reads_processed_success, '0.57', 'reads processed success is 0.57');

#print $build->data_directory."\n";<STDIN>;
done_testing();
exit;

##############################

sub _link_example_data {
    my ($build, $example_build) = @_;

    for my $dir_to_link (qw/ chromat_dir edit_dir /) {
        my $dest_dir = $build->$dir_to_link;
        Genome::Sys->validate_existing_directory($dest_dir) or die;
        my $source_dir = $example_build->$dir_to_link;
        my $dh = Genome::Sys->open_directory($source_dir) or die;

        $dh->read; $dh->read; # . and .. dirs
        while ( my $file = $dh->read ) {
            my $target = "$source_dir/$file";
            next if -d $target;
            my $link =  $dest_dir.'/'.$file;
            unless ( symlink($target, $link) ) {
                die "Can't symlink ($target) to ($link): $!.";
            }
        }
    }

    return 1;
}

