package Genome::Model::Command::Build::ImportedAnnotation::Run;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ImportedAnnotation::Run {
    is => 'Genome::Model::Event',
 };

$Workflow::Simple::override_lsf_use=1;

sub sub_command_sort_position { 41 }

sub help_brief {
    "Build for imported annotation  models (not implemented yet => no op)"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given imported annotation database
EOS
}

sub execute {
    my $self = shift;
    $DB::single = 1;
    my $model = $self->model;
    my $source = $model->annotation_source;
    my $build = $self->build;
    my $version = $build->version;
    my $annotation_data_source_directory = $build->annotation_data_source_directory;

    unless (-d $self->build->data_directory){
        $self->create_directory($self->build->data_directory);
    }
    unless (-d $self->build->data_directory) {
        $self->error_message("Failed to create new build dir: " . $self->build->data_directory);
        die;
    }

    if ($source =~ /^genbank$/i){

        my ($flatfile, $genbank_file) = $self->get_genbank_info($version);

        my $command = Genome::Model::Tools::ImportAnnotation::Genbank->create(
            outputdir       => $annotation_data_source_directory,
            version         => $version,
            flatfile        => $flatfile,
            genbank_file    => $genbank_file,
        );
        $command->execute;

        symlink $annotation_data_source_directory, $build->annotation_data_directory;

    }elsif ($source =~ /^ensembl$/i){

        my ($host, $user, $pass) = $self->get_ensembl_info($version);

        my $command = Genome::Model::Tools::ImportAnnotation::Ensembl->create(
            outputdir       => $annotation_data_source_directory,
            ensembl_version => $version,
            host            => $host,
            user            => $user,
            pass            => $pass,
        );
        $command->execute;
            
        symlink $annotation_data_source_directory, $build->annotation_data_directory;

    }elsif ($source =~ /^combined-annotation$/){
        my @from_models = $model->from_models;

        unless (@from_models){
            $self->error_message("no from models composed this combined-annotation model, this is a serious error!");
            die;
        }
        my @from_builds_by_version = map { $_->build_by_version($version) } @from_models;
        
        my $latest_ca_build = $model->last_complete_build;
    
        if ($latest_ca_build){
            my @latest_ca_build_from_builds = $latest_ca_build->from_builds;

            my @latest_ca_build_from_builds_ids = map {$_->build_id} @latest_ca_build_from_builds;
            @latest_ca_build_from_builds_ids = sort {$a <=> $b} @latest_ca_build_from_builds_ids;
            
            my @from_builds_by_version_ids = map {$_->build_id} @from_builds_by_version;
            @from_builds_by_version_ids = sort {$a <=> $b} @from_builds_by_version_ids;

            if ( @from_builds_by_version_ids eq @latest_ca_build_from_builds_ids ){
                $self->error_message("already have a build that contains the latest builds of the models this combined-annotation model is a composite of, skipping!");
                #TODO, do this gracefully
                die; 
            }
        }

        for my $from_build (@from_builds_by_version){
            $build->add_from_build(from_build => $from_build, role => 'member');
        }

        my @test_from_builds = $build->from_builds;
        unless(scalar @test_from_builds eq @from_builds_by_version){
            $self->error_message("didn't successfully add latest from builds to this one!");
            die;
        }
    }

    return 1;
}

sub get_genbank_info
{
    my $self = shift;
    my $version = shift;
    my $gbfile = "/gscmnt/sata363/info/medseq/annotation_data/human.rna.gbff";
    my $flatfile = "/gsc/var/lib/import/entrez/".$version."/Homo_sapiens.agc";
    unless(-f $flatfile)
    {
        die "$flatfile does not exist";
    }
    return ($flatfile,$gbfile);
}

sub get_ensembl_info
{
    my $self = shift;
    my $version = shift;
    my ($eversion,$ncbiversion) = split(/_/,$version);
    my $path = "/gsc/scripts/share/ensembl-".$eversion;
    unless(-d $path)
    {
        die "$path  does not exist, is $eversion for ensembl installed?";
    }

    return ("mysql1","mse",undef); # no pass word needed here. all else const
}

1;
