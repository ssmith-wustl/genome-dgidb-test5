#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::MetagenomicComposition16s::Test;
use Test::More;

use_ok('Genome::Model::Event::Build::MetagenomicComposition16s::CleanUp');

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

# make sure we got files
my @files_remaining = glob($build->edit_dir.'/*');
is(@files_remaining, 80, "Start w/ correct number of files");

# run
my $clean_up = Genome::Model::Event::Build::MetagenomicComposition16s::CleanUp->create(build => $build);
ok($clean_up, 'create');
$clean_up->dump_status_messages(1);
ok($clean_up->execute, 'execute');

# verify
@files_remaining = glob($build->edit_dir.'/*');
is(@files_remaining, 80, "Removed correct number of files");
#is(@files_remaining, 15, "Removed correct number of files");

#print $self->_build->data_directory."\n";<STDIN>;
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

