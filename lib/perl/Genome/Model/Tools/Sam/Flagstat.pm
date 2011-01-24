package Genome::Model::Tools::Sam::Flagstat;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sam::Flagstat {
    is => 'Genome::Model::Tools::Sam',
    has => [
        bam_file => { },
        output_file => { },
        include_stderr => { is => 'Boolean', is_optional => 1, default_value => 0, doc => 'Include any error output from flagstat in the output file.'}
    ],
};

sub execute {
    my $self = shift;
    my $stderr_redirector = $self->include_stderr ? ' 2>&1 ' : '';
    my $cmd = $self->samtools_path .' flagstat '. $self->bam_file .' > '. $self->output_file . $stderr_redirector;
    Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file],
        output_files => [$self->output_file],
    );
    return 1;
}

sub parse_file_into_hashref {
    my ($class, $flag_file) = @_;

    unless ($flag_file and -s $flag_file) {
        warn "Bam flagstat file: $flag_file is not valid";
        return;
    }

    my $flag_fh = Genome::Sys->open_file_for_reading($flag_file);
    unless($flag_fh) {
        warn 'Fail to open ' . $flag_file . ' for reading';
        return;
    }
    
    my %data;
    my @lines = <$flag_fh>;
    
    for (@lines){
        chomp $_;
    }
    
    while (scalar @lines and $lines[0] =~ /^\[.*\]/){
        push @{ $data{errors} }, shift @lines;
    }

    unless (scalar @lines == 12) {
        warn 'Unexpected output from flagstat. Check ' . $flag_file;
        return;
    }

    my ($total, $qc_failure, $duplicates, $mapped, $paired, $read1, $read2, $properly_paired, $mate_mapped, $singletons, $mate_different, $mate_different_hq) = @lines;
    
    ($data{total_reads})             = $total      =~ /^(\d+) in total$/;
    ($data{reads_marked_failing_qc}) = $qc_failure =~ /^(\d+) QC failure$/;
    ($data{reads_marked_duplicates}) = $duplicates =~ /^(\d+) duplicates$/;
    
    ($data{reads_mapped}, $data{reads_mapped_percentage}) =
        $mapped =~ /^(\d+) mapped \((\d{1,3}\.\d{2}|nan)\%\)$/;
    undef($data{reads_mapped_percentage}) if $data{reads_mapped_percentage} eq 'nan';
    
    ($data{reads_paired_in_sequencing}) = $paired =~ /^(\d+) paired in sequencing$/;
    ($data{reads_marked_as_read1})      = $read1  =~ /^(\d+) read1$/;
    ($data{reads_marked_as_read2})      = $read2  =~ /^(\d+) read2$/;
    
    ($data{reads_mapped_in_proper_pairs}, $data{reads_mapped_in_proper_pairs_percentage}) =
        $properly_paired =~ /^(\d+) properly paired \((\d{1,3}\.\d{2}|nan)\%\)$/;
    undef($data{reads_mapped_in_proper_pairs_percentage}) if $data{reads_mapped_in_proper_pairs_percentage} eq 'nan';
    
    ($data{reads_mapped_in_pair}) = $mate_mapped =~ /^(\d+) with itself and mate mapped$/;
    
    ($data{reads_mapped_as_singleton}, $data{reads_mapped_as_singleton_percentage}) =
        $singletons =~ /^(\d+) singletons \((\d{1,3}\.\d{2}|nan)\%\)$/;
    undef($data{reads_mapped_as_singleton_percentage}) if $data{reads_mapped_as_singleton_percentage} eq 'nan';
    
    ($data{reads_mapped_in_interchromosomal_pairs})    = $mate_different    =~ /^(\d+) with mate mapped to a different chr$/;
    ($data{hq_reads_mapped_in_interchromosomal_pairs}) = $mate_different_hq =~ /^(\d+) with mate mapped to a different chr \(mapQ>=5\)$/;
    
    $flag_fh->close;
    return \%data;
}
