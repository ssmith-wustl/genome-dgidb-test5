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
    my %alt_to_genes;
    for (Genome::DruggableGene::GeneNameReportAssociation->get) { #operate on all associations, which map genes to alternate names
        next if $_->alternate_name =~ /^.$/;    #ignore single character names
        next if $_->alternate_name =~ /^\d\d$/; #ignore 2 digit names
        push @{ $alt_to_genes{uc($_->alternate_name)} }, $_->gene_name_report;   #Save genes with the same alternate name in an array in a hash with key being the alt-name
    }

    my $progress_counter = 0;

    print "Putting alternate names into groups\n";
    for my $alt (keys %alt_to_genes) {
        my @genes = @{$alt_to_genes{$alt}};
        next if @genes > 15;#Ignore alts with more than 15 supposedly synonymous genes

        my @bridges = map{Genome::DruggableGene::GeneNameGroupBridge->get(gene_name_report_id => $_->id)}
        grep{Genome::DruggableGene::GeneNameGroupBridge->get(gene_name_report_id => $_->id)} @genes;

        my @groups = map{$_->gene_name_group} @bridges;
        @groups = uniq @groups;
        if (@groups) {
            print "Multiple groups for $alt , using first one:\n" . join("\n",map{'*'.$_->name}@groups) . "\n" if @groups > 1;
            my @genes_groupless = grep{not Genome::DruggableGene::GeneNameGroupBridge->get(gene_name_report_id => $_->id)} @genes;

            my $group = shift @groups;
            $group->consume(@groups);
            Genome::DruggableGene::GeneNameGroupBridge->create(gene_name_report_id => $_->id, gene_name_group_id => $group->id) for @genes_groupless;

            print "$alt added to existing group " . $group->name . "\n" if rand() < .001;
        } else {
            my $group = Genome::DruggableGene::GeneNameGroup->create(name => $alt);
            Genome::DruggableGene::GeneNameGroupBridge->create(gene_name_report_id => $_->id, gene_name_group_id => $group->id) for @genes;
        }
        $progress_counter++;
        print "Completed $progress_counter, and on $alt\n" if rand() < .001;
    }
    return 1;
}
1;
