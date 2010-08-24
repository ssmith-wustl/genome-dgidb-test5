package Genome::Model::Tools::Bmr::CombineGeneSummaryFiles;

use warnings;
use strict;

use IO::File;
use Genome;

class Genome::Model::Tools::Bmr::CombineGeneSummaryFiles {
    is => 'Genome::Command::OO',
    has_input => [
    class_summary_file => {
        is => 'String',
        is_optional => 0,
        doc => 'output from combine-class-summary tool',
    },
    gene_summary_output_dir => {
        is => 'String',
        is_optional => 0,
        doc => 'directory containing results from batch-gene-summary tool',
    },
    output_file => {
        is => 'String',
        is_optional => 0,
        doc => 'final gene summary file for the dataset',
    },
    ]
};

sub help_brief {
    "Combines results from batched gene-summary jobs and adds BMRs."
}

sub help_detail {
    "This tool combines results from batched gene-summary jobs, and also adds a 5th column to the data which is the genome-wide background mutation rate for each class."
}

sub execute {
    my $self = shift;

    #parse inputs
    my $class_summary = $self->class_summary_file;
    my $gene_sum_dir = $self->gene_summary_output_dir;
    my $outfile = $self->output_file;

    #grab class summary info
    my $sumfh = new IO::File $class_summary,"r";
    my %BMR;
    $sumfh->getline; #discard the header
    while (my $line = $sumfh->getline) {
        chomp $line;
        my ($class,$bmr,$cov,$muts) = split /\t/,$line;
        $BMR{$class}{'bmr'} = $bmr;
    }
    $sumfh->close;

    #parse gene summary dir to get filenames
    opendir(GENESUM,$gene_sum_dir);
    my @files = readdir(GENESUM);
    closedir(GENESUM);
    @files = grep { /\.gene_summary$/ } @files;
    @files = map {$_ = "$gene_sum_dir/" . $_ } @files;

    #open output file and print header
    my $outfh = new IO::File $outfile,"w";
    print $outfh "Gene\tClass\tBases_Covered\tNon_Syn_Mutations\tBMR\n";

    #loop through files and print output file
    for my $file (@files) {
        my $fh = new IO::File $file,"r";
        $fh->getline; #discard the header
        while (my $line = $fh->getline) {
            chomp $line;
            my ($gene,$class,$coverage,$muts) = split /\t/,$line;
            my $newline = join("\t",$gene,$class,$coverage,$muts,$BMR{$class}{'bmr'});
            print $outfh "$newline\n";
        }
        $fh->close;
    }
    $outfh->close;

    return 1;
}

1;
