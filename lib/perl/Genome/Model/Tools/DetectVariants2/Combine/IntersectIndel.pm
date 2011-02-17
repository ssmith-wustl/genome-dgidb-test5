package Genome::Model::Tools::DetectVariants2::Combine::IntersectIndel;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::IntersectIndel{
    is => 'Genome::Model::Tools::DetectVariants2::Combine',
};


sub help_brief {
    "Intersect two indel variant bed files",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants combine intersect-indel --variant-file-a samtools.hq.v1.bed --variant-file-b varscan.hq.v1.bed --output-file 
EOS
}

sub help_detail {                           
    return <<EOS 
EOS
}

sub _combine_variants {
    my $self = shift;
    
    my $indels_a = $self->input_directory_a."/indels.hq.bed";
    my $indels_b = $self->input_directory_b."/indels.hq.bed";
    my $output_file = $self->output_directory."/indels.hq.bed";
    my $miss_a_file = $self->output_directory."/indels.lq.a.bed";
    my $miss_b_file = $self->output_directory."/indels.lq.b.bed";

    # Using joinx with --merge-only will do a union, effectively
    my $intersect_command = Genome::Model::Tools::Joinx::Intersect->create(
        input_file_a => $indels_a,
        input_file_b => $indels_b,
        output_file => $output_file,
        miss_a_file => $miss_a_file,
        miss_b_file => $miss_b_file,
    );
    
    unless ($intersect_command->execute) {
        $self->error_message("Error executing intersect command");
        die $self->error_message;
    }

    # Create an "lq" file that has things that were either in only file a or only file b
    my $lq_file = $self->output_directory."/indels.lq.bed";
    my $cmd = "sort -m $miss_a_file $miss_b_file > $lq_file";
    my $result = Genome::Sys->shellcmd( cmd => $cmd);

    unless ($result) {
        $self->error_message("Failed to combine $miss_a_file and $miss_b_file into $lq_file");
        die $self->error_message;
    }

    return 1;
}

1;
