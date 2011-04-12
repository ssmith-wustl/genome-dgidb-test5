package Genome::Model::ReferenceAlignment::Command::CreateMetrics::GoldSnpConcordance;

use strict;
use warnings;

use File::Basename;
use Genome;

class Genome::Model::ReferenceAlignment::Command::CreateMetrics::GoldSnpConcordance {
    is => 'Genome::Command::Base',
    has => [
        build => {
            doc => 'The build for which to compute GoldSNP concordance',
            is => 'Genome::Model::Build::ReferenceAlignment',
            id_by => 'build_id',
            shell_args_position => 1,
        },
        build_id => {
            is => 'Integer',
            is_input => 1,
        },
    ],
    has_optional => [
        output_dir => {
            doc => "Override the default output directory",
            is => 'File',
            is_input => 1,
        },
        _snvs_bed => {
            is => 'File',
            doc => "instance variable: path to build's snv bed file",
        },
        _filtered_snvs_bed => {
            is => 'File',
            doc => "instance variable: path to build's filtered snv bed file",
        },
        _gold_snp_file => {
            is => 'File',
            doc => "instance variable: path to gold_snp build's snv bed file",
         },
    ],
    doc => "Compute dbSNP concordance for a build and store the resulting metrics the the database",
};

sub _verify_build_and_set_paths {
    my ($self, $build) = @_;

    my $bname = $build->__display_name__;
    my $gold_snp_build = $build->gold_snp_build;
    if (!defined $gold_snp_build) {
        die "No gold_snp_build property found on build $bname.";
    }

    my $build_rsb = $build->model->reference_sequence_build;
    my $gold_snp_rsb = $gold_snp_build->model->reference_sequence_build;
    if (!defined $gold_snp_rsb) {
        die "GoldSnp build " . $gold_snp_build->__display_name__ . " does not define a reference sequence!";
    }

    if (!$build_rsb->is_compatible_with($gold_snp_rsb)) {
        die "Build $bname has reference sequence " . $build_rsb->__display_name__ .
            " which is incompatible with " .  $gold_snp_rsb->__display_name__ . " specified by " .
            $gold_snp_build->__display_name__;
    }

    $self->_gold_snp_file($gold_snp_build->snvs_bed("v2"));
    if (!defined $self->_gold_snp_file()) {
        die "Failed to get gold_snp file from gold_snp build " . $gold_snp_build->__display_name__;
    }

    for my $type ("snvs_bed", "filtered_snvs_bed") {
        if (!$build->can($type)) {
            die "Don't know how to find snv bed file for build $bname.";
        }
        my $snv_file = $build->$type("v2");
        if (!defined $snv_file || ! -f $snv_file) {
            die "No suitable snv bed file found for build $bname [$type].";
        }
        my $propname = "_$type";
        $self->$propname($snv_file);
    }
}

sub _gen_concordance {
    my ($self, $f1, $f2, $output_path) = @_;

    my $snvcmp_cmd = Genome::Model::Tools::Joinx::SnvConcordance->create(
        depth => 1,
        input_file_a => $f1,
        input_file_b => $f2,
        output_file  => $output_path,
    );
    $snvcmp_cmd->execute() or die "joinx failed!";
}

sub execute {
    my $self = shift;

    eval {
        $self->_verify_build_and_set_paths($self->build);

        my $out_filt = $self->build->gold_snp_report_file_filtered;
        my $out_unfilt = $self->build->gold_snp_report_file_unfiltered;
        if ($self->output_dir) {
            $out_filt = join('/', $self->output_dir, basename($out_filt));
            $out_unfilt = join('/', $self->output_dir, basename($out_unfilt));
        }
        $self->_gen_concordance($self->_gold_snp_file, $self->_snvs_bed, $out_unfilt);
        $self->_gen_concordance($self->_gold_snp_file, $self->_filtered_snvs_bed, $out_filt);
    };
    if ($@) {
        $self->error_message($@);
        return;
    }

    return 1;
}

1;
