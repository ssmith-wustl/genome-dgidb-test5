package Genome::GeneNameReport::Command::LookupInteractions;

use strict;
use warnings;
use Genome;
use List::MoreUtils qw/ uniq /;

class Genome::GeneNameReport::Command::LookupInteractions {
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

    my $gene_name_report_results = {};

    for my $gene_identifier (@gene_identifiers){
        my $cmd = Genome::GeneNameReport::Command::ConvertToEntrez->execute(gene_identifier => $gene_identifier);
        my @entrez_gene_name_reports = $cmd->_entrez_gene_name_reports;
        my @intermediates = $cmd->_intermediate_gene_name_reports;
        $DB::single = 1;
        my @gene_name_reports = $self->find_gene_name_reports($gene_identifier);
        my @complete_gene_name_reports = (@entrez_gene_name_reports, @intermediates, @gene_name_reports);
        @complete_gene_name_reports = uniq @complete_gene_name_reports;
        $gene_name_report_results->{$gene_identifier} = {};
        $gene_name_report_results->{$gene_identifier}->{'gene_name_reports'} = \@complete_gene_name_reports;
        $self->get_interactions($gene_identifier, $gene_name_report_results);
    }

    my %grouped_interactions = $self->group_interactions_by_drug_name_report($gene_name_report_results);

    $self->print_grouped_interactions(%grouped_interactions);

    return 1;
}

sub find_gene_name_reports {
    my $self = shift;
    my $gene_identifier = shift;

    my @gene_name_reports = Genome::GeneNameReport->get(name => $gene_identifier);
    my @gene_name_report_associations = Genome::GeneNameReportAssociation->get(alternate_name => $gene_identifier);
    @gene_name_reports = (@gene_name_reports, map($_->gene_name_report, @gene_name_report_associations));
    @gene_name_reports = uniq @gene_name_reports;
    return @gene_name_reports;
}

sub get_interactions {
    my $self = shift;
    my $gene_identifier = shift;
    my $gene_name_report_results = shift;

    for my $gene_name_report (@{$gene_name_report_results->{$gene_identifier}->{'gene_name_reports'}}){
        my @interactions = $gene_name_report->drug_gene_interactions;
        $gene_name_report_results->{$gene_identifier}->{'interactions'} = \@interactions;
    }
    return $gene_name_report_results;
}

sub group_interactions_by_drug_name_report {
    my $self = shift;
    my $gene_name_report_results = shift;
    my %grouped_interactions;

    for my $gene_name_report (keys %$gene_name_report_results){
    #TODO: rework this using $gene_name_report->drug_name_reports
        for my $interaction (@{$gene_name_report_results->{$gene_name_report}->{'interactions'}}){
            if($grouped_interactions{$interaction->drug_name_report->name}){
                my @interactions = @{$grouped_interactions{$interaction->drug_name_report->name}};
                push @interactions, $interaction;
                $grouped_interactions{$interaction->drug_name_report->name} = \@interactions;
            }
            else{
                $grouped_interactions{$interaction->drug_name_report->name} = [$interaction];
            }
        }
    }

    return %grouped_interactions;
}

sub print_grouped_interactions{
    my $self = shift;
    my %grouped_interactions = @_;
    my @headers = qw/interaction_id interaction_type drug_name_report_id drug_name_report drug_nomenclature drug_source_db_name drug_source_db_version gene_name_report_id
        gene_name_report gene_nomenclature gene_source_db_name gene_source_db_version/;
    print join("\t", @headers), "\n";
    for my $drug_name_report (keys %grouped_interactions){
        for my $interaction (@{$grouped_interactions{$drug_name_report}}){
            print $self->_build_interaction_line($interaction), "\n";
        }
    }
    return 1;
}

sub _build_interaction_line {
    my $self = shift;
    my $interaction = shift;
    my $drug_name_report = $interaction->drug_name_report;
    my $gene_name_report = $interaction->gene_name_report;
    my $interaction_line = join("\t", $interaction->id, $interaction->interaction_type,
        $drug_name_report->id, $drug_name_report->name, $drug_name_report->nomenclature, $drug_name_report->source_db_name,
        $drug_name_report->source_db_version, $gene_name_report->id, $gene_name_report->name, $gene_name_report->nomenclature,
        $gene_name_report->source_db_name, $gene_name_report->source_db_version);
    return $interaction_line;
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

1;
