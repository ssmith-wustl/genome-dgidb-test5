package Genome::Model::Command::Build::ReferenceAlignment::RefCov;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment::RefCov {
    is => ['Genome::Model::Event'],
    has => [
        _sorted_bams => {
            is => 'Array',
            is_optional => 1,
        },
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

sub sorted_bam_files {
    my $self = shift;
    my $build = $self->build;
    my @sorted_bam_files;
    unless (defined($self->_sorted_bams)) {
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
        $self->_sorted_bams(\@sorted_bam_files);
    } else {
        @sorted_bam_files = @{$self->_sorted_bams};
    }
    return @sorted_bam_files;;
}

sub snapshot_count {
    my $self = shift;
    my @sorted_bam_files = $self->sorted_bam_files;
    my $snapshot_count = scalar(@sorted_bam_files);
    return $snapshot_count;
}

sub execute {
    my $self = shift;

    my $ref_cov_dir = $self->build->reference_coverage_directory;
    unless (Genome::Utility::FileSystem->create_directory($ref_cov_dir)) {
        $self->error_message('Failed to create ref_cov directory '. $ref_cov_dir .":  $!");
        return;
    }

    # Run ref-cov on each accumulated iteration or snapshot
    # produces a reference coverage stats file for each iteration and relative coverage
    unless ($self->verify_snapshots) {
        my @sorted_bam_files = $self->sorted_bam_files;
        my $snapshot_cmd = '/gscuser/jwalker/svn/TechD/RefCov/bin/new_snapshot.pl '. $self->build->genes_file .' '.$ref_cov_dir .' '. join(' ',@sorted_bam_files);
        Genome::Utility::FileSystem->shellcmd(
            cmd => $snapshot_cmd,
            input_files => \@sorted_bam_files,
        );
    }
    unless ($self->verify_snapshots) {
        $self->error_message('Failed to verify snapshot directories after running ref-cov');
        return;
    }

    my @snapshot_stats_files = $self->snapshot_stats_files;
    my $final_stats_file = $snapshot_stats_files[-1];
    unless (Genome::Utility::FileSystem->validate_file_for_reading($final_stats_file)) {
        $self->error_message("Failed to validate stats file '$final_stats_file' for reading:  $!");
        die($self->error_message);
    }
    my $stats_file = $self->build->coverage_stats_file;
    unless ( -l $stats_file) {
        unless (symlink($final_stats_file,$stats_file)) {
            $self->error_message("Failed to create final stats snapshot symlink:  $!");
            die($self->error_message);
        }
    }

    unless (-s $self->build->coverage_progression_file) {
        unless (Genome::Model::Tools::RefCov::Progression->execute(
            stats_files => \@snapshot_stats_files,
            sample_name => $self->model->subject_name,
            output_file => $self->build->coverage_progression_file,
        ) ) {
            $self->error_message('Failed to execute the progression for snapshots:  '. join("\n",@snapshot_stats_files));
            die($self->error_message);
        }
    }

    unless (-s $self->build->breakdown_file) {
        my @sorted_bam_files = $self->sorted_bam_files;
        my $breakdown_cmd = '/gscuser/jwalker/svn/TechD/RefCov/bin/breakdown.pl '. $ref_cov_dir .' '. join(' ',@sorted_bam_files);
        Genome::Utility::FileSystem->shellcmd(
            cmd => $breakdown_cmd,
            input_files => \@sorted_bam_files,
            output_files => [$self->build->breakdown_file],
        );
    }

    return $self->verify_successful_completion;
}

sub snapshot_stats_files {
    my $self = shift;

    my @stats_files = map { $self->build->reference_coverage_directory .'/STATS_'. $_ .'.tsv' } (1 .. $self->snapshot_count);
    return @stats_files;
}

sub verify_snapshots {
    my $self = shift;
    my @snapshot_stats_files = $self->snapshot_stats_files;
    for my $snapshot_stats_file (@snapshot_stats_files) {
        unless (-e $snapshot_stats_file) {
            return;
        }
        unless (-f $snapshot_stats_file) {
            return;
        }
        unless (-s $snapshot_stats_file) {
            return;
        }
    }
    return 1;
}

sub verify_successful_completion {
    my $self = shift;

    unless ($self->verify_snapshots) {
        $self->error_message('Failed to verify snapshots!');
        die($self->error_message);
    }
    my @files = (
        $self->build->coverage_progression_file,
        $self->build->coverage_stats_file,
        $self->build->breakdown_file
    );
    my @SIZES = qw/SMALL MEDIUM LARGE/;
    for my $size (@SIZES) {
        push @files, $self->build->relative_coverage_file($size);
    }
    for my $file (@files) {
        $self->check_output_file_existence($file);
    }
    return 1;
}

sub check_output_file_existence {
    my $self = shift;
    my $file = shift;

    unless (-e $file) {
        $self->error_message('Missing reference coverage output file '. $file);
        return;
    }
}

1;
