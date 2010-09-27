package Genome::Model::ReferenceAlignment::Command::CompareBuilds;

use strict;
use warnings;
use Genome;
use Carp 'confess';

class Genome::Model::ReferenceAlignment::Command::CompareBuilds {
    is => 'Genome::Command::OO',
    has => [
        model => {
            shell_args_position => 1,
            is => 'Genome::Model::ReferenceAlignment',
            id_by => 'model_id',
        },
    ],
};

sub help_brief {
    return "Determines if two builds of the same reference alignment model produced the same output";
}

sub help_detail { 
    return <<EOS
This tool compares select files from two builds of the same reference 
alignment model and compares their md5 hashes. This is especially useful for
checking that the output of two builds match after the underlying code has 
changed in a way that should not affect build output.
EOS
}

sub files_to_compare {
    return [qw(
        snp_related_metrics/indels_all_sequences
        snp_related_metrics/indels_all_sequences.bed
        snp_related_metrics/indels_all_sequences.filtered
        snp_related_metrics/indels_all_sequences.filtered.bed
        snp_related_metrics/snps_all_sequences
        snp_related_metrics/snps_all_sequences.bed
        snp_related_metrics/snps_all_sequences.filtered
        snp_related_metrics/snps_all_sequences.filtered.bed
        snp_related_metrics/report_input_all_sequences
        snp_related_metrics/filtered.variants.pre_annotation
        snp_related_metrics/filtered.variants.post_annotation
        alignments/*merged_rmdup.bam.flagstat
    )];
}
        
sub execute {
    my $self = shift;
    my $model = $self->model;
    my @builds = $model->builds;
    my $num_builds = scalar @builds;

    unless ($num_builds >= 2) {
        confess "Model does not have 2 or more builds, only has $num_builds!";
    }

    @builds = sort { $b->build_id <=> $a->build_id } @builds;
    my $old_build = $builds[1]; # Second newest build
    my $new_build = $builds[0]; # Newest build

    $self->status_message("Comparing newest build " . $new_build->build_id . " to next newest build " . $old_build->build_id);
    $self->status_message("Files are located in " . $new_build->data_directory . "/ and " . $old_build->data_directory . "/");

    my @diff_files;
    FILE: for my $file (@{$self->files_to_compare}) {
        my $old_file = $old_build->data_directory . "/" . $file;
        my $new_file = $new_build->data_directory . "/" . $file;

        # If the file name contains a *, assume that some regex is needed to determine full name
        # For now, only expecting one file to match... any more or less is a problem
        unless (index($file, "*") == -1) {
            my @old_files = glob($old_file);
            my @new_files = glob($new_file);
            
            if (@old_files > 1 or @new_files > 1) {
                push @diff_files, $file;
                next FILE;
            }
            elsif (@old_files < 1 or @new_files < 1) {
                push @diff_files, $file;
                next FILE;
            }

            $old_file = shift @old_files;
            $new_file = shift @new_files;
        }
            
        # Skip files that neither build have
        next FILE unless -e $old_file and -e $new_file;

        # If one build has a file that the other doesn't, that's a problem
        if ((-e $old_file and not -e $new_file) or (-e $new_file and not -e $old_file)) {
            push @diff_files, $file;
            next FILE;
        }

        my $old_md5 = Genome::Utility::FileSystem->md5sum($old_file);
        my $new_md5 = Genome::Utility::FileSystem->md5sum($new_file);

        unless ($old_md5 eq $new_md5) {
            push @diff_files, $file;
            next FILE;
        }
    }

    if (@diff_files) {
        $self->status_message("Differences found:\n" . join("\n", @diff_files));
    }
    else {
        $self->status_message("All files are identical!");
    }

    return 1;
}

1;

