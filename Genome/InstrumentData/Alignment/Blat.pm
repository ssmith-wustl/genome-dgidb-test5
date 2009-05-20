package Genome::InstrumentData::Alignment::Blat;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Alignment::Blat {
    is => ['Genome::InstrumentData::Alignment'],
    has_constant => [
        aligner_name => { value => 'blat' },
    ],
};

sub find_or_generate_alignment_data {
    my $self = shift;

    my $lock = $self->lock_alignment_resource;
    unless ($self->verify_alignment_data) {
        $self->_run_aligner;
    } else {
        $self->status_message("Existing alignment data is available and deemed correct.");
    }
    unless ($self->unlock_alignment_resource) {
        $self->error_message('Failed to unlock alignment resource '. $self->_lock);
        return;
    }
    return 1;
}

sub _run_aligner {
    my $self = shift;

    my $instrument_data = $self->instrument_data;
    my $reference_build = $self->reference_build;
    my $alignment_directory = $self->alignment_directory;

    my @ref_seq_paths = grep {$_ !~ /all_sequences/ } $reference_build->subreference_paths(reference_extension => 'fa');
    unless (scalar(@ref_seq_paths)) {
        $self->error_message('No reference sequences found: '. $reference_build->full_consensus_path('fa'));
        $self->die_and_clean_up($self->error_message);
    }

    my $blat_params = '-mask=lower -out=pslx -noHead';
    $blat_params .= $self->aligner_params || '';

    my %params = (
                  query_file => $instrument_data->fasta_file,
                  subject_files => \@ref_seq_paths,
                  blat_params => $blat_params,
                  psl_path => $self->instrument_data_alignment_file,
                  blat_output_path => $self->instrument_data_aligner_output_file,
              );
    $self->status_message("Running aligner with params:\n". Data::Dumper::Dumper(%params));
    unless (Genome::Model::Tools::Blat::Subjects->execute(%params)) {
        $self->error_message('Failed to execute blat subjects with params:  '. %params);
        $self->die_and_clean_up($self->error_message);
    }
    return 1;

}

sub output_files {
    my $self = shift;

    my @files;
    push @files, $self->alignment_files;
    push @files, $self->aligner_output_files;
    return @files;
};

sub instrument_data_alignment_file {
    my $self = shift;
    my $instrument_data = $self->instrument_data;
    return $self->alignment_directory .'/'. $instrument_data->subset_name .'.psl';
}

sub instrument_data_aligner_output_file {
    my $self = shift;
    my $instrument_data = $self->instrument_data;
    return $self->alignment_directory .'/'. $instrument_data->subset_name .'.out';
}

sub alignment_files {
    my $self = shift;

    my $instrument_data = $self->instrument_data;
    my @alignment_files = grep { -e $_ } glob($self->alignment_directory .'/'. $instrument_data->subset_name .'.psl*');
    return @alignment_files;
}

sub alignment_file {
    my $self = shift;
    my @alignment_files = $self->alignment_files;
    unless (@alignment_files) {
        $self->status_message('Alignment file not found.');
        return;
    }
    if (scalar(@alignment_files) > 1) {
        $self->die_and_clean_up(scalar(@alignment_files) .' alignment files found.');
    }
    return $alignment_files[0];
}

sub aligner_output_files {
    my $self = shift;
    my $instrument_data = $self->instrument_data;
    my @aligner_output_files = grep { -e $_ } glob($self->alignment_directory .'/'. $instrument_data->subset_name .'.out*');
    return @aligner_output_files;
}


sub aligner_output_file {
    my $self = shift;
    my @aligner_output_files = $self->aligner_output_files;
    unless (@aligner_output_files) {
        $self->status_message('Aligner output file not found.');
        return;
    }
    if (scalar(@aligner_output_files) > 1) {
        $self->die_and_clean_up(scalar(@aligner_output_files) .' aligner output files found.');
    }
    return $aligner_output_files[0];
}

sub verify_alignment_data {
    my $self = shift;

    my $alignment_dir = $self->alignment_directory;
    return unless $alignment_dir;
    return unless -d $alignment_dir;

    unless ($self->output_files) {
        $self->status_message('No output files found in alignment directory: '. $alignment_dir);
        return;
    }
    my $errors;
    unless ($self->alignment_file) {
        $errors++
    }
    unless (-s $self->alignment_file) {
        $self->error_message('Alignment file has zero size: '. $self->alignment_file);
        $errors++;
    }
    unless ($self->aligner_output_file) {
        $errors++;
    }
    unless (-s $self->aligner_output_file) {
        $self->error_message('Aligner output file has zero size: '. $self->aligner_output_file);
        $errors++;
    }
    #TODO: test the aligner output files for completion
    if ($errors) {
        my @output_files = $self->output_files;
        if (@output_files) {
            my $msg = 'REFUSING TO CONTINUE with files in place in alignment directory:' ."\n";
            $msg .= join("\n",@output_files) ."\n";
            $self->die_and_clean_up($msg);
        }
        return;
    }
    $self->status_message('Alignment data verified: '. $alignment_dir);
    return 1;
}

1;

