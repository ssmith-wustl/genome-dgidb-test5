package Genome::DruggableGene::Command::GeneNameGroup::LookupInteractions;

use strict;
use warnings;
use Genome;
use List::MoreUtils qw/ uniq /;

class Genome::DruggableGene::Command::GeneNameGroup::LookupInteractions {
    is => 'Genome::Command::Base',
    has_optional => [
#        output_file => {
#            is => 'Text',
#            is_input => 1,
#            is_output=> 1,
#            doc => "Output interactions to specified file. Defaults to STDOUT if no file is supplied.",
#            default => "STDOUT",
#        },
        gene_file => {
            is => 'Path',
            is_input => 1,
            doc => 'Path to a list of gene identifiers',
            shell_args_position => 1,
        },
        gene_identifiers => {
            is => 'Text',
            is_many => 1,
            doc => 'Array of gene identifiers',
        },
        filter => {
            is => 'Text',
            doc => 'Filter results based on the parameters.  See below for how to.',
            shell_args_position => 2,
        },
#        headers => {
#            is => 'Boolean',
#            default => 1,
#            doc => 'Do include headers',
#        },
    ],
    has_transient_optional => [
        no_match_genes => {
            is_many => 1,
            is => 'Text',
        },
        many_match_genes => {
            is_many => 1,
            is => 'Text',
        },
        no_interaction_genes => {
            is_many => 1,
            is => 'Genome::DruggableGene::GeneNameReport',
        },
        filtered_out_interactions => {
            is_many => 1,
            is => 'Genome::DruggableGene::GeneNameReport',
        },
        interactions => {
            is_many => 1,
            is => 'Genome::DruggableGene::DrugGeneInteractionReport',
        },
        identifier_to_genes => {
            is => 'HASH',
        },
        result => {
            is => 'HASH',
        },
    ],
};

sub help_brief { 'Lookup drug-gene interactions through groups using gene identifiers' }

sub help_synopsis { "genome druggable-gene gene-name-group lookup-interactions --gene-file ./gene_file.txt --filter 'drug.is_withdrawn=0'" }

sub help_detail {
    return <<EOS
Example Filters:

'drug.is_withdrawn=0,drug.is_nutraceutical=0,is_potentiator=0,is_untyped=0,drug.is_antineoplastic=1,gene.is_kinase=0'

'drug.is_approved=1,drug.is_withdrawn=0,drug.is_nutraceutical=0,interaction_attributes.name=is_known_action,interaction_attributes.value=yes,is_potentiator=0'

'drug.is_withdrawn=0,drug.is_nutraceutical=0,interaction_attributes.name=is_known_action,interaction_attributes.value=yes,is_potentiator=0'

'drug.is_withdrawn=0,drug.is_nutraceutical=0,is_potentiator=0,(is_untyped=0 or is_known_action=1)';

'drug.is_withdrawn=0,drug.is_nutraceutical=0,is_potentiator=0,is_inhibitor=1,(is_untyped=0 or is_known_action=1)';

'drug.is_withdrawn=0,drug.is_nutraceutical=0,is_potentiator=0,gene.is_kinase=1,(is_untyped=0 or is_known_action=1)';

'drug.is_withdrawn=0,drug.is_nutraceutical=0,is_potentiator=0,drug.is_antineoplastic=1,(is_untyped=0 or is_known_action=1)';
EOS
}

sub execute {
    my $self = shift;

    #Read in all gene names from file or command options
    my @gene_identifiers;
    @gene_identifiers = Genome::Sys->read_file($self->gene_file) if $self->gene_file;
    push @gene_identifiers, $_ for $self->gene_identifiers;
    $self->status_message('No genes found') unless @gene_identifiers;

    #Populate a data structure for each name
    # Maybe the names given were: HUGO_GENE_NAME1, VAGUE_GENE_NAME2, AMBIGUOUS_GENE_NAME3
    # and we found 1 possible group for each of the first two, and several possible groups for the ambiguous one
    #$result = {
    #  HUGO_GENE_NAME1 => {
    #    group => $DIRECT_GROUP1,
    #    interactions => [
    #      $INTERACTION1,
    #    ],
    #  },
    #  VAGUE_GENE_NAME2 => {
    #    group => $INDIRECT_GROUP2,
    #    interactions => [
    #      $INTERACTION2,
    #      $ANOTHER_INTERACTION2,
    #    ],
    #  },
    #  AMBIGUOUS_GENE_NAME3 => {
    #    groups => [
    #      $POSSIBLE_GROUP3,
    #      $ANOTHER_POSSIBLE_GROUP3,
    #    ]
    #  },
    #}
    my $result;
    for my $name (@gene_identifiers){
        $name = uc $name;

        #Search for group, directly and indirectly
        my $group = Genome::DruggableGene::GeneNameGroup->get(name=>$name);#Group generation guarentees no duplicate named groups
        if($group){
            $self->status_message("$name has direct group");
        } else {
            my @alts = Genome::DruggableGene::GeneAlternateNameReport->get(alternate_name=>$name);
            my @groups;
            push @groups, Genome::DruggableGene::GeneNameGroupBridge->get(gene_id=>$_->gene_id)->group for (@alts);
            @groups = uniq @groups;

            if(@groups > 1){
                $self->status_message("$name has multiple groups");
                $result->{$name}{groups} = \@groups;#Record all the ambiguous groups
            } elsif(@groups == 1) {
                ($group) = @groups;
                $self->status_message("$name has indirect group " . $group->name);
            } else {
                $self->status_message("$name has no groups");
            }
        }

        if($group){ #found direct or indirect group
            $result->{$name}{group} = $group;
            for my $gene ($group->genes){
                push @{$result->{$name}{interactions}}, $gene->interactions;
                map{$self->status_message("$name has interaction " . $_->__display_name__)}$gene->interactions;
            }
        }
    }
    return 1;
}

sub group_interactions_by_drug{
    my $self = shift;
    my @interactions = @_;
    my %grouped_interactions = ();

    for my $interaction (@interactions){
        my $drug_id = $interaction->drug_id;
        if($grouped_interactions{$drug_id}){
            my @temp = @{$grouped_interactions{$drug_id}};
            push @temp, $interaction;
            $grouped_interactions{$drug_id} = \@temp;
        }
        else{
            $grouped_interactions{$drug_id} = [$interaction];
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

    my @headers = qw/
    drug
    drug_nomenclature
    drug_primary_name
    drug_alternate_names
    drug_brands
    drug_types
    drug_groups
    drug_categories
    drug_source_db_name
    drug_source_db_version
    gene_identifiers
    gene
    gene_nomenclature
    gene_alternate_names
    gene_source_db_name
    gene_source_db_version
    entrez_gene_name
    entrez_gene_synonyms
    interaction_types
    /;
    if($self->headers){
        $output_fh->print(join("\t", @headers), "\n");
    }

    my @drugs = Genome::DruggableGene::DrugNameReport->get($self->_chunk_in_clause_list('Genome::DruggableGene::DrugNameReport', 'id', '', keys %grouped_interactions));
    for my $drug_id (keys %grouped_interactions){
        for my $interaction (@{$grouped_interactions{$drug_id}}){
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
    my $drug = $interaction->drug;
    my $gene = $interaction->gene;
    my $gene_alternate_names = join(':', map($_->alternate_name, $gene->gene_alt_names));
    my $gene_identifiers = join(':', sort @{$self->gene_to_identifiers->{$gene->id}});
    my ($entrez_gene_name, $entrez_gene_synonyms) = $self->_create_entrez_gene_outputs($gene_identifiers);
    my ($drug_primary_name) = map($_->alternate_name, grep($_->nomenclature =~ /primary/i, $drug->drug_alt_names));
    my $drug_alternate_names = join(':', map($_->alternate_name, grep($_->nomenclature !~ /primary/i && $_->nomenclature ne 'drug_brand', $drug->drug_alt_names)));
    my $drug_brands = join(':', map($_->alternate_name, grep($_->nomenclature eq 'drug_brand', $drug->drug_alt_names)));
    my $drug_types = join(';', map($_->category_value, grep($_->category_name eq 'drug_type', $drug->drug_categories)));
    my $drug_groups = join(';', map($_->category_value, grep($_->category_name eq 'drug_group', $drug->drug_categories)));
    my $drug_categories = join(';', map($_->category_value, grep($_->category_name eq 'drug_category', $drug->drug_categories)));
    my $interaction_types = join(':', $interaction->interaction_types);
    my $interaction_line = join("\t", $drug->name, $drug->nomenclature, $drug_primary_name,
        $drug_alternate_names, $drug_brands, $drug_types, $drug_groups, $drug_categories, $drug->source_db_name, $drug->source_db_version,
        $gene_identifiers, $gene->name, $gene->nomenclature, $gene_alternate_names,
        $gene->source_db_name, $gene->source_db_version, $entrez_gene_name, $entrez_gene_synonyms, $interaction_types);
    return $interaction_line;
}

sub _create_entrez_gene_outputs{
    my $self = shift;
    my @gene_identifiers = split(':', shift);
    my $entrez_gene_output = "";
    my $entrez_gene_synonyms_output = "";
    my $entrez_delimiter = '|';
    my $sub_delimiter = '/';
    for my $gene_identifier (@gene_identifiers){
        my @genes = @{$self->identifier_to_genes->{$gene_identifier}};
        my @entrez_genes = grep($_->nomenclature eq 'entrez_id', @genes);
        if(@entrez_genes){
            for my $entrez_gene (sort {$a->name cmp $b->name} @entrez_genes){
                my ($entrez_gene_symbol) = sort map($_->alternate_name, grep($_->nomenclature eq 'entrez_gene_symbol', $entrez_gene->gene_alt_names));
                my @entrez_gene_synonyms = sort map($_->alternate_name, grep($_->nomenclature eq 'entrez_gene_synonym', $entrez_gene->gene_alt_names));
                $entrez_gene_output = $entrez_gene_output . ($entrez_gene_output ? $entrez_delimiter : '') . $entrez_gene_symbol;
                $entrez_gene_synonyms_output = $entrez_gene_synonyms_output . ($entrez_gene_synonyms_output ? $entrez_delimiter : '') . join($sub_delimiter, @entrez_gene_synonyms);
            }
        }else{
            $entrez_gene_output = $entrez_gene_output . $entrez_delimiter;
            $entrez_gene_synonyms_output = $entrez_gene_synonyms_output . $entrez_delimiter;
        }
    }
    return ($entrez_gene_output, $entrez_gene_synonyms_output);
}
1;
