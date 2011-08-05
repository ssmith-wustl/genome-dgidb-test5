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
    $flag_fh->close;
    my $line_ct = scalar @lines;
            
    while ($line_ct and $lines[0] =~ /^\[.*\]/){
        push @{ $data{errors} }, shift @lines;
    }

    unless ($line_ct =~ /^1[12]$/) {#samtools 0.1.15 (r949), older versions get 12 lines, newer get 11 line with QC passed/failed separate in each line
        warn 'Unexpected output from flagstat. Check ' . $flag_file;
        return;
    }

   for (@lines) {
        chomp;
        $data{total_reads}             = $1 if /^(\d+) (\+\s\d+\s)?in total/;
        $data{reads_marked_failing_qc} = $1 if /^\d+ \+ (\d+) in total/;
        $data{reads_marked_failing_qc} = $1 if /^(\d+) QC failure/;
        $data{reads_marked_duplicates} = $1 if /^(\d+) (\+\s\d+\s)?duplicates$/;
        ($data{reads_mapped}, $data{reads_mapped_percentage}) = ($1, $3)
            if /^(\d+) (\+\s\d+\s)?mapped \((\d{1,3}\.\d{2}|nan)\%[\:\)]/;
        undef($data{reads_mapped_percentage}) 
            if $data{reads_mapped_percentage} && $data{reads_mapped_percentage} eq 'nan';

        $data{reads_paired_in_sequencing} = $1 if /^(\d+) (\+\s\d+\s)?paired in sequencing$/;
        $data{reads_marked_as_read1}      = $1 if /^(\d+) (\+\s\d+\s)?read1$/;
        $data{reads_marked_as_read2}      = $1 if /^(\d+) (\+\s\d+\s)?read2$/;

        ($data{reads_mapped_in_proper_pairs}, $data{reads_mapped_in_proper_pairs_percentage}) = ($1, $3)
            if /^(\d+) (\+\s\d+\s)?properly paired \((\d{1,3}\.\d{2}|nan)\%[\:\)]/;
        undef($data{reads_mapped_in_proper_pairs_percentage}) 
            if $data{reads_mapped_in_proper_pairs_percentage} && $data{reads_mapped_in_proper_pairs_percentage} eq 'nan';

        $data{reads_mapped_in_pair} = $1 if /^(\d+) (\+\s\d+\s)?with itself and mate mapped$/;

        ($data{reads_mapped_as_singleton}, $data{reads_mapped_as_singleton_percentage}) = ($1, $3)
            if /^(\d+) (\+\s\d+\s)?singletons \((\d{1,3}\.\d{2}|nan)\%[\:\)]/;
        undef($data{reads_mapped_as_singleton_percentage}) 
            if $data{reads_mapped_as_singleton_percentage} && $data{reads_mapped_as_singleton_percentage} eq 'nan';

        $data{reads_mapped_in_interchromosomal_pairs}    = $1 if /^(\d+) (\+\s\d+\s)?with mate mapped to a different chr$/;
        $data{hq_reads_mapped_in_interchromosomal_pairs} = $1 if /^(\d+) (\+\s\d+\s)?with mate mapped to a different chr \(mapQ>=5\)$/;
    }

    return \%data;
}


