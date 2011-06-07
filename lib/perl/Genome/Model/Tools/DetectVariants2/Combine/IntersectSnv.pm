package Genome::Model::Tools::DetectVariants2::Combine::IntersectSnv;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::IntersectSnv{
    is => 'Genome::Model::Tools::DetectVariants2::Combine',
    has_constant => [
        _variant_type => {
            type => 'String',
            default => 'snvs',
            doc => 'variant type that this module operates on',
        },
    ],

};


sub help_brief {
    "Intersect two snv variant bed files",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants combine intersect-snv --variant-file-a samtools.hq.v1.bed --variant-file-b varscan.hq.v1.bed --output-file 
EOS
}

sub help_detail {                           
    return <<EOS 
EOS
}

sub _combine_variants {
    my $self = shift;
    
    my $snvs_a = $self->input_directory_a."/snvs.hq.bed";
    my $snvs_b = $self->input_directory_b."/snvs.hq.bed";
    my $output_file = $self->output_directory."/snvs.hq.bed";
    my $miss_a_file = $self->output_directory."/snvs.lq.a.bed";
    my $miss_b_file = $self->output_directory."/snvs.lq.b.bed";

    my $intersect_command = Genome::Model::Tools::Joinx::Intersect->create(
        input_file_a => $snvs_a,
        input_file_b => $snvs_b,
        output_file => $output_file,
        miss_a_file => $miss_a_file,
        miss_b_file => $miss_b_file,
    );
    
    unless ($intersect_command->execute) {
        $self->error_message("Error executing intersect command");
        die $self->error_message;
    }

    # Create an "lq" file that has things that were either in only file a or only file b
    # Using joinx with --merge-only will do a union, effectively
    my $lq_file = $self->output_directory."/snvs.lq.bed";
    my $merge_cmd = Genome::Model::Tools::Joinx::Sort->create(
        merge_only => 1,
        input_files => [$miss_a_file, $miss_b_file],
        output_file => $lq_file,
    );
    unless ($merge_cmd->execute) {
        $self->error_message("Failed to combine $miss_a_file and $miss_b_file into $lq_file");
        die $self->error_message;
    }

    return 1;
}

sub _validate_output {
    my $self = shift;
    my $variant_type = $self->_variant_type;
    my $input_a_file = $self->input_directory_a."/".$variant_type.".hq.bed";
    my $input_b_file = $self->input_directory_b."/".$variant_type.".hq.bed";
    my $hq_output_file = $self->output_directory."/".$variant_type.".hq.bed";
    my $lq_output_file = $self->output_directory."/".$variant_type.".lq.bed";
    my $input_total = $self->line_count($input_a_file) + $self->line_count($input_b_file);

    # Count hq * 2 because every hq line for an intersection implies 2 lines from input combined into one
    my $output_total = $self->line_count($hq_output_file) * 2 + $self->line_count($lq_output_file);
    unless(($input_total - $output_total) == 0){
        die $self->error_message("Combine operation in/out check failed. Input total: $input_total \toutput total: $output_total");
    }
    return 1;
}

1;
