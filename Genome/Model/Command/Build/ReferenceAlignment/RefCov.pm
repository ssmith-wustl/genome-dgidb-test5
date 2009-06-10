package Genome::Model::Command::Build::ReferenceAlignment::RefCov;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment::RefCov {
    is => ['Genome::Model::Event'],
    has => [
            snapshots => {
                          calculate_from => 'build',
                          calculate => q|
                                   my @idas = $build->instrument_data_assignments;
                                   return scalar(@idas);
                          |,
                      },
            sample_name => { via => 'model', to => 'subject_name'},
            reference_coverage_directory => { via => 'build' },
            layers_file => { via => 'build', },
            genes_file => { via => 'build', },
        ],
};

sub help_brief {
    "Use ref-cov to calculate coverage metrics for cDNA or RNA";
}

sub help_synopsis {
    return <<"EOS"
    genome model build reference-alignment ref-cov --model-id=? --build-id=? 
EOS
}

sub help_detail {
    return <<EOS 
This command is usually called as part of the add-reads process
EOS
}

sub bsub_rusage {
    return "-M 16000000 -R 'select[type==LINUX64 && mem>16000] rusage[mem=16000]'";
}

sub execute {
    my $self = shift;
    my $build = $self->build;
    my $ref_cov_dir = $self->reference_coverage_directory;
    unless (Genome::Utility::FileSystem->create_directory($ref_cov_dir)) {
        $self->error_message('Failed to create ref_cov directory '. $ref_cov_dir .":  $!");
        return;
    }

    unless ($self->verify_snapshot_directories) {
        $self->status_message('Running ref-cov with '. $self->snapshots .' snapshots in directory '. $ref_cov_dir);
        my $snapshot = Genome::Model::Tools::RefCov::Snapshot->execute(
                                                                       snapshots => $self->snapshots,
                                                                       layers_file_path => $self->layers_file,
                                                                       genes_file_path => $self->genes_file,
                                                                       base_output_directory => $ref_cov_dir,
                                                                   );
        unless ($snapshot) {
            $self->error_message('Failed to run ref-cov snpashot command!');
            die($self->error_message);
        }
    }

    unless ($self->verify_snapshot_directories) {
        $self->error_message('Failed to verify snapshot directories after running ref-cov');
        return;
    }

    unless ($self->verify_composed_directories) {
        my @snapshots = $self->snapshot_directories;
        $self->status_message("Running ref-cov composed on:\n". join("\n",@snapshots)); 
        my $compose = Genome::Model::Tools::RefCov::Compose->execute(
                                                                     snapshot_directories => \@snapshots,
                                                                     composed_directory => $ref_cov_dir,
                                                                 );
        unless($compose) {
            $self->error_message('Failed to execute compose on ref-cov snapshots.');
            die($self->error_message);
        }
    }

    unless ($self->verify_composed_directories) {
        $self->error_message('Failed to verify composed directories after running ref-cov');
        return;
    }

    my @composed_dirs = $self->all_composed_directories;
    my $final_dir = pop(@composed_dirs);
    my $final_frozen_dir = $final_dir .'/FROZEN';
    my $final_stats_file = $final_dir .'/STATS.tsv';

    unless (Genome::Utility::FileSystem->validate_directory_for_read_access($final_frozen_dir)) {
        $self->error_message("Failed to validate frozen directory '$final_frozen_dir' for read access:  $!");
        die($self->error_message);
    }
    unless (Genome::Utility::FileSystem->validate_file_for_reading($final_stats_file)) {
        $self->error_message("Failed to validate stats file '$final_stats_file' for reading:  $!");
        die($self->error_message);
    }
    my $bias = Genome::Model::Tools::RefCov::Bias->execute(
                                                           frozen_directory => $final_frozen_dir,
                                                           sample_name => $self->sample_name,
                                                           image_file => $self->bias_png_file,
                                                           output_file => $self->bias_data_file,
                                                       );
    unless ($bias) {
        $self->error_message('Failed to run ref-cov bias report!');
        die($self->error_message);
    }
    my $coverage_bins = Genome::Model::Tools::RefCov::CoverageBins->execute(
                                                                            stats_file => $final_stats_file,
                                                                            output_file => $self->coverage_bins_data_file,
                                                                        );
    unless ($coverage_bins) {
        $self->error_message('Failed to run ref-cov coverage-bins report!');
        die($self->error_message);
    }
    my $size_histos = Genome::Model::Tools::RefCov::SizeHistos->execute(
                                                                        stats_file => $final_stats_file,
                                                                        output_file => $self->size_histos_data_file,
                                                                    );
    unless ($size_histos) {
        $self->error_message('Failed to run ref-cov size-histos report!');
        die($self->error_message);
    }

    my @composed_stats_files = map { $_ .'/STATS.tsv'} $self->all_composed_directories;
    my $progression = Genome::Model::Tools::RefCov::CoverageProgression->execute(
                                                                                 stats_files => \@composed_stats_files,
                                                                                 sample_name => $self->sample_name,
                                                                                 image_file => $self->progression_png_file,
                                                                                 output_file => $self->progression_data_file,
                                                                             );

    return $self->verify_successful_completion;
}

sub snapshot_directories {
    my $self = shift;
    my @subdirs = $self->_ref_cov_subdirs;
    my @snapshots = sort { $a cmp $b } grep {$_ =~ /\/\d{2}$/ } @subdirs;
    return @snapshots;
}

sub composed_directories {
    my $self = shift;
    my @subdirs = $self->_ref_cov_subdirs;
    my @composed = sort { $a cmp  $b } grep { $_ =~ /(\d{2}_\d{2})+/ } @subdirs;
    return @composed;
}

sub all_composed_directories {
    my $self = shift;

    my @snapshots = $self->snapshot_directories;
    my $first_snapshot = shift(@snapshots);

    my @composed = $self->composed_directories;
    unshift(@composed,$first_snapshot);
    return @composed;
}

sub _ref_cov_subdirs {
    my $self = shift;
    my $ref_cov_dir = $self->reference_coverage_directory;
    unless (opendir(DIR,$ref_cov_dir)) {
        $self->error_message('Failed to open ref-cov directory '. $ref_cov_dir .":  $!");
        return;
    }
    my @subdirs = grep { -d  } map { $ref_cov_dir .'/'. $_ } grep { $_ !~ /^composed/ } grep { $_ !~ /^\./ } readdir(DIR);
    closedir(DIR);
    return @subdirs;
}

sub bias_data_file {
    my $self = shift;
    return $self->_data_file('bias');
}

sub bias_png_file {
    my $self = shift;
    return $self->_png_file('bias');
}

sub coverage_bins_data_file {
    my $self = shift;
    return $self->_data_file('coverage_bins');
}

sub size_histos_data_file {
    my $self = shift;
    return $self->_data_file('size_histos');
}

sub progression_data_file {
    my $self = shift;
    return $self->_data_file('progression');
}

sub progression_png_file {
    my $self = shift;
    return $self->_png_file('progression');
}

sub _data_file {
    my $self = shift;
    my $type = shift;
    return $self->reference_coverage_directory .'/'. $self->sample_name .'_'. $type;
}

sub _png_file {
    my $self = shift;
    my $type = shift;
    my $data_file = $self->_data_file($type);
    return $data_file .'.png';
}

sub verify_successful_completion {
    my $self = shift;

    unless ($self->verify_snapshot_directories) {
        $self->error_message('Failed to verify_snapshot_directories!');
        die($self->error_message);
    }
    unless ($self->verify_composed_directories) {
        $self->error_message('Failed to verify_composed_directories!');
        die($self->error_message);
    }
    for my $data_type ( qw/bias coverage_bins size_histos progression/ ) {
        my $file_method = $data_type .'_data_file';
        my $file = $self->file_method;
        unless (-f $file) {
            $self->error_message('Missing data file '. $file);
            return;
        }
    }
    for my $image_type ( qw /bias progression/ ) {
        my $file_method = $image_type .'_png_file';
        my $file = $self->$file_method;
        unless (-f $file ) {
            $self->error_message('Missing image file '. $file);
            return;
        }
    }
    return 1;
}

sub verify_snapshot_directories {
    my $self = shift;

    my @snapshots = $self->snapshot_directories;
    unless (@snapshots) {
        return;
    }
    unless ($self->_verify_refcov_directories(\@snapshots,$self->snapshots)) {
        $self->error_message('Failed to verify_snapshot_directories!');
        die($self->error_message);
    }
    return 1;
}

sub verify_composed_directories {
    my $self = shift;

    my @composed_dirs = $self->composed_directories;
    unless (@composed_dirs) {
        return;
    }
    unless ($self->_verify_refcov_directories(\@composed_dirs,($self->snapshots - 1))) {
        $self->error_message('Failed to verify_composed_directories!');
        die($self->error_message);
    }
    return 1;
}

sub _verify_refcov_directories {
    my $self = shift;
    my $dir_ref = shift;
    my $expected = shift;

    my @dirs = @{$dir_ref};
    unless (scalar(@dirs) == $expected) {
        $self->error_message('Found '. scalar(@dirs) .' directories but expecting '. $expected ."!\n". join("\n",@dirs));
        return;
    }
    for my $dir (@dirs) {
        unless (-d $dir .'/FROZEN') {
            $self->error_message('Failed to find frozen directory in '. $dir);
            return;
        }
        unless (-f $dir .'/STATS.tsv') {
            $self->error_message('Failed to find stats file in '. $dir);
            return;
        }
        # TODO: Add wc -l on the STATS.tsv and the genes file
        # they should be equal
    }
    return 1;
}

1;
