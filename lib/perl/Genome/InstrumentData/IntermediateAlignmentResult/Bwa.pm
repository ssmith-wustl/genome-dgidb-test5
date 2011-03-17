package Genome::InstrumentData::IntermediateAlignmentResult::Bwa;

use Genome;
use File::Copy qw/mv/;
use File::Basename;
use File::Slurp qw/read_file/;
use Carp qw/confess/;

use warnings;
use strict;

class Genome::InstrumentData::IntermediateAlignmentResult::Bwa {
    is=>['Genome::InstrumentData::IntermediateAlignmentResult']
};

sub output_file_prefix {
    my $self = shift;
    my $prefix = basename($self->input_file);
    my $input_pass = $self->input_pass || '';
    $prefix .= ".$input_pass" if defined $input_pass;
    return $prefix;
}

sub sai_file {
    my $self = shift;
    return $self->output_dir.'/'.$self->output_file_prefix.".sai";
}

sub log_file {
    my $self = shift;
    return $self->output_dir.'/'.$self->output_file_prefix.".log";
}

sub md5sum {
    my $self = shift;
    my $path = $self->output_dir.'/'.$self->output_file_prefix . '.sai.md5';
    return read_file($path);
}

sub _run_aligner {
    my $self = shift;

    my $fasta_file = $self->aligner_index->full_consensus_path('fa');
    my $tmp_dir = $self->temp_scratch_directory;

    my $bam_flag;
    if ($self->input_file =~ /\.bam/) {
        $bam_flag = "-b" . ($self->input_pass||'');
    }

    my $output_file_prefix = $self->output_file_prefix;
    my $sai_file = "$tmp_dir/$output_file_prefix.sai";
    my $log_file = "$tmp_dir/$output_file_prefix.log";

    my $bwa = Genome::Model::Tools::Bwa->path_for_bwa_version($self->aligner_version);

    my @args = (
        "aln", 
        $self->aligner_params,
        $bam_flag,
        $fasta_file,
        $self->input_file,
        "1> $sai_file 2>> $log_file"
    );

    my $cmd = join(" ", $bwa, @args);

    # disconnect the db handle before this long-running event
    if (Genome::DataSource::GMSchema->has_default_handle) {
        $self->status_message("Disconnecting GMSchema default handle.");
        Genome::DataSource::GMSchema->disconnect_default_dbh();
    }

    Genome::Sys->shellcmd(
        cmd          => $cmd,
        input_files  => [ $fasta_file, $self->input_file ],
        output_files => [ $sai_file, $log_file ],
        skip_if_output_is_present => 0,
    );

    unless ($self->_verify_bwa_aln_did_happen(sai_file => $sai_file, log_file => $log_file)) {
        die $self->error_message("bwa aln did not seem to successfully take place for " . $fasta_file);
    }

    my $sai_bytes = -s $sai_file;
    $self->status_message("Created $sai_file ($sai_bytes bytes)");

    my $md5_file = $self->_create_md5($sai_file);
    unless($md5_file) {
        die $self->error_message("Failed to create md5 file for sai file $sai_file");
    }

    $self->_promote_to_staging($sai_file, $log_file, $md5_file);
}

# TODO: put this somewhere else, maybe SR::Stageable
sub _create_md5 {
    my ($self, $file) = @_;

    my $md5_file = "$file.md5";
    my $cmd      = "md5sum $file > $md5_file";

    my $rv  = Genome::Sys->shellcmd(
        cmd                        => $cmd, 
        input_files                => [$file],
        output_files               => [$md5_file],
        skip_if_output_is_present  => 0,
    ); 
    $self->error_message("Fail to run: $cmd") and return unless $rv == 1;
    return $md5_file;
}

sub _promote_to_staging {
    my ($self, @files) = @_;
    for my $f (@files) {
        mv($f, $self->temp_staging_directory);
    }
}

sub _verify_bwa_aln_did_happen {
    my $self = shift;
    my %p = @_;

    unless (-e $p{sai_file} && -s $p{sai_file}) {
        $self->error_message("Expected SAI file is $p{sai_file} nonexistent or zero length.");
        return;
    } 
    
    unless ($self->_inspect_log_file(log_file=>$p{log_file},
                                     log_regex=>'(\d+) sequences have been processed')) {
        
        $self->error_message("Expected to see 'X sequences have been processed' in the log file where 'X' must be a nonzero number.");
        return;
    }
    
    return 1;
}

sub _inspect_log_file {
    my $self = shift;
    my %p = @_;

    my $log_file = $p{log_file};
    unless ($log_file and -s $log_file) {
        $self->error_message("log file $log_file is not valid");
        return;
    }

    my $last_line = `tail -1 $log_file`;    
    my $check_nonzero = 0;
    
    my $log_regex = $p{log_regex};
    if ($log_regex =~ m/\(\\d\+\)/) {
        $check_nonzero = 1;
    }

    if ($last_line =~ m/$log_regex/) {
        if ( !$check_nonzero || $1 > 0 ) {
            $self->status_message('The last line of aligner.log matches the expected pattern');
            return 1;
        }
    }
    
    $self->error_message("The last line of $log_file is not valid: $last_line");
    return;
}


1;
