package Genome::Site::WUGC::ReconcileSampleGenotypeData;

use strict;
use warnings;
use Genome;

class Genome::Site::WUGC::ReconcileSampleGenotypeData {
    is => 'Genome::Command::Base',
    doc => 'Updates the default_genotype_data column for Genome::Samples using data from the Organism Sample table',
};

sub execute {
    my $self = shift;
    my @organism_samples = Genome::Site::WUGC::Sample->get();
    my @imported_instrument_data = Genome::InstrumentData::Imported->get();
    @organism_samples = grep($_->default_genotype_seq_id, @organism_samples);
    for my $organism_sample (@organism_samples){
        my $genome_sample = Genome::Sample->get($organism_sample->id);
        print "No Genome::Sample for organism_sample: ", $organism_sample->id, "\n" and next unless $genome_sample;
        next if defined $genome_sample->default_genotype_data and $genome_sample->default_genotype_data->id eq $organism_sample->default_genotype_seq_id;
        my $genotype_instrument_data = Genome::InstrumentData::Imported->get($organism_sample->default_genotype_seq_id);
        print "No imported instrument data for id: ", $organism_sample->default_genotype_seq_id, "\n" and next unless $genotype_instrument_data;
        eval{
            $genome_sample->set_default_genotype_data($genotype_instrument_data);
        };
        if($@){
            print "Failed to set default genotype data: ", $genotype_instrument_data->id, " for Genome::Sample: ", $genome_sample->id, " (err: $@)\n";
        }else{
            print "Successfully updated Genome::Sample ", $genome_sample->id, "\n";
        }
    }
}

1;
