package Genome::Model::Tools::RepeatMasker::CompareTables;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Tools::RepeatMasker::CompareTables {
    is => 'Genome::Model::Tools::RepeatMasker::TableI',
    has => [
        input_tables => { },
        _total_count => {
            is => 'Integer',
            is_optional => 1,
        },
        _total_bp => {
            is => 'Integer',
            is_optional => 1,
        },
    ],
};

sub execute {
    my $self = shift;
    my %samples;
    for my $table ( @{$self->input_tables} ) {
        my $sample_name = basename($table);
        my $table_fh = IO::File->new($table,'r');
        my $family;
        while ( my $line = $table_fh->getline ) {
            chomp($line);
            my @entry = split("\t",$line);
            if (scalar(@entry) == 2) {
                if ($entry[0] eq 'sequences:') {
                    $samples{$sample_name}{sequences} = $entry[1];
                } elsif ($entry[0] eq 'total length:') {
                    $samples{$sample_name}{'base_pair'} = $entry[1];
                } elsif ($entry[0] eq 'aligned:') {
                    $samples{$sample_name}{'aligned'} = $entry[1];
                } elsif ($entry[0] eq 'repeat aligned:') {
                    $samples{$sample_name}{'repeat_aligned'} = $entry[1];
                }
                # new repeat family
            } elsif (scalar(@entry) == 4) {
                $family = $entry[0];
                $family =~ s/://;
                $samples{$sample_name}{$family}{base_pair} += $entry[2];
                $samples{$sample_name}{masked} += $entry[2];
            } elsif (scalar(@entry) == 5) {
                unless ($family) { die; }
                my $class = $entry[1];
                $class =~ s/://;
                $samples{$sample_name}{$family}{$class}{base_pair} += $entry[3];
            }
        }
        $table_fh->close;
    }
    $self->print_samples_summary_from_hash_ref(\%samples);
    return 1;
}

1;
