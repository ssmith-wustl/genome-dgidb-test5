#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::MetagenomicComposition16s::Test;
use Test::More;
use File::Compare 'compare';

use_ok('Genome::Model::Event::Build::MetagenomicComposition16s::Trim::Finishing') or die;

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

# run
my $trim = Genome::Model::Event::Build::MetagenomicComposition16s::Trim::Finishing->create(build => $build);
ok($trim, 'create');
$trim->dump_status_messages(1);
ok($trim->execute, 'execute');

# check files
ok(-s $build->processed_reads_fasta_file, 'Created the processed reads fasta file');
ok(-s $build->processed_reads_qual_file, 'Created the processed reads qual file');

#print $build->data_directory."\n";<STDIN>;
done_testing();
exit;

#####################################

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

