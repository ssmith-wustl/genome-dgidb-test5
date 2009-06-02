package Genome::Variation;

use strict;
use warnings;
use Genome;

class Genome::Variation{
    type_name => 'genome variation',
    table_name => 'GENOME_VARIATION',
    id_by => [
        variation_id => {is => 'Number'},
    ],
    has => [
        external_variation_id => {is => 'Number'},
        allele_string => {is => 'String'},
        reference => {
            calculate_from => 'allele_string',
            calculate => q|
                my ($reference, $variant) = split ("/", $allele_string);
                return $reference;
            |,
        },
        variant => {
            calculate_from => 'allele_string',
            calculate => q|
                my ($reference, $variant) = split ("/", $allele_string);
                return $variant;
            |,
        },
        variation_type => {is => 'String'},
        chrom_name => {is => 'String'},
        start => {is => 'Number'},
        stop => {is => 'Number'},
        pubmed_id => {is => 'Number'},
        build => {
            is => "Genome::Model::Build",
            id_by => 'build_id',
        },
    ],
    has_many => [
        variation_instances => {
            calculate_from => [qw/ variation_id build_id/],
            calculate => q|
                Genome::VariationInstance->get(variation_id => $variation_id, build_id => $build_id);
            |,
        },
        submitters => {is => 'Genome::Submitter', via => 'variation_instances', to => 'submitter'},
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::Variations',
};

sub submitter_name
{
    my $self = shift;

    my @submitters = $self->submitters;
    return 'NONE' unless @submitters;

    return $submitters[0]->submitter_name;
}

sub source
{
    my $self = shift;

    my @submitters = $self->submitters;
    return 'NONE' unless @submitters;

    return $submitters[0]->variation_source;
}

__END__
    [
        is                  => 'UR::DataSource::FileMux',
        required_for_get    => ['chrom_name'],
        file_resolver       => sub {
                                my($chrom_name) = @_;
                                $DB::single =1;
                                # TODO: this will connect to a watson/venter/dbSNP/etc. model instead
                                my $path = '/gscmnt/sata363/info/medseq/annotation_data/variations/variations_' . $chrom_name . ".csv";
                                return $path;
                            },
        delimiter   =>"\t",
        skip_first_line => 0,
        column_order => [
            qw(
                variation_id
                external_variation_id
                allele_string
                variation_type
                chrom_name
                start
                stop
                pubmed_id
            )
        ],
        sort_order => 'start',
    ],


1;

