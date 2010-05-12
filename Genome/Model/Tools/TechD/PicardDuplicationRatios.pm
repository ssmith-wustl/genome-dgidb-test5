package Genome::Model::Tools::TechD::PicardDuplicationRatios;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::TechD::PicardDuplicationRatios{
    is => ['Command'],
    has => {
        build_id => { },
    },
};

sub execute {
    my $self = shift;
    my $build = Genome::Model::Build->get($self->build_id);
    unless ($build) {
        die('Failed to find build by id '. $self->build_id);
    }
    my $subject = $build->model->subject_name;
    my $data_directory = $build->data_directory;
    my $dedup_metrics = $data_directory .'/logs/mark_duplicates.metrics';
    my $fh = Genome::Utility::FileSystem->open_file_for_reading($dedup_metrics);
    my %library_duplication_ratios;
    while (my $line = $fh->getline) {
        chomp($line);
        if ($line =~ /^$subject/) {
            my @entry = split("\t",$line);
            my $duplicate_ratio = $entry[7];
            $library_duplication_ratios{$subject} = $duplicate_ratio;
        }
    }
    $fh->close;
    print Data::Dumper::Dumper(%library_duplication_ratios);
    return 1;
}
