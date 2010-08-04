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
sub calculate_metrics {
    my  $self = shift;

    my $stats_file = $self->stats_file;
    my $stats_fh = Genome::Utility::FileSystem->open_file_for_reading($stats_file);
    unless ( $stats_fh ) {
        $self->error_message("Can't set metrics because can't open stats file ($stats_file).");
        return;
    }
    
    my %stat_to_metric_names = ( # old names to new
        # contig
        'total contig number' => 'contigs',
        'n50 contig length' => 'median_contig_length',
        'major_contig n50 contig length' => 'median_contig_length_gt_500',			 
        'average contig length' => 'average_contig_length',
        'major_contig avg contig length' => 'average_contig_length_gt_500',			 
        # supercontig
        'total supercontig number' => 'supercontigs',
        'n50 supercontig length' => 'median_supercontig_length',
        'major_supercontig n50 contig length' => 'median_supercontig_length_gt_500',
        'average supercontig length' => 'average_supercontig_length',
        'major_supercontig avg contig length' => 'average_supercontig_length_gt_500',
        # reads
        'total input reads' => 'reads_processed',
        'placed reads' => 'reads_assembled',
        'chaff rate' => 'reads_not_assembled_pct',
        'average read length' => 'average_read_length',
        # bases
        'total contig bases' => 'assembly_length',
	# read depths			 
	'depth >= 5' => 'read_depths_ge_5x',
    );

    my %metrics;
    while ( my $line = $stats_fh->getline ) {
        next unless $line =~ /\:/;
        chomp $line;
        my ($stat, $values) = split(/\:\s+/, $line);
        $stat = lc $stat;
        next unless grep { $stat eq $_ } keys %stat_to_metric_names;

	unless ( defined $values ) {
            $self->error_message("Found '$stat' in stats file, but it does not have a value on line ($line)");
            return;
        }
	my @tmp = split (/\s+/, $values);

	#in most value we want is $tmp[0]
	my $value = $tmp[0];

	# need value other than $temp[1[;
	if ($stat eq 'depth >= 5') {
	    unless (defined $tmp[1]) {
		$self->error_message("Failed to derive >= 5x depth from line: $values\n\t".
				     "Expected line like: 3760	0.0105987146239711");
		return;
	    }
	    $value = $tmp[1];#sprintf("%.1f", $tmp[1] * 100);
	}

	my $metric = delete $stat_to_metric_names{$stat};
        $metrics{$metric} = $value;
    }

    if ( %stat_to_metric_names ) {
        $self->error_message(
            'Missing these metrics ('.join(', ', keys %stat_to_metric_names).') in stats file ($stats_file)'
        );
        return;
    }

    $metrics{reads_not_assembled_pct} =~ s/%//;
    $metrics{reads_not_assembled_pct} = sprintf('%0.3f', $metrics{reads_not_assembled_pct} / 100);

    $metrics{reads_attempted} = $self->calculate_reads_attempted
        or return; # error in sub
    $metrics{reads_processed_success} =  sprintf(
        '%0.3f', $metrics{reads_processed} / $metrics{reads_attempted}
    );
    $metrics{reads_assembled_success} = sprintf(
        '%0.3f', $metrics{reads_assembled} / $metrics{reads_processed}
    );
    $metrics{read_depths_ge_5x} = sprintf ('%0.1f', $metrics{read_depths_ge_5x} * 100);

    return %metrics;
}

# Old metrics
sub total_contig_number { return $_[0]->contigs; }
sub n50_contig_length { return $_[0]->median_contig_length; }
sub total_supercontig_number { return $_[0]->supercontigs; }
sub n50_supercontig_length { return $_[0]->median_supercontig_length; }
sub total_input_reads { return $_[0]->reads_processed; }
sub placed_reads { return $_[0]->reads_assembled; }
sub chaff_rate { return $_[0]->reads_not_assembled_pct; }
sub total_contig_bases { return $_[0]->assembly_length; }
#<>#

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Build/DeNovoAssembly/Velvet.pm $
#$Id: Velvet.pm 61146 2010-07-20 21:19:56Z kkyung $
