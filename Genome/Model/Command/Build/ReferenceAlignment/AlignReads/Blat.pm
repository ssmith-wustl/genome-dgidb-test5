package Genome::Model::Command::AddReads::AlignReads::Blat;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;
use Genome::Model::Command::AddReads::AlignReads;
use Genome::Utility::PSL::Writer;
use Genome::Utility::PSL::Reader;
use File::Basename;

class Genome::Model::Command::AddReads::AlignReads::Blat {
    is => [
        'Genome::Model::Command::AddReads::AlignReads',
    ],
    has => [
            fasta_file => {
                           doc => 'the file path to the fasta file of reads',
                           calculate_from => ['read_set_directory','read_set'],
                           calculate => q|
                               return $read_set_directory .'/'. $read_set->subset_name .'.fa';
                           |
                       },
            _alignment_files =>{
                               doc => "the file path to store the blat alignment",
                               calculate_from => ['new_read_set_alignment_directory','read_set'],
                               calculate => q|
                                        return grep { -e $_ } glob($new_read_set_alignment_directory .'/'. $read_set->subset_name .'.psl.*');
                               |
                           },
            _aligner_output_files => {
                                     calculate_from => ['new_read_set_alignment_directory','read_set'],
                                     calculate => q|
                                                  return grep { -e $_ } glob($new_read_set_alignment_directory .'/'. $read_set->subset_name .'.out.*');
                                             |
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


sub proper_blat_path {
    my $self = shift;
    return '/gsc/bin/blat';
}

sub alignment_file {
    my $self = shift;

    my @alignment_files = $self->_alignment_files;
    unless (@alignment_files) {
        $self->error_message('Missing alignment file');
        return;
    }
    if (scalar(@alignment_files) > 1) {
        die(scalar(@alignment_files) .' alignment files found for '. $self->id);
    }
    return $alignment_files[0];
}

sub aligner_output_file {
    my $self = shift;
    my @aligner_output_files = $self->_aligner_output_files;
    unless (@aligner_output_files) {
        $self->error_message('Missing aligner output file');
        return;
    }
    if (scalar(@aligner_output_files) > 1) {
        die(scalar(@aligner_output_files) .' aligner output files found for '. $self->id);
    }
    return $aligner_output_files[0];
}

sub read_set_alignment_file {
    my $self = shift;
    return $self->new_read_set_alignment_directory .'/'. $self->read_set->subset_name .'.psl.'. $self->id;
}

sub read_set_aligner_output_file {
    my $self = shift;
    return $self->new_read_set_alignment_directory .'/'. $self->read_set->subset_name .'.out.'. $self->id;
}

sub read_set_aligner_error_file {
    my $self = shift;
    return $self->new_read_set_alignment_directory .'/'. $self->read_set->subset_name .'.err.'. $self->id;
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;
    $self->create_directory($self->read_set_directory);
    unless (-s $self->fasta_file) {
        unless($self->read_set->run_region_454->dump_library_region_fasta_file(filename => $self->fasta_file)) {
            $self->error_message('Failed to dump fasta file to '. $self->fasta_file .' for event '. $self->id);
            return;
        }
    }
    
    # check_for_existing_alignment_files
    my $read_set_alignment_directory = $self->new_read_set_alignment_directory;
    if (-d $read_set_alignment_directory) {
        my $errors;
        $self->status_message("found existing run directory $read_set_alignment_directory");
        my $alignment_file = $self->alignment_file;
        my $aligner_output_file = $self->aligner_output_file;
        unless (-s $alignment_file && -s $aligner_output_file) {
            $self->warning_message("RE-PROCESSING: Moving old directory out of the way");
            unless (rename ($read_set_alignment_directory,$read_set_alignment_directory . ".old.$$")) {
                die "Failed to move old alignment directory out of the way: $!";
            }
            # fall through to the regular processing and try this again...
        } else {
            $self->status_message("SHORTCUT SUCCESS: alignment data is already present.");
            return 1;
        }
    }
    $self->create_directory($read_set_alignment_directory);

    my $model = $self->model;
    my @ref_seq_paths = grep {$_ !~ /all_sequences/ } $model->get_subreference_paths(reference_extension => 'fa');

    my $blat_path = $self->proper_blat_path;
    my $blat_params = '-mask=lower -out=pslx -noHead';
    $blat_params .= $model->read_aligner_params || '';

    my %jobs;
    my @psl_to_cat;
    my @out_to_cat;
    my @err_to_cat;
    for my $ref_seq_path (@ref_seq_paths) {
        my $ref_seq_name = basename($ref_seq_path);
        $ref_seq_name =~ s/\.fa//;

        my $psl_file = $self->read_set_alignment_file .'_'. $ref_seq_name;
        my $out_file = $self->read_set_aligner_output_file .'_'. $ref_seq_name;
        my $err_file = $self->read_set_aligner_error_file .'_'. $ref_seq_name;

        push @psl_to_cat, $psl_file;
        push @out_to_cat, $out_file;
        push @err_to_cat, $err_file;

        my $blat_cmd = $blat_path .' '. $blat_params.' '. $ref_seq_path .' '. $self->fasta_file .' '.
            $psl_file;

        my $job = PP::LSF->create(
                                  pp_type => 'lsf',
                                  q => 'long',
                                  command => $blat_cmd,
                                  o => $out_file,
                                  e => $err_file,
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
    unless ($self->_cat_alignment_files(@psl_to_cat)) {
        $self->error_message("Failed to cat psl blat alignments");
        return;
    }
    unless ($self->_cat_aligner_output_files(@out_to_cat)) {
        $self->error_message("Failed to cat blat output");
        return;
    }
    unless ($self->_cat_aligner_error_files(@err_to_cat)) {
        $self->error_message("Failed to cat blat error");
        return;
    }
    my @to_remove;
    push @to_remove, @psl_to_cat, @out_to_cat, @err_to_cat;
    for (@to_remove) {
        unless (unlink($_)) {
            $self->error_message("Failed to remove file '$_'");
        }
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

sub _cat_alignment_files {
    my $self = shift;
    my @files = @_;

    my $out_file = $self->read_set_alignment_file;
    if (-s $out_file) {
        $self->error_message("File already exists '$out_file'");
        return;
    }
    my $writer = Genome::Utility::PSL::Writer->create(
                                                      file => $out_file,
                                                  );
    for my $file (@files) {
        my $reader = Genome::Utility::PSL::Reader->create(
                                                          file => $file,
                                                      );
        unless ($reader) {
            $self->error_message("Failed to read file '$file'");
            return;
        }
        while (my $record = $reader->next) {
            $writer->write_record($record);
        }
        $reader->close
    }
    $writer->close;
    return 1;
}

sub _cat_aligner_output_files {
    my $self = shift;
    my @files = @_;

    my $out_file = $self->read_set_aligner_output_file;
    return $self->_cat_files($out_file,@files);
}

sub _cat_aligner_error_files {
    my $self = shift;
    my @files = @_;

    my $out_file = $self->read_set_aligner_error_file;
    return $self->_cat_files($out_file,@files);
}

sub _cat_files {
    my $self = shift;
    my $out_file = shift;
    my @files = @_;

    if (-s $out_file) {
        $self->error_message("File already exists '$out_file'");
        return;
    }

    my $out_fh = IO::File->new($out_file,'w');
    unless ($out_fh) {
        $self->error_message("File will not open with write priveleges '$out_file'");
        return;
    }
    for my $in_file (@files) {
        my $in_fh = IO::File->new($in_file,'r');
        unless ($in_fh) {
            $self->error_message("File will not open with read priveleges '$in_file'");
            return;
        }
        while (my $line = $in_fh->getline()) {
            $out_fh->print($line);
        }
    }
    $out_fh->close();
    return 1;
}

sub verify_successful_completion {
    my $self = shift;

    unless (-s $self->alignment_file && -s $self->aligner_output_file) {
        $self->error_message("Failed to verify successfule completion of event ". $self->id);
        return;
    }
    return 1;
}


1;

