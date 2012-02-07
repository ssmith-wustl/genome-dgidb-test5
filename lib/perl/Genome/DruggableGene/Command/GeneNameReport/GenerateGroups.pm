package Genome::DruggableGene::Command::GeneNameReport::GenerateGroups;

use strict;
use warnings;
use Genome;
use List::MoreUtils qw/ uniq /;

class Genome::DruggableGene::Command::GeneNameReport::GenerateGroups {
    is => 'Genome::Command::Base',
    doc => 'Generate a ton of groups to bundle genes with similar alternate names',
};

sub help_brief { 'Generate a ton of groups to bundle genes with similar alternate names' }

sub help_synopsis { help_brief() }

sub help_detail { help_brief() }

sub execute {
    my $self = shift;

    print "Preloading all genes\n";
    Genome::DruggableGene::GeneNameReport->get;#Preload

    print "Loading alternate names and creating hash\n";
    my %alt_to_entrez;
    for (Genome::DruggableGene::GeneAlternateNameReport->get) { #operate on all alternate names
    my %alt_to_other;
        next if $_->alternate_name =~ /^.$/;    #ignore single character names
        next if $_->alternate_name =~ /^\d\d$/; #ignore 2 digit names
        if($_->nomenclature eq 'entrez_gene_synonym' or $_->nomenclature eq 'entrez_gene_symbol'){
            push @{ $alt_to_other{$_->alternate_name} }, $_;   #Save genes with the same alternate name in an array in a hash with key being the alt-name
        } else {
            push @{ $alt_to_entrez{$_->alternate_name} }, $_;   #Save genes with the same alternate name in an array in a hash with key being the alt-name
        }
    }

    my $progress_counter = 0;

    print "Putting entrez alternate names into groups\n";
    for my $alt (keys %alt_to_entrez) {
        my @genes = map{$_->gene_name_report} @{$alt_to_entrez{$alt}};
        next if @genes > 15;#Ignore alts with more than 15 supposedly synonymous genes

        my @bridges = map{Genome::DruggableGene::GeneNameGroupBridge->get(gene_id => $_->id)}
        grep{Genome::DruggableGene::GeneNameGroupBridge->get(gene_id => $_->id)} @genes;

        my @groups = map{$_->gene_name_group} @bridges;
        @groups = uniq @groups;
        if (@groups) {
            my @genes_groupless = grep{not Genome::DruggableGene::GeneNameGroupBridge->get(gene_id => $_->id)} @genes;

            my $group = shift @groups;
            unless($group->name){ #If not currently using an entrez_gene_symbol primary name, find one
                my ($name) = map{$_->alternate_name}grep{$_->nomenclature eq 'entrez_gene_symbol'} map{$_->gene_alt_names}@genes_groupless;
                ($name) = grep{$_}map{$_->name}@groups unless $name;
                if($name){
                    print "$progress_counter : $name chosen among multiple groups as name for $alt\n";
                    $group->name($name);
                }
            }
            $group->consume(@groups); #gobble other groups and their members, deleting them
            Genome::DruggableGene::GeneNameGroupBridge->create(gene_id => $_->id, gene_name_group_id => $group->id) for @genes_groupless;

            print "$alt added to existing group " . $group->name . "\n" if rand() < .001;
        } else {
            my $name = ''; #only use a name if its the primary name, aka entrez gene symbol
            $name = $alt if grep{$_->nomenclature eq 'entrez_gene_symbol'}@{$alt_to_entrez{$alt}};
            my $group = Genome::DruggableGene::GeneNameGroup->create(name => $name);
            Genome::DruggableGene::GeneNameGroupBridge->create(gene_id => $_->id, gene_name_group_id => $group->id) for @genes;
        }
        $progress_counter++;
        print "Completed $progress_counter, and on $alt\n" if rand() < .001;
    }

    print "Finished $progress_counter. Putting other alternate names into groups\n";
    for my $alt (keys %alt_to_other) {
        my @genes = map{$_->gene_name_report} @{$alt_to_other{$alt}};
        next if @genes > 15;#Ignore alts with more than 15 supposedly synonymous genes

        my @bridges = map{Genome::DruggableGene::GeneNameGroupBridge->get(gene_id => $_->id)}
        grep{Genome::DruggableGene::GeneNameGroupBridge->get(gene_id => $_->id)} @genes;

        my @groups = map{$_->gene_name_group} @bridges;
        @groups = uniq @groups;
        if (@groups) {
            my @genes_groupless = grep{not Genome::DruggableGene::GeneNameGroupBridge->get(gene_id => $_->id)} @genes;
            my $group = shift @groups;
            Genome::DruggableGene::GeneNameGroupBridge->create(gene_id => $_->id, gene_name_group_id => $group->id) for @genes_groupless;
            print "$alt added to existing group " . $group->name . "\n" if rand() < .001;
        } else {
            my $group = Genome::DruggableGene::GeneNameGroup->create(name => $alt);
            Genome::DruggableGene::GeneNameGroupBridge->create(gene_id => $_->id, gene_name_group_id => $group->id) for @genes;
        }
        $progress_counter++;
        print "Completed $progress_counter, and on $alt\n" if rand() < .001;
    }
    print "Finished $progress_counter\n";
    return 1;
}
1;
