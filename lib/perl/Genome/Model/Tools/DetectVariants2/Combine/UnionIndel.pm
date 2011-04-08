package Genome::Model::Tools::DetectVariants2::Combine::UnionIndel;


use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::UnionIndel{
    is => 'Genome::Model::Tools::DetectVariants2::Combine',
    has_constant => [
        _variant_type => {
            type => 'String',
            default => 'indels',
            doc => 'variant type that this module operates on',
        },
    ],

};


sub help_brief {
    "Union two indel variant bed files",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants combine union indel --variant-file-a samtools.hq.v1.bed --variant-file-b varscan.hq.v1.bed --output-file 
EOS
}

sub help_detail {                           
    return <<EOS 
EOS
}

sub _combine_variants {
    my $self = shift;
    my $bed_version = $self->bed_input_version;    
    my $indels_a = $self->input_directory_a."/indels.hq.v".$bed_version.".bed";
    my $indels_b = $self->input_directory_b."/indels.hq.v".$bed_version.".bed";
    my $output_file = $self->output_directory."/indels.hq.v".$bed_version.".bed";

    my @input_files = ($indels_a, $indels_b);

    # Using joinx with --merge-only will do a union, effectively
    my $union_command = Genome::Model::Tools::Joinx::Sort->create(
        input_files => \@input_files,
        merge_only => 1,
        output_file => $output_file,
    );
    
    unless ($union_command->execute) {
        $self->error_message("Error executing union command");
        die $self->error_message;
    }

    # When unioning, there is no "fail" really, everything should be in the hq file
    my $lq_file = $self->output_directory."/indels.lq.v".$bed_version.".bed";
    `touch $lq_file`;
    return 1;
}

1;
