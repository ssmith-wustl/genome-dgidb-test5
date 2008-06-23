package Genome::Model::Command::AddReads::AlignReads::Blat;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use Genome::Model::Command::AddReads::AlignReads;
use Genome::Model::Tools::Reads::454::SffInfo;
use File::Basename;

class Genome::Model::Command::AddReads::AlignReads::Blat {
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
            alignment_file => {
                            calculate_from => ['read_set_directory','read_set'],
                            calculate => q|
                                        return $read_set_directory .'/'. $read_set->subset_name .'.psl';
                            |
                        },
            aligner_output_file => {
                                    calculate_from => ['read_set_directory','read_set'],
                                    calculate => q|
                                        return $read_set_directory .'/'. $read_set->subset_name .'.out';
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
    "Use blat plus to align reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads align-reads blat --model-id 5 --run-id 10
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

    if ($params =~ /$regex/) {
        if ($1) {
            $self->blat_version($1);
        } else {
            $self->error_message("blat version not found in param string '$params'");
            return;
        }
        $self->blat_params($2);
    } else {
        $self->error_message("blat params not recognized '$params'");
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

sub execute {
    my $self = shift;

    $DB::single = 1;
    my $model = $self->model;
    my $read_set = $self->read_set;

    my $alignment_file = $self->alignment_file;
    if (-s $alignment_file) {
        $self->error_message("Alignment file '$alignment_file' already exists.");
        return;
    }

    my $sffinfo = Genome::Model::Tools::Reads::454::SffInfo->create(
                                                                    sff_file => $self->sff_file,
                                                                    params => '-s',
                                                                    output_file => $self->fasta_file,
                                                                );
    unless ($sffinfo->execute) {
        $self->error_message('Can not convert sff '. $self->sff_file .' to fasta '. $self->fasta_file);
        return;
    }

    my $ext = 'fa';
    my @ref_seq_paths = grep {$_ !~ /all_sequences\.$ext$/ } $model->get_subreference_paths(reference_extension => $ext);

    my $blat_path = $self->proper_blat_path;
    my $blat_params = $self->blat_params || '' ;

    my %jobs;
    my @psls_to_cat;
    my @blat_to_cat;
    for my $ref_seq_path (@ref_seq_paths) {
        my $ref_seq_name = basename($ref_seq_path);
        $ref_seq_name =~ s/\.$ext//;

        my $ref_seq_psl = $self->alignment_file .'_'. $ref_seq_name;
        push @psls_to_cat, $ref_seq_psl;

        my $ref_seq_output = $self->aligner_output_file .'_'. $ref_seq_name;
        push @blat_to_cat, $ref_seq_output;

        my $blat_cmd = $blat_path .' '. $blat_params.' '. $ref_seq_path .' '. $self->fasta_file .' '.
            $ref_seq_psl;

        my $job = PP::LSF->create(
                                  pp_type => 'lsf',
                                  queue => 'long',
                                  command => $blat_cmd,
                                  output => $ref_seq_output,
                              );
        unless ($job) {
            $self->error_message("Failed to create job for '$blat_cmd'");
            return;
        }
        my $id = $job->id;
        $jobs{$id} = $job;
    }

    for my $job_id (keys %jobs) {
        my $job = $jobs{$job_id};
        $self->status_message('starting '. $job->id  .' bsub_cmd:'. $job->bsub_cmd);
        unless ($job->start) {
            $self->error_message('failed to start '. $job->id  .' bsub_cmd:'. $job->bsub_cmd);
            return;
        }
    }
  MONITOR: while ( %jobs ) {
        sleep 30;
        for my $job_id ( keys %jobs ) {
            my $job = $jobs{$job_id};
            if ( $job->has_ended ) {
                if ( $job->has_ended ) {
                    if ( $job->is_successful ) {
                        $self->status_message("$job_id successful");
                        delete $jobs{$job_id};
                    } else {
                        $self->status_message("$job_id failed\n");
                        $self->_kill_jobs(values %jobs);
                        last MONITOR;
                    }
                }
            }
        }
    }
    unless ($self->_cat_files($self->alignment_file,@psls_to_cat)) {
        $self->error_message("Failed to cat psl blat alignments");
        return;
    }
    unless ($self->_cat_files($self->aligner_output_file,@blat_to_cat)) {
        $self->error_message("Failed to cat blat output");
        return;
    }

    my @to_remove;
    push @to_remove, @psls_to_cat;
    push @to_remove, @blat_to_cat;
    for my $file_to_remove (@to_remove) {
        unlink $file_to_remove || $self->error_message("Failed to remove $file_to_remove");
    }
    return 1;
}


sub _kill_jobs {
    my $self = shift;
    my @jobs = @_;
    for my $job ( @jobs ) {
        next if $job->has_ended;
        $job->kill;
    }
    return 1;
}

sub _cat_files {
    my $self = shift;
    my $out_file = shift;
    my @files = @_;

    if (-s $out_file) {
        $self->error_message("File already exists '$out_file'");
        return;
    }

    for my $file (@files) {
        my $rv = system sprintf('cat %s >> %s', $file, $out_file);
        unless ($rv == 0) {
            $self->error_message("Failed to cat '$file' onto '$out_file'");
            return;
        }
    }
    return 1;
}

sub verify_successful_completion {
    my ($self) = @_;

    return 1;
}


1;

