package Genome::Model::Tools::454::ReadSeparation;

use strict;
use warnings;

use Genome;

use File::Basename;

class Genome::Model::Tools::454::ReadSeparation {
    is => ['Genome::Model::Tools::454'],
    has => [
            sff_file => {
                         is => 'String',
                         is_input => 1,
                         doc => 'The sff format sequence file to separate reads by primer',
                     },
        ],
};

sub help_brief {
    "tool to separate reads for 454"
}

sub help_detail {
    return <<EOS

EOS
}


sub execute {
    my $self = shift;

    my $sff_file_dirname = dirname($self->sff_file);
    my $sff_file_basename = basename($self->sff_file);
    $sff_file_basename =~ s/\.sff$//;

    #TODO: All intermediate files should be written to _tmp_dir

    my $out_sff_file = $self->_tmp_dir .'/'. $sff_file_basename .'_20bp.sff';
    #my $out_sff_file = $sff_file_dirname .'/'. $sff_file_basename .'_20bp.sff';

    my $cross_match_file = $self->_tmp_dir .'/'. $sff_file_basename .'_20bp.cm';
    #my $cross_match_file = $sff_file_dirname .'/'. $sff_file_basename .'_20bp.cm';

    my $isolate_primer = Genome::Model::Tools::454::IsolatePrimerTag->create(
                                                                             in_sff_file => $self->sff_file,
                                                                             out_sff_file => $out_sff_file,
                                                                         );
    unless ($isolate_primer->execute) {
        $self->error_message('Failed to execute '. $isolate_primer->command_name);
        return;
    }
    # For now this is hard coded
    # Ideally, we could pass a comma delimited list of primers and cat each individual fasta into a tmp fasta
    my $primer_fasta = '/gscmnt/sata180/info/medseq/biodb/shared/Vector_sequence/M13-MID1-MID2-primers.fasta';
    my $cross_match = Genome::Model::Tools::454::CrossMatchPrimerTag->create(
                                                                             cross_match_file => $cross_match_file,
                                                                             sff_file => $out_sff_file,
                                                                             primer_fasta => $primer_fasta,
                                                                         );
    unless ($cross_match->execute) {
        $self->error_message('Failed to execute '. $cross_match->command_name);
        return;
    }

    my $separate_reads = Genome::Model::Tools::454::SeparateReadsWithCrossMatchAlignment->create(
                                                                                                 cross_match_file => $cross_match_file,
                                                                                                 sff_file => $self->sff_file,
                                                                                             );
    unless ($separate_reads->execute) {
        $self->error_message('Failed to execute '. $separate_reads->command_name);
        return;
    }
    return 1;
}


1;

