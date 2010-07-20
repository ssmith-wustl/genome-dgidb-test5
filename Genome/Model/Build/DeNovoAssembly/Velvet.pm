package Genome::Model::Build::DeNovoAssembly::Velvet;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Build::DeNovoAssembly::Velvet {
    is => 'Genome::Model::Build::DeNovoAssembly',
};

#< Files / Dirs >#
sub collated_fastq_file {
    return $_[0]->data_directory.'/collated.fastq';
}

sub assembly_afg_file {
    return $_[0]->data_directory.'/velvet_asm.afg';
}

sub contigs_fasta_file {
    return $_[0]->data_directory.'/contigs.fa';
}

sub sequences_file {
    return $_[0]->data_directory.'/Sequences';
}

sub velvet_fastq_file {
    return $_[0]->data_directory.'/velvet.fastq';
}

sub velvet_ace_file {
    return $_[0]->data_directory.'/edit_dir/velvet_asm.ace';
}

sub stats_file { 
    return $_[0]->edit_dir.'/stats.txt';
}
sub edit_dir {
    return $_[0]->data_directory.'/edit_dir';
}

sub ace_file {
    return $_[0]->edit_dir.'/velvet_asm.ace';
}

sub gap_file {
    return $_[0]->edit_dir.'/gap.txt';
}

sub contigs_bases_file {
    return $_[0]->edit_dir.'/contigs.bases';
}

sub contigs_quals_file {
    return $_[0]->edit_dir.'/contigs.quals';
}

sub read_info_file {
    return $_[0]->edit_dir.'/readinfo.txt';
}

sub reads_placed_file {
    return $_[0]->edit_dir.'/reads.placed';
}

sub supercontigs_agp_file {
    return $_[0]->edit_dir.'/supercontigs.agp';
}

sub supercontigs_fasta_file {
    return $_[0]->edit_dir.'/supercontigs.fasta';
}

sub assembly_fasta_file {
    return contigs_bases_file(@_);
}
#<>#

#< Metrics >#
sub set_metrics {
    my  $self = shift;

    my $stats_file = $self->stats_file;
    my $stats_fh = Genome::Utility::FileSystem->open_file_for_reading($stats_file);
    unless ( $stats_fh ) {
        $self->error_message("Can't set metrics because can't open stats file ($stats_file).");
        return;
    }
    
    my @interesting_metric_names = $self->interesting_metric_names;

    #more meaningful metric names look up
    my $meaningful_names = $self->meaningful_metric_names;

    my %metrics;
    while ( my $line = $stats_fh->getline ) {
        next unless $line =~ /\:/;
        chomp $line;
        my ($metric, $value) = split(/\:\s+/, $line);
        $metric = lc $metric;
        next unless grep { $metric eq $_ } @interesting_metric_names;
        $value =~ s/\s.*$//;
        unless ( defined $value ) {
            $self->error_message("Found metric ($metric) in stats file, but it does not have a vlue ($line)");
            return;
        }
        my $metric_method = join('_', split(/\s/, $metric));
        $self->$metric_method($value);

	#return the more meaning fule name
	$metric_method = (exists $meaningful_names->{$metric_method}) ? $meaningful_names->{$metric_method} : $metric_method;

        $metrics{$metric_method} = $value;
    }

    return %metrics;
}

#<>#

1;

#$HeadURL$
#$Id$
