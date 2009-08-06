package Genome::Model::Command::Build::ReferenceAlignment::RefCov;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment::RefCov {
    is => ['Genome::Model::Event'],
    has => [
            sample_name => { via => 'model', to => 'subject_name'},
            reference_coverage_directory => { via => 'build' },
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
    return "-R 'select[type==LINUX86]'";
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
        my @sorted_bam_files;
        my @sorted_idas = sort { $a->instrument_data_id <=> $b->instrument_data_id } $build->instrument_data_assignments;
        for my $idas (@sorted_idas) {
            my @alignments = $idas->alignments;
            unless (@alignments) {
                $self->error_message('No alignments found for instrument data '. $idas->instrument_data_id);
                return;
            }
            for my $alignment (@alignments) {
                push @sorted_bam_files, $alignment->alignment_bam_file_paths;
            }
        }
        my $snapshot_cmd = '/gscuser/jwalker/svn/TechD/RefCov/bin/snapshot.pl '. $ref_cov_dir .' '. join(' ',@sorted_bam_files);
        Genome::Utility::FileSystem->shellcmd(
            cmd => $snapshot_cmd,
            input_files => \@sorted_bam_files,
        );
    }

    unless ($self->verify_snapshot_directories) {
        $self->error_message('Failed to verify snapshot directories after running ref-cov');
        return;
    }

    my @snapshot_dirs = $self->snapshot_directories;
    my $final_dir = pop(@snapshot_dirs);
    my $final_stats_file = $final_dir .'/STATS.tsv';

     unless (Genome::Utility::FileSystem->validate_file_for_reading($final_stats_file)) {
        $self->error_message("Failed to validate stats file '$final_stats_file' for reading:  $!");
        die($self->error_message);
    }

    unless (-s $self->progression_data_file) {
        my @snapshot_stats_files = map { $_ .'/STATS.tsv'} $self->snapshot_directories;
        my $progression = Genome::Model::Tools::RefCov::Progression->execute(
                                                                             stats_files => \@snapshot_stats_files,
                                                                             sample_name => $self->sample_name,
                                                                             image_file => $self->progression_png_file,
                                                                             output_file => $self->progression_data_file,
                                                                         );
    }

    return $self->verify_successful_completion;
}

sub snapshot_directories {
    my $self = shift;
    my @subdirs = $self->_ref_cov_subdirs;
    my @snapshots = sort { $a cmp $b } grep {$_ =~ /\/\d+$/ } @subdirs;
    return @snapshots;
}

sub _ref_cov_subdirs {
    my $self = shift;
    my $ref_cov_dir = $self->reference_coverage_directory;
    unless (opendir(DIR,$ref_cov_dir)) {
        $self->error_message('Failed to open ref-cov directory '. $ref_cov_dir .":  $!");
        return;
    }
    my @subdirs = grep { -d  } map { $ref_cov_dir .'/'. $_ }  grep { $_ !~ /^\./ } readdir(DIR);
    closedir(DIR);
    return @subdirs;
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
    for my $data_type ( qw/progression/ ) {
        my $file_method = $data_type .'_data_file';
        my $file = $self->$file_method;
        unless (-f $file) {
            $self->error_message('Missing data file '. $file);
            return;
        }
    }
    # TODO: add bias to this list, but must account for the small, medium, and large files
    for my $image_type ( qw /progression/ ) {
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
    my $build = $self->build;
    my @sorted_idas = sort { $a->instrument_data_id <=> $b->instrument_data_id } $build->instrument_data_assignments;
    my $expected;
    for my $idas (@sorted_idas) {
        $expected += $idas->alignments;
    }
    unless (scalar(@snapshots) == $expected) {
        return 0;
    }
    return 1;
}



1;
