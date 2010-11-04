package Genome::Model::Tools::Analysis::LaneQc::CopyNumberCorrelationFaster;

use warnings;
use strict;
use Genome;
use IO::File;
use List::Util qw(sum);
use Statistics::Descriptive;

class Genome::Model::Tools::Analysis::LaneQc::CopyNumberCorrelationFaster {
    is => 'Command',
    has => [
    copy_number_laneqc_file_glob => {
        type => 'FilePath',
        is_optional => 0,
        doc => 'glob string for grabbing copy-number laneqc files to compare',
    },
    output_file => {
        type => 'FilePath',
        is_optional => 0,
        doc => 'output filename',
    },
    ]
};

sub help_brief {
    "Script to create a correlation matrix from copy-number lane-qc data."
}
sub help_detail {
    "Script to create a correlation matrix from copy-number lane-qc data."
}

sub execute {
    my $self = shift;
    $DB::single=1;

    #parse inputs
    my $fileglob = $self->copy_number_laneqc_file_glob;
    my @cnfiles = sort glob($fileglob);
    my $num_files = $#cnfiles;
    my $outfile = $self->output_file;
    print "@cnfiles\n"; #to test

    #print outfile headers
    my $outfh = new IO::File $outfile,"w";
    print $outfh "File1\tFile2\tCommon_Probes\tCorrelation_coefficient(max=1)\n";

    #Check that files are reasonably similar
    my $standard_wc;
    for my $file (@cnfiles) {
        my $wc_call = `wc -l $file`;
        my ($wc) = $wc_call =~ m/^(\d+)\s+\w+$/;
        unless ($standard_wc) { 
            $standard_wc = $wc; 
            next;
        }
        my $wc_diff = $standard_wc - $wc;
        $wc_diff = abs($wc_diff);
        if ($wc_diff > 100) {
            $self->status_message("Files have largely varied wordcounts (diff>100) - just letting you know in case this is of concern.");
        }
    }

    #Load a hash with the values from all of the files (FIXME or change this later to load one at a time during the loops below)
    my %data;
    for my $file (@cnfiles) {
        my $fh = new IO::File $file,"r";
        while (my $line = $fh->getline) {
            next if $line =~ m/(^#|CHR)/;
            chomp $line;
            my ($chr,$pos,$rc,$cn) = split /\t/,$line;
            $data{$file}{$chr}{$pos} = $cn;
        }
    }

    #Loop through copy-number to write correlation output file
    my %corr_matrix;
    for my $i1 (0..$num_files) {
        my $f1 = $cnfiles[$i1];
        my $loop2index = $i1 + 1;
        for my $i2 ($loop2index..$num_files) {
            my $f2 = $cnfiles[$i2];
            next if $f1 eq $f2;

            #find common probes
            my (@f1_common,@f2_common);
            my $f1_common = \@f1_common;
            my $f2_common = \@f2_common;
            ($f1_common,$f2_common) = $self->find_common_probes(\%data,$f1,$f2,$f1_common,$f2_common);
            if ($#f1_common ne $#f2_common) {
                $self->error_message("Common probe numbers don't match for $f1 and $f2.");
                return;
            }

            #find means and standard deviations of common probes
            my $stats1 = Statistics::Descriptive::Full->new();
            my $stats2 = Statistics::Descriptive::Full->new();
            $stats1->add_data(@f1_common);
            $stats2->add_data(@f2_common);
            my $mean1 = $stats1->mean();
            my $mean2 = $stats2->mean();
            my $std1 = $stats1->standard_deviation();
            my $std2 = $stats2->standard_deviation();
            #correlation denominator = $std1*$std2
            my $corr_denominator = $std1 * $std2;

            #divide data from common probes by the means of the arrays
            #and multiply them together to start numerator calculation
            my @numerator_array;
            for (my $i=0; $i<@f1_common; $i++) {
                $f1_common[$i] -= $mean1;
                $f2_common[$i] -= $mean2;
                $numerator_array[$i] = $f1_common[$i] * $f2_common[$i];
                #This works since the arrays were required to be equal lengths above.
            }
            #finish numerator:
            my $corr_numerator = sum(@numerator_array);

            #print output:
            my $corr = $corr_numerator / $corr_denominator;
            my $num_common_probes = scalar @f1_common;
            $corr /= ($num_common_probes-1);
            my $outline = join("\t",$f1,$f2,$num_common_probes,"$corr\n");
            print $outfh $outline;

        }#end, f2 loop
    }#end, f1 loop

    return 1;
}

sub find_common_probes {
    my ($self,$data,$f1,$f2,$f1comref,$f2comref) = @_;
    #recall that $data{$file}{$chr}{$pos} = $cn;
    print "$f1\n";
    print "$f2\n";
    for my $chr (keys %{$data->{$f1}}) {
        for my $pos (keys %{$data->{$f1}{$chr}}) {
            if (exists $data->{$f2}{$chr}{$pos}) {
                push @$f1comref,$data->{$f1}{$chr}{$pos};
                push @$f2comref,$data->{$f2}{$chr}{$pos};
            }
        }
    }
    return ($f1comref,$f2comref);
}

1;
