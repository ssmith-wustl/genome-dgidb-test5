#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 7;

BEGIN {use_ok('Genome::Model::Tools::DeleteFiles');}

my ($dir, $file_count) = (Genome::Utility::FileSystem->create_temp_directory, 5);

my @files;

#create files to delete
for (my ($i,$file,$cmd) = (0,undef,undef); $i < $file_count; $i++)
{
    $file = $dir . 'tmp_' . $i . '.del';
    $cmd = "touch $file";
    system($cmd);
    push(@files,$file);
}

#delete files
my $delete_files = Genome::Model::Tools::DeleteFiles->create(files => \@files);
ok($delete_files->execute, "deleting files");

#check that files are deleted
foreach my $file(@files)
{
    ok(!(-e $file), "$file was successfully deleted");
}

