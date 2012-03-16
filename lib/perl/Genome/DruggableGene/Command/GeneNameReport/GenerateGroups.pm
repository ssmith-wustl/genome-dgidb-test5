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

sub load {
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

    return \%alt_to_entrez, \%alt_to_other;
}

sub create_groups {
    my $self = shift;
    my $alt_to_entrez = shift;
    my $progress_counter = 0;

    print "Putting " . scalar(keys(%{$alt_to_entrez})) . " entrez gene symbol hugo names into groups\n";
    for my $alt (keys %{$alt_to_entrez}) {
        $progress_counter++;
        my @genes = map{$_->gene_name_report} @{$alt_to_entrez->{$alt}};

        next if Genome::DruggableGene::GeneNameGroup->get(name => $alt); #hugo name group already exists

        my $group = Genome::DruggableGene::GeneNameGroup->create(name => $alt);
        Genome::DruggableGene::GeneNameGroupBridge->create(gene_id => $_->id, gene_name_group_id => $group->id) for @genes;

        print "$progress_counter : created new group for $alt\n" if rand() < .001;
    }

    print "\n****\nFinished $progress_counter.\n****\n\n";
}

sub add_members {
    my $self = shift;
    my $alt_to_other = shift;
    print "Now processing " . scalar(keys(%{$alt_to_other})) . " other alternate names";

    for my $gene (Genome::DruggableGene::GeneNameReport->get){
        next if Genome::DruggableGene::GeneNameGroupBridge->get(gene_id => $gene->id); #if already in a group


        my %groups;#track how times alternate names are associated with each group
        my %hugo_groups;#track how many alternate names are hugo names, identical to preexisting group names

        $hugo_groups{$gene->name}++ if Genome::DruggableGene::GeneNameGroup->get(name=>$gene->name); #go genes for instance have hugo names

        for my $alt($gene->alternate_names){
            $hugo_groups{$alt}++ if Genome::DruggableGene::GeneNameGroup->get(name=>$alt);

            my @alt_genes = map{$_->gene_name_report} @{$alt_to_other->{$alt}};
            for my $alt_gene (@alt_genes){
                $groups{Genome::DruggableGene::GeneNameGroupBridge->get(gene_id => $alt_gene->id)->gene_name_group->name}++;
            }
        }

        my @potential_hugo_groups;
        my @potential_groups;
        while (my ($group_name, $count) = each %hugo_groups){
            push @potential_hugo_groups, $group_name if $count == 1;
        }
        if(@potential_hugo_groups == 1){
            my ($group_name) = @potential_hugo_groups;
            my $group_id = Genome::DruggableGene::GeneNameGroup->get(name=>$group_name)->id;
            Genome::DruggableGene::GeneNameGroupBridge->create(gene_id => $gene->id, gene_name_group_id => $group_id);
            next;
        }

        while (my ($group_name, $count) = each %groups){
            push @potential_groups, $group_name if $count == 1;
        }
        if(@potential_groups == 1){
            my ($group_name) = @potential_groups;
            my $group_id = Genome::DruggableGene::GeneNameGroup->get(name=>$group_name)->id;
            Genome::DruggableGene::GeneNameGroupBridge->create(gene_id => $gene->id, gene_name_group_id => $group_id);
            next;
        }
    }
}

sub execute {
    my $self = shift;

    my ($alt_to_entrez, $alt_to_other) = $self->load();
    $self->create_groups($alt_to_entrez);
    $self->add_members($alt_to_other);

    return 1;
}
1;
