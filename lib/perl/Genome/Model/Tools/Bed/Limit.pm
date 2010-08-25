package Genome::Model::Tools::Bed::Limit;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Bed::Limit {
    is => ['Command'],
    has => [
        gene_list => {
            is => 'Text',
        },
        input_bed_file => {
            is => 'Text',
        },
        output_bed_file => {
            is => 'Text',
        },
        feature_types => {
            is => 'Text',
        },
    ],
};

sub execute {
    my $self = shift;

    my %feature_types = map { $_ => 1 } split(',',$self->feature_types);
    my $list_fh = Genome::Utility::FileSystem->open_file_for_reading($self->gene_list);
    my $input_fh = Genome::Utility::FileSystem->open_file_for_reading($self->input_bed_file);
    my $output_fh = Genome::Utility::FileSystem->open_file_for_writing($self->output_bed_file);

    my %include;
    while (my $line = $list_fh->getline) {
        chomp($line);
        if ($line =~ /^(\S+)/) {
            $include{$1} = 1;
        }
    }
    $list_fh->close;

    while (my $line = $input_fh->getline) {
        chomp($line);
        my @entry = split("\t",$line);
        my $name = $entry[3];
        my ($gene,$transcript,$feature_type,$ordinal) = split(':',$name);
        if ($include{$gene} && $feature_types{$feature_type}) {
            print $output_fh $line ."\n";
        }
    }
    $input_fh->close;
    $output_fh->close;
    return 1;
}

1;
