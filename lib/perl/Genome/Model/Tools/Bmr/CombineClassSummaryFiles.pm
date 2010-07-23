package Genome::Model::Tools::Bmr::CombineClassSummaryFiles;

use warnings;
use strict;

use IO::File;
use Genome;

class Genome::Model::Tools::Bmr::CombineClassSummaryFiles {
    is => 'Genome::Command::OO',
    has_input => [
    class_summary_output_dir => {
        is => 'String',
        is_optional => 0,
        doc => 'directory containing results from batch-class-summary',
    },
    output_file => {
        is => 'String',
        is_optional => 0,
        doc => 'final class summary file for the dataset',
    },
    ]
};

sub help_brief {
    "Combine results from batched class-summary jobs."
}

sub help_detail {
    "Combine results from batched class-summary jobs."
}

sub execute {
    my $self = shift;
    my $summary_dir = $self->class_summary_output_dir;
    my $outfile = $self-> output_file;

    #read dir
    opendir(SUM,$summary_dir);
    my @files = readdir(SUM);
    closedir(SUM);
    @files = grep { !/^(\.|\.\.)$/ } @files;
    @files = map {$_ = "$summary_dir/" . $_ } @files;

    #record data from files
    my %DATA;
    for my $file (@files) {
        my $fh = new IO::File $file,"r";
        while (my $line = $fh->getline) {
            next if $line =~ /Class/;
            chomp $line;
            my ($class,$bmr,$cov,$muts) = split /\t/,$line;
            $DATA{$class}{'coverage'} += $cov;
            unless ($DATA{$class}{'mutations'}) {
                $DATA{$class}{'mutations'} = $muts;
            }
        }
    }

    #print output
    my $outfh = new IO::File $outfile,"w";
    print $outfh "Class\tBMR\tCoverage(Bases)\tNon_Syn_Mutations\n";
    for my $class (sort keys %DATA) {
        my $rate = $DATA{$class}{'mutations'} / $DATA{$class}{'coverage'};
        print $outfh "$class\t$rate\t$DATA{$class}{'coverage'}\t$DATA{$class}{'mutations'}\n";
    }

    return 1;
}
1;

