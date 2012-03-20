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
    my %alt_to_other;
    for (Genome::DruggableGene::GeneAlternateNameReport->get) { #operate on all alternate names
        my $alt = $_->alternate_name;
        print "Skipping $alt\n" and next if $alt =~ /^.$/;    #ignore single character names
        print "Skipping $alt\n" and next if $alt =~ /^\d\d$/; #ignore 2 digit names

        #Save genes with the same alternate name in an array in a hash with key being the alt-name
        if($_->nomenclature eq 'entrez_gene_symbol'){
            push @{ $alt_to_entrez{$alt} }, $_;
        } else {
            push @{ $alt_to_other{$alt} }, $_;
        }
    }

    my $progress_counter = 0;

    print "Putting " . scalar(keys(%alt_to_entrez)) . " entrez gene symbol alternate names into groups\n";
    for my $alt (keys %alt_to_entrez) {
        $progress_counter++;
        my @genes = map{$_->gene_name_report} @{$alt_to_entrez{$alt}};
        print "$progress_counter : skipping $alt due to 16+ matches\n" and next if @genes > 15;

        my @groups = Genome::DruggableGene::GeneNameGroup->get(name => $alt); #Existing hugo name groups are used first
        #Next, look at the groups for genes with this alt name
        unshift @groups, map{$_->gene_name_group} map{Genome::DruggableGene::GeneNameGroupBridge->get(gene_id => $_->id)} @genes;
        @groups = uniq @groups;

        if (@groups) {
            my @genes_groupless = grep{not Genome::DruggableGene::GeneNameGroupBridge->get(gene_id => $_->id)} @genes;
            my $group = shift @groups;
            $group->consume(@groups); #gobble other groups and their members, deleting them
            Genome::DruggableGene::GeneNameGroupBridge->create(gene_id => $_->id, gene_name_group_id => $group->id) for @genes_groupless;
            print "$progress_counter : found existing group " . $group->name . " for $alt\n" if rand() < .001;
        } else {
            my $group = Genome::DruggableGene::GeneNameGroup->create(name => $alt);
            Genome::DruggableGene::GeneNameGroupBridge->create(gene_id => $_->id, gene_name_group_id => $group->id) for @genes;
            print "$progress_counter : created new group for $alt\n" if rand() < .001;
        }
    }

    print "\n****\nFinished $progress_counter. Now processing " . scalar(keys(%alt_to_other)) . " other alternate names\n****\n\n";

    $progress_counter = 0;
    my $no_group_count = 0;
    for my $alt (keys %alt_to_other) {
        $progress_counter++;
        my @genes = map{$_->gene_name_report} @{$alt_to_other{$alt}};
        print "$progress_counter : skipping $alt due to 16+ matches\n" and next if @genes > 15;

        my @groups = Genome::DruggableGene::GeneNameGroup->get(name => $alt); #Existing hugo name groups are used first
        #Next, look at the groups for genes with this alt name
        unshift @groups, map{$_->gene_name_group} map{Genome::DruggableGene::GeneNameGroupBridge->get(gene_id => $_->id)} @genes;
        @groups = uniq @groups;

        if (@groups) {
            my @genes_groupless = grep{not Genome::DruggableGene::GeneNameGroupBridge->get(gene_id => $_->id)} @genes;
            my $group = shift @groups;
            Genome::DruggableGene::GeneNameGroupBridge->create(gene_id => $_->id, gene_name_group_id => $group->id) for @genes_groupless;
            print "$progress_counter : found existing group " . $group->name . " for $alt\n" if rand() < .001 || $alt eq 'FLT3';
        } else {
            $no_group_count++;
            print "$progress_counter : $alt failed to find any hugo group - it joins the ranks of $no_group_count others\n" if rand() < .001 || $alt eq 'FTL3';
        }
    }
    print "Finished $progress_counter with $no_group_count that didn't fit into any hugo group\n";
    return 1;
}
1;
