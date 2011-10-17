package Genome::GeneName::Command::LookupInteractions;

use strict;
use warnings;
use Genome;

class Genome::GeneName::Command::LookupInteractions {
    is => 'Genome::Command::Base',
    has => [
        gene_file => {
            is => 'Path',
            is_input => 1,
            doc => 'Path to a list of gene identifiers',
            shell_args_position => 1,
        },
    ],
};

sub help_brief {
    'Lookup drug-gene interactions by gene identifier';
}

sub help_synopsis {
    #TODO: write me
}

sub help_detail {
    #TODO: write me
}

sub execute {
    my $self = shift;
    my @gene_identifiers = $self->_get_gene_identifiers();
    unless(@gene_identifiers){
        $self->error_message('No gene identifiers in gene_file ' . $self->gene_file . ', exiting');
        return;
    }

    my $gene_name_results = {};

    for my $gene_identifier (@gene_identifiers){
        $self->find_gene_names($gene_identifier, $gene_name_results);
        $self->get_interactions($gene_identifier, $gene_name_results);
    }

    my %grouped_interactions = $self->group_interactions_by_drug_name($gene_name_results);

    $self->print_grouped_interactions(%grouped_interactions);

    return 1;
}

sub _get_gene_identifiers{
    my $self = shift;
    my $gene_file = $self->gene_file;
    my @gene_identifiers;

    my $gene_fh = Genome::Sys->open_file_for_reading($gene_file);
    unless($gene_fh){
        $self->error_message("Failed to open gene_file $gene_file: $@");
        return;
    }

    while (my $gene_identifier = <$gene_fh>){
        chomp $gene_identifier;    
        push @gene_identifiers, $gene_identifier;
    }

    $gene_fh->close;
    return @gene_identifiers;
}

sub find_gene_names {
    my $self = shift;
    my $gene_identifier = shift;
    my $gene_name_results = shift;

    my @gene_names = Genome::GeneName->get(name => $gene_identifier);
    my @gene_name_associations = Genome::GeneNameAssociation->get(alternate_name => $gene_identifier);
    @gene_names = (@gene_names, map($_->gene_name, @gene_name_associations));
    my %results;
    $results{'gene_names'} = \@gene_names;
    $gene_name_results->{$gene_identifier} = \%results;
    return $gene_name_results
}

sub get_interactions {
    my $self = shift;
    my $gene_identifier = shift;
    my $gene_name_results = shift;

    for my $gene_name (@{$gene_name_results->{$gene_identifier}->{'gene_names'}}){
        my @interactions = $gene_name->drug_gene_interactions;
        $gene_name_results->{$gene_identifier}->{'interactions'} = \@interactions;
    }
    return $gene_name_results;
}

sub group_interactions_by_drug_name {
    my $self = shift; 
    my $gene_name_results = shift;
    my %grouped_interactions;

    for my $gene_name (keys %$gene_name_results){
        for my $interaction (@{$gene_name_results->{$gene_name}->{'interactions'}}){
            if($grouped_interactions{$interaction->drug_name->name}){
                my @interactions = @{$grouped_interactions{$interaction->drug_name->name}};
                push @interactions, $interaction;
                $grouped_interactions{$interaction->drug_name->name} = \@interactions;
            }
            else{
                $grouped_interactions{$interaction->drug_name->name} = [$interaction];
            }
        }
    }

    return %grouped_interactions;
}

sub print_grouped_interactions{
    my $self = shift; 
    my %grouped_interactions = @_;
    my @headers = qw/interaction_id interaction_type drug_name_id drug_name drug_nomenclature drug_source_db_name drug_source_db_version gene_name_id
        gene_name gene_nomenclature gene_source_db_name gene_source_db_version/;
    print join("\t", @headers), "\n";
    for my $drug_name (keys %grouped_interactions){
        for my $interaction (@{$grouped_interactions{$drug_name}}){
            print $self->_build_interaction_line($interaction), "\n"; 
        }
    }
    return 1;
}

sub _build_interaction_line {
    my $self = shift;
    my $interaction = shift;
    my $drug_name = $interaction->drug_name;
    my $gene_name = $interaction->gene_name;
    my $interaction_line = join("\t", $interaction->id, $interaction->interaction_type,
        $drug_name->id, $drug_name->name, $drug_name->nomenclature, $drug_name->source_db_name, 
        $drug_name->source_db_version, $gene_name->id, $gene_name->name, $gene_name->nomenclature, 
        $gene_name->source_db_name, $gene_name->source_db_version); 
    return $interaction_line;
}

1;
