package Genome::Model::Event::Build::ImportedAnnotation::Run;

use strict;
use warnings;

use Genome;
use Carp;

class Genome::Model::Event::Build::ImportedAnnotation::Run {
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
    my $build = $self->build;

    my $source = $model->annotation_source;
    confess "Could not get imported annotation source!" unless defined $source;

    my $version = $build->version;
    confess "Could not get build version!" unless defined $version;

    my $data_directory = $self->build->data_directory;
    confess "Could not get data directory for build!" unless defined $data_directory;
    unless (-d $data_directory){
        $self->create_directory($self->build->data_directory);
    }
    unless (-d $data_directory) {
        $self->error_message("Failed to create new build dir: " . $self->build->data_directory);
        confess;
    }

    my $log_file = $data_directory . "/" . $source . "_import.log";
    my $dump_file = $data_directory . "/" . $source . "_import.dump";

    if ($source =~ /^genbank$/i) {
        my ($flatfile, $genbank_file) = $self->get_genbank_info($version);

        my $annotation_data_source_directory = $build->annotation_data_source_directory;
        confess "Could not determine annotation data source directory!" unless defined $annotation_data_source_directory;
        
        my $command = Genome::Model::Tools::ImportAnnotation::Genbank->create(
            data_directory => $annotation_data_source_directory,
            version => $version,
            flatfile => $flatfile,
            genbank_file => $genbank_file,
            species => $model->species_name,
            log_file => $log_file,
            dump_file => $dump_file,
        );
        $self->status_message("Executing genbank import!");
        my $rv = $command->execute;
        confess "Trouble executing genbank import process!" unless $rv;

        my $annotation_data_directory = $build->_annotation_data_directory;
        confess "Could not get annotation data directory for build" unless defined $annotation_data_directory;
        my $sym_rv = symlink $annotation_data_source_directory, $annotation_data_directory;
        confess "Could not create symlink from $annotation_data_source_directory to $annotation_data_directory" unless $sym_rv;
    }
    elsif ($source =~ /^ensembl$/i) {
        my ($host, $user, $pass) = $self->get_ensembl_info($version);

        my $annotation_data_source_directory = $build->annotation_data_source_directory;
        confess "Could not determine annotation data source directory!" unless defined $annotation_data_source_directory;

        my $command = Genome::Model::Tools::ImportAnnotation::Ensembl->create(
            data_directory  => $annotation_data_source_directory,
            version         => $version,
            host            => $host,
            user            => $user,
            pass            => $pass,
            species         => $model->species_name,
            log_file        => $log_file,
            dump_file       => $dump_file,
        );
        $command->execute;
            
        my $annotation_data_directory = $build->_annotation_data_directory;
        confess "Could not get annotation data directory for build" unless $annotation_data_directory;
        my $sym_rv = symlink $annotation_data_source_directory, $annotation_data_directory;
        confess "Could not create symlink from $annotation_data_source_directory to $annotation_data_directory" unless $sym_rv;

    }
    elsif ($source =~ /^combined-annotation$/) {
        # Grab composite builds for this version from other imported annotation models
        my @from_models = $model->from_models;
        confess "Combined Annotation models should be composed of other models, but none were found!" unless @from_models;
        my @from_builds_by_version = map { $_->build_by_version($version) } @from_models;

        # Check that there isn't already a combined annotation build for this version
        my @ca_builds = grep { $_->version eq $version } $model->succeeded_builds;
        if (@ca_builds) {
            confess "There are previous combined annotation builds with version $version!\n" . 
                    join("\n", map { $_->build_id } @ca_builds);
        }

        # Set up and test from builds links
        for my $from_build (@from_builds_by_version){
            $build->add_from_build(from_build => $from_build, role => 'member');
        }

        my @test_from_builds = $build->from_builds;
        unless(scalar @test_from_builds eq @from_builds_by_version){
            confess "Didn't successfully add latest from builds to this one!";
        }

        #TODO: grab and merge annotation data from the component builds
    }

    return 1;
}

sub get_genbank_info {
    my $self = shift;
    my $version = shift;
    my $species = $self->model->species_name;
    $self->status_message("Getting genbank files for species $species and version $version");

    my $annotation_dir = "/gsc/var/lib/import/entrez/$species/$version";
    confess "Could not find annotation directory $annotation_dir" unless -d $annotation_dir;

    my ($gbfile, $flatfile);
    if ($species eq 'human') {
        $gbfile = "$annotation_dir/human.rna.gbff";
        $flatfile = "$annotation_dir/Homo_sapiens.agc";
    }
    elsif ($species eq 'mouse') {
        $gbfile = "$annotation_dir/mouse.rna.gbff";
        $flatfile = "$annotation_dir/Mus_musculus.agc";
    }

    confess "Genbank flatfile $flatfile does not exist!" unless -e $flatfile;
    confess "Genbank gbff file $gbfile does not exist!" unless -e $gbfile;

    $self->status_message("Using genbank flatfile $flatfile and gbff file $gbfile");
    return ($flatfile,$gbfile);
}

sub get_ensembl_info {
    my $self = shift;
    my $version = shift;
    my ($eversion,$ncbiversion) = split(/_/,$version);
    my $path = "/gsc/scripts/share/ensembl-".$eversion;

    unless(-d $path) {
        die "$path  does not exist, is $eversion for ensembl installed?";
    }

    return ("mysql1","mse",undef); # no pass word needed here. all else const
}

1;
