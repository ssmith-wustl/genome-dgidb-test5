package Genome::DruggableGene::Command::GeneNameGroup::LookupInteractions;

use strict;
use warnings;
use Genome;
use Set::Scalar;
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
#        headers => {
#            is => 'Boolean',
#            default => 1,
#            doc => 'Do include headers',
#        },
        filter => {
            is => 'Text',
            doc => 'Filter results based on the parameters.  See below for how to.',
            shell_args_position => 2,
        },
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
    ],
    has_transient_optional => [
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

    my $result = $self->find_groups_and_interactions(@gene_identifiers);
    $self->result($result);
    return $result;
}

#######   find_groups_and_interactions    #######
#Populate a data structure containing each search term
# Maybe the names given were: 'stk1','flt3','cdk7','asdf'
# and we found 1 possible group for flt3 and cdk7, and two possible groups for stk1, and no groups for asdf
#
#                     THE DATA
#
#    definite_groups
#        CDK7
#            group
#                $group
#            search_terms
#                "CDK7"
#            interactions
#                $interaction
#            filtered_interations
#                $interaction1
#        FLT3
#            group
#                $group
#            search_terms
#                "FLT3"
#    ambiguous_search_terms
#        STK1
#            CDK7
#                group
#                    $group
#                number_of_matches
#                    2
#                interactions
#                    $interaction
#                    $interaction
#                filtered_interactions
#                    $interaction
#                    $interaction
#            FLT3
#                group
#                    $group
#                number_of_matches
#                    1
#                interactions
#                    $interaction
#                    $interaction
#    search_terms_without_groups
#        "ASDF"
#
sub find_groups_and_interactions{
    my $self = shift;
    my @gene_names = @_;
    @gene_names = map{uc}@gene_names;
    @gene_names = uniq @gene_names;
    my $result;

    for my $name (@gene_names){
        $name = uc $name;

        #Search for group, directly and indirectly
        #If no groups are found ... drop it on the floor and don't try to match genes that aren't in hugo groups
        my @groups;
        my %group_matches;
        my $group = Genome::DruggableGene::GeneNameGroup->get(name=>$name);#Group generation guarentees no duplicate named groups
        unless($group) {
            #Cycle alternate names, and their group association
            for(Genome::DruggableGene::GeneAlternateNameReport->get(alternate_name=>$name)){
                my $ambiguous_group_bridge = Genome::DruggableGene::GeneNameGroupBridge->get(gene_id=>$_->gene_id);
                if($ambiguous_group_bridge){
                    my $ambiguous_group = $ambiguous_group_bridge->group;
                    push @groups, $ambiguous_group;#record a uniq list of groups
                    $group_matches{$ambiguous_group->name}++;#record how many times each group was matched
                }
            }
            @groups = uniq @groups;

            ($group) = @groups if @groups == 1;
            push @{$result->{search_terms_without_groups}}, $name if @groups == 0;
            if(@groups > 1){ #Found multiple indirect groups from ambiguous search term
                for my $ambiguous_group (@groups){
                    $result->{ambiguous_search_terms}{$name}{$ambiguous_group->name}{group} = $ambiguous_group;
                    $result->{ambiguous_search_terms}{$name}{$ambiguous_group->name}{number_of_matches} = $group_matches{$ambiguous_group->name};
                    my ($interactions, $filtered_interactions) = $self->filter_interactions(map{$_->interactions}$ambiguous_group->genes);
                    push @{$result->{ambiguous_search_terms}{$name}{$ambiguous_group->name}{interactions}}, $interactions->members if $interactions;
                    push @{$result->{ambiguous_search_terms}{$name}{$ambiguous_group->name}{filtered_interactions}}, $filtered_interactions->members if $filtered_interactions;
                }
            }
        }

        if($group){ #found single direct or indirect group
            $result->{definite_groups}{$group->name}{group} = $group;
            push @{$result->{definite_groups}{$group->name}{search_terms}}, $name;
            my ($interactions, $filtered_interactions) = $self->filter_interactions(map{$_->interactions}$group->genes);
            push @{$result->{definite_groups}{$group->name}{interactions}}, $interactions->members if $interactions;
            push @{$result->{definite_groups}{$group->name}{filtered_interactions}}, $filtered_interactions->members if $filtered_interactions;
        }
    }
    return $result;
}

sub filter_interactions {
    my $self = shift;
    my $all_interactions = Set::Scalar->new(@_);
    my $filter = $self->filter . ',id';
    if(@$all_interactions){
        $filter .= '=' if @$all_interactions == 1;
        $filter .= ':' if @$all_interactions > 1;#if we have multiple sources, we need to use : with / delimited list for boolean expr syntax
        $filter .= join '/', map{$_->id}@$all_interactions;
        my $interactions = Set::Scalar->new(
            Genome::DruggableGene::DrugGeneInteractionReport->get(
                UR::BoolExpr->resolve_for_string('Genome::DruggableGene::DrugGeneInteractionReport', $filter)
            )
        );
        my $filtered_interactions = $all_interactions - $interactions;
        return ($interactions, $filtered_interactions);
    }
}
1;
