package Genome::Model::Tools::Array::GetGenotypesFromIscanResults;

use warnings;
use strict;

use IO::File;
use Genome;
use GSC;

class Genome::Model::Tools::Array::GetGenotypesFromIscanResults {
    is => 'Command',
    has => [
        sample => {
            type => 'String',
            is_optional => 0,
            doc => "Sample name or id.",
        },
        output_file => {
            type => 'String',
            is_optional => 0,
            doc => "Path and name of the output file.",
        },
    ]
};

sub execute {
    my $self = shift;

    #TODO normalize output to positive strand.
    warn "This tool currently does not normalize output to the positive strand.";
    my @samples = Genome::Command::Base->resolve_param_value_from_text($self->sample,'Genome::Sample');

    unless(scalar(@samples)==1){
        $self->error_message("found ".scalar(@samples)." samples to match ".$self->sample);
        die $self->error_message;
    }

    my $sample = $samples[0];

    # Get the sample

    my $organism_sample = GSC::Organism::Sample->get(  organism_sample_id => $sample->id );

    unless($organism_sample){
        $self->error_message("Could not locate organism sample.");
        die $self->error_message;
    }

    my $output = IO::File->new(">".$self->output_file);

    unless(defined($output)){
        $self->error_message("couldn't open output file.".$self->output_file."\n");
        die $self->error_message;
    }

    # Get all genotypes for this sample
    unless(scalar($organism_sample->get_genotype)==1){
        $self->error_message("Expected to find one genotype result, but instead found ".scalar($organism_sample->get_genotype)." results.");
        die $self->error_message;
    }

    my %genotype;

    for my $genotype ( $organism_sample->get_genotype ) {

        # Get the data adapter (DataAdapter::GSGMFinalReport class object)
        my $data_adapter = $genotype->get_genotype_data_adapter;

        # Next if there is no iScan genotype data.
        next unless($data_adapter);

        # Loop through the result row (DataAdapter::Result::GSGMFinalReport class object)
        $self->status_message("Getting Genotype results now. This may take several minutes.\n");
        my $result;
        while ($result = $data_adapter->next_result ) {
            $genotype{$result->chromosome}{$result->position}=$result->alleles;
        }
    }

    #my @chroms = sort(keys(%genotype));
    
    # this listing of chromosome names yields the order we expect
    my @chroms = qw| 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X XY Y|;

    $self->status_message("now writing results to output file.\n");

    for my $chrom (@chroms){
        for my $pos (sort(keys(%{$genotype{$chrom}}))){
            my $line = join "\t", ($chrom,$pos,$genotype{$chrom}{$pos});
            print $output $line . "\n";
        }
    }
    $output->close;
}

sub help_brief {
    "Get genotype files from iScan results. This tool does not normalize output to the positive strand."
}

sub help_detail {
    "Get genotype files from iScan results. This tool does not normalize output to the positive strand."
}

1;
