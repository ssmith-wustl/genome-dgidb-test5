package Genome::Model::Tools::CompareBuilds::ReferenceAlignment;

use strict;
use warnings;

use Genome;
use Carp 'confess';

class Genome::Model::Tools::CompareBuilds::ReferenceAlignment {
    is => 'Genome::Model::Tools::CompareBuilds',
};

# TODO Add bam comparison, talk to Feiyu about it
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

    my $first_build_id = $self->first_build_id;
    my $first_build = $self->first_build;
    my $second_build_id = $self->second_build_id;
    my $second_build = $self->second_build;

    unless ($first_build->model_id eq $second_build->model_id) {
        confess "Build $first_build_id has model " . $first_build->model_id . " and build $second_build_id has model " .
            $second_build->model_id . ", these builds must come from the same model in order to be compared!";
    }

    unless ($first_build->class =~ /ReferenceAlignment/i) {
        confess "Builds are not ReferenceAlignment, type is " . $first_build->class;
    }

    my @diff_files;
    FILE: for my $file (@{$self->files_to_compare}) {
        my $old_file = $first_build->data_directory . "/" . $file;
        my $new_file = $second_build->data_directory . "/" . $file;

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

