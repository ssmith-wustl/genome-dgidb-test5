package Genome::Model::Command::Build::CombineVariants::DeriveAssemblyNames; 
use strict;
use warnings;
use Genome;
use File::Copy "cp";


class Genome::Model::Command::Build::CombineVariants::DeriveAssemblyNames {
    is => 'Genome::Model::Event',
};

sub help_brief {
    "Derives assembly names from a list of genes for a research project",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt combine-variants derive-assembly-names 
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;
    my %p = @_;

    my @genes = split(',', $self->model->processing_profile->limit_genes_to);

    # FIXME This should be removed once we somehow integrate code that will grab all assemblies for a research project
    unless (@genes) {
        $self->error_message("No genes specified in limit_genes_to of processing profile. This is currently requred. Bailing out.");
        return;
    }
    
    my $research_project = $self->model->subject_name;

    # TODO Get all assemblies that concern this research project here...
    my @assemblies_for_research_project;
    my %assemblies_for_genes;
    # If genes are specified... get all assemblies for the genes specifid
    for my $gene_name (@genes){
        my $gene = GSC::Gene->get(gene_name => $gene_name);

        my @roi = GSC::AmplificationRoi->get(region_of_interest_seq_id => $gene->ref_seq_id );

        my %asp_ids;
        for my $r (@roi) {
            my @bridge = GSC::RoiAssemblyProject->get(amplification_roi_id => $r->id);
            for(@bridge) {
                $asp_ids{$_->asp_id}++;
            }
        }

        for my $asp_id (sort {$a <=> $b} keys %asp_ids){
            my $asp = GSC::AssemblyProject->get(asp_id => $asp_id, assembly_type => 'assemble by amplicon with overlapping amplicons for a project');

            unless($asp) {
                #$self->error_message("Could not get GSC::AssemblyProject for asp_id $asp_id, skipping\n");
                next;
            }

            $assemblies_for_genes{$asp->assembly_project_name}++;
        }
    }

    # If we are limiting by genes... grab all assemblies in the research project in those genes
    my @assembly_intersection;
    if (@genes) {
        # FIXME... this is what we want to do when we can get all assemblies for a research project...
        # But since we cant just grab all stuff for genes
        #@assembly_intersection = grep( $assemblies_for_genes{$_}, @assemblies_for_research_project);
        @assembly_intersection = keys %assemblies_for_genes;
    } else {
        @assembly_intersection = @assemblies_for_research_project;
    }

    my $outfile = $self->build->assemblies_to_run_file;
    my $assembly_fh = IO::File->new(">$outfile");

    unless ($assembly_fh) {
        $self->error_message("Could not open file handle to $outfile");
        return; 
    }
    print $assembly_fh join("\n", @assembly_intersection);
    $assembly_fh->close;

    unless (-s $outfile) {
        $self->error_message("Could not create assemblies_to_run_file $outfile or file is 0 size");
        return;
    }
    
    return @assembly_intersection;
}

1;

