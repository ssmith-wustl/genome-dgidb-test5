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

    my @organism_samples = Genome::Site::WUGC::Sample->get('default_genotype_seq_id >' => '0');
    print "Found " . @organism_samples . " samples.\n";

    my @organism_sample_ids = map { $_->id } @organism_samples;
    my @attributes = Genome::SubjectAttribute->get(
        subject_id => \@organism_sample_ids,
        attribute_label => 'default_genotype_data',
        -order_by => 'subject_id',
    );
    print "Found " . @attributes . " attributes.\n";

    # Limit to sample that have differing default_genotype...
    my @changed_organism_samples;
    for my $organism_sample (@organism_samples) {
        my ($attribute) = grep { $_->subject_id eq $organism_sample->id } @attributes;

        if (!$attribute || $organism_sample->default_genotype_seq_id ne $attribute->attribute_value) {
            push @changed_organism_samples, $organism_sample;
        }
    }
    print "Found " . @changed_organism_samples . " changed organism samples.\n";

    # This is pre-fetching the instrument data so it will be faster during the loop.
    my @default_genotype_seq_id = map { $_->default_genotype_seq_id } @changed_organism_samples;
    my @imported_instrument_data = Genome::InstrumentData::Imported->get(\@default_genotype_seq_id);
    print "Found " . @imported_instrument_data. " instrument data.\n";

    # This is pre-fetching the samples so it will be faster during the loop.
    my @changed_organism_sample_ids = map { $_->id } @changed_organism_samples;
    my @samples = Genome::Sample->get(id => \@changed_organism_sample_ids);

    my $count = 0;
    for my $organism_sample (@changed_organism_samples){
        my $genome_sample = Genome::Sample->get($organism_sample->id);
        print "No Genome::Sample for organism_sample: ", $organism_sample->id, "\n" and next unless $genome_sample;

        eval{
            $genome_sample->set_default_genotype_data($organism_sample->default_genotype_seq_id);
        };
        if($@){
            print "Failed to set default genotype data: " . $organism_sample->default_genotype_seq_id .
                " for Genome::Sample: " . $genome_sample->id . " (err: $@)\n";
            next;
        }
        print "Successfully updated Genome::Sample " . $genome_sample->id . "\n";
        if (++$count % 100 == 0) {
            print "Committing after $count successful updates\n";
            UR::Context->commit;
        }
    }

    UR::Context->commit;
}

1;
