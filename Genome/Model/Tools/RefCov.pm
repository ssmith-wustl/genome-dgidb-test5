package Genome::Model::Tools::RefCov;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Tools::RefCov {
    is => ['Command'],
    is_abstract => 1,
    has_input => [
            layers_file_path => {
                                 is => 'Text',
                                 doc => 'The layers file path(fully qualified) formatted from maq alignments',
                             },
            genes_file_path  => {
                                 is => 'Text',
                                 doc => 'The genes or backbone file path(fully qualified) containing reference sequence data',
                             },
            base_output_directory => {
                                      is => 'Text',
                                      doc => 'The output directory where files are written',
                                  },
              ],
    has_output => [
            stats_file_path  => {
                                 calculate_from => ['output_directory', 'stats_file_name'],
                                 calculate => q|
                                    return $output_directory .'/'. $stats_file_name;
                                 |,
                             },
            log_file_path    => {
                                 calculate_from => ['output_directory', 'log_file_name'],
                                 calculate => q|
                                    return $output_directory .'/'. $log_file_name;
                                 |,
                             },
            frozen_directory => {
                                 calculate_from => ['output_directory'],
                                 calculate => q|
                                    return $output_directory .'/FROZEN';
                                 |,
                             },
            layer_stats_file => {
                calculate_from => ['output_directory'],
                calculate => q|
                    return $output_directory . '/STATS.tsv';
                |
            }
    ],
    has => [
            output_directory => {
                                 calculate_from => ['base_output_directory','unique_subdirectory'],
                                 calculate => q|
                                     return $base_output_directory . $unique_subdirectory;
                                 |
                             },
            unique_subdirectory => {
                            calculate_from => ['layers_file_path'],
                            calculate => q|
                                               my $layers_basename = File::Basename::basename($layers_file_path);
                                               if ($layers_basename =~ /(\d+)$/) {
                                                   return '/'. $1;
                                               } else {
                                                   return '';
                                               }
                                           |,
                        },
            ],
    has_optional  => [
                      stats_file_name => {
                                          is => 'Text',
                                          doc => 'The output file name to dump RefCov stats(default_value=STATS'. ($ENV{LSB_JOBID} || '') .'.tsv)',
                                          default_value => 'STATS'. ($ENV{LSB_JOBID} || '') .'.tsv',
                                      },
                      log_file_name => {
                                        is => 'Text',
                                        doc => 'The output log file name(default_value=time'. ($ENV{LSB_JOBID} || '') .'.LOG)',
                                        default_value => 'time'. ($ENV{LSB_JOBID} || '') .'.LOG',
                                    },
                  ],
};

1;
