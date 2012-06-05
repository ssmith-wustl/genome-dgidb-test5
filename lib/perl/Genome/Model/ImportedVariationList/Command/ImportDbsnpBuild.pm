package Genome::Model::ImportedVariationList::Command::ImportDbsnpBuild;

use warnings;
use strict;

use Genome;

class Genome::Model::ImportedVariationList::Command::ImportDbsnpBuild {
   is => 'Command::V2',
   has_input => [
       vcf_file_url => {
           is => 'Text',
           doc => 'Path to the full VCF file on the DBSnp ftp server'
       },
       flat_file_pattern => {
           is => 'Text',
           is_optional => 1,
           doc => 'String representing the pattern that the flat file filenames follow with [X] substituted in for the chromosome number',
       },
       version => {
           is => 'Text',
           doc => 'The version of the build to create',
       },
       reference_sequence_build => {
           is => 'Genome::Model::Build::ReferenceSequence',
           doc => 'The reference upon which the DBSnp build will be based'
       },
   ],
   has_transient_optional_output => [
       build => {
           is => 'Genome::Model::Build::ImportedVariationList',
           doc => 'Build created by this command'
       },
   ],
};

sub execute {
    my $self = shift;

    my $allocation = Genome::Disk::Allocation->create(
        kilobytes_requested =>20_971_520 , 
        disk_group_name => 'info_genome_models', 
        allocation_path => 'build_merged_alignments/import_dbsnp_' . $self->version . '_' . Genome::Sys->md5sum_data($self->vcf_file_url),
        owner_class_name => 'Genome::Model::ImportedVariationList::Command::ImportDbsnpBuild',
        owner_id => $self->id
    );

    local $ENV{'TMPDIR'} = $allocation->absolute_path;

    my $import_vcf = Genome::Model::Tools::Dbsnp::ImportVcf->create(
        vcf_file_url => $self->vcf_file_url,
        ($self->flat_file_pattern ? (flat_file_pattern => $self->flat_file_pattern) : ()),
        output_file_path => $allocation->absolute_path . '/merged_dbsnp.vcf'
    );

    unless ($import_vcf->execute()){
        die($self->error_message("VCF file download and merge failed"));
    }

    my $original_file_path = $allocation->absolute_path . '/merged_dbsnp.vcf';
    my $import_cmd = Genome::Model::ImportedVariationList::Command::ImportVariants->create(
        input_path => $original_file_path,
        reference_sequence_build => $self->reference_sequence_build,
        source_name => "dbsnp",
        description => "this had better work!",
        description => 'Imported VCF file from DBSnp ' . $self->vcf_file_url,
        variant_type => "snv",
        format => "vcf",
        version => $self->version
    );


    my $rv = $import_cmd->execute;
    $self->build($import_cmd->build);
    
    $allocation->delete;
    return $rv;
}

1;

