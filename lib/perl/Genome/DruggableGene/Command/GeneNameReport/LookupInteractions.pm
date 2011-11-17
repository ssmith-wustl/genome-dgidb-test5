package Genome::DruggableGene::Command::GeneNameReport::LookupInteractions;

use strict;
use warnings;
use Genome;
use List::MoreUtils qw/ uniq /;

class Genome::DruggableGene::Command::GeneNameReport::LookupInteractions {
    is => 'Genome::Command::Base',
    has => [
        gene_file => {
            is => 'Path',
            is_input => 1,
            doc => 'Path to a list of gene identifiers',
            shell_args_position => 1,
        },
        output_file => {
            is => 'Text',
            is_input => 1,
            is_output=> 1,
            doc => "Output interactions to specified file. Defaults to STDOUT if no file is supplied.",
            default => "STDOUT",
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

    my @gene_name_reports = $self->lookup_gene_identifiers;
    my @interactions = $self->get_interactions(@gene_name_reports);
    my %grouped_interactions = $self->group_interactions_by_drug_name_report(@interactions);
    $self->print_grouped_interactions(%grouped_interactions);

    return 1;
}

sub lookup_gene_identifiers {
    my $self = shift;

    my @gene_identifiers = $self->_read_gene_file();
    unless(@gene_identifiers){
        $self->error_message('No gene identifiers in gene_file ' . $self->gene_file . ', exiting');
        return;
    }

    my ($entrez_gene_name_reports, $intermediates) = Genome::DruggableGene::GeneNameReport->convert_to_entrez(@gene_identifiers);
    my %gene_name_reports = $self->_find_gene_name_reports_for_identifiers(@gene_identifiers);

    my @complete_genes;
    for my $gene_identifier (@gene_identifiers){
        my $entrez_gene_name_reports_for_identifier = $entrez_gene_name_reports->{$gene_identifier};
        push @complete_genes, @$entrez_gene_name_reports_for_identifier if $entrez_gene_name_reports_for_identifier;
        my $intermediates_for_identifier = $intermediates->{$gene_identifier};
        push @complete_genes, @$intermediates_for_identifier if $intermediates_for_identifier;
        my $gene_name_reports_for_identifier = $gene_name_reports{$gene_identifier};
        push @complete_genes, @$gene_name_reports_for_identifier if $gene_name_reports_for_identifier;
    }

    return uniq @complete_genes;
}

sub _find_gene_name_reports_for_identifiers {
    my $self = shift;
    my @gene_identifiers = @_;
    my %results;

    my @gene_name_reports = Genome::DruggableGene::GeneNameReport->get(name => \@gene_identifiers);
    my @gene_name_report_associations = Genome::DruggableGene::GeneNameReportAssociation->get(alternate_name => \@gene_identifiers);
    for my $gene_identifier(@gene_identifiers){
        my @reports_for_identifier = grep($_->name eq $gene_identifier, @gene_name_reports);
        my @associations_for_identifier = grep($_->alternate_name eq $gene_identifier, @gene_name_report_associations);
        @reports_for_identifier = (@reports_for_identifier, map($_->gene_name_report, @associations_for_identifier));
        @reports_for_identifier = uniq @reports_for_identifier;
        $results{$gene_identifier} = \@reports_for_identifier;
    }
    return %results;
}

sub get_interactions {
    my $self = shift;
    my @gene_name_reports = @_;

    my @gene_name_report_ids = map($_->id, @gene_name_reports);
    @gene_name_report_ids = uniq @gene_name_report_ids;
    return Genome::DruggableGene::DrugGeneInteractionReport->get(gene_name_report_id => \@gene_name_report_ids);
}

sub group_interactions_by_drug_name_report {
    my $self = shift;
    my @interactions = @_;
    my %grouped_interactions = ();

    for my $interaction (@interactions){
        my $drug_name_report_id = $interaction->drug_name_report_id;
        if($grouped_interactions{$drug_name_report_id}){
            my @temp = @{$grouped_interactions{$drug_name_report_id}};
            push @temp, $interaction;
            $grouped_interactions{$drug_name_report_id} = \@temp;
        }
        else{
            $grouped_interactions{$drug_name_report_id} = [$interaction];
        }
    }

    return %grouped_interactions;
}

sub print_grouped_interactions{
    my $self = shift;
    my %grouped_interactions = @_;

    my $output_file = $self->output_file;
    my $output_fh;
    if ($self->output_file =~ /STDOUT/i) {
        $output_fh = 'STDOUT';
    }else{
        $output_fh = IO::File->new($self->output_file, 'w');
        unless($output_fh){
            $self->error_message("Could not open file " . $self->output_file . " : $@");
            return;
        }
    }

    my @headers = qw/interaction_id interaction_type drug_name_report_id drug_name_report drug_nomenclature drug_source_db_name drug_source_db_version gene_name_report_id
        gene_name_report gene_nomenclature gene_source_db_name gene_source_db_version/;
    $output_fh->print(join("\t", @headers), "\n");

    Genome::DruggableGene::DrugNameReport->get(id => [keys %grouped_interactions]);
    for my $drug_name_report_id (keys %grouped_interactions){
        for my $interaction (@{$grouped_interactions{$drug_name_report_id}}){
            $output_fh->print($self->_build_interaction_line($interaction), "\n");
        }
    }

    unless($self->output_file =~ /STDOUT/i){
        $output_fh->close;
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

sub _read_gene_file{
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
