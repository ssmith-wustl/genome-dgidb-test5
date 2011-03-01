package Genome::Model::Tools::DetectVariants2::Filter::VarscanHighConfidence;

use warnings;
use strict;

use File::Copy;
use Genome;

class Genome::Model::Tools::DetectVariants2::Filter::VarscanHighConfidence{
    is => 'Genome::Model::Tools::DetectVariants2::Filter',
};

sub _filter_variants {
    my $self = shift;
    my $varscan_status_file = $self->input_directory."/snvs.hq";
    my $base_name = $self->_temp_staging_directory."/snvs";

    my $vshc = Genome::Model::Tools::Varscan::ProcessSomatic->create(
        status_file => $varscan_status_file,
        output_basename => $base_name,
    );

    unless( $vshc->execute ){
        die $self->error_message("Execution of gmt varscan process-somatic failed.");
    }

    $self->prepare_output;

    my $lq_output = $self->_temp_staging_directory."/snvs.lq";
    my $hq_output = $self->_temp_staging_directory."/snvs.hq";

    ## Possibly move this to a class method on Filter
    my $hq_cnv_cmd = Genome::Model::Tools::Bed::Convert::Snv::VarscanSomaticToBed->create(
        source => $hq_output,
        output => $hq_output.".bed",
        reference_sequence_input => $self->reference_sequence_input,
    );

    unless( $hq_cnv_cmd->execute ){
        die $self->error_message(" Failed to execute command to convert hq output to bed format.");
    }

    my $lq_cnv_cmd = Genome::Model::Tools::Bed::Convert::Snv::VarscanSomaticToBed->create(
        source => $lq_output,
        output => $lq_output.".bed",
        reference_sequence_input => $self->reference_sequence_input,
    );

    unless( $lq_cnv_cmd->execute ){
        die $self->error_message(" Failed to execute command to convert lq output to bed format.");
    }

    return 1;
}

# Condition output into one hq (sns.Somatic.hc) and one lq file (cat all other outputs)
sub prepare_output {
    my $self = shift;
    my $somatic_hq = $self->_temp_staging_directory."/snvs.Somatic.hc";
    my $somatic_lq = $self->_temp_staging_directory."/snvs.Somatic.lc";
    my $germline = $self->_temp_staging_directory."/snvs.Germline";
    my $loh = $self->_temp_staging_directory."/snvs.LOH";
    my $somatic_lq_temp = Genome::Sys->create_temp_file_path;
    my $germline_temp = Genome::Sys->create_temp_file_path;
    my $loh_temp = Genome::Sys->create_temp_file_path;

    my $hq_file = $self->_temp_staging_directory."/snvs.hq";
    my $lq_file = $self->_temp_staging_directory."/snvs.lq";

    $self->copy_no_header( $somatic_hq, $hq_file );
    $self->copy_no_header( $somatic_lq, $somatic_lq_temp );
    $self->copy_no_header( $germline, $germline_temp );
    $self->copy_no_header( $loh, $loh_temp );

    my @lq_source = ($somatic_lq_temp, $germline_temp, $loh_temp);

    my $catcmd = Genome::Model::Tools::Cat->create(
        dest => $lq_file,
        source => \@lq_source,
    );

    unless( $catcmd->execute ){
        die $self->error_message("Failed to run gmt cat on lq files.");
    }

}

# This sub provides the functionality of copying all but the first line from arg1 to arg2
sub copy_no_header {
    my $self = shift;
    my $from = shift;
    my $to = shift;
    my $cmd = "tail -n +2 $from > $to";
    my $result = Genome::Sys->shellcmd( cmd => $cmd);
    return $result;
}

1;
