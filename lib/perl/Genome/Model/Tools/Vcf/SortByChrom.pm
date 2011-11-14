package Genome::Model::Tools::Vcf::SortByChrom;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Vcf::SortByChrom {
    is => 'Command',
    has => [
        output_file => {
            is => 'Text',
            is_output => 1,
            is_optional => 0,
            doc => "Output sorted VCF",
        },
        input_file => {
            is => 'Text',
            is_input => 1,
            is_optional => 0,
            doc => "VCF file to sort",
        },
    ],
};

sub execute {
    my $self = shift;

    my $input_file = $self->input_file;
    unless(-s $input_file) {
        die $self->error_message("Could not locate input file at: ".$input_file);
    }

    my $output_fh = Genome::Sys->open_file_for_writing($self->output_file);

    my %present;
    my @chrom_order = qw(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y MT GL000207.1 GL000226.1 GL000229.1 GL000231.1 GL000210.1 GL000239.1 GL000235.1 GL000201.1 GL000247.1 GL000245.1 GL000197.1 GL000203.1 GL000246.1 GL000249.1 GL000196.1 GL000248.1 GL000244.1 GL000238.1 GL000202.1 GL000234.1 GL000239.1 GL000235.1 GL000201.1 GL000247.1 GL000245.1 GL000197.1 GL000203.1 GL000246.1 GL000249.1 GL000196.1 GL000248.1 GL000244.1 GL000238.1 GL000202.1 GL000234.1 GL000232.1 GL000206.1 GL000240.1 GL000236.1 GL000241.1 GL000243.1 GL000242.1 GL000230.1 GL000237.1 GL000233.1 GL000204.1 GL000198.1 GL000208.1 GL000191.1 GL000227.1 GL000228.1 GL000214.1 GL000221.1 GL000209.1 GL000218.1 GL000220.1 GL000213.1 GL000211.1 GL000199.1 GL000217.1 GL000216.1 GL000215.1 GL000205.1 GL000219.1 GL000224.1 GL000217.1 GL000216.1 GL000215.1 GL000205.1 GL000219.1 GL000224.1 GL000223.1 GL000195.1 GL000212.1 GL000222.1 GL000200.1 GL000193.1 GL000194.1 GL000225.1 GL000192.1);
    my %cardinal;
    my $count = 0;
    foreach my $chrom (@chrom_order) {
        $cardinal{$chrom} = $count;
        $count++;
    }
    my $fh = Genome::Sys->open_file_for_reading($input_file);
    while (my $line = $fh->getline) {
        if ($line =~ /^#/) {
            print $output_fh $line;
            next;
        }
        my @fields = split(/\t/, $line);
        $present{$fields[0]} = 1;
    }
    $fh->close;
    foreach my $chrom (@chrom_order) {
        if ($present{$chrom}) {
            my $fh = Genome::Sys->open_file_for_reading($input_file);
            while(my $line = $fh->getline) {
                if ($line =~ /^#/) {
                    next;
                }
                my @fields = split(/\t/, $line);
                if ($cardinal{$fields[0]} > $cardinal{$chrom}) {
                    last;
                }
                if ($fields[0] eq $chrom) {
                    print $output_fh $line;
                }
            }
            $fh->close;
        }
    }
    $output_fh->close;
}

1;

