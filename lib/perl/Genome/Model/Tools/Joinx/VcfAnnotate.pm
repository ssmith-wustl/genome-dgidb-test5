package Genome::Model::Tools::Joinx::VcfAnnotate;

use strict;
use warnings;

use Genome;
use Data::Dumper;

our $MINIMUM_JOINX_VERSION = 1.4;

class Genome::Model::Tools::Joinx::VcfAnnotate {
    is => 'Genome::Model::Tools::Joinx',
    has_input => [
        input_file => {
            is => 'Text',
            doc => 'Vcf File to filter',
            shell_args_position => 1,
        },
        annotation_file => {
            is => 'Text',
            doc => 'Vcf File containing annotation',
            shell_args_position => 2,
        },
        info_fields => {
            is => 'Text',
            doc => 'Field ids to embed from the annotation VCF. Use colons to separate multiple field descriptors.',
            #doing the above because UR autosplits on commas with is_many, but joinx uses commas in its field descriptors
        },
    ],
    has_optional_input => [
        output_file => {
            is => 'Text',
            is_output => 1,
            doc => 'The output file (defaults to stdout)',
        },
        use_bgzip => {
            is => 'Boolean',
            doc => 'zcats the input files into stdin, and bgzips the output',
            default => 0,
        },
        identifiers => {
            is => 'Boolean',
            default => 1,
            doc => 'copy identifiers from the annotation file',
        },
        info => {
            is => 'Boolean',
            default => 1,
            doc => 'copy information from info fields from the annotation file',
        },
    ],
};

sub help_brief {
    "Annotate information from one VCF file's identifiers and info fields into another."
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
  gmt joinx vcf-annotate --input-file a.vcf --annotation-file dbsnp.vcf --info-fields GMAF;dbSNPBuildID=dbSNPBuildID,per-alt --output-file annotated.vcf
EOS
}

sub execute {
    my $self = shift;
    $DB::single = 1;

    if($self->use_version < $MINIMUM_JOINX_VERSION) {
        die $self->error_message("This module requires joinx version 1.4 or higher to function correctly.");
    }

    if(defined($self->use_bgzip) && not defined($self->output_file)){
       die $self->error_message("If use_bgzip is set, output_file must also be set, otherwise binary nonsense will spew forth."); 
    }
    my $output = "-";
    $output = $self->output_file if (defined $self->output_file);

    my $input_file = $self->input_file;

    unless(-s $input_file) {
        die $self->error_message("$input_file does not exist");
    }

    my $annotation_file = $self->annotation_file;
    unless(-s $annotation_file) {
        die $self->error_message("$annotation_file does not exist");
    }

    if($self->use_bgzip){
        $input_file = "<(zcat $input_file)";
    }

    my $cmd = $self->joinx_path . " vcf-annotate" . " --input-file $input_file" . " --annotation-file $annotation_file";
    my $info_fields = " --info-fields " . join(" --info-fields ", split /:/, $self->info_fields);
    $cmd .= $info_fields;
    unless($self->identifiers) {
        $cmd .= " --no-identifiers";
    }
    unless($self->info) {
        $cmd .= " --no-info";
    }

    if(defined($self->output_file) && not defined($self->use_bgzip)){
        $cmd .= " --output-file $output" if defined($self->output_file);
    } elsif ( defined($self->use_bgzip) && defined($self->output_file) ){
        $cmd .= " | bgzip -c > $output";
        $cmd = "bash -c \"$cmd\"";
    }
    $self->status_message($cmd);
        
    my %params = (
        cmd => $cmd,
    );
    $params{output_files} = [$output] if $output ne "-";
    $params{skip_if_output_is_present} = 0;
    Genome::Sys->shellcmd(%params);

    return 1;
}

1;
