package Genome::Model::Event::Build::ReferenceAlignment::AlignReads::Maq;
use strict;
use warnings;
use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::AlignReads::Maq {
    is => ['Genome::Model::Event::Build::ReferenceAlignment::AlignReads'],
};

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[tmp=50000:mem=12000]' -M 1610612736";
}

sub metrics_for_class {
    my $class = shift;
    my @metric_names = $class->SUPER::metrics_for_class(@_);
    push @metric_names, 'contaminated_read_count';
    return @metric_names;
}

sub contaminated_read_count {
    my $self = shift;
    return $self->get_metric_value('contaminated_read_count');
}

sub _calculate_contaminated_read_count {
    my $self = shift;
 
    my $instrument_data_assignment = $self->instrument_data_assignment;
    my $alignment = $instrument_data_assignment->alignment_set;
    my @f = $alignment->aligner_output_file_paths;
    @f = grep($_ !~ 'sanitized', @f);
    
    my $contaminated_read_count = 0;
    for my $f (@f) {
        my $fh = IO::File->new($f);
        $fh or die "Failed to open $f to read.  Error returning value for contaminated_read_count.\n";
        my $n;
        while (my $row = $fh->getline) {
            if ($row =~ /\[ma_trim_adapter\] (\d+) reads possibly contains adaptor contamination./) {
                $n = $1;
                last;
            }
        }
        unless (defined $n) {
            #$self->warning_message("No adaptor information found in $f!");
            next;
        }
        $contaminated_read_count += $n;
    }
    
    return $contaminated_read_count;
}

1;

