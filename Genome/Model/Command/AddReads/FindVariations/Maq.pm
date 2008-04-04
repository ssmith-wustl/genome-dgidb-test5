package Genome::Model::Command::AddReads::FindVariations::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;
use File::Temp;
use IO::File;

class Genome::Model::Command::AddReads::FindVariations::Maq {
    is => ['Genome::Model::Event', 'Genome::Model::Command::MaqSubclasser'],
};

sub help_brief {
    "Use maq to find snips and idels"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads find-variations maq --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the postprocess-alignments process
EOS
}

sub bsub_rusage {
    return "-R 'select[type=LINUX64]'";

}


sub execute {
    my $self = shift;
    
    my $model = Genome::Model->get(id => $self->model_id);
    my $maq_pathname = $self->proper_maq_pathname('indel_finder_name');

    # ensure the reference sequence exists.
    my $ref_seq_file = $model->reference_sequence_path . "/all_sequences.bfa";
    unless (-e $ref_seq_file) {
        $self->error_message("reference sequence file $ref_seq_file does not exist.  please verify this first.");
        return;
    }

    my $model_dir = $model->data_directory;

    my $accumulated_alignments_file = $model->resolve_accumulated_alignments_filename(ref_seq_id=>$self->ref_seq_id);
    unless (-f $accumulated_alignments_file) {
        $self->error_message("Alignment file $accumulated_alignments_file was not found.  It should have been created by a prior run of align-reads maq");
        return;
    }
    
    my $analysis_base_path = $model_dir . "/identified_variations";
    unless (-d $analysis_base_path) {
        mkdir($analysis_base_path);
    }

    my $assembly_output_file = sprintf('%s/consensus/%s.cns',
                                       $model_dir, 
                                       (defined $self->ref_seq_id ? $self->ref_seq_id
                                                              : ""));
    
    unless (-f $assembly_output_file) {
        $self->error_message("Assembly output file $assembly_output_file was not found.  It should have been created by a prior run of update-genotype-probabilities maq");
        return;
    }

    my $snp_resource_name = sprintf("snips%s",
                                    defined $self->ref_seq_id ? "_".$self->ref_seq_id
                                                              : "");

    my $indel_resource_name = sprintf("indels%s",
                                    defined $self->ref_seq_id ? "_".$self->ref_seq_id
                                                              : "");

    my $pileup_resource_name = sprintf("pileup%s",
                                    defined $self->ref_seq_id ? "_".$self->ref_seq_id
                                                              : "");

    foreach my $resource ( $snp_resource_name, $indel_resource_name, $pileup_resource_name) {
        unless ($model->lock_resource(resource_id=>$resource)) {
            $self->error_message("Can't get lock for resource $resource");
            return undef;
        }
    }

    my $snip_output_file =  $analysis_base_path . "/" . $snp_resource_name;
    my $indel_output_file =  $analysis_base_path . "/" . $indel_resource_name;
    my $pileup_output_file = $analysis_base_path . "/" . $pileup_resource_name;
                                       
    my $retval = system("$maq_pathname cns2snp $assembly_output_file > $snip_output_file");
    unless ($retval == 0) {
        $self->error_message("running maq cns2snp returned non-zero exit code $retval");
        return;
    }
    
    $retval = system("$maq_pathname indelsoa $ref_seq_file $accumulated_alignments_file > $indel_output_file");
    unless ($retval == 0) {
        $self->error_message("running maq indelsoa returned non-zero exit code $retval");
        return;
    }

    # Running pileup requires some parsing of the snip file
    my $tmpfh = File::Temp->new();
    my $snip_fh = IO::File->new($snip_output_file);
    unless ($snip_fh) {
        $self->error_message("Can't open snip output file for reading: $!");
        return;
    }
    while(<$snip_fh>) {
        chomp;
        my ($id, $start, $ref_sequence, $iub_sequence, $quality_score,
            $depth, $avg_hits, $high_quality, $unknown) = split("\t");
        $tmpfh->print("$id\t$start\n");
    }
    $tmpfh->close();
    $snip_fh->close();

    my $pileup_command = sprintf("$maq_pathname pileup -v -l %s %s %s > %s",
                                 $tmpfh->filename,
                                 $ref_seq_file,
                                 $accumulated_alignments_file,
                                 $pileup_output_file);

    $retval = system($pileup_command);
    unless ($retval == 0) {
        $self->error_message("running maq pileup returned non-zero exit code $retval");
        return;
    }

    return 1;
}




1;

