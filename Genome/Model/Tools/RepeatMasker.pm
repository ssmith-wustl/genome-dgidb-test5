package Genome::Model::Tools::RepeatMasker;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Tools::RepeatMasker {
    is => ['Command'],
    is_abstract => 1,
    has_input => [
        fasta_file => {
            is => 'Text',
            doc => 'The layers file path(fully qualified) formatted from maq alignments',
        },
        base_output_directory => {
            is => 'Text',
            doc => 'The output directory where files are written',
        },
    ],
    has => [
            output_directory => {
                                 calculate_from => ['base_output_directory','unique_subdirectory'],
                                 calculate => q|
                                     return $base_output_directory . $unique_subdirectory;
                                 |
                             },
            unique_subdirectory => {
                            calculate_from => ['fasta_file'],
                            calculate => q|
                                               my $fasta_basename = File::Basename::basename($fasta_file);
                                               if ($fasta_basename =~ /(\d+)$/) {
                                                   return '/'. $1;
                                               } else {
                                                   return '';
                                               }
                                           |,
                        },
            ],
};

1;
