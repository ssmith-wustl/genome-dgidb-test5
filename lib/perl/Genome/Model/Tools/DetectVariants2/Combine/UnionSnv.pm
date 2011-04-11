package Genome::Model::Tools::DetectVariants2::Combine::UnionSnv;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::UnionSnv{
    is => 'Genome::Model::Tools::DetectVariants2::Combine',
    doc => 'Union snvs into one file',
    has_constant => [
        _variant_type => {
            type => 'String',
            default => 'snvs',
            doc => 'variant type that this module operates on',
        },
    ],

};

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants combine --variant-file-a samtools.hq.v1.bed --variant-file-b varscan.hq.v1.bed --output-file 
EOS
}


sub _combine_variants {
    my $self = shift;
    my $snvs_a = $self->input_directory_a."/snvs.hq.bed";
    my $snvs_b = $self->input_directory_b."/snvs.hq.bed";
    my $output_file = $self->output_directory."/snvs.hq.bed";

    my @input_files = ($snvs_a, $snvs_b);

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
    my $lq_file = $self->output_directory."/snvs.lq.bed";
    `touch $lq_file`;
    return 1;
}

1;
