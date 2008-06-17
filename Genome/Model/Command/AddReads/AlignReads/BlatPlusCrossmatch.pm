package Genome::Model::Command::AddReads::AlignReads::BlatPlusCrossmatch;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use Genome::Model::Command::AddReads::AlignReads;
use Genome::Model::Tools::Reads::454::SffInfo;

class Genome::Model::Command::AddReads::AlignReads::BlatPlusCrossmatch {
    is => [
        'Genome::Model::Command::AddReads::AlignReads',
    ],
    has => [
            sff_file => { via => "prior_event" },
            blat_version => {
                             is => 'string',
                             doc => "",
                             is_transient => 1,
                             is_optional =>1,
                         },
            blat_params => {
                            is => 'string',
                            doc => "",
                            is_transient => 1,
                            is_optional => 1,
                        },
            blat_aligner_output => {
                                    calculate_from => ['read_set_directory','read_set'],
                                    calculate => q|
                                        return $read_set_directory .'/'. $read_set->subset_name .'.blat.out';
                                    |
                                },
            cross_match_version => {
                                   is => 'string',
                                   doc => "",
                                   is_transient => 1,
                                   is_optional => 1,
                               },
            cross_match_params => {
                                  is => 'string',
                                  doc => "",
                                  is_transient => 1,
                                  is_optional => 1,
                              },
            cross_match_aligner_output => {
                                          calculate_from => ['read_set_directory','read_set'],
                                          calculate => q|
                                              return $read_set_directory .'/'. $read_set->subset_name .'.cross_match.out';
                                          |
                                      },
            fasta_file => {
                           is => 'string',
                           doc => "The path were the fasta file will be dumped",
                           calculate_from => ['read_set_directory','read_set'],
                           calculate => q|
                               return $read_set_directory .'/'. $read_set->subset_name .'.fna';
                           |,
                       },
        ],
};

sub help_brief {
    "Use blat plus cross_match to align reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads align-reads blat-plus-crossmatch --model-id 5 --run-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the add-reads process
EOS
}

sub should_bsub { 1;}

sub _parse_read_aligner_params {
    my $self = shift;
    my $regex = 'v([\w\.]+)\s*(.*)';

    my $params = $self->model->read_aligner_params;

    my @params = split(/;/,$params);
    my $blat_params = $params[0];
    my $cross_match_params = $params[1];

    if ($blat_params =~ /$regex/) {
        if ($1) {
            $self->blat_version($1);
        } else {
            $self->error_message("blat version not found in param string '$blat_params'");
            return;
        }
        $self->blat_params($2);
    } else {
        $self->error_message("blat params not recognized '$blat_params'");
        return;
    }

    if ($cross_match_params =~ /$regex/) {
        if ($1) {
            $self->cross_match_version($1);
        } else {
            $self->error_message("cross_match version not found in param string '$blat_params'");
            return;
        }
        $self->cross_match_params($2);
    } else {
        $self->error_message("cross_match params not recognized '$cross_match_params'");
        return;
    }

    return 1;
}


sub proper_blat_path {
    my $self = shift;

    unless ($self->blat_version) {
        unless ($self->_parse_read_aligner_params) {
            return;
        }
    }
    my $version = $self->blat_version;
    if ($version eq '32x1') {
        # This is not the path to version 32x1, but simply the installed app server version
        return '/gsc/bin/blat';
    } elsif ($version eq '2.0') {
        return '/blat/2_0';
    } else {
        $self->error_message("No blat path defined for version '$version'");
        return;
    }
}


sub proper_cross_match_path {
    my $self = shift;

    unless ($self->cross_match_version) {
        $self->_parse_read_aligner_params;
    }
    my $version = $self->cross_match_version;
    if ($version eq '0.990319') {
        # This is not the path to version 0.990319, but simply the installed app server version
        return '/gsc/bin/cross_match';
    } elsif ($version eq '1.080426') {
        # This is not the path to version 1.080426, but simply the installed app server test version
        return '/gsc/bin/cross_match.test';
    } else {
        $self->error_message("No cross_match path defined for version '$version'");
        return;
    }
}


sub execute {
    my $self = shift;

    $DB::single = 1;
    my $model = $self->model;
    my $read_set = $self->read_set;

    my $sffinfo = Genome::Model::Tools::Reads::454::SffInfo->create(
                                                                    sff_file => $self->sff_file,
                                                                    params => '-s',
                                                                    output_file => $self->fasta_file,
                                                                );
    unless ($sffinfo->execute) {
        $self->error_message('Can not convert sff '. $self->sff_file .' to fasta '. $self->fasta_file);
        return;
    }

    my $ref_seq_path = $model->reference_sequence_path .'/all_sequences.fa';

    my $blat_path = $self->proper_blat_path;
    my $blat_params = $self->blat_params || '' ;
    my $out_psl = $self->read_set_directory .'/'. $read_set->id .'.psl';
    my $blat_cmd = $blat_path .' '. $blat_params.' '. $ref_seq_path .' '. $self->fasta_file .' '.
        $out_psl . ' > '. $self->blat_aligner_output .' 2>&1';
    $self->status_message('Running '. $blat_cmd ."\n");
    my $blat_rv = system($blat_cmd);
    unless ($blat_rv == 0) {
        $self->error_message("non-zero exit code '$blat_rv' from '$blat_cmd'");
        return;
    }

    my $cross_match_path = $self->proper_cross_match_path;
    my $cross_match_params = $self->cross_match_params || '';
    my $cm_cmd = $cross_match_path .' '. $cross_match_params .' '. $self->fasta_file  .' '. $ref_seq_path .' > '.
        $self->cross_match_aligner_output .' 2>&1';
    $self->status_message('Running '. $cm_cmd ."\n");
    my $cm_rv = system($cm_cmd);
    unless ($cm_rv == 0) {
        $self->error_message("non-zero exit code '$cm_rv' from '$cm_cmd'");
        return;
    }

    return 1;
}


sub verify_successful_completion {
    my ($self) = @_;

    return 1;
}


1;

