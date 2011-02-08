#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::DeNovoAssembly::Test;
use Genome::Utility::Text;
use Test::More;

use_ok('Genome::Model::Build::DeNovoAssembly::Soap') or die;

my $model = Genome::Model::DeNovoAssembly::Test->model_for_soap;
ok($model, 'Got de novo assembly model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->example_build_for_model($model);
ok($build, 'Got example de novo assembly build');

my $file_prefix = $build->file_prefix;
is($file_prefix, Genome::Utility::Text::sanitize_string_for_filesystem($model->subject_name).'_WUGC', 'file prefix');
my $library_file_base = $build->data_directory.'/'.$file_prefix;

# library info and assembler input files
my ($inst_data) = $build->instrument_data;
ok($inst_data, 'instrument data for build');
my $library_id = $inst_data->library_id;
ok($library_id, 'library id for inst data');
my $assembler_forward_input_file_for_library_id = $build->assembler_forward_input_file_for_library_id($library_id);
is($assembler_forward_input_file_for_library_id, $library_file_base.'.'.$library_id.'.forward.fastq', 'forward fastq file for library id');
my $assembler_reverse_input_file_for_library_id = $build->assembler_reverse_input_file_for_library_id($library_id);
is($assembler_reverse_input_file_for_library_id, $library_file_base.'.'.$library_id.'.reverse.fastq', 'reverse fastq file for library id');
my $assembler_fragment_input_file_for_library_id = $build->assembler_fragment_input_file_for_library_id($library_id);
is($assembler_fragment_input_file_for_library_id, $library_file_base.'.'.$library_id.'.fragment.fastq', 'fragment fastq file for library id');
my @libraries = $build->libraries_with_existing_assembler_input_files;
is_deeply( # also tests existing_assembler_input_files_for_library_id
    \@libraries,
    [
        {
            library_id => -12345,
            insert_size => 260,
            paired_fastq_files => [ 
                $assembler_forward_input_file_for_library_id, $assembler_reverse_input_file_for_library_id 
            ],
        },
    ],
    'libraries and existing assembler input files',
);
my @existing_assembler_input_files = $build->existing_assembler_input_files;
is_deeply(
    \@existing_assembler_input_files,
    $libraries[0]->{paired_fastq_files},
    'existing assembler input files',
);

# edit dir files
my %files_to;

done_testing();
exit;
