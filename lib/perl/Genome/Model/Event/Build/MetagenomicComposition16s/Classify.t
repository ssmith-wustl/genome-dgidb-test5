#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::MetagenomicComposition16s::Test;
require File::Copy;
use Test::More;

use_ok('Genome::Model::Event::Build::MetagenomicComposition16s::Classify') or die;

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

# set some values
$build->amplicons_attempted(5);
is($build->amplicons_attempted, 5, 'amplicons attempted set');
#$build->amplicons_processed(0);
#is($build->amplicons_processed, 0, 'amplicons processed set');
#$build->amplicons_processed_success(0);
#is($build->amplicons_processed_success, 0, 'amplicons processed success set');
#$build->amplicons_classified(0);
#is($build->amplicons_classified, 0, 'amplicons classified set');
#$build->amplicons_classified_success(0);
#is($build->amplicons_classified_success, 0, 'amplicons classified success set');

# run
my $classify = Genome::Model::Event::Build::MetagenomicComposition16s::Classify->create(build => $build);
ok($classify, 'create');
$classify->dump_status_messages(1);
ok($classify->execute, 'execute');

# verify
my $cnt = 0;
my @amplicon_sets = $build->amplicon_sets;
is(@amplicon_sets, 1, 'amplicon_sets');
for my $set ( @amplicon_sets ) {
    while ( my $amplicon = $set->next_amplicon ) {
        $cnt++ if -s $build->classification_file_for_amplicon_name($amplicon->name);
    }
}
is($cnt, 4, 'Verified - Created classification for 4 of 5 amplicons');
is($build->amplicons_processed, 4, 'amplicons processed is 4');
is($build->amplicons_processed_success, '0.80', 'amplicons processed sucess is .8');
is($build->amplicons_classified, 4, 'amplicons classified is 4');
ok(-s $build->classification_file_for_set_name(''), 'build classification file');

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

