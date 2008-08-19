#!/gsc/bin/perl

use above "Genome";
use IO::File;

my $fh=IO::File->new("/gscuser/charris/svn/pm2/Genome/Model/Tools/SeeFourFive/fifth.txt");

my @lines=$fh->getlines;

my $object=Genome::Model::Tools::SeeFourFive::Tree->create(
);
#$object->lines(\@lines);
$object->c45_file("/gscuser/charris/svn/pm2/Genome/Model/Tools/SeeFourFive/fifth.txt");
$object->load_trees;
my $perl_source=$object->perl_src;

print $perl_source;


