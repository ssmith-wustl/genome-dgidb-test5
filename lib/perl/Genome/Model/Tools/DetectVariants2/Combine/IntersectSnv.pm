package Genome::Model::Tools::DetectVariants2::Combine::IntersectSnv;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::IntersectSnv{
    is => 'Genome::Model::Tools::DetectVariants2::Combine',
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

    # Using joinx with --merge-only will do a union, effectively
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
    my $lq_file = $self->output_directory."/snvs.lq.bed";
    my $cmd = "sort -m $miss_a_file $miss_b_file > $lq_file";
    my $result = Genome::Sys->shellcmd( cmd => $cmd);

    unless ($result) {
        $self->error_message("Failed to combine $miss_a_file and $miss_b_file into $lq_file");
        die $self->error_message;
    }

    return 1;
}

1;
